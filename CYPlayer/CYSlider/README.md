# CYSlider
滑块视图    
```Ruby   
    pod 'CYSlider'    
```    
___

### 进度(支持 AutoLayout)
<img src = "https://github.com/yellowei/CYSlider/blob/master/CYSliderProjectFile/CYSlider/WechatIMG86.jpeg" >    

```Objective-C    

    CYSlider *slider = [CYSlider new];
    [self.view addSubview:slider];
    slider.frame = CGRectMake(20, 100, 200, 10);
    slider.value = 0.5;      
    
```    

___   

### 滑块 + 不切圆角
<img src = "https://github.com/yellowei/CYSlider/blob/master/CYSliderProjectFile/CYSlider/WechatIMG88.jpeg">    

```Objective-C    
    CYSlider *slider = [CYSlider new];
    [self.view addSubview:slider];
    slider.isRound = NO;
    slider.frame = CGRectMake(20, 100, 200, 10);
    slider.thumbImageView.image = [UIImage imageNamed:@"thumb"];
    slider.value = 0.5;
```
___    

### 缓冲
<img src = "https://github.com/yellowei/CYSlider/blob/master/CYSliderProjectFile/CYSlider/WechatIMG87.jpeg">    

```Objective-C    
    CYSlider *slider = [CYSlider new];
    [self.view addSubview:slider];
    slider.frame = CGRectMake(20, 100, 200, 10);
    slider.value = 0.5;
    slider.enableBufferProgress = YES;
    slider.bufferProgress = 0.8;
```
___    

### 左右标签
<img src = "https://github.com/yellowei/CYSlider/blob/master/CYSliderProjectFile/CYSlider/WechatIMG89.jpeg">    

```Objective-C    
    CYButtonSlider *b_slider = [CYButtonSlider new];
    b_slider.frame = CGRectMake(50, 300, 300, 40);
    b_slider.slider.value = 0.3;
    b_slider.slider.thumbImageView.image = [UIImage imageNamed:@"thumb"];
    b_slider.leftText = @"00:00";
    b_slider.rightText = @"12:00";
    b_slider.titleColor = [UIColor whiteColor];
    [self.view addSubview:b_slider];
```
