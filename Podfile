xcodeproj 'timeforcoffee'

use_frameworks!
platform :ios, '8.0'

link_with 'timeforcoffeeKit'
pod 'MGSwipeTableCell'
pod 'PINCache', :git => 'https://github.com/pinterest/PINCache', :commit => 'eecf84426751ae3c3f224411763946427fe3aa5b'
pod 'SwipeView'

# Needed so that PINCache can be used in the watchkit extension

post_install do |installer_representation|
  installer_representation.project.targets.each do |target|
    if target.name == 'Pods-PINCache'
      target.build_configurations.each do |config|
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)']
        config.build_settings['GCC_PREPROCESSOR_DEFINITIONS']  << 'PIN_APP_EXTENSIONS=1'
        config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
      end
    else 
      target.build_configurations.each do |config|
        config.build_settings['APPLICATION_EXTENSION_API_ONLY'] = 'YES'
      end
    end
  end
end

