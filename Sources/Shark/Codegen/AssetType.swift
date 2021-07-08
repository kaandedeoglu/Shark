protocol AssetType {
    static func declaration(forPropertyName propertyName: String, value: String) -> String
    static var `extension`: String { get }
}
