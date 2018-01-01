source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '9.0'
use_frameworks!

project 'MusicFav'

target "MusicFav" do
  pod 'OAuthSwift'
  pod 'Prephirences'
  pod 'JASidePanels',         '>= 1.3'
  pod 'MBProgressHUD'
  pod 'MCSwipeTableViewCell', '>= 2.1.0'
  pod 'InAppSettingsKit'
  pod 'EAIntroView',          '~> 2.7.0'
  pod 'Fabric'
  pod 'Crashlytics'
  pod 'GoogleAnalytics'
  pod 'MarqueeLabel'
  pod "RMDateSelectionViewController", "~> 1.5.1"
  pod 'ISAlternativeRefreshControl'
  pod 'RATreeView',           :git => 'https://github.com/kumabook/RATreeView.git',
                           :branch => 'pull_to_refresh'

  target "UnitTests" do
    inherit! :search_paths
  end
end
