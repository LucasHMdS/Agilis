import Agilis

enum ItemPrefabs {

    static func sword(at pos: Vector2) -> Prefab {
        var prefab = Prefab()
        prefab.add(Transform2D(position: pos))
        prefab.add(Velocity2D())
        prefab.add(RigidBody2D(mass: 0, bodyType: .static))
        prefab.add(Collider2D(
            shape: .circle(radius: 10),
            isTrigger: true,
            layer: RPG.layerItem,
            mask: RPG.layerPlayer
        ))
        prefab.add(ItemPickup(itemId: "sword", displayName: "Iron Sword", itemType: "weapon"))
        prefab.withName("Sword")
        return prefab
    }

    static func shield(at pos: Vector2) -> Prefab {
        var prefab = Prefab()
        prefab.add(Transform2D(position: pos))
        prefab.add(Velocity2D())
        prefab.add(RigidBody2D(mass: 0, bodyType: .static))
        prefab.add(Collider2D(
            shape: .circle(radius: 10),
            isTrigger: true,
            layer: RPG.layerItem,
            mask: RPG.layerPlayer
        ))
        prefab.add(ItemPickup(itemId: "shield", displayName: "Wooden Shield", itemType: "armor"))
        prefab.withName("Shield")
        return prefab
    }

    static func healthPotion(at pos: Vector2) -> Prefab {
        var prefab = Prefab()
        prefab.add(Transform2D(position: pos))
        prefab.add(Velocity2D())
        prefab.add(RigidBody2D(mass: 0, bodyType: .static))
        prefab.add(Collider2D(
            shape: .circle(radius: 8),
            isTrigger: true,
            layer: RPG.layerItem,
            mask: RPG.layerPlayer
        ))
        prefab.add(ItemPickup(itemId: "potion", displayName: "Health Potion", itemType: "potion"))
        prefab.withName("HealthPotion")
        return prefab
    }

    static func chest(at pos: Vector2, containsItemId: String, containsName: String) -> Prefab {
        var prefab = Prefab()
        prefab.add(Transform2D(position: pos))
        prefab.add(Velocity2D())
        prefab.add(RigidBody2D(mass: 0, bodyType: .static))
        prefab.add(Collider2D(
            shape: .aabb(halfExtents: Vector2(x: 14, y: 12)),
            isTrigger: true,
            layer: RPG.layerChest,
            mask: RPG.layerPlayer
        ))
        prefab.add(Chest(containsItemId: containsItemId, containsDisplayName: containsName))
        prefab.withName("Chest")
        return prefab
    }

    static func npc(at pos: Vector2, name: String, dialogue: String) -> Prefab {
        var prefab = Prefab()
        prefab.add(Transform2D(position: pos))
        prefab.add(Velocity2D())
        prefab.add(RigidBody2D(mass: 0, bodyType: .static))
        prefab.add(Collider2D(
            shape: .circle(radius: 14),
            layer: RPG.layerNPC,
            mask: RPG.layerPlayer | RPG.layerWall
        ))
        prefab.add(NPCTag(dialogue: dialogue, npcName: name))
        prefab.withName(name)
        return prefab
    }
}
