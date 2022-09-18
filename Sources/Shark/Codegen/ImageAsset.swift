struct ImageAsset: AssetType {
    static var `extension`: String = "imageset"
    static func declaration(forPropertyName propertyName: String, value: String, framework: Framework) -> String {
        switch framework {
            case .uikit:
                return #"public static var \#(propertyName): UIImage { return UIImage(named:"\#(value)", in: bundle, compatibleWith: nil)! }"#
            case .appkit:
                return #"public static var \#(propertyName): NSImage { return NSImage(named:"\#(value)")! }"#
            case .swiftui:
                return #"public static var \#(propertyName): Image { return Image("\#(value)", bundle: bundle) }"#
        }
    }
}
