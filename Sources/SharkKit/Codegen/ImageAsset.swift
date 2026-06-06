struct ImageAsset: AssetType {
    static var `extension`: String = "imageset"
    static func declaration(forPropertyName propertyName: String, value: String, options: Options) -> String {
        switch options.framework {
            case .uikit:
                return #"\#(options.visibility) static var \#(propertyName): UIImage { return UIImage(named:"\#(value)", in: bundle, compatibleWith: nil)! }"#
            case .appkit:
                return #"\#(options.visibility) static var \#(propertyName): NSImage { return NSImage(named:"\#(value)")! }"#
            case .swiftui:
                return #"\#(options.visibility) static var \#(propertyName): Image { return Image("\#(value)", bundle: bundle) }"#
        }
    }
}
