@testable import Agilis
import Testing

@Suite("AssetManager Tests")
struct AssetManagerTests {
    @Test func loadAndCache() throws {
        let manager = AssetManager()
        var loadCount = 0

        let value1: String = try manager.load("test.txt") {
            loadCount += 1
            return "hello"
        }
        #expect(value1 == "hello")
        #expect(loadCount == 1)

        // Second load should return cached value without calling loader
        let value2: String = try manager.load("test.txt") {
            loadCount += 1
            return "different"
        }
        #expect(value2 == "hello")
        #expect(loadCount == 1) // loader was NOT called again
    }

    @Test func differentPathsDifferentAssets() throws {
        let manager = AssetManager()

        let a: Int = try manager.load("a") { 1 }
        let b: Int = try manager.load("b") { 2 }
        #expect(a == 1)
        #expect(b == 2)
        #expect(manager.count == 2)
    }

    @Test func storeAndGet() {
        let manager = AssetManager()
        manager.store(42, for: "answer")

        let result = manager.get(Int.self, for: "answer")
        #expect(result == 42)
    }

    @Test func getWrongType() {
        let manager = AssetManager()
        manager.store("hello", for: "key")

        let result = manager.get(Int.self, for: "key")
        #expect(result == nil)
    }

    @Test func getMissing() {
        let manager = AssetManager()
        let result = manager.get(String.self, for: "nonexistent")
        #expect(result == nil)
    }

    @Test func unload() throws {
        let manager = AssetManager()
        let _: String = try manager.load("file") { "data" }
        #expect(manager.count == 1)

        manager.unload("file")
        #expect(manager.isEmpty)
        #expect(manager.get(String.self, for: "file") == nil)
    }

    @Test func unloadAll() throws {
        let manager = AssetManager()
        let _: String = try manager.load("a") { "1" }
        let _: String = try manager.load("b") { "2" }
        let _: String = try manager.load("c") { "3" }
        #expect(manager.count == 3)

        manager.unloadAll()
        #expect(manager.isEmpty)
    }

    @Test func loaderThrows() {
        let manager = AssetManager()

        #expect(throws: AssetError.self) {
            let _: String = try manager.load("bad") {
                throw AssetError.fileNotFound("bad")
            }
        }
        #expect(manager.isEmpty) // nothing cached on failure
    }

    @Test func reloadAfterUnload() throws {
        let manager = AssetManager()
        var loadCount = 0

        let _: String = try manager.load("file") { loadCount += 1; return "v1" }
        #expect(loadCount == 1)

        manager.unload("file")

        let v2: String = try manager.load("file") { loadCount += 1; return "v2" }
        #expect(v2 == "v2")
        #expect(loadCount == 2) // loader called again after unload
    }
}
