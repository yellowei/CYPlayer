//
//  CYPlayerGLView.m
//  cyplayer
//
//  Created by yellowei on 22.10.12.
//  Copyright (c) 2018 yellowei . All rights reserved.
//
//  https://github.com/yellowei/cyplayer
//  this file is part of CYPlayer
//  CYPlayer is licenced under the LGPL v3, see lgpl-3.0.txt

#import "CYPlayerGLView.h"
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import "CYPlayerDecoder.h"
#import "CYLogger.h"

//////////////////////////////////////////////////////////

#pragma mark - shaders

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

NSString *const vertexShaderString = SHADER_STRING
(
 attribute vec4 position;
 attribute vec2 texcoord;
 uniform mat4 modelViewProjectionMatrix;
 varying vec2 v_texcoord;
 
 void main()
 {
     gl_Position = modelViewProjectionMatrix * position;
     v_texcoord = texcoord.xy;
 }
);

NSString *const rgbFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 uniform sampler2D s_texture;
 
 void main()
 {
     gl_FragColor = texture2D(s_texture, v_texcoord);
 }
);

NSString *const yuvFragmentShaderString = SHADER_STRING
(
 varying highp vec2 v_texcoord;
 uniform sampler2D s_texture_y;
 uniform sampler2D s_texture_u;
 uniform sampler2D s_texture_v;
 
 void main()
 {
     highp float y = texture2D(s_texture_y, v_texcoord).r;
     highp float u = texture2D(s_texture_u, v_texcoord).r - 0.5;
     highp float v = texture2D(s_texture_v, v_texcoord).r - 0.5;
     
     highp float r = y +             1.402 * v;
     highp float g = y - 0.344 * u - 0.714 * v;
     highp float b = y + 1.772 * u;
     
     gl_FragColor = vec4(r,g,b,1.0);     
 }
);

static BOOL validateProgram(GLuint prog)
{
	GLint status;
	
    glValidateProgram(prog);
    
#ifdef DEBUG
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        LoggerVideo(1, @"Program validate log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == GL_FALSE) {
		LoggerVideo(0, @"Failed to validate program %d", prog);
        return NO;
    }
	
	return YES;
}

static GLuint compileShader(GLenum type, NSString *shaderString)
{
	GLint status;
	const GLchar *sources = (GLchar *)shaderString.UTF8String;
	
    GLuint shader = glCreateShader(type);
    if (shader == 0 || shader == GL_INVALID_ENUM) {
        LoggerVideo(0, @"Failed to create shader %d", type);
        return 0;
    }
    
    glShaderSource(shader, 1, &sources, NULL);
    glCompileShader(shader);
	
#ifdef DEBUG
	GLint logLength;
    glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0)
    {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(shader, logLength, &logLength, log);
        LoggerVideo(1, @"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(shader, GL_COMPILE_STATUS, &status);
    if (status == GL_FALSE) {
        glDeleteShader(shader);
		LoggerVideo(0, @"Failed to compile shader:\n");
        return 0;
    }
    
	return shader;
}

static void mat4f_LoadOrtho(float left, float right, float bottom, float top, float near, float far, float* mout)
{
	float r_l = right - left;
	float t_b = top - bottom;
	float f_n = far - near;
	float tx = - (right + left) / (right - left);
	float ty = - (top + bottom) / (top - bottom);
	float tz = - (far + near) / (far - near);
    
	mout[0] = 2.0f / r_l;
	mout[1] = 0.0f;
	mout[2] = 0.0f;
	mout[3] = 0.0f;
	
	mout[4] = 0.0f;
	mout[5] = 2.0f / t_b;
	mout[6] = 0.0f;
	mout[7] = 0.0f;
	
	mout[8] = 0.0f;
	mout[9] = 0.0f;
	mout[10] = -2.0f / f_n;
	mout[11] = 0.0f;
	
	mout[12] = tx;
	mout[13] = ty;
	mout[14] = tz;
	mout[15] = 1.0f;
}

//////////////////////////////////////////////////////////

#pragma mark - frame renderers

@protocol CYPlayerGLRenderer
- (BOOL) isValid;
- (NSString *) fragmentShader;
- (void) resolveUniforms: (GLuint) program;
- (void) setFrame: (CYVideoFrame *) frame;
- (BOOL) prepareRender;
@end

@interface CYPlayerGLRenderer_RGB : NSObject<CYPlayerGLRenderer> {
    
    GLint _uniformSampler;
    GLuint _texture;
}
@end

@implementation CYPlayerGLRenderer_RGB

- (BOOL) isValid
{
    return (_texture != 0);
}

- (NSString *) fragmentShader
{
    return rgbFragmentShaderString;
}

- (void) resolveUniforms: (GLuint) program
{
    _uniformSampler = glGetUniformLocation(program, "s_texture");
}

- (void) setFrame: (CYVideoFrame *) frame
{
    CYVideoFrameRGB *rgbFrame = (CYVideoFrameRGB *)frame;
   
    assert(rgbFrame.rgb.length == rgbFrame.width * rgbFrame.height * 3);

    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    if (0 == _texture)
        glGenTextures(1, &_texture);
    
    glBindTexture(GL_TEXTURE_2D, _texture);
    
    glTexImage2D(GL_TEXTURE_2D,
                 0,
                 GL_RGB,
                 (int)(frame.width),
                 (int)(frame.height),
                 0,
                 GL_RGB,
                 GL_UNSIGNED_BYTE,
                 rgbFrame.rgb.bytes);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

- (BOOL) prepareRender
{
    if (_texture == 0)
        return NO;
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _texture);
    glUniform1i(_uniformSampler, 0);
    
    return YES;
}

- (void) dealloc
{
    if (_texture) {
        glDeleteTextures(1, &_texture);
        _texture = 0;
    }
}

@end

@interface CYPlayerGLRenderer_YUV : NSObject<CYPlayerGLRenderer> {
    
    GLint _uniformSamplers[3];
    GLuint _textures[3];
}
@end

@implementation CYPlayerGLRenderer_YUV

- (BOOL) isValid
{
    return (_textures[0] != 0);
}

- (NSString *) fragmentShader
{
    return yuvFragmentShaderString;
}

- (void) resolveUniforms: (GLuint) program
{
    _uniformSamplers[0] = glGetUniformLocation(program, "s_texture_y");
    _uniformSamplers[1] = glGetUniformLocation(program, "s_texture_u");
    _uniformSamplers[2] = glGetUniformLocation(program, "s_texture_v");
}

- (void) setFrame: (CYVideoFrame *) frame
{
    if (![frame isKindOfClass:[CYVideoFrameYUV class]]) {
        return;
    }
    CYVideoFrameYUV *yuvFrame = (CYVideoFrameYUV *)frame;

    assert(yuvFrame.luma.length == yuvFrame.bytesPerRowOfPlans.yBytes * yuvFrame.height);
    assert(yuvFrame.chromaB.length == ((yuvFrame.bytesPerRowOfPlans.cbBytes) * (yuvFrame.height / 2)));
    assert(yuvFrame.chromaR.length == ((yuvFrame.bytesPerRowOfPlans.crBytes) * (yuvFrame.height / 2)));

//    const NSUInteger frameWidth = frame.width;
    const NSUInteger frameHeight = frame.height;    
    
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    
    if (0 == _textures[0])
        glGenTextures(3, _textures);

    const UInt8 *pixels[3] = { yuvFrame.luma.bytes, yuvFrame.chromaB.bytes, yuvFrame.chromaR.bytes };
    const GLsizei widths[3]  = { (GLsizei)(yuvFrame.bytesPerRowOfPlans.yBytes), (GLsizei)(yuvFrame.bytesPerRowOfPlans.cbBytes), (GLsizei)(yuvFrame.bytesPerRowOfPlans.crBytes) };
    const GLsizei heights[3] = { (GLsizei)frameHeight, (GLsizei)(frameHeight / 2), (GLsizei)(frameHeight / 2) };
    
    for (int i = 0; i < 3; ++i) {

        glBindTexture(GL_TEXTURE_2D, _textures[i]);

        glTexImage2D(GL_TEXTURE_2D,
                     0,
                     GL_LUMINANCE,
                     widths[i],
                     heights[i],
                     0,
                     GL_LUMINANCE,
                     GL_UNSIGNED_BYTE,
                     pixels[i]);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
}

- (BOOL) prepareRender
{
    if (_textures[0] == 0)
        return NO;
    
    for (int i = 0; i < 3; ++i) {
        glActiveTexture(GL_TEXTURE0 + i);
        glBindTexture(GL_TEXTURE_2D, _textures[i]);
        glUniform1i(_uniformSamplers[i], i);
    }
    
    return YES;
}

- (void) dealloc
{
    if (_textures[0])
        glDeleteTextures(3, _textures);
}

@end

//////////////////////////////////////////////////////////

#pragma mark - gl view

enum {
	ATTRIBUTE_VERTEX,
   	ATTRIBUTE_TEXCOORD,
};

@implementation CYPlayerGLView {
    
    CYPlayerDecoder  *_decoder;
    EAGLContext     *_context;
    GLuint          _framebuffer;
    GLuint          _renderbuffer;
    GLint           _backingWidth;
    GLint           _backingHeight;
    GLuint          _program;
    GLint           _uniformMatrix;
    GLfloat         _vertices[8];
    
    id<CYPlayerGLRenderer> _renderer;
    
    dispatch_semaphore_t _glRenderLock;
}

+ (Class) layerClass
{
	return [CAEAGLLayer class];
}

- (id) initWithFrame:(CGRect)frame
             decoder: (CYPlayerDecoder *) decoder
{
    self = [super initWithFrame:frame];
    if (self) {
        
        _glRenderLock = dispatch_semaphore_create(1);//初始化锁
        
        _decoder = decoder;
        
        if ([decoder setupVideoFrameFormat:CYVideoFrameFormatYUV]) {
            
            _renderer = [[CYPlayerGLRenderer_YUV alloc] init];
            LoggerVideo(1, @"OK use YUV GL renderer");
            
        } else {
            
            _renderer = [[CYPlayerGLRenderer_RGB alloc] init];
            LoggerVideo(1, @"OK use RGB GL renderer");
        }
                
        CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:FALSE], kEAGLDrawablePropertyRetainedBacking,
                                        kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat,
                                        nil];
        
        _context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        
        if (!_context ||
            ![EAGLContext setCurrentContext:_context]) {
            
            LoggerVideo(0, @"failed to setup EAGLContext");
            self = nil;
            return nil;
        }
        
        //创建纹理
        
        //加载着色器
        [self createFrameAndRenderBuffer];
//        glGenFramebuffers(1, &_framebuffer);
//        glGenRenderbuffers(1, &_renderbuffer);
//        glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
//        glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
//        [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
//        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
//        glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
//        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
        
        GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
        if (status != GL_FRAMEBUFFER_COMPLETE) {
            
            LoggerVideo(0, @"failed to make complete framebuffer object %x", status);
            self = nil;
            return nil;
        }
        
        GLenum glError = glGetError();
        if (GL_NO_ERROR != glError) {
            
            LoggerVideo(0, @"failed to setup GL %x", glError);
            self = nil;
            return nil;
        }
                
        if (![self loadShaders]) {
            
            self = nil;
            return nil;
        }
        
        _vertices[0] = -1.0f;  // x0
        _vertices[1] = -1.0f;  // y0
        _vertices[2] =  1.0f;  // ..
        _vertices[3] = -1.0f;
        _vertices[4] = -1.0f;
        _vertices[5] =  1.0f;
        _vertices[6] =  1.0f;  // x3
        _vertices[7] =  1.0f;  // y3
        
        LoggerVideo(1, @"OK setup GL");
    }
    
    return self;
}

- (void)setDecoder:(CYPlayerDecoder *)decoder
{
    _decoder = decoder;
}

- (UIImage *)makeImageWithView:(UIView *)view withSize:(CGSize)size
{

    // 下面方法，第一个参数表示区域大小。第二个参数表示是否是非透明的。如果需要显示半透明效果，需要传NO，否则传YES。第三个参数就是屏幕密度了，关键就是第三个参数 [UIScreen mainScreen].scale。
    UIGraphicsBeginImageContextWithOptions(size, NO, 1.0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

+ (UIImage *)imageFromView:(UIView *)view{
    
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, 0.0);
    
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    
    UIImage *theImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    return theImage;
    
}

- (UIImage*)snapshot
{
    if (@available(iOS 13.0, *)) {
        
        return [CYPlayerGLView imageFromView:self];
        
    }else {
        GLint x = 0, y = 0, width = _backingWidth, height = _backingHeight;
        
        NSInteger dataLength = width * height * 4;
        
        GLubyte *data = (GLubyte*)malloc(dataLength * sizeof(GLubyte));
        
        // Read pixel data from the framebuffer
        
        glPixelStorei(GL_PACK_ALIGNMENT, 4);
        
        glReadPixels(x, y, width, height, GL_RGBA, GL_UNSIGNED_BYTE, data);
        
        // Create a CGImage with the pixel data
        
        // If your OpenGL ES content is opaque, use kCGImageAlphaNoneSkipLast to ignore the alpha channel
        
        // otherwise, use kCGImageAlphaPremultipliedLast
        
        CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
        
        CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
        
        CGImageRef iref = CGImageCreate(width, height, 8, 32, width * 4, colorspace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
                                            
                                            ref, NULL, true, kCGRenderingIntentDefault);
        
        // OpenGL ES measures data in PIXELS
        
        // Create a graphics context with the target size measured in POINTS
        
        NSInteger widthInPoints, heightInPoints;
        
        if (@available(iOS 4.0, *)) {
            
            // On iOS 4 and later, use UIGraphicsBeginImageContextWithOptions to take the scale into consideration
            
            // Set the scale parameter to your OpenGL ES view's contentScaleFactor
            
            // so that you get a high-resolution snapshot when its value is greater than 1.0
            
            CGFloat scale = self.contentScaleFactor;
            
            widthInPoints = width / scale;
            
            heightInPoints = height / scale;
            
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(widthInPoints, heightInPoints), NO, scale);
            
            }
        
        else {
            
            // On iOS prior to 4, fall back to use UIGraphicsBeginImageContext
            
            widthInPoints = width;
            heightInPoints = height;
            UIGraphicsBeginImageContext(CGSizeMake(widthInPoints, heightInPoints));
            
            }
        
        CGContextRef cgcontext = UIGraphicsGetCurrentContext();
        // UIKit coordinate system is upside down to GL/Quartz coordinate system
        // Flip the CGImage by rendering it to the flipped bitmap context
        
        // The size of the destination area is measured in POINTS
        CGContextSetBlendMode(cgcontext, kCGBlendModeCopy);
        CGContextDrawImage(cgcontext, CGRectMake(0.0, 0.0, widthInPoints, heightInPoints), iref);
        // Retrieve the UIImage from the current context
        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        // Clean up
        free(data);
        CFRelease(ref);
        CFRelease(colorspace);
        CGImageRelease(iref);
        return image;
    }
}

- (BOOL)createFrameAndRenderBuffer
{
    //创建帧缓冲绑定
    glGenFramebuffers(1, &_framebuffer);
    //创建渲染缓冲
    glGenRenderbuffers(1, &_renderbuffer);
    
    //将之前用glGenFramebuffers创建的帧缓冲绑定为当前的Framebuffer(绑定到context上？).
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    //Renderbuffer绑定到context上,此时当前Framebuffer完全由renderbuffer控制
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    
    //分配空间
    if (![_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer])
    {
        NSLog(@"attach渲染缓冲区失败");
    }
    
    //这个函数看起来有点复杂，但其实它很好理解的。它要做的全部工作就是把把前面我们生成的深度缓存对像与当前的FBO对像进行绑定，当然我们要注意一个FBO有多个不同绑定点，这里是要绑定在FBO的深度缓冲绑定点上。
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderbuffer);
    
    //检查当前帧缓存的关联图像和帧缓存参数
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"创建缓冲区错误 0x%x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    return YES;
}

- (void)destoryFrameAndRenderBuffer
{
    if (_framebuffer)
    {
        //删除FBO
        glDeleteFramebuffers(1, &_framebuffer);
    }
    
    if (_renderbuffer)
    {
        //删除渲染缓冲区
        glDeleteRenderbuffers(1, &_renderbuffer);
    }
    
    _framebuffer = 0;
    _renderbuffer = 0;
}

- (void)dealloc
{
    _renderer = nil;

    if (_framebuffer) {
        glDeleteFramebuffers(1, &_framebuffer);
        _framebuffer = 0;
    }
    
    if (_renderbuffer) {
        glDeleteRenderbuffers(1, &_renderbuffer);
        _renderbuffer = 0;
    }
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
	
	if ([EAGLContext currentContext] == _context) {
		[EAGLContext setCurrentContext:nil];
	}
    
	_context = nil;
}

- (void)layoutSubviews
{
    [self destoryFrameAndRenderBuffer];
    [self createFrameAndRenderBuffer];
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer*)self.layer];
	glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &_backingWidth);
    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &_backingHeight);
	
    GLenum status = glCheckFramebufferStatus(GL_FRAMEBUFFER);
	if (status != GL_FRAMEBUFFER_COMPLETE) {
		
        LoggerVideo(0, @"failed to make complete framebuffer object %x", status);
        
	} else {
        
        LoggerVideo(1, @"OK setup GL framebuffer %d:%d", _backingWidth, _backingHeight);
    }
    
    [self updateVertices];
    [self render: nil];
}

- (void)setContentMode:(UIViewContentMode)contentMode
{
    [super setContentMode:contentMode];
    [self updateVertices];
    if (_renderer.isValid)
        [self render:nil];
}

- (BOOL)loadShaders
{
    BOOL result = NO;
    GLuint vertShader = 0, fragShader = 0;
    
    //创建程序容器
	_program = glCreateProgram();
	
   //编译着色
    vertShader = compileShader(GL_VERTEX_SHADER, vertexShaderString);
	if (!vertShader)
        goto exit;
    
	fragShader = compileShader(GL_FRAGMENT_SHADER, _renderer.fragmentShader);
    if (!fragShader)
        goto exit;
    //绑定shader到program

	glAttachShader(_program, vertShader);
	glAttachShader(_program, fragShader);
	glBindAttribLocation(_program, ATTRIBUTE_VERTEX, "position");
    glBindAttribLocation(_program, ATTRIBUTE_TEXCOORD, "texcoord");
	
	glLinkProgram(_program);
    
    GLint status;
    glGetProgramiv(_program, GL_LINK_STATUS, &status);
    if (status == GL_FALSE) {
		LoggerVideo(0, @"Failed to link program %d", _program);
        goto exit;
    }
    
    result = validateProgram(_program);
        
    _uniformMatrix = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    [_renderer resolveUniforms:_program];
	
exit:
    
    if (vertShader)
        glDeleteShader(vertShader);
    if (fragShader)
        glDeleteShader(fragShader);
    
    if (result) {
        
        LoggerVideo(1, @"OK setup GL programm");
        
    } else {
        
        glDeleteProgram(_program);
        _program = 0;
    }
    
    return result;
}

- (void)updateVertices
{
    const BOOL fit      = (self.contentMode == UIViewContentModeScaleAspectFit);
    const float width   = _decoder.frameWidth;
    const float height  = _decoder.frameHeight;
    const float dH      = (float)_backingHeight / height;
    const float dW      = (float)_backingWidth	  / width;
    const float dd      = fit ? MIN(dH, dW) : MAX(dH, dW);
    const float h       = (height * dd / (float)_backingHeight);
    const float w       = (width  * dd / (float)_backingWidth );
    
    _vertices[0] = - w;
    _vertices[1] = - h;
    _vertices[2] =   w;
    _vertices[3] = - h;
    _vertices[4] = - w;
    _vertices[5] =   h;
    _vertices[6] =   w;
    _vertices[7] =   h;
}

- (void)render: (CYVideoFrame *) frame
{
    dispatch_semaphore_wait(self->_glRenderLock, DISPATCH_TIME_FOREVER);//加锁
    static const GLfloat texCoords[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
	
    [EAGLContext setCurrentContext:_context];
    
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glViewport(0, 0, _backingWidth, _backingHeight);
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
	glUseProgram(_program);
        
    if (frame) {
        [_renderer setFrame:frame];
    }
    
    if ([_renderer prepareRender]) {
        
        GLfloat modelviewProj[16];
        mat4f_LoadOrtho(-1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f, modelviewProj);
        glUniformMatrix4fv(_uniformMatrix, 1, GL_FALSE, modelviewProj);
        
        glVertexAttribPointer(ATTRIBUTE_VERTEX, 2, GL_FLOAT, 0, 0, _vertices);
        glEnableVertexAttribArray(ATTRIBUTE_VERTEX);
        glVertexAttribPointer(ATTRIBUTE_TEXCOORD, 2, GL_FLOAT, 0, 0, texCoords);
        glEnableVertexAttribArray(ATTRIBUTE_TEXCOORD);
        
    #if 0
        if (!validateProgram(_program))
        {
            LoggerVideo(0, @"Failed to validate program");
            return;
        }
    #endif
        
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);        
    }
    
    glBindRenderbuffer(GL_RENDERBUFFER, _renderbuffer);
    [_context presentRenderbuffer:GL_RENDERBUFFER];
    dispatch_semaphore_signal(self->_glRenderLock);//放行
}

@end
