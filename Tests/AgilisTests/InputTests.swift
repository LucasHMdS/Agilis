@testable import Agilis
import Testing

/// A mock input backend for testing. Allows programmatic control of key/mouse state.
final class MockNativeInput: @unchecked Sendable, InputBackend {
    deinit {}

    var keysDown: Set<Key> = []
    var mouseButtonsDown: Set<MouseButton> = []
    var currentMousePosition = Vector2.zero
    var currentMouseDelta = Vector2.zero
    var currentScrollDelta: Float = 0
    var currentCharPressed: Character?

    func isKeyDown(_ key: Key) -> Bool {
        keysDown.contains(key)
    }

    func isMouseButtonDown(_ button: MouseButton) -> Bool {
        mouseButtonsDown.contains(button)
    }

    func mousePosition() -> Vector2 { currentMousePosition }
    func mouseDelta() -> Vector2 { currentMouseDelta }
    func mouseScrollDelta() -> Float { currentScrollDelta }
    func charPressed() -> Character? { currentCharPressed }
}

@Suite("InputManager Tests")
struct InputManagerTests {

    // MARK: - Keyboard

    @Test func keyDown() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)

        backend.keysDown = [.space]
        input.update()

        #expect(input.isKeyDown(.space))
        #expect(!input.isKeyDown(.a))
    }

    @Test func keyPressed() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)

        // Frame 1: nothing pressed
        input.update()
        #expect(!input.isKeyPressed(.space))
        input.consumeTransitions()

        // Frame 2: space pressed
        backend.keysDown = [.space]
        input.update()
        #expect(input.isKeyPressed(.space))  // just pressed this frame
        input.consumeTransitions()

        // Frame 3: space still held
        input.update()
        #expect(!input.isKeyPressed(.space)) // not "just pressed" anymore
        #expect(input.isKeyDown(.space))     // but still down
    }

    @Test func keyReleased() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)

        // Frame 1: press space
        backend.keysDown = [.space]
        input.update()
        input.consumeTransitions()

        // Frame 2: release space
        backend.keysDown = []
        input.update()
        #expect(input.isKeyReleased(.space))
        #expect(!input.isKeyDown(.space))
        input.consumeTransitions()

        // Frame 3: still released (no longer "just released")
        input.update()
        #expect(!input.isKeyReleased(.space))
    }

    @Test func multipleKeysSimultaneously() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)

        backend.keysDown = [.w, .a, .leftShift]
        input.update()

        #expect(input.isKeyDown(.w))
        #expect(input.isKeyDown(.a))
        #expect(input.isKeyDown(.leftShift))
        #expect(!input.isKeyDown(.s))
    }

    // MARK: - Mouse

    @Test func mouseButtonDown() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)

        backend.mouseButtonsDown = [.left]
        input.update()

        #expect(input.isMouseButtonDown(.left))
        #expect(!input.isMouseButtonDown(.right))
    }

    @Test func mouseButtonPressed() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)

        input.update()
        input.consumeTransitions()

        backend.mouseButtonsDown = [.right]
        input.update()
        #expect(input.isMouseButtonPressed(.right))
        input.consumeTransitions()

        input.update()
        #expect(!input.isMouseButtonPressed(.right)) // held, not just pressed
    }

    @Test func mouseButtonReleased() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)

        backend.mouseButtonsDown = [.left]
        input.update()
        input.consumeTransitions()

        backend.mouseButtonsDown = []
        input.update()
        #expect(input.isMouseButtonReleased(.left))
        input.consumeTransitions()

        input.update()
        #expect(!input.isMouseButtonReleased(.left))
    }

    @Test func mousePosition() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)

        backend.currentMousePosition = Vector2(x: 400, y: 300)
        #expect(input.mousePosition == Vector2(x: 400, y: 300))
    }

    @Test func mouseDelta() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)

        backend.currentMouseDelta = Vector2(x: 5, y: -3)
        #expect(input.mouseDelta == Vector2(x: 5, y: -3))
    }

    @Test func mouseScrollDelta() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)

        backend.currentScrollDelta = 2.5
        #expect(input.mouseScrollDelta == 2.5)
    }

    // MARK: - Action Mapping

    @Test func actionWithKeyBinding() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)
        input.registerAction("jump", keys: [.space, .w])

        input.update()
        #expect(!input.isActionActive("jump"))
        input.consumeTransitions()

        backend.keysDown = [.space]
        input.update()
        #expect(input.isActionActive("jump"))
        #expect(input.isActionJustActivated("jump"))
        input.consumeTransitions()

        input.update()
        #expect(input.isActionActive("jump"))
        #expect(!input.isActionJustActivated("jump")) // still held, not "just"
    }

    @Test func actionWithMouseBinding() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)
        input.registerAction("shoot", mouseButtons: [.left])

        input.update()

        backend.mouseButtonsDown = [.left]
        input.update()
        #expect(input.isActionActive("shoot"))
        #expect(input.isActionJustActivated("shoot"))
    }

    @Test func actionWithMixedBindings() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)
        input.registerAction("fire", keys: [.space], mouseButtons: [.left])

        input.update()

        // Activate via mouse
        backend.mouseButtonsDown = [.left]
        input.update()
        #expect(input.isActionActive("fire"))

        // Release mouse, activate via key
        backend.mouseButtonsDown = []
        backend.keysDown = [.space]
        input.update()
        #expect(input.isActionActive("fire"))
    }

    @Test func actionDeactivated() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)
        input.registerAction("jump", keys: [.space])

        // Press
        backend.keysDown = [.space]
        input.update()
        input.consumeTransitions()

        // Release
        backend.keysDown = []
        input.update()
        #expect(input.isActionJustDeactivated("jump"))
        #expect(!input.isActionActive("jump"))
        input.consumeTransitions()

        // Next frame: no longer "just" deactivated
        input.update()
        #expect(!input.isActionJustDeactivated("jump"))
    }

    @Test func unregisteredAction() {
        let backend = MockNativeInput()
        let input = InputManager()
        input.bind(backend)

        backend.keysDown = [.space]
        input.update()

        #expect(!input.isActionActive("nonexistent"))
        #expect(!input.isActionJustActivated("nonexistent"))
        #expect(!input.isActionJustDeactivated("nonexistent"))
    }
}
