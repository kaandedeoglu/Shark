import Foundation

// A simple tree node
final class Node<Element> {
    var value: Element
    weak var parent: Node?
    private(set) var children: [Node<Element>] = []
    
    init(value: Element) {
        self.value = value
    }
    
    func add(child : Node<Element>) {
        children.append(child)
        child.parent = self
    }
}

extension Node: Equatable where Element: Equatable {
    func add(childrenRelatively children: [Node<Element>]) {
        var currentParent: Node = self
        children.forEach { child in
            if let idx = currentParent.children.firstIndex(where: { $0.value == child.value }) {
                currentParent = currentParent.children[idx]
            } else {
                currentParent.add(child: child)
                currentParent = child
            }
        }
    }
    
    static func ==(lhs: Node, rhs: Node) -> Bool {
        return lhs.value == rhs.value && lhs.children == rhs.children
    }
}

extension Node: Comparable where Element: Comparable {
    func sort() {
        children.sort(by: <)
        children.forEach { $0.sort() }
    }
    
    static func <(lhs: Node, rhs: Node) -> Bool {
        return lhs.value < rhs.value
    }
}
