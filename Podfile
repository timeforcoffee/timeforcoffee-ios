xcodeproj 'timeforcoffee'

use_frameworks!
platform :ios, '8.0'

link_with 'timeforcoffeeKit'
#link_with 'Time for Coffee! WatchKit Extension'

pod 'MGSwipeTableCell'
pod 'SwipeView'

# Needed so that PINCache can be used in the watchkit extension

post_install do |installer_representation|
  installer_representation.pods_project.targets.each do |target|
    print target.name
    if target.name == 'PINCache'
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

