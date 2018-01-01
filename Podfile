platform :ios, '10.0'
use_frameworks!

target 'openLibreReader' do
    pod 'Socket.IO-Client-Swift', '~> 12.1.2' # Or latest version
    pod 'MMWormhole', '~> 2.0.0'
    pod 'Charts'
    target 'openLibreReaderWidget' do
        inherit! :search_paths
    end
    post_install do |installer|
      installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['SWIFT_VERSION'] = '4.0'
        end
      end
    end
end
