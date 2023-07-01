# CYBorderLineView
视图 或上或下或左或右 绘制一条线    
pod 'CYBorderLineView'    

```
    CYBorderlineView *lineView = [CYBorderlineView borderlineViewWithSide:CYBorderlineSideTop | CYBorderlineSideLeading | CYBorderlineSideBottom | CYBorderlineSideTrailing startMargin:10 endMargin:10 lineColor:[UIColor redColor] lineWidth:5];
    lineView.frame = CGRectMake(20, 100, 200, 35);
    lineView.backgroundColor = [UIColor grayColor];
    [self.view addSubview:lineView];
```
    
<img src="https://github.com/yellowei/CYBorderLineView/blob/master/CYBorderLineViewProject/sample1.png" width="30%" />
   
<img src="https://github.com/yellowei/CYBorderLineView/blob/master/CYBorderLineViewProject/sample.png" width="30%" />
