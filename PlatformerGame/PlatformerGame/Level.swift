import SpriteKit

// Tile types used in the level map
// 0 = empty, 1 = grass top, 2 = dirt, 3 = grass left, 4 = grass right
// 5 = platform left, 6 = platform mid, 7 = platform right
// 8 = grass top-left corner, 9 = grass top-right corner
struct TileMapping {
    // Maps our simple tile IDs to actual tile file names (Tile_01 through Tile_60)
    static let tileFileIndex: [Int: Int] = [
        1: 1,   // grass top
        2: 11,  // dirt fill
        3: 10,  // grass left edge
        4: 12,  // grass right edge
        5: 4,   // platform left
        6: 5,   // platform middle
        7: 6,   // platform right
        8: 2,   // corner top-left
        9: 3,   // corner top-right
    ]

    static func textureName(for tileID: Int) -> String {
        let fileIdx = tileFileIndex[tileID] ?? tileID
        return String(format: "GameAssets/1 Tiles/Tile_%02d", fileIdx)
    }
}

// MARK: - Level Data
struct LevelData {
    let tileMap: [[Int]]       // 2D array, row 0 = top
    let playerSpawn: CGPoint   // tile coordinates
    let enemies: [(x: CGFloat, patrolLeft: CGFloat, patrolRight: CGFloat, y: CGFloat)]
    let bushPositions: [(x: CGFloat, y: CGFloat, type: Int)]
    let levelWidth: Int
    let levelHeight: Int

    var pixelWidth: CGFloat {
        CGFloat(levelWidth) * kDisplayTileSize
    }

    var pixelHeight: CGFloat {
        CGFloat(levelHeight) * kDisplayTileSize
    }
}

struct LevelBuilder {

    // Create the default level
    static func buildLevel1() -> LevelData {
        // Level: 60 tiles wide x 18 tiles tall
        // Row 0 = top of level, Row 17 = bottom
        let W = 60
        let H = 18
        var map = Array(repeating: Array(repeating: 0, count: W), count: H)

        // Ground layer (rows 15-17)
        for col in 0..<W {
            // Skip gaps
            if (col >= 18 && col <= 19) || (col >= 38 && col <= 39) { continue }
            map[15][col] = 1  // grass top
            map[16][col] = 2  // dirt
            map[17][col] = 2  // dirt
        }

        // Floating platforms
        let platforms: [(row: Int, startCol: Int, length: Int)] = [
            (12, 5, 4),
            (10, 11, 3),
            (11, 16, 5),
            (9, 22, 3),
            (12, 25, 4),
            (10, 30, 3),
            (8, 34, 4),
            (12, 40, 5),
            (10, 46, 3),
            (9, 50, 4),
            (12, 55, 4),
        ]

        for p in platforms {
            for col in p.startCol..<min(p.startCol + p.length, W) {
                if col == p.startCol {
                    map[p.row][col] = 5  // platform left
                } else if col == p.startCol + p.length - 1 {
                    map[p.row][col] = 7  // platform right
                } else {
                    map[p.row][col] = 6  // platform mid
                }
            }
        }

        // Steps/stairs near start
        map[14][3] = 1
        map[13][4] = 1

        let enemies: [(x: CGFloat, patrolLeft: CGFloat, patrolRight: CGFloat, y: CGFloat)] = [
            (10, 7, 14, 15),
            (24, 20, 28, 15),
            (33, 30, 36, 15),
            (45, 42, 50, 15),
            (54, 52, 58, 15),
            (13, 11, 14, 10),     // on platform
            (27, 25, 29, 12),     // on platform
        ]

        let bushPositions: [(x: CGFloat, y: CGFloat, type: Int)] = [
            (2, 15, 1), (8, 15, 3), (15, 15, 2),
            (22, 15, 1), (30, 15, 4), (42, 15, 2),
            (50, 15, 1), (56, 15, 3),
        ]

        return LevelData(
            tileMap: map,
            playerSpawn: CGPoint(x: 2, y: 14),
            enemies: enemies,
            bushPositions: bushPositions,
            levelWidth: W,
            levelHeight: H
        )
    }
}

// MARK: - Level Node Builder
class LevelNode: SKNode {

    let data: LevelData
    private var groundBodies: [SKPhysicsBody] = []

    init(data: LevelData) {
        self.data = data
        super.init()
        buildTiles()
        buildBushes()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func buildTiles() {
        let tileSize = kDisplayTileSize

        for row in 0..<data.levelHeight {
            for col in 0..<data.levelWidth {
                let tileID = data.tileMap[row][col]
                guard tileID != 0 else { continue }

                let texName = TileMapping.textureName(for: tileID)
                let texture = SKTexture(imageNamed: texName)
                texture.filteringMode = .nearest

                let tile = SKSpriteNode(texture: texture, size: CGSize(width: tileSize, height: tileSize))
                // Convert row,col to world position (bottom-left origin)
                let x = CGFloat(col) * tileSize + tileSize / 2
                let y = CGFloat(data.levelHeight - 1 - row) * tileSize + tileSize / 2
                tile.position = CGPoint(x: x, y: y)
                tile.zPosition = 10

                // Add physics for solid tiles
                if tileID == 1 || tileID == 2 || tileID == 3 || tileID == 4 ||
                   tileID == 5 || tileID == 6 || tileID == 7 || tileID == 8 || tileID == 9 {
                    let body = SKPhysicsBody(rectangleOf: CGSize(width: tileSize, height: tileSize))
                    body.isDynamic = false
                    body.categoryBitMask = PhysicsCategory.ground
                    body.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.enemy
                    body.friction = 0.5
                    tile.physicsBody = body
                }

                addChild(tile)
            }
        }
    }

    private func buildBushes() {
        let tileSize = kDisplayTileSize

        for bush in data.bushPositions {
            let type = max(1, min(9, bush.type))
            let texName = "GameAssets/Bushes/\(type)"
            let texture = SKTexture(imageNamed: texName)
            texture.filteringMode = .nearest

            let bushNode = SKSpriteNode(texture: texture,
                                        size: CGSize(width: 31 * kSpriteScale, height: 15 * kSpriteScale))
            let x = bush.x * tileSize + tileSize / 2
            let y = CGFloat(data.levelHeight - 1 - Int(bush.y)) * tileSize + tileSize + bushNode.size.height / 2
            bushNode.position = CGPoint(x: x, y: y)
            bushNode.zPosition = 8
            addChild(bushNode)
        }
    }

    // Convert tile coordinates to world position
    func tileToWorld(col: CGFloat, row: CGFloat) -> CGPoint {
        let tileSize = kDisplayTileSize
        let x = col * tileSize + tileSize / 2
        let y = CGFloat(data.levelHeight - 1 - Int(row)) * tileSize + tileSize / 2
        return CGPoint(x: x, y: y)
    }

    // Spawn position above the given tile row
    func spawnPosition(col: CGFloat, row: CGFloat) -> CGPoint {
        let pos = tileToWorld(col: col, row: row)
        return CGPoint(x: pos.x, y: pos.y + kDisplayTileSize)
    }
}
