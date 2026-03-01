import SpriteKit

class Enemy: SKSpriteNode {

    // MARK: - State
    var health: Int = kEnemyMaxHealth
    var isDead = false
    var facingRight = true
    private var isAttacking = false
    private var animState: AnimationState = .idle
    private var currentAnimKey: AnimationState?

    // MARK: - AI
    private var patrolLeft: CGFloat = 0
    private var patrolRight: CGFloat = 0
    private var movingRight = true
    private var playerRef: Player?
    private var isChasing = false
    private var attackCooldown: TimeInterval = 0

    // MARK: - Animations
    private var animations: [AnimationState: [SKTexture]] = [:]

    // MARK: - Init
    init(patrolStart: CGFloat, patrolEnd: CGFloat) {
        let idleTextures = loadSpriteSheet(named: "enemy_assets/Enemy_Idle", frameCount: 5)
        let firstFrame = idleTextures.first ?? SKTexture()
        super.init(texture: firstFrame, color: .clear,
                   size: CGSize(width: kSpriteFrameSize * kSpriteScale,
                                height: kSpriteFrameSize * kSpriteScale))

        self.name = "enemy"
        self.zPosition = 45

        self.patrolLeft = patrolStart
        self.patrolRight = patrolEnd

        animations[.idle] = idleTextures
        animations[.walk] = loadSpriteSheet(named: "enemy_assets/Enemy_Walk", frameCount: 8)
        animations[.run] = loadSpriteSheet(named: "enemy_assets/Enemy_Run", frameCount: 6)
        animations[.attack1] = loadSpriteSheet(named: "enemy_assets/Enemy_Attack_1", frameCount: 4)
        animations[.attack2] = loadSpriteSheet(named: "enemy_assets/Enemy_Attack_2", frameCount: 4)
        animations[.dead] = loadSpriteSheet(named: "enemy_assets/Enemy_Dead", frameCount: 4)

        setupPhysics()
        playAnimation(.idle)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Physics
    private func setupPhysics() {
        let bodySize = CGSize(width: 36 * kSpriteScale, height: 64 * kSpriteScale)
        let bodyCenter = CGPoint(x: 0, y: -12 * kSpriteScale)
        physicsBody = SKPhysicsBody(rectangleOf: bodySize, center: bodyCenter)
        physicsBody?.categoryBitMask = PhysicsCategory.enemy
        physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.playerAttack | PhysicsCategory.ground
        physicsBody?.collisionBitMask = PhysicsCategory.ground
        physicsBody?.allowsRotation = false
        physicsBody?.friction = 0.2
        physicsBody?.restitution = 0
        physicsBody?.mass = 1.0
    }

    // MARK: - Animation
    private func playAnimation(_ state: AnimationState, force: Bool = false) {
        guard state != currentAnimKey || force else { return }
        guard let textures = animations[state], !textures.isEmpty else { return }

        currentAnimKey = state
        removeAction(forKey: "animation")

        let isOneShot = (state == .attack1 || state == .attack2 || state == .dead)
        let speed: TimeInterval = (state == .attack1 || state == .attack2) ? 0.1 : 0.12

        if isOneShot {
            let animAction = SKAction.animate(with: textures, timePerFrame: speed, resize: false, restore: false)
            let completion = SKAction.run { [weak self] in
                guard let self = self else { return }
                if state == .dead { return }
                self.isAttacking = false
            }
            run(SKAction.sequence([animAction, completion]), withKey: "animation")
        } else {
            let animAction = SKAction.animate(with: textures, timePerFrame: speed, resize: false, restore: true)
            run(SKAction.repeatForever(animAction), withKey: "animation")
        }
    }

    // MARK: - Update
    func update(deltaTime dt: TimeInterval, player: Player) {
        guard !isDead else { return }
        playerRef = player
        attackCooldown = max(0, attackCooldown - dt)

        let distToPlayer = hypot(player.position.x - position.x, player.position.y - position.y)
        let playerAlive = !player.isDead

        if playerAlive && distToPlayer < kEnemyAttackRange {
            attackPlayer(player)
        } else if playerAlive && distToPlayer < kEnemyDetectRange {
            chasePlayer(player)
        } else {
            patrol()
        }

        updateFacing()
    }

    // MARK: - AI Behaviors
    private func patrol() {
        isChasing = false
        guard !isAttacking else { return }

        let speed = kEnemySpeed

        if movingRight {
            physicsBody?.velocity.dx = speed
            if position.x >= patrolRight { movingRight = false }
        } else {
            physicsBody?.velocity.dx = -speed
            if position.x <= patrolLeft { movingRight = true }
        }

        playAnimation(.walk)
    }

    private func chasePlayer(_ player: Player) {
        isChasing = true
        guard !isAttacking else { return }

        let dir: CGFloat = player.position.x > position.x ? 1 : -1
        physicsBody?.velocity.dx = dir * kEnemyChaseSpeed

        playAnimation(.run)
    }

    private func attackPlayer(_ player: Player) {
        guard !isAttacking && attackCooldown <= 0 else { return }

        isAttacking = true
        attackCooldown = 1.2
        physicsBody?.velocity.dx = 0

        playAnimation(.attack1, force: true)

        let hitDelay = SKAction.wait(forDuration: 0.2)
        let hit = SKAction.run { [weak self] in
            guard let self = self, let player = self.playerRef, !player.isDead else { return }
            let dist = hypot(player.position.x - self.position.x, player.position.y - self.position.y)
            if dist < kEnemyAttackRange * 2 {
                player.takeDamage(kEnemyDamage, from: self.position)
            }
        }
        run(SKAction.sequence([hitDelay, hit]))
    }

    private func updateFacing() {
        if let vel = physicsBody?.velocity.dx {
            if vel > 5 {
                facingRight = true
                xScale = -abs(xScale) // enemy sprites face left by default
            } else if vel < -5 {
                facingRight = false
                xScale = abs(xScale)
            }
        }
    }

    // MARK: - Damage
    func takeDamage(_ amount: Int, from sourcePos: CGPoint) {
        guard !isDead else { return }

        health -= amount

        let knockDir: CGFloat = position.x > sourcePos.x ? 1 : -1
        physicsBody?.velocity = CGVector(dx: knockDir * 200, dy: 150)

        // Flash red
        let flash = SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 0.8, duration: 0.05),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
        ])
        run(SKAction.repeat(flash, count: 2))

        if health <= 0 {
            die()
        }
    }

    private func die() {
        isDead = true
        isAttacking = false
        physicsBody?.velocity = .zero
        physicsBody?.categoryBitMask = PhysicsCategory.none
        physicsBody?.collisionBitMask = PhysicsCategory.none
        playAnimation(.dead)

        run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }
}
