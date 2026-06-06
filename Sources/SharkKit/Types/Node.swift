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

extension Node where Element: SanitizableValue {
    func sanitize() {
        //If two children have the same name, or if a children has the same name with a parent, underscore
        var modified = false
        repeat {
            modified = false
            var countedSet = CountedSet<String>()
            for child in children {
                for _ in 0..<countedSet.count(for: child.name) {
                    child.underscoreName()
                    modified = true
                }
                countedSet.add(child.name)
                if name == child.name {
                    child.underscoreName()
                    modified = true
                }
            }
        } while modified

        children.forEach { $0.sanitize() }
    }

    private var name: String {
        return value.name
    }

    private func underscoreName() {
        value = value.underscoringName()
    }
}
