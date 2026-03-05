# File Format Parsers

`Sources/AgilisFormats/`

Pure Swift parsers with zero platform dependencies. All parsers accept either `Data` or `[UInt8]` input.

---

## LDtk

`Sources/AgilisFormats/LDtk/`

Parser for [LDtk](https://ldtk.io/) level editor JSON exports.

### Loading

```swift
let project = try LDtkLoader.load(from: jsonData)
// or
let project = try LDtkLoader.load(from: jsonBytes)
```

### Types

**`LDtkProject`**

| Property | Type | Description |
|----------|------|-------------|
| `jsonVersion` | `String` | LDtk format version |
| `worldGridWidth` | `Int?` | World grid dimensions |
| `worldGridHeight` | `Int?` | |
| `defaultGridSize` | `Int` | Default tile grid size |
| `levels` | `[LDtkLevel]` | All levels |
| `defs` | `LDtkDefinitions` | Layer and tileset definitions |

**`LDtkLevel`**

| Property | Type | Description |
|----------|------|-------------|
| `identifier` | `String` | Level name |
| `uid` | `Int` | Unique ID |
| `pxWid`, `pxHei` | `Int` | Pixel dimensions |
| `worldX`, `worldY` | `Int` | Position in world |
| `layerInstances` | `[LDtkLayerInstance]?` | Layer data |

**`LDtkLayerInstance`**

| Property | Type | Description |
|----------|------|-------------|
| `identifier` | `String` | Layer name |
| `type` | `String` | `"IntGrid"`, `"Tiles"`, `"Entities"`, `"AutoLayer"` |
| `gridSize` | `Int` | Cell size in pixels |
| `gridTiles` | `[LDtkTileInstance]` | Manual tiles |
| `autoLayerTiles` | `[LDtkTileInstance]` | Auto-generated tiles |
| `intGridCsv` | `[Int]` | IntGrid values |

**`LDtkTileInstance`**

| Property | Type | Description |
|----------|------|-------------|
| `px` | `[Int]` | Pixel position in layer [x, y] |
| `src` | `[Int]` | Source position in tileset [x, y] |
| `f` | `Int` | Flip flags (0=none, 1=X, 2=Y, 3=both) |
| `t` | `Int` | Tile ID |

### LDtk Bridge

`Sources/AgilisFormats/LDtk/LDtkBridge.swift`

Convert parsed LDtk data to Agilis's `TileMap`:

```swift
let tileMap = TileMap.fromLDtk(
    level: project.levels[0],
    project: project,
    textures: ["tileset.png": texHandle]
)
```

Pixel-to-grid conversion, flip flag decoding, layer order reversed (bottom-first). Tile IDs offset by +1 (LDtk `t` + 1) so 0 = empty.

---

## Tiled

`Sources/AgilisFormats/Tiled/TiledMap.swift`

Parser for [Tiled](https://www.mapeditor.org/) JSON map exports (`.json`/`.tmj`).

### Loading

```swift
let map = try TiledLoader.load(from: jsonData)
```

### Types

**`TiledMapData`**

| Property | Type | Description |
|----------|------|-------------|
| `width`, `height` | `Int` | Map size in tiles |
| `tilewidth`, `tileheight` | `Int` | Tile size in pixels |
| `layers` | `[TiledLayerData]` | All layers |
| `tilesets` | `[TiledTilesetRef]` | Tileset references |

**`TiledLayerData`**

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Layer name |
| `type` | `String` | `"tilelayer"`, `"objectgroup"`, `"imagelayer"`, `"group"` |
| `data` | `[Int]?` | Tile GIDs (for tile layers) |
| `visible` | `Bool` | Visibility |
| `opacity` | `Float` | Layer opacity |

**`TiledTilesetRef`**

| Property | Type | Description |
|----------|------|-------------|
| `firstgid` | `Int` | First global tile ID |
| `source` | `String?` | External tileset path |
| `name`, `image` | `String?` | Embedded tileset fields |
| `tilewidth`, `tileheight` | `Int?` | Tile dimensions |
| `columns`, `tilecount` | `Int?` | Layout info |

### Tiled Bridge

`Sources/AgilisFormats/Tiled/TiledBridge.swift`

Convert parsed Tiled data to Agilis's `TileMap`:

```swift
let tileMap = TileMap.fromTiled(
    tiled,
    textures: ["tileset.png": texHandle]
)
```

Decodes GID flip bits (bit 31 = flipX, bit 30 = flipY). Only `tilelayer` type is converted.

---

## TexturePacker

`Sources/AgilisFormats/TextureAtlas/TextureAtlasFormat.swift`

Parser for TexturePacker JSON (Hash) atlas exports.

### Loading

```swift
let atlas = try TextureAtlasLoader.load(from: jsonData)
```

### Types

**`TextureAtlasData`**

| Property | Type | Description |
|----------|------|-------------|
| `frames` | `[String: AtlasFrame]` | Sprite frames keyed by name |
| `meta` | `AtlasMeta` | Atlas metadata |

**`AtlasFrame`**

| Property | Type | Description |
|----------|------|-------------|
| `frame` | `AtlasRect` | Position and size in atlas |
| `rotated` | `Bool` | Whether sprite is rotated 90 degrees |
| `trimmed` | `Bool` | Whether transparent pixels were trimmed |
| `spriteSourceSize` | `AtlasRect` | Trimmed offset within original |
| `sourceSize` | `AtlasSize` | Original sprite dimensions |

**`AtlasMeta`** — `image: String`, `size: AtlasSize`, `scale: String?`

### TextureAtlas Animation Bridge

`Sources/AgilisFormats/TextureAtlas/TextureAtlasBridge.swift`

Create `AnimationClip` from TexturePacker atlas frames by prefix matching:

```swift
let walkClip = AnimationClip.fromTextureAtlas(
    atlas, prefix: "player_walk_", frameDuration: 0.1
)
```

---

## Aseprite

`Sources/AgilisFormats/Aseprite/AsepriteAnimation.swift`

Parser for Aseprite JSON animation data exports.

### Loading

```swift
let anim = try AsepriteLoader.load(from: jsonData)
```

### Types

**`AsepriteData`**

| Property | Type | Description |
|----------|------|-------------|
| `frames` | `[AsepriteFrame]` | Animation frames |
| `meta` | `AsepriteMeta` | Metadata including frame tags |

**`AsepriteFrame`**

| Property | Type | Description |
|----------|------|-------------|
| `frame` | `AsepriteRect` | Position and size in spritesheet |
| `duration` | `Int` | Frame duration in milliseconds |
| `rotated` | `Bool` | Rotation flag |
| `trimmed` | `Bool` | Trim flag |

**`AsepriteFrameTag`** — Named animation sequences:

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Tag name (e.g., "walk", "idle") |
| `from`, `to` | `Int` | Frame range |
| `direction` | `String` | `"forward"`, `"reverse"`, `"pingpong"` |

Handles both array and dictionary frame export formats.

### Aseprite Animation Bridge

`Sources/AgilisFormats/Aseprite/AsepriteAnimationBridge.swift`

Create `AnimationClip` from Aseprite frame tags:

```swift
let clips = AnimationClip.fromAseprite(anim)
// Returns [AnimationClip] — one per frame tag
// Durations converted from ms to seconds
// Direction mapped: "forward" → .forward, "reverse" → .reverse, "pingpong" → .pingPong
```
