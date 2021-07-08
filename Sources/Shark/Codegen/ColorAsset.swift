struct ColorAsset: AssetType {
    static var `extension`: String = "colorset"
    static func declaration(forPropertyName propertyName: String, value: String) -> String {
        return #"public static var \#(propertyName): UIColor { return UIColor(named: "\#(value)", in: bundle, compatibleWith: nil)! }"#
    }
}
