protocol AssetType {
    static var `extension`: String { get }
    static func declaration(forPropertyName propertyName: String, value: String, framework: Framework) -> String
}
