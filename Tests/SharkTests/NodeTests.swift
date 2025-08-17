import Testing
import Foundation
@testable import Shark

struct NodeTests {
    
    @Test func nodeInitialization() {
        let node = Node(value: "test")
        #expect(node.value == "test")
        #expect(node.children.isEmpty)
    }
    
    @Test func addChild() {
        let parent = Node(value: "parent")
        let child = Node(value: "child")
        
        parent.add(child: child)
        #expect(parent.children.count == 1)
        #expect(parent.children.first?.value == "child")
    }
    
    @Test func addChildrenRelatively() {
        let root = Node(value: "root")
        let child1 = Node(value: "child1")
        let child2 = Node(value: "child2")
        
        root.add(childrenRelatively: [child1, child2])
        
        #expect(root.children.count == 1)
        #expect(root.children.first?.value == "child1")
        #expect(root.children.first?.children.count == 1)
        #expect(root.children.first?.children.first?.value == "child2")
    }
    
    @Test func addChildrenRelativelyCreatesHierarchy() {
        let root = Node(value: "root")
        let child1 = Node(value: "level1")
        let child2 = Node(value: "level2")
        let child3 = Node(value: "level3")
        
        root.add(childrenRelatively: [child1, child2, child3])
        
        #expect(root.children.count == 1)
        #expect(root.children.first?.value == "level1")
        #expect(root.children.first?.children.count == 1)
        #expect(root.children.first?.children.first?.value == "level2")
        #expect(root.children.first?.children.first?.children.first?.value == "level3")
    }
}