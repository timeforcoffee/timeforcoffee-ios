project 'timeforcoffee'

use_frameworks!


def shared_pods
    pod 'Smooch'
    pod 'Fabric'
    pod 'Crashlytics'
end

def shared_kit_pods
  pod 'RealmSwift'
end


#target 'timeforcoffeeKit' do
#    platform :ios, '8.0'
#    shared_kit_pods
#end


target 'timeforcoffee' do
    platform :ios, '8.2'
    pod 'MGSwipeTableCell'
    pod 'SwipeView'
    shared_pods
end 

target 'timeforcoffee Widget' do
    pod 'Fabric'
    pod 'Crashlytics'
end  

#target 'Time for Coffee! WatchOS 2 App Extension' do
#     platform :watchos, '2.0'
#     shared_kit_pods
#end
 


# Needed so that PINCache can be used in the watchkit extension

post_install do |installer_representation|
  installer_representation.pods_project.targets.each do |target|
    print target.name
    print "\n"
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

