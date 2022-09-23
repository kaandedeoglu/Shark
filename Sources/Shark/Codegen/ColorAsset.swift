struct ColorAsset: AssetType {
    static var `extension`: String = "colorset"
    static func declaration(forPropertyName propertyName: String, value: String, options: Options) -> String {
        switch options.framework {
            case .uikit:
                return #"\#(options.visibility) static var \#(propertyName.propertyNameSanitized): UIColor { return UIColor(named: "\#(value)", in: bundle, compatibleWith: nil)! }"#
            case .appkit:
                return #"\#(options.visibility) static var \#(propertyName.propertyNameSanitized): NSColor { return NSColor(named: "\#(value)", bundle: bundle)! }"#
            case .swiftui:
                return #"\#(options.visibility) static var \#(propertyName.propertyNameSanitized): Color { return Color("\#(value)", bundle: bundle) }"#
        }
    }
}
