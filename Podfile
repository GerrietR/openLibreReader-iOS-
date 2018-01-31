use_frameworks!

def shared_pods
    pod 'MMWormhole', '~> 2.0.0'
end

target 'openLibreReader' do
    platform :ios, '10.0'
    shared_pods
    pod 'Socket.IO-Client-Swift', '~> 12.0.0' # Or latest version
    pod 'Charts'
    pod 'XLForm'
end

target 'openLibreReaderWidget' do
	platform :ios, '10.0'
    shared_pods
    pod 'Charts'
end
    
target 'openLibreWatch' do
    platform :watchos, '2.0'
    shared_pods
end

target 'openLibreWatch Extension' do
    platform :watchos, '2.0'
    shared_pods
end
