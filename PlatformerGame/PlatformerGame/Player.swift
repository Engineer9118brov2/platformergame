import SpriteKit

class Player: SKSpriteNode {

    // MARK: - State
    var health: Int = kPlayerMaxHealth
    var isOnGround = false
    var isAttacking = false
    var isDead = false
    var facingRight = true
    var animState: AnimationState = .idle

    // Move input: -1 left, 0 none, 1 right
    var moveDirection: CGFloat = 0
    var wantsJump = false
    var wantsAttack = false

    // MARK: - Animations
    private var animations: [AnimationState: [SKTexture]] = [:]
    private var currentAnimKey: AnimationState?

    // MARK: - Init
    init() {
        let idleTextures = loadSpriteSheet(named: "Warrior_1/Idle", frameCount: 6)
        let firstFrame = idleTextures.first ?? SKTexture()
        super.init(texture: firstFrame, color: .clear,
                   size: CGSize(width: kSpriteFrameSize * kSpriteScale,
                                height: kSpriteFrameSize * kSpriteScale))

        self.name = "player"
        self.zPosition = 50

        animations[.idle] = idleTextures
        animations[.walk] = loadSpriteSheet(named: "Warrior_1/Walk", frameCount: 8)
        animations[.run] = loadSpriteSheet(named: "Warrior_1/Run", frameCount: 6)
        animations[.jump] = loadSpriteSheet(named: "Warrior_1/Jump", frameCount: 5)
        animations[.attack1] = loadSpriteSheet(named: "Warrior_1/Attack_1", frameCount: 4)
        animations[.attack2] = loadSpriteSheet(named: "Warrior_1/Attack_2", frameCount: 4)
        animations[.hurt] = loadSpriteSheet(named: "Warrior_1/Hurt", frameCount: 2)
        animations[.dead] = loadSpriteSheet(named: "Warrior_1/Dead", frameCount: 4)

        setupPhysics()
        playAnimation(.idle)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    // MARK: - Physics
    private func setupPhysics() {
        let bodySize = CGSize(width: 40 * kSpriteScale, height: 70 * kSpriteScale)
        let bodyCenter = CGPoint(x: 0, y: -10 * kSpriteScale)
        physicsBody = SKPhysicsBody(rectangleOf: bodySize, center: bodyCenter)
        physicsBody?.categoryBitMask = PhysicsCategory.player
        physicsBody?.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.enemyAttack | PhysicsCategory.ground
        physicsBody?.collisionBitMask = PhysicsCategory.ground
        physicsBody?.allowsRotation = false
        physicsBody?.friction = 0.2
        physicsBody?.restitution = 0
        physicsBody?.mass = 1.0
    }

    // MARK: - Animation
    func playAnimation(_ state: AnimationState, force: Bool = false) {
        guard state != currentAnimKey || force else { return }
        guard let textures = animations[state], !textures.isEmpty else { return }

        currentAnimKey = state
        removeAction(forKey: "animation")

        let isOneShot = (state == .attack1 || state == .attack2 || state == .hurt || state == .dead)
        let speed: TimeInterval = (state == .attack1 || state == .attack2) ? 0.08 : 0.1

        if isOneShot {
            let animAction = SKAction.animate(with: textures, timePerFrame: speed, resize: false, restore: false)
            let completion = SKAction.run { [weak self] in
                guard let self = self else { return }
                if state == .dead { return }
                self.isAttacking = false
                self.updateAnimation()
            }
            run(SKAction.sequence([animAction, completion]), withKey: "animation")
        } else {
            let animAction = SKAction.animate(with: textures, timePerFrame: speed, resize: false, restore: true)
            run(SKAction.repeatForever(animAction), withKey: "animation")
        }
    }

    // MARK: - Update
    func update(deltaTime dt: TimeInterval) {
        guard !isDead else { return }

        handleMovement()
        handleJump()
        handleAttack()
        updateFacing()
        updateAnimation()
        checkGroundContact()
    }

    private func handleMovement() {
        guard !isAttacking else { return }
        guard let body = physicsBody else { return }

        let speed = kPlayerSpeed
        body.velocity.dx = moveDirection * speed
    }

    private func handleJump() {
        if wantsJump && isOnGround && !isAttacking {
            physicsBody?.velocity.dy = kJumpVelocity
            isOnGround = false
            wantsJump = false
        } else {
            wantsJump = false
        }
    }

    private func handleAttack() {
        if wantsAttack && !isAttacking && isOnGround {
            isAttacking = true
            wantsAttack = false
            physicsBody?.velocity.dx = 0
            playAnimation(.attack1, force: true)
            performAttackHitDetection()
        } else {
            wantsAttack = false
        }
    }

    private func performAttackHitDetection() {
        let delay = SKAction.wait(forDuration: 0.15)
        let detect = SKAction.run { [weak self] in
            guard let self = self, let scene = self.scene else { return }
            let attackX = self.position.x + (self.facingRight ? kAttackRange : -kAttackRange)
            let attackPoint = CGPoint(x: attackX, y: self.position.y)

            scene.enumerateChildNodes(withName: "//enemy*") { node, _ in
                if let enemy = node as? Enemy, !enemy.isDead {
                    let dist = hypot(enemy.position.x - attackPoint.x,
                                     enemy.position.y - attackPoint.y)
                    if dist < kAttackRange * 1.5 {
                        enemy.takeDamage(kAttackDamage, from: self.position)
                    }
                }
            }
        }
        run(SKAction.sequence([delay, detect]))
    }

    private func updateFacing() {
        if moveDirection > 0 {
            facingRight = true
            xScale = abs(xScale)
        } else if moveDirection < 0 {
            facingRight = false
            xScale = -abs(xScale)
        }
    }

    private func updateAnimation() {
        guard !isAttacking && !isDead else { return }

        if !isOnGround {
            playAnimation(.jump)
        } else if abs(moveDirection) > 0 {
            playAnimation(.run)
        } else {
            playAnimation(.idle)
        }
    }

    private func checkGroundContact() {
        guard let body = physicsBody else { return }
        if abs(body.velocity.dy) < 5 && !isOnGround {
            // Will be set properly by contact delegate
        }
    }

    // MARK: - Damage
    func takeDamage(_ amount: Int, from sourcePos: CGPoint) {
        guard !isDead else { return }

        health -= amount

        // Knockback
        let knockDir: CGFloat = position.x > sourcePos.x ? 1 : -1
        physicsBody?.velocity = CGVector(dx: knockDir * 250, dy: 200)

        if health <= 0 {
            die()
        } else {
            playAnimation(.hurt, force: true)
            isAttacking = true // prevent movement briefly
            run(SKAction.sequence([
                SKAction.wait(forDuration: 0.3),
                SKAction.run { [weak self] in self?.isAttacking = false }
            ]))

            // Flash effect
            let blink = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.1),
                SKAction.fadeAlpha(to: 1.0, duration: 0.1)
            ])
            run(SKAction.repeat(blink, count: 3))
        }
    }

    private func die() {
        isDead = true
        isAttacking = false
        physicsBody?.velocity = .zero
        physicsBody?.categoryBitMask = PhysicsCategory.none
        playAnimation(.dead)
    }

    func respawn(at pos: CGPoint) {
        position = pos
        health = kPlayerMaxHealth
        isDead = false
        isAttacking = false
        isOnGround = false
        alpha = 1.0
        physicsBody?.categoryBitMask = PhysicsCategory.player
        physicsBody?.velocity = .zero
        playAnimation(.idle, force: true)
    }
}
