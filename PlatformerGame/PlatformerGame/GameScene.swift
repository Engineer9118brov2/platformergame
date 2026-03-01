import SpriteKit

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Nodes
    var player: Player!
    var enemies: [Enemy] = []
    var levelNode: LevelNode!
    var cameraNode: SKCameraNode!
    var hud: GameHUD!
    var backgroundLayers: [SKSpriteNode] = []

    // MARK: - State
    private var lastUpdateTime: TimeInterval = 0
    private var isGameOver = false
    private var levelData: LevelData!

    // MARK: - Input (macOS)
    private var keysPressed: Set<UInt16> = []

    // MARK: - Input (iOS)
    var touchMoveDirection: CGFloat = 0
    var touchJump = false
    var touchAttack = false

    // MARK: - Scene Setup
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.45, green: 0.72, blue: 0.88, alpha: 1.0)

        physicsWorld.gravity = CGVector(dx: 0, dy: kGravity)
        physicsWorld.contactDelegate = self

        // Camera
        cameraNode = SKCameraNode()
        addChild(cameraNode)
        camera = cameraNode

        // Build level
        levelData = LevelBuilder.buildLevel1()
        levelNode = LevelNode(data: levelData)
        addChild(levelNode)

        // Background
        setupBackground()

        // Player
        player = Player()
        let spawn = levelNode.spawnPosition(col: levelData.playerSpawn.x, row: levelData.playerSpawn.y)
        player.position = spawn
        addChild(player)

        // Enemies
        spawnEnemies()

        // HUD
        hud = GameHUD()
        cameraNode.addChild(hud)

        // Floor boundary
        addFloorBoundary()
    }

    private func setupBackground() {
        let viewSize = self.size

        // Layer 1 (farthest) - Mountain view
        let bg1 = SKSpriteNode(imageNamed: "GameAssets/Mountain-view")
        bg1.setScale(max(viewSize.width / bg1.size.width, viewSize.height / bg1.size.height) * 1.5)
        bg1.zPosition = -30
        bg1.name = "bg_far"
        addChild(bg1)
        backgroundLayers.append(bg1)

        // Layer 2 (mid) - Plains with trees
        let bg2 = SKSpriteNode(imageNamed: "GameAssets/Plainwtrees")
        bg2.setScale(max(viewSize.width / bg2.size.width, viewSize.height / bg2.size.height) * 1.5)
        bg2.zPosition = -20
        bg2.name = "bg_mid"
        addChild(bg2)
        backgroundLayers.append(bg2)

        // Layer 3 (near) - Plains
        let bg3 = SKSpriteNode(imageNamed: "GameAssets/Plains")
        bg3.setScale(max(viewSize.width / bg3.size.width, viewSize.height / bg3.size.height) * 1.8)
        bg3.zPosition = -10
        bg3.name = "bg_near"
        addChild(bg3)
        backgroundLayers.append(bg3)
    }

    private func spawnEnemies() {
        for enemyData in levelData.enemies {
            let patrolLeftPx = enemyData.patrolLeft * kDisplayTileSize
            let patrolRightPx = enemyData.patrolRight * kDisplayTileSize
            let enemy = Enemy(patrolStart: patrolLeftPx, patrolEnd: patrolRightPx)
            let pos = levelNode.spawnPosition(col: enemyData.x, row: enemyData.y)
            enemy.position = pos
            addChild(enemy)
            enemies.append(enemy)
        }
    }

    private func addFloorBoundary() {
        // Death zone below level
        let deathZone = SKNode()
        deathZone.position = CGPoint(x: levelData.pixelWidth / 2, y: -100)
        let body = SKPhysicsBody(rectangleOf: CGSize(width: levelData.pixelWidth * 2, height: 20))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.ground
        deathZone.physicsBody = body
        deathZone.name = "deathZone"
        addChild(deathZone)
    }

    // MARK: - Game Loop
    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdateTime == 0 ? 0 : currentTime - lastUpdateTime
        lastUpdateTime = currentTime

        guard !isGameOver else { return }

        // Process input
        processInput()

        // Update entities
        player.update(deltaTime: dt)
        for enemy in enemies where !enemy.isDead {
            enemy.update(deltaTime: dt, player: player)
        }

        // Camera follow
        updateCamera()

        // Update parallax
        updateParallax()

        // Update HUD
        hud.updateHealth(player.health)

        // Check death by falling
        if player.position.y < -50 {
            player.takeDamage(kPlayerMaxHealth, from: player.position)
        }

        // Check game over
        if player.isDead && !isGameOver {
            gameOver()
        }

        // Clean up dead enemies and score
        enemies.removeAll { enemy in
            if enemy.isDead && enemy.parent == nil {
                hud.addScore(100)
                return true
            }
            return false
        }
    }

    private func updateCamera() {
        let targetX = player.position.x
        let targetY = player.position.y + 50

        // Clamp camera to level bounds
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2

        let minX = halfWidth
        let maxX = levelData.pixelWidth - halfWidth
        let minY = halfHeight
        let maxY = levelData.pixelHeight - halfHeight

        let clampedX = max(minX, min(maxX, targetX))
        let clampedY = max(minY, min(maxY, targetY))

        // Smooth follow
        let lerpFactor: CGFloat = 0.1
        cameraNode.position.x += (clampedX - cameraNode.position.x) * lerpFactor
        cameraNode.position.y += (clampedY - cameraNode.position.y) * lerpFactor

        hud.updatePosition(cameraPos: .zero, viewSize: size)
    }

    private func updateParallax() {
        let camX = cameraNode.position.x
        let camY = cameraNode.position.y
        let parallaxFactors: [CGFloat] = [0.1, 0.3, 0.5]

        for (i, bg) in backgroundLayers.enumerated() {
            let factor = parallaxFactors[i]
            bg.position = CGPoint(x: camX * (1.0 - factor) + camX * factor,
                                  y: camY * 0.3 + 100)
        }
    }

    // MARK: - Input Processing
    private func processInput() {
        var moveDir: CGFloat = 0
        var jump = false
        var attack = false

        #if os(macOS)
        // Arrow keys / WASD
        if keysPressed.contains(123) || keysPressed.contains(0) { moveDir -= 1 } // Left / A
        if keysPressed.contains(124) || keysPressed.contains(2) { moveDir += 1 } // Right / D
        if keysPressed.contains(126) || keysPressed.contains(13) || keysPressed.contains(49) {
            jump = true // Up / W / Space
        }
        if keysPressed.contains(6) || keysPressed.contains(3) { attack = true } // Z / F
        #endif

        // iOS touch input
        if touchMoveDirection != 0 { moveDir = touchMoveDirection }
        if touchJump { jump = true; touchJump = false }
        if touchAttack { attack = true; touchAttack = false }

        player.moveDirection = moveDir
        if jump { player.wantsJump = true }
        if attack { player.wantsAttack = true }
    }

    // MARK: - macOS Keyboard
    #if os(macOS)
    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        keysPressed.insert(event.keyCode)

        if isGameOver && event.keyCode == 15 { // R key
            restartGame()
        }
    }

    override func keyUp(with event: NSEvent) {
        keysPressed.remove(event.keyCode)
    }
    #endif

    // MARK: - iOS Touch
    #if os(iOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isGameOver {
            restartGame()
        }
    }
    #endif

    // MARK: - Physics Contact
    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA
        let b = contact.bodyB

        let playerMask = PhysicsCategory.player
        let groundMask = PhysicsCategory.ground

        // Player lands on ground
        if (a.categoryBitMask == playerMask && b.categoryBitMask == groundMask) ||
           (b.categoryBitMask == playerMask && a.categoryBitMask == groundMask) {

            // Check if player is above the ground tile
            let playerBody = a.categoryBitMask == playerMask ? a : b
            let groundBody = a.categoryBitMask == groundMask ? a : b

            if let playerNode = playerBody.node, let groundNode = groundBody.node {
                if playerNode.position.y > groundNode.position.y {
                    player.isOnGround = true
                }
            }
        }

        // Player-enemy collision
        if (a.categoryBitMask == playerMask && b.categoryBitMask == PhysicsCategory.enemy) ||
           (b.categoryBitMask == playerMask && a.categoryBitMask == PhysicsCategory.enemy) {
            let enemyNode = a.categoryBitMask == PhysicsCategory.enemy ? a.node : b.node
            if let enemy = enemyNode as? Enemy, !enemy.isDead {
                // Player takes damage on touch
                if !player.isAttacking {
                    player.takeDamage(1, from: enemy.position)
                }
            }
        }
    }

    func didEnd(_ contact: SKPhysicsContact) {
        let a = contact.bodyA
        let b = contact.bodyB

        let playerMask = PhysicsCategory.player
        let groundMask = PhysicsCategory.ground

        if (a.categoryBitMask == playerMask && b.categoryBitMask == groundMask) ||
           (b.categoryBitMask == playerMask && a.categoryBitMask == groundMask) {
            // Small delay before setting not on ground (for edge transitions)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                if let vel = self?.player.physicsBody?.velocity.dy, abs(vel) > 10 {
                    self?.player.isOnGround = false
                }
            }
        }
    }

    // MARK: - Game State
    private func gameOver() {
        isGameOver = true
        hud.showGameOver()
    }

    func restartGame() {
        isGameOver = false
        hud.hideGameOver()
        hud.score = 0

        // Remove old enemies
        for enemy in enemies { enemy.removeFromParent() }
        enemies.removeAll()

        // Respawn player
        let spawn = levelNode.spawnPosition(col: levelData.playerSpawn.x, row: levelData.playerSpawn.y)
        player.respawn(at: spawn)

        // Respawn enemies
        spawnEnemies()
    }

    // MARK: - Scene Size
    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
    }
}
