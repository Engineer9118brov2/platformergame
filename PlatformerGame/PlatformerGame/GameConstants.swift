import SpriteKit

// MARK: - Physics Categories
enum PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32 = 1 << 0
    static let enemy: UInt32 = 1 << 1
    static let ground: UInt32 = 1 << 2
    static let playerAttack: UInt32 = 1 << 3
    static let enemyAttack: UInt32 = 1 << 4
}

// MARK: - Animation States
enum AnimationState {
    case idle, walk, run, jump, attack1, attack2, hurt, dead
}

// MARK: - Tile & Sprite Constants
let kTileSize: CGFloat = 32
let kSpriteScale: CGFloat = 2.0
let kDisplayTileSize: CGFloat = kTileSize * kSpriteScale
let kSpriteFrameSize: CGFloat = 96

// MARK: - Player Constants
let kPlayerSpeed: CGFloat = 200
let kJumpVelocity: CGFloat = 620
let kPlayerMaxHealth: Int = 5
let kAttackRange: CGFloat = 80
let kAttackDamage: Int = 1

// MARK: - Enemy Constants
let kEnemySpeed: CGFloat = 80
let kEnemyChaseSpeed: CGFloat = 140
let kEnemyDetectRange: CGFloat = 250
let kEnemyAttackRange: CGFloat = 60
let kEnemyMaxHealth: Int = 2
let kEnemyDamage: Int = 1

// MARK: - World Constants
let kGravity: CGFloat = -22

// MARK: - Sprite Sheet Frame Counts
let kFrameCounts: [String: Int] = [
    // Warrior_1 (Player)
    "Warrior_1/Idle": 6,
    "Warrior_1/Walk": 8,
    "Warrior_1/Run": 6,
    "Warrior_1/Jump": 5,
    "Warrior_1/Attack_1": 4,
    "Warrior_1/Attack_2": 4,
    "Warrior_1/Attack_3": 4,
    "Warrior_1/Hurt": 2,
    "Warrior_1/Dead": 4,
    "Warrior_1/Run+Attack": 4,
    // Enemy
    "enemy_assets/Enemy_Idle": 5,
    "enemy_assets/Enemy_Walk": 8,
    "enemy_assets/Enemy_Run": 6,
    "enemy_assets/Enemy_Attack_1": 4,
    "enemy_assets/Enemy_Attack_2": 4,
    "enemy_assets/Enemy_Dead": 4,
]

// MARK: - Texture Helper
func loadSpriteSheet(named name: String, frameCount: Int) -> [SKTexture] {
    let sheet = SKTexture(imageNamed: name)
    sheet.filteringMode = .nearest
    var textures: [SKTexture] = []
    let frameWidth = 1.0 / CGFloat(frameCount)
    for i in 0..<frameCount {
        let rect = CGRect(x: CGFloat(i) * frameWidth, y: 0, width: frameWidth, height: 1.0)
        let tex = SKTexture(rect: rect, in: sheet)
        tex.filteringMode = .nearest
        textures.append(tex)
    }
    return textures
}
