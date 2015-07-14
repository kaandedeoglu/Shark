
public struct ECMA48 {
	/// “ESC is used for code extension purposes. It causes the meanings of a limited 
	/// number of bit combinations following it in the data stream to be changed.”
	public static let escape = "\u{001B}"
	/// “used as the first character of a control sequence”
	public static let controlSequenceIntroducer = escape + "["
}

public typealias SelectGraphicRendition = String

public protocol SelectGraphicRenditionWrapType {
	
	/// A SelectGraphicRendition code in two parts: enable and disable.
	var code: (enable: SelectGraphicRendition, disable: SelectGraphicRendition) { get }
	
	/// Wraps a string in the SelectGraphicRendition code.
	func wrap(string: String) -> String
	
	var parameters: [Parameter] { get set }
	
}

public protocol Parameter {
	var code: (enable: [UInt8], disable: UInt8?) { get }
}

/// Defines equality for Parameters.
public func == (a: Parameter, b: Parameter) -> Bool {
	return a.code.enable == b.code.enable
}

/// Defines inequality for Parameters.
public func != (a: Parameter, b: Parameter) -> Bool {
	return !(a == b)
}