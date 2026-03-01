import SpriteKit

class GameHUD: SKNode {

    private var heartNodes: [SKSpriteNode] = []
    private var scoreLabel: SKLabelNode!
    private var gameOverLabel: SKLabelNode?
    private var restartLabel: SKLabelNode?
    var score: Int = 0 {
        didSet { scoreLabel?.text = "Score: \(score)" }
    }

    override init() {
        super.init()
        self.zPosition = 200
        self.name = "hud"
        setupHearts()
        setupScore()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    private func setupHearts() {
        for i in 0..<kPlayerMaxHealth {
            let heart = SKSpriteNode(color: .red, size: CGSize(width: 24, height: 24))
            heart.name = "heart_\(i)"
            // Will position relative to camera in updatePosition
            heartNodes.append(heart)
            addChild(heart)
        }
    }

    private func setupScore() {
        scoreLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        scoreLabel.fontSize = 20
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .right
        scoreLabel.text = "Score: 0"
        addChild(scoreLabel)
    }

    func updatePosition(cameraPos: CGPoint, viewSize: CGSize) {
        let left = cameraPos.x - viewSize.width / 2
        let top = cameraPos.y + viewSize.height / 2

        for (i, heart) in heartNodes.enumerated() {
            heart.position = CGPoint(x: left + 30 + CGFloat(i) * 30, y: top - 30)
        }

        scoreLabel.position = CGPoint(x: cameraPos.x + viewSize.width / 2 - 20, y: top - 35)

        gameOverLabel?.position = CGPoint(x: cameraPos.x, y: cameraPos.y + 30)
        restartLabel?.position = CGPoint(x: cameraPos.x, y: cameraPos.y - 20)
    }

    func updateHealth(_ health: Int) {
        for (i, heart) in heartNodes.enumerated() {
            heart.alpha = i < health ? 1.0 : 0.2
        }
    }

    func showGameOver() {
        guard gameOverLabel == nil else { return }

        let bg = SKSpriteNode(color: SKColor(red: 0, green: 0, blue: 0, alpha: 0.6),
                              size: CGSize(width: 300, height: 120))
        bg.name = "gameOverBG"
        bg.zPosition = 199
        addChild(bg)

        gameOverLabel = SKLabelNode(fontNamed: "Helvetica-Bold")
        gameOverLabel!.fontSize = 32
        gameOverLabel!.fontColor = .red
        gameOverLabel!.text = "GAME OVER"
        addChild(gameOverLabel!)

        restartLabel = SKLabelNode(fontNamed: "Helvetica")
        restartLabel!.fontSize = 18
        restartLabel!.fontColor = .white
        #if os(iOS)
        restartLabel!.text = "Tap to restart"
        #else
        restartLabel!.text = "Press R to restart"
        #endif
        addChild(restartLabel!)
    }

    func hideGameOver() {
        gameOverLabel?.removeFromParent()
        gameOverLabel = nil
        restartLabel?.removeFromParent()
        restartLabel = nil
        childNode(withName: "gameOverBG")?.removeFromParent()
    }

    func addScore(_ points: Int) {
        score += points
    }
}
