struct DataAsset: AssetType {
    static var `extension`: String = "dataset"
    static func declaration(forPropertyName propertyName: String, value: String, options: Options) -> String {
        return #"\#(options.visibility) static var \#(propertyName): Data { return NSDataAsset(name: "\#(value)", bundle: bundle)!.data }"#
    }
}
