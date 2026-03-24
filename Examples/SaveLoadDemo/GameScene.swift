import Agilis
import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(CRT)
import CRT
#endif

final class GameScene: Scene {
    private var font: FontHandle = .invalid
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var physics: PhysicsWorld2D!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var sounds: RPGSounds.SoundSet!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var serializer: WorldSerializer!
    private var savedData: Data?

    private var playerEntity: Entity = .null
    private var wallEntities: [Entity] = []
    private var itemEntities: [Entity] = []
    private var chestEntities: [Entity] = []
    private var npcEntities: [Entity] = []

    // UI
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var ui: UIContext!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var inventoryList: UIListView!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var weaponLabel: UILabel!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var armorLabel: UILabel!
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var statusLabel: UILabel!

    func didEnter(app: Application) {
        font = app.renderer.loadDefaultFont()
        sounds = RPGSounds.generate(audio: app.audio)

        // Physics (top-down, no gravity)
        physics = PhysicsWorld2D(gravity: .zero)
        app.world.addSystem(physics)

        // Serializer
        serializer = WorldSerializer()
        serializer.registerDefaults()
        serializer.register(PlayerTag.self)
        serializer.register(Inventory.self)
        serializer.register(Equipment.self)
        serializer.register(ItemPickup.self)
        serializer.register(Chest.self)
        serializer.register(NPCTag.self)

        // Build the room
        buildRoom(app: app)
        spawnPlayer(app: app)
        spawnItems(app: app)
        spawnChests(app: app)
        spawnNPCs(app: app)

        // Setup events
        setupEvents(app: app)

        // Setup UI panel
        setupUI(app: app)
    }

    func update(app: Application, deltaTime: Double) {
        let dt = Float(deltaTime)

        // Escape to menu
        if app.input.isKeyPressed(.escape) {
            app.sceneManager.replace(
                with: MenuScene(),
                transition: .fade(duration: 0.5),
                app: app
            )
            return
        }

        // Player movement (WASD)
        if playerEntity != .null {
            var moveX: Float = 0
            var moveY: Float = 0
            if app.input.isKeyDown(.w) { moveY -= 1 }
            if app.input.isKeyDown(.s) { moveY += 1 }
            if app.input.isKeyDown(.a) { moveX -= 1 }
            if app.input.isKeyDown(.d) { moveX += 1 }

            // Normalize diagonal
            let len = sqrtf(moveX * moveX + moveY * moveY)
            if len > 0 {
                moveX /= len
                moveY /= len
            }

            app.world.updateComponent(Velocity2D.self, on: playerEntity) { vel in
                vel.linear = Vector2(x: moveX * RPG.playerSpeed, y: moveY * RPG.playerSpeed)
            }
        }

        // Trigger collision checks for items/chests
        for event in physics.events {
            handleCollisionEvent(event, app: app)
        }

        // UI update
        ui.update(app: app, deltaTime: Double(dt))
    }

    func render(app: Application, interpolation _: Double) {
        let screen = app.renderer.screenSize

        // Draw floor
        app.renderer.drawRect(
            Rect(x: 0, y: 0, width: RPG.gameAreaWidth, height: RPG.screenHeight),
            color: RPG.floorColor
        )

        // Draw walls
        for entity in wallEntities {
            if let pos = app.world.getComponent(Transform2D.self, from: entity),
               let col = app.world.getComponent(Collider2D.self, from: entity) {
                if case .aabb(let he) = col.shape {
                    app.renderer.drawRect(
                        Rect(
                            x: pos.position.x - he.x,
                            y: pos.position.y - he.y,
                            width: he.x * 2,
                            height: he.y * 2
                        ),
                        color: RPG.wallColor
                    )
                }
            }
        }

        // Draw items
        for entity in itemEntities {
            if let pos = app.world.getComponent(Transform2D.self, from: entity) {
                app.renderer.drawCircle(center: pos.position, radius: 8, color: RPG.itemColor)
            }
        }

        // Draw chests
        for entity in chestEntities {
            if let pos = app.world.getComponent(Transform2D.self, from: entity),
               let chest = app.world.getComponent(Chest.self, from: entity) {
                let color = chest.isOpen ? RPG.chestOpenColor : RPG.chestColor
                app.renderer.drawRect(
                    Rect(
                        x: pos.position.x - 14,
                        y: pos.position.y - 12,
                        width: 28,
                        height: 24
                    ),
                    color: color
                )
            }
        }

        // Draw NPCs
        for entity in npcEntities {
            if let pos = app.world.getComponent(Transform2D.self, from: entity),
               let npc = app.world.getComponent(NPCTag.self, from: entity) {
                app.renderer.drawCircle(center: pos.position, radius: 14, color: RPG.npcColor)
                app.renderer.drawText(
                    npc.npcName,
                    position: Vector2(x: pos.position.x - 20, y: pos.position.y - 26),
                    font: font,
                    size: 10,
                    color: RPG.textBright
                )
            }
        }

        // Draw player
        if playerEntity != .null,
           let pos = app.world.getComponent(Transform2D.self, from: playerEntity) {
            app.renderer.drawCircle(center: pos.position, radius: 12, color: RPG.playerColor)
        }

        // UI panel background
        app.renderer.drawRect(
            Rect(x: RPG.gameAreaWidth, y: 0, width: RPG.panelWidth, height: RPG.screenHeight),
            color: RPG.panelBg
        )

        // Render UI
        ui.render(renderer: app.renderer)

        // HUD
        app.renderer.drawText(
            "[ESC] Menu  [WASD] Move",
            position: Vector2(x: 5, y: RPG.screenHeight - 18),
            font: font,
            size: 11,
            color: RPG.textDim
        )
        app.renderer.drawText(
            "\(app.fps) FPS",
            position: Vector2(x: screen.width - 65, y: screen.height - 18),
            font: font,
            size: 12,
            color: Color(r: 80, g: 80, b: 80)
        )
    }

    func willExit(app: Application) {
        app.world.removeAllEventHandlers()
        clearAllEntities(app: app)

        app.world.removeSystem(physics)
        sounds.unloadAll(audio: app.audio)
        if font != .invalid {
            app.renderer.destroyFont(font)
        }
    }

    private func clearAllEntities(app: Application) {
        for e in wallEntities { app.world.destroyEntity(e) }
        for e in itemEntities { app.world.destroyEntity(e) }
        for e in chestEntities { app.world.destroyEntity(e) }
        for e in npcEntities { app.world.destroyEntity(e) }
        if playerEntity != .null { app.world.destroyEntity(playerEntity) }

        wallEntities.removeAll()
        itemEntities.removeAll()
        chestEntities.removeAll()
        npcEntities.removeAll()
        playerEntity = .null
    }

    // MARK: - Room Building

    private func buildRoom(app: Application) {
        let ts = RPG.tileSize
        let cols = RPG.roomCols
        let rows = RPG.roomRows

        // Border walls
        for col in 0..<cols {
            // Top
            wallEntities.append(createWall(app: app, pos: Vector2(
                x: Float(col) * ts + ts / 2,
                y: ts / 2
            )))
            // Bottom
            wallEntities.append(createWall(app: app, pos: Vector2(
                x: Float(col) * ts + ts / 2,
                y: Float(rows - 1) * ts + ts / 2
            )))
        }
        for row in 1..<(rows - 1) {
            // Left
            wallEntities.append(createWall(app: app, pos: Vector2(
                x: ts / 2,
                y: Float(row) * ts + ts / 2
            )))
            // Right
            wallEntities.append(createWall(app: app, pos: Vector2(
                x: Float(cols - 1) * ts + ts / 2,
                y: Float(row) * ts + ts / 2
            )))
        }

        // Internal walls — a corridor
        for row in 3..<8 {
            wallEntities.append(createWall(app: app, pos: Vector2(
                x: 5 * ts + ts / 2,
                y: Float(row) * ts + ts / 2
            )))
        }
        for row in 6..<11 {
            wallEntities.append(createWall(app: app, pos: Vector2(
                x: 10 * ts + ts / 2,
                y: Float(row) * ts + ts / 2
            )))
        }
    }

    private func createWall(app: Application, pos: Vector2) -> Entity {
        let entity = app.world.createEntity()
        app.world.addComponent(Transform2D(position: pos), to: entity)
        app.world.addComponent(RigidBody2D(mass: 0, bodyType: .static), to: entity)
        app.world.addComponent(
            Collider2D(
                shape: .aabb(halfExtents: Vector2(x: RPG.tileSize / 2, y: RPG.tileSize / 2)),
                layer: RPG.layerWall,
                mask: RPG.layerPlayer | RPG.layerNPC
            ),
            to: entity
        )
        return entity
    }

    private func spawnPlayer(app: Application) {
        playerEntity = app.world.createEntity()
        app.world.addComponent(Transform2D(position: Vector2(x: 80, y: 80)), to: playerEntity)
        app.world.addComponent(Velocity2D(), to: playerEntity)
        app.world.addComponent(
            RigidBody2D(
                mass: 1,
                gravityScale: 0,
                bodyType: .dynamic,
                linearDamping: 10
            ),
            to: playerEntity
        )
        app.world.addComponent(
            Collider2D(
                shape: .circle(radius: 12),
                layer: RPG.layerPlayer,
                mask: RPG.layerWall | RPG.layerItem | RPG.layerNPC | RPG.layerChest
            ),
            to: playerEntity
        )
        app.world.addComponent(PlayerTag(name: "Hero"), to: playerEntity)
        app.world.addComponent(Inventory(), to: playerEntity)
        app.world.addComponent(Equipment(), to: playerEntity)
        app.world.addComponent(Sprite(texture: .invalid), to: playerEntity)
    }

    private func spawnItems(app: Application) {
        let positions: [(Vector2, () -> Prefab)] = [
            (Vector2(x: 200, y: 100), { ItemPrefabs.sword(at: Vector2(x: 200, y: 100)) }),
            (Vector2(x: 300, y: 200), { ItemPrefabs.shield(at: Vector2(x: 300, y: 200)) }),
            (Vector2(x: 120, y: 300), { ItemPrefabs.healthPotion(at: Vector2(x: 120, y: 300)) }),
            (Vector2(x: 400, y: 150), { ItemPrefabs.healthPotion(at: Vector2(x: 400, y: 150)) })
        ]
        for (_, factory) in positions {
            let entity = factory().instantiate(in: app.world)
            itemEntities.append(entity)
        }
    }

    private func spawnChests(app: Application) {
        let chest1 = ItemPrefabs
            .chest(
                at: Vector2(x: 350, y: 350),
                containsItemId: "gold_sword",
                containsName: "Golden Sword"
            )
            .instantiate(in: app.world)
        chestEntities.append(chest1)

        let chest2 = ItemPrefabs
            .chest(
                at: Vector2(x: 450, y: 250),
                containsItemId: "magic_armor",
                containsName: "Magic Armor"
            )
            .instantiate(in: app.world)
        chestEntities.append(chest2)
    }

    private func spawnNPCs(app: Application) {
        let npc1 = ItemPrefabs
            .npc(
                at: Vector2(x: 250, y: 300),
                name: "Elder",
                dialogue: "Welcome, adventurer!"
            )
            .instantiate(in: app.world)
        npcEntities.append(npc1)
    }

    // MARK: - Events

    private func setupEvents(app: Application) {
        app.world.on(ItemPickedUp.self) { [weak self] event in
            guard let self = self else { return }
            app.world.updateComponent(Inventory.self, on: playerEntity) { inv in
                if inv.items.count < inv.maxSlots {
                    inv.items.append(event.displayName)
                }
            }
            app.world.emit(InventoryChanged(playerEntity: playerEntity))
            app.audio.playSound(sounds.pickup, volume: 0.5, pitch: 1.0, looping: false)
        }

        app.world.on(ChestOpened.self) { [weak self] event in
            guard let self = self else { return }
            app.world.updateComponent(Inventory.self, on: playerEntity) { inv in
                if inv.items.count < inv.maxSlots {
                    inv.items.append(event.displayName)
                }
            }
            app.world.emit(InventoryChanged(playerEntity: playerEntity))
            app.audio.playSound(sounds.chestOpen, volume: 0.5, pitch: 1.0, looping: false)
        }

        app.world.on(InventoryChanged.self) { [weak self] _ in
            self?.refreshInventoryUI(app: app)
        }
    }

    private func handleCollisionEvent(_ event: CollisionEvent, app: Application) {
        guard event.type == .began else { return }
        let entityA = event.entityA
        let entityB = event.entityB

        // Check item pickup
        if let pickup = app.world.getComponent(ItemPickup.self, from: entityB),
           app.world.getComponent(PlayerTag.self, from: entityA) != nil {
            app.world.emit(ItemPickedUp(entity: entityB, itemId: pickup.itemId, displayName: pickup.displayName))
            removeItem(entityB, app: app)
        } else if let pickup = app.world.getComponent(ItemPickup.self, from: entityA),
                  app.world.getComponent(PlayerTag.self, from: entityB) != nil {
            app.world.emit(ItemPickedUp(entity: entityA, itemId: pickup.itemId, displayName: pickup.displayName))
            removeItem(entityA, app: app)
        }

        // Check chest opening
        if let chest = app.world.getComponent(Chest.self, from: entityB),
           app.world.getComponent(PlayerTag.self, from: entityA) != nil,
           !chest.isOpen {
            app.world.updateComponent(Chest.self, on: entityB) { c in c.isOpen = true }
            app.world.emit(ChestOpened(chestEntity: entityB, itemId: chest.containsItemId, displayName: chest.containsDisplayName))
        } else if let chest = app.world.getComponent(Chest.self, from: entityA),
                  app.world.getComponent(PlayerTag.self, from: entityB) != nil,
                  !chest.isOpen {
            app.world.updateComponent(Chest.self, on: entityA) { c in c.isOpen = true }
            app.world.emit(ChestOpened(chestEntity: entityA, itemId: chest.containsItemId, displayName: chest.containsDisplayName))
        }
    }

    private func removeItem(_ entity: Entity, app: Application) {
        if let idx = itemEntities.firstIndex(of: entity) {
            itemEntities.remove(at: idx)
        }
        app.world.destroyEntity(entity)
    }

    // MARK: - UI

    private func setupUI(app: Application) {
        ui = UIContext(font: font)

        let panelX = RPG.gameAreaWidth + 5
        let panelW = RPG.panelWidth - 10

        // Use a manual-layout container for the side panel
        let panel = UIContainer(id: "panel")
        panel.layout = .manual
        panel.frame = Rect(x: panelX, y: 0, width: panelW, height: RPG.screenHeight)

        // Title
        let invTitle = UILabel("Inventory", fontSize: 16, color: RPG.textBright)
        invTitle.frame = Rect(x: 0, y: 10, width: panelW, height: 20)
        panel.add(invTitle)

        // Inventory list
        inventoryList = UIListView(items: ["(empty)"], fontSize: 12)
        inventoryList.frame = Rect(x: 0, y: 35, width: panelW, height: 200)
        inventoryList.rowHeight = 22
        panel.add(inventoryList)

        // Equipment labels
        weaponLabel = UILabel("Weapon: -", fontSize: 12, color: RPG.textDim)
        weaponLabel.frame = Rect(x: 0, y: 245, width: panelW, height: 18)
        panel.add(weaponLabel)

        armorLabel = UILabel("Armor: -", fontSize: 12, color: RPG.textDim)
        armorLabel.frame = Rect(x: 0, y: 265, width: panelW, height: 18)
        panel.add(armorLabel)

        // Save button
        let saveBtn = UIButton("Save Game", fontSize: 14) { [weak self] in
            self?.saveGame(app: app)
        }
        saveBtn.frame = Rect(x: 0, y: 300, width: panelW, height: 35)
        panel.add(saveBtn)

        // Load button
        let loadBtn = UIButton("Load Game", fontSize: 14) { [weak self] in
            self?.loadGame(app: app)
        }
        loadBtn.frame = Rect(x: 0, y: 345, width: panelW, height: 35)
        panel.add(loadBtn)

        // Status label
        statusLabel = UILabel("", fontSize: 11, color: RPG.textDim)
        statusLabel.frame = Rect(x: 0, y: 390, width: panelW, height: 18)
        panel.add(statusLabel)

        ui.add(panel)
    }

    private func refreshInventoryUI(app: Application) {
        guard let inv = app.world.getComponent(Inventory.self, from: playerEntity) else { return }
        inventoryList.items = inv.items.isEmpty ? ["(empty)"] : inv.items

        if let equip = app.world.getComponent(Equipment.self, from: playerEntity) {
            weaponLabel.text = "Weapon: \(equip.weaponSlot.isEmpty ? "-" : equip.weaponSlot)"
            armorLabel.text = "Armor: \(equip.armorSlot.isEmpty ? "-" : equip.armorSlot)"
        }
    }

    // MARK: - Save/Load

    private func saveGame(app: Application) {
        do {
            savedData = try serializer.encode(world: app.world)
            // swiftlint:disable:next force_unwrapping
            statusLabel.text = "Saved! (\(savedData!.count) bytes)"
            app.audio.playSound(sounds.save, volume: 0.5, pitch: 1.0, looping: false)
        } catch {
            statusLabel.text = "Save failed!"
        }
    }

    private func loadGame(app: Application) {
        guard let data = savedData else {
            statusLabel.text = "No save data!"
            return
        }

        // Clean up current entities
        clearAllEntities(app: app)

        do {
            let remap = try serializer.decode(from: data, into: app.world)
            _ = remap

            // Re-find entities by their components
            app.world.forEach { (entity: Entity, _: inout PlayerTag) in
                playerEntity = entity
            }
            app.world.forEach { (entity: Entity, _: inout ItemPickup) in
                itemEntities.append(entity)
            }
            app.world.forEach { (entity: Entity, _: inout Chest) in
                chestEntities.append(entity)
            }
            app.world.forEach { (entity: Entity, _: inout NPCTag) in
                npcEntities.append(entity)
            }
            // Find walls — entities with Collider2D + static body but no special tags
            app.world.forEach { (entity: Entity, rb: inout RigidBody2D) in
                if rb.bodyType == .static
                    && app.world.getComponent(ItemPickup.self, from: entity) == nil
                    && app.world.getComponent(Chest.self, from: entity) == nil
                    && app.world.getComponent(NPCTag.self, from: entity) == nil {
                    wallEntities.append(entity)
                }
            }

            refreshInventoryUI(app: app)
            statusLabel.text = "Loaded!"
            app.audio.playSound(sounds.load, volume: 0.5, pitch: 1.0, looping: false)
        } catch {
            statusLabel.text = "Load failed!"
            // Rebuild from scratch
            buildRoom(app: app)
            spawnPlayer(app: app)
            spawnItems(app: app)
            spawnChests(app: app)
            spawnNPCs(app: app)
        }
    }
}
