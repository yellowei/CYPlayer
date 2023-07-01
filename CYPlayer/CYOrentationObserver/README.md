# CYOrentationObserver

### Use
```Objective-C
    _observer = [[CYOrentationObserver alloc] initWithTarget:targetView container:superview];
    _observer.rotationCondition = ^BOOL(CYOrentationObserver * _Nonnull observer) {
        if ( .... ) return NO;
        return YES;
    };
```

### Pod
```ruby
	pod 'CYOrentationObserver'
```
