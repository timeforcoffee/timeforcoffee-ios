project 'timeforcoffee'

platform :ios, '15.0'
use_frameworks!

target 'timeforcoffee' do
    platform :ios, '15.0'
    pod 'MGSwipeTableCell'
    pod 'SwipeView', :git => 'https://github.com/nicklockwood/SwipeView.git'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
    end
  end
end

 


