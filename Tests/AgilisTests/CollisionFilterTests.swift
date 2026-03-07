@testable import Agilis
import Testing

@Suite("Collision Filter Tests")
struct CollisionFilterTests {

    @Test("Same layer and full mask: collides")
    func sameLayerCollides() {
        #expect(shouldCollide(layerA: 1, maskA: 0xFFFF_FFFF,
                              layerB: 1, maskB: 0xFFFF_FFFF))
    }

    @Test("Default values: everything collides")
    func defaultsCollide() {
        // Default: layer=1, mask=0xFFFFFFFF
        #expect(shouldCollide(layerA: 1, maskA: 0xFFFF_FFFF,
                              layerB: 1, maskB: 0xFFFF_FFFF))
    }

    @Test("Disjoint layers: no collision")
    func disjointLayers() {
        // Layer 1 vs layer 2, each only sees its own layer
        #expect(!shouldCollide(layerA: 0b01, maskA: 0b01,
                               layerB: 0b10, maskB: 0b10))
    }

    @Test("One-way mask: A sees B but B doesn't see A")
    func oneWayMask() {
        // A is on layer 1, wants to see layer 2
        // B is on layer 2, does NOT want to see layer 1
        #expect(!shouldCollide(layerA: 0b01, maskA: 0b10,
                               layerB: 0b10, maskB: 0b10))
    }

    @Test("Bidirectional mask: both see each other")
    func bidirectionalMask() {
        #expect(shouldCollide(layerA: 0b01, maskA: 0b10,
                              layerB: 0b10, maskB: 0b01))
    }

    @Test("Zero mask: nothing collides")
    func zeroMask() {
        #expect(!shouldCollide(layerA: 1, maskA: 0,
                               layerB: 1, maskB: 0xFFFF_FFFF))
    }

    @Test("Multiple layers bitmask")
    func multipleLayers() {
        // Entity on layers 1+3, mask sees layers 2+4
        let layerA: UInt32 = 0b0101
        let maskA: UInt32 = 0b1010

        // Entity on layer 2, mask sees everything
        let layerB: UInt32 = 0b0010
        let maskB: UInt32 = 0xFFFF_FFFF

        #expect(shouldCollide(layerA: layerA, maskA: maskA,
                              layerB: layerB, maskB: maskB))
    }

    @Test("Both masks zero: no collision")
    func bothMasksZero() {
        #expect(!shouldCollide(layerA: 0xFFFF_FFFF, maskA: 0,
                               layerB: 0xFFFF_FFFF, maskB: 0))
    }
}
