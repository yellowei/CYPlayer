//
//  shaders.metal
//  LearnMetal
//
//  Created by loyinglin on 2018/6/21.
//  Copyright © 2018年 loyinglin. All rights reserved.
//

#include <metal_stdlib>
#import "CYPlayerMetalShaders.h"

using namespace metal;


kernel void yuvToRGB(texture2d<float, access::read> y_inTexture [[ texture(0) ]],
                     texture2d<float, access::read> uv_inTexture [[ texture(1) ]],
                     texture2d<float, access::write> outTexture [[ texture(2) ]],
                     uint2 gid [[ thread_position_in_grid ]]) {
    float4 yFloat4 = y_inTexture.read(gid);
    float4 uvFloat4 = uv_inTexture.read(gid/2);
    float y = yFloat4.x;
    float u = uvFloat4.x - 0.5;
    float v = uvFloat4.y - 0.5;

    float r = y + 1.403 * v;
    r = (r < 0.0) ? 0.0 : ((r > 1.0) ? 1.0 : r);
    float g = y - 0.343 * u - 0.714 * v;
    g = (g < 0.0) ? 0.0 : ((g > 1.0) ? 1.0 : g);
    float b = y + 1.770 * u;
    b = (b < 0.0) ? 0.0 : ((b > 1.0) ? 1.0 : b);
    outTexture.write(float4(r, g, b, 1.0), gid);
}


typedef struct
{
    float4 clipSpacePosition [[position]]; // position的修饰符表示这个是顶点
    
    float2 textureCoordinate; // 纹理坐标，会做插值处理
    
} RasterizerData;

vertex RasterizerData // 返回给片元着色器的结构体
vertexShader(uint vertexID [[ vertex_id ]], // vertex_id是顶点shader每次处理的index，用于定位当前的顶点
             constant CYVertex *vertexArray [[ buffer(CYVertexInputIndexVertices) ]]) { // buffer表明是缓存数据，0是索引
    RasterizerData out;
    out.clipSpacePosition = vertexArray[vertexID].position;
    out.textureCoordinate = vertexArray[vertexID].textureCoordinate;
    return out;
}

fragment float4
samplingShader(RasterizerData input [[stage_in]], // stage_in表示这个数据来自光栅化。（光栅化是顶点处理之后的步骤，业务层无法修改）
               texture2d<float> textureY [[ texture(CYFragmentTextureIndexTextureY) ]], // texture表明是纹理数据，LYFragmentTextureIndexTextureY是索引
               texture2d<float> textureUV [[ texture(CYFragmentTextureIndexTextureUV) ]], // texture表明是纹理数据，LYFragmentTextureIndexTextureUV是索引
               constant CYConvertMatrix *convertMatrix [[ buffer(CYFragmentInputIndexMatrix) ]]) //buffer表明是缓存数据，LYFragmentInputIndexMatrix是索引
{
    constexpr sampler textureSampler (mag_filter::linear,
                                      min_filter::linear); // sampler是采样器
    
    float3 yuv = float3(textureY.sample(textureSampler, input.textureCoordinate).r,
                          textureUV.sample(textureSampler, input.textureCoordinate).rg);
    
    float3 rgb = convertMatrix->matrix * (yuv + convertMatrix->offset);
        
    return float4(rgb, 1.0);
}
