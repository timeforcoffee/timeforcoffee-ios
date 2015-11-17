# Smooch Help Kit

The Smooch Help Kit library is an extension to the capabilities of the [Smooch iOS SDK](https://github.com/smooch/smooch-ios). This library adds self-help functionality, as well as an app-wide gesture to access help from anywhere in the app.

Check out the [wiki](https://github.com/smooch/smooch-helpkit-ios/wiki) for descriptions of the features.

![Screenshot](https://raw.githubusercontent.com/smooch/smooch-helpkit-ios/master/helpkit-demo.gif)

# Usage

## Installation Using Cocoapods

Add `pod SmoochHelpKit` to your Podfile, and run `pod install`

*Note:* `SmoochHelpKit` registers `Smooch` as a dependent pod, so if you are already using the `Smooch` pod, you may replace it with this one.

## Installation Without Cocoapods

1. Follow the [instructions](http://docs.smooch.io/ios/#manual-method) for manual installation of the Smooch SDK.
2. Download the latest [zip](https://github.com/smooch/smooch-helpkit-ios/archive/master.zip) file, and extract it.
3. Copy the `SmoochHelpKit` directory into your project
4. Add the required libraries and frameworks to your project's `Link Binary With Libraries` build phase.
  * SystemConfiguration.framework
  * UIKit.framework
  * Foundation.framework
  * OpenGLES.framework
  * QuartzCore.framework
  * CoreText.framework
5. Add the `-lxml2` flag to your app’s `Other Linker Flags` build setting.

## Initializing the SDK

Sign up and get an app token at [app.smooch.io](https://app.smooch.io). Then, in `application:didFinishLaunchingWithOptions:`

```objc
#import "SmoochHelpKit.h"

SHKSettings* settings = [SHKSettings settingsWithAppToken:@"YOUR_APP_TOKEN"];
[SmoochHelpKit initWithSettings:settings];
```

*Note:* `SHKSettings` derives from `SKTSettings`, and calling `[SmoochHelpKit initWithSettings:]` will automatically call through to `[Smooch initWithSettings:]`. There is no need to call `+initWithSettings:` on both classes.

To show the UI:

```objc
[SmoochHelpKit show];
```

# API Documentation

For Help Kit API documentation, see the `SmoochHelpKit.h` and `SHKSettings.h` header files.

For Smooch documentation, visit [the docs](http://docs.smooch.io)

# License

Copyright (c) 2015 Smooch Technologies Inc.
All rights reserved.
See [here](https://smooch.io/terms.html) for license details.

# Acknowledgements

This library makes use of, was inspired by, and distributes a number of other open-source components. Special thanks to the creators and maintainers of these libraries (in no particular order):

* [luisespinoza/LEColorPicker](https://github.com/luisespinoza/LEColorPicker)
* [zootreeves/Objective-C-HMTL-Parser](https://github.com/zootreeves/Objective-C-HMTL-Parser)
* [Marxon13/M13BadgeView](https://github.com/Marxon13/M13BadgeView)
* [nicklockwood/SwipeView](https://github.com/nicklockwood/SwipeView)
* [AFNetworking/AFNetworking](https://github.com/AFNetworking/AFNetworking)
