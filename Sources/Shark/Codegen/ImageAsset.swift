struct ImageAsset: AssetType {
    static var `extension`: String = "imageset"
    static func declaration(forPropertyName propertyName: String, value: String) -> String {
        return #"public static var \#(propertyName): UIImage { return UIImage(named:"\#(value)", in: bundle, compatibleWith: nil)! }"#
    }
}
