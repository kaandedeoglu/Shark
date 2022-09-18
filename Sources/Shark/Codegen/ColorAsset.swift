struct ColorAsset: AssetType {
    static var `extension`: String = "colorset"
    static func declaration(forPropertyName propertyName: String, value: String, framework: Framework) -> String {
        switch framework {
            case .uikit:
                return #"public static var \#(propertyName.propertyNameSanitized): UIColor { return UIColor(named: "\#(value)", in: bundle, compatibleWith: nil)! }"#
            case .appkit:
                return #"public static var \#(propertyName.propertyNameSanitized): NSColor { return NSColor(named: "\#(value)", bundle: bundle)! }"#
            case .swiftui:
                return #"public static var \#(propertyName.propertyNameSanitized): Color { return Color("\#(value)", bundle: bundle) }"#
        }
    }
}
