struct DataAsset: AssetType {
    static var `extension`: String = "dataset"
    static func declaration(forPropertyName propertyName: String, value: String, framework: Framework) -> String {
        return #"public static var \#(propertyName): Data { return NSDataAsset(name: "\#(value)", bundle: bundle)!.data }"#
    }
}
