import Foundation

extension CharacterSet {
    static let firstLetterForbidden: CharacterSet = {
        var validSet = CharacterSet(charactersIn: "_")
        validSet.formUnion(.letters)
        return validSet.inverted
    }()
    
    static let forbidden: CharacterSet = {
        var validSet = CharacterSet(charactersIn: "_")
        validSet.formUnion(.letters)
        validSet.formUnion(.decimalDigits)
        return validSet.inverted
    }()
}
