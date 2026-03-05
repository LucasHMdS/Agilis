import Agilis

// MARK: - Custom Serializable Components

struct PlayerTag: SerializableComponent {
    static let componentName = "PlayerTag"
    var name: String
}

struct Inventory: SerializableComponent {
    static let componentName = "Inventory"
    var items: [String] = []
    var maxSlots: Int = 8
}

struct Equipment: SerializableComponent {
    static let componentName = "Equipment"
    var weaponSlot: String = ""
    var armorSlot: String = ""
}

struct ItemPickup: SerializableComponent {
    static let componentName = "ItemPickup"
    var itemId: String
    var displayName: String
    var itemType: String // "weapon", "armor", "potion"
}

struct Chest: SerializableComponent {
    static let componentName = "Chest"
    var isOpen: Bool = false
    var containsItemId: String
    var containsDisplayName: String
}

struct NPCTag: SerializableComponent {
    static let componentName = "NPCTag"
    var dialogue: String
    var npcName: String
}

// MARK: - Events

struct ItemPickedUp: Event {
    let entity: Entity
    let itemId: String
    let displayName: String
}

struct ChestOpened: Event {
    let chestEntity: Entity
    let itemId: String
    let displayName: String
}

struct InventoryChanged: Event {
    let playerEntity: Entity
}
