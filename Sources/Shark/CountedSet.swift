//A simple counted set implementation that uses a dictionary for storage.
struct CountedSet<Element: Hashable>: Sequence {
    private var backingDictionary: [Element: Int] = [:]
    
    @discardableResult
    mutating func add(_ object: Element) -> Int {
        let currentCount = backingDictionary[object] ?? 0
        let newCount = currentCount + 1
        backingDictionary[object] = newCount
        return newCount
    }
    
    func count(for object: Element) -> Int {
        return backingDictionary[object] ?? 0
    }
    
    func makeIterator() -> Dictionary<Element, Int>.Values.Iterator {
        return backingDictionary.values.makeIterator()
    }
}
