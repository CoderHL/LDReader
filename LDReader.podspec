

Pod::Spec.new do |s|
    
    s.name         = "LDReader"
    s.version      = "1.0.2"
    s.summary      = "A powerful txt reader."
    s.description  = <<-DESC
    The library provides all the functions of TXT text from parsing to display, providing four ways to turn pages and user defined display mode.
    DESC
    
    s.homepage     = "http://192.168.21.17/txtReaderSdk_iOS"
    s.license      = "MIT"
    s.author             = { "liuhong" => "liuhong@1391.com" }
    s.platform     = :ios, "7.0"
    s.source = { :git => "http://192.168.21.17/txtReaderSdk_iOS.git", :tag => s.version }
    
    # s.public_header_files = 'LDReader/LDReader/Controller/LDReader.h','LDReader/LDReader/DataModel/setting/LDConfiguration.h','LDReader/LDReader/DataModel/store/LDBookModel.h','LDReader/LDReader/DataModel/store/LDChapterModel.h','LDReader/LDReader/DataModel/setting/LDConfiguration.h','LDReader/LDReader/Other/LDReaderConstants.h'
    # s.source_files = 'LDReader/LDReader/Controller/*','LDReader/LDReader/DataModel/parser/*.{h,m}','LDReader/LDReader/DataModel/setting/*.{h,m}','LDReader/LDReader/Other/*.{h,m}','LDReader/LDReader/Utils/*','LDReader/LDReader/Views/*','LDReader/LDReader/Utils/NSString+MD5.{h,m}','LDReader/LDReader/Utils/UIView+LDExtension.{h,m}','LDReader/LDReader/DataModel/store/*'
    s.subspec 'Controller' do |controller|
       controller.source_files = 'LDReader/LDReader/Controller/*'
       controller.public_header_files = 'LDReader/LDReader/Controller/LDReader.h'
#       controller.dependency 'LDReader/DataModel'
       controller.dependency 'LDReader/Views'
    end
    s.subspec 'Views' do |views|
        views.source_files = 'LDReader/LDReader/Views/*'
        views.dependency 'LDReader/Utils'
#        views.dependency 'LDReader/Other'
#        views.dependency 'LDReader/DataModel'
    end
    s.subspec 'DataModel' do |datamodel|
            datamodel.source_files = 'LDReader/LDReader/DataModel/setting/*.{h,m}','LDReader/LDReader/DataModel/parser/*.{h,m}','LDReader/LDReader/DataModel/store/*','LDReader/LDReader/Utils/LDAttributedString.{h,m}'
            datamodel.public_header_files = 'LDReader/LDReader/DataModel/setting/LDConfiguration.h','LDReader/LDReader/DataModel/store/LDBookModel.h','LDReader/LDReader/DataModel/store/LDChapterModel.h'
            datamodel.dependency 'LDReader/Other'
    end
    s.subspec 'Other' do |other|
        other.source_files = 'LDReader/LDReader/Other/*.{h,m}','LDReader/LDReader/Utils/UIView+LDExtension.{h,m}','LDReader/LDReader/Utils/NSString+MD5.{h,m}'
        other.public_header_files = 'LDReader/LDReader/Other/LDReaderConstants.h'
    end
    s.subspec 'Utils' do |utils|
        utils.source_files = 'LDReader/LDReader/Utils/*'
        utils.exclude_files = 'LDReader/LDReader/Utils/UIView+LDExtension.{h,m}','LDReader/LDReader/Utils/NSString+MD5.{h,m}','LDReader/LDReader/Utils/LDAttributedString.{h,m}'
        utils.dependency 'LDReader/DataModel'
    end
#    s.source_files =
    s.frameworks = "CoreText", "MobileCoreServices","QuartzCore","ImageIO"
    s.prefix_header_file = 'LDReader/LDReader/Other/LDReader-Prefix.pch'
    s.resource  = "LDReader/LDReader/Other/LDResource.bundle"
    s.library   = "xml2"
    s.requires_arc = true
    s.dependency "DTCoreText", "~> 1.6.21"
    s.user_target_xcconfig = { 'CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES' => 'YES' }
end

