//
//  GameScene.swift
//  Color Panic
//
//  Created by Ted Svärd on 2025-06-15.
//

import SpriteKit

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

class GameScene: SKScene {
    
    private var cutZones: [SKShapeNode] = []
    private var scoreLabel: SKLabelNode!
    private var perfectLabel: SKLabelNode!
    private var missLabel: SKLabelNode!
    private var currentScore: Int = 0
    
    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.1, green: 0.12, blue: 0.15, alpha: 1)
        
        if let view = self.view {
            print("Frame: \(frame)")
            print("Safe area insets: \(view.safeAreaInsets)")
        }
        
        let spawnAction = SKAction.run { [weak self] in
            self?.spawnFallingObjects()
        }
        let waitAction = SKAction.wait(forDuration: 1.0)
        let spawnSequence = SKAction.sequence([spawnAction, waitAction])
        let spawnForever = SKAction.repeatForever(spawnSequence)
        run(spawnForever)
        
        setupCutZones()
        setupScoreLabel()
        setupPerfectLabel()
        setupMissLabel()
    }
    
    override func didChangeSize(_ oldSize: CGSize) {
        removeAllChildren()
        cutZones.removeAll()
        setupCutZones()
        setupScoreLabel()
        setupPerfectLabel()
        setupMissLabel()
    }
    
    private func setupCutZones() {
        let zoneWidth: CGFloat = 120
        let zoneHeight: CGFloat = 50
        let numberOfZones = 4
        cutZones.removeAll()
        
        let yPosition: CGFloat = 100
        for i in 0..<numberOfZones {
            let zone = SKShapeNode(rectOf: CGSize(width: zoneWidth, height: zoneHeight), cornerRadius: 16)
            let spacing = size.width / CGFloat(numberOfZones + 1)
            let xPosition = spacing * CGFloat(i + 1) - 390
            zone.position = CGPoint(x: xPosition, y: yPosition)
            zone.fillColor = SKColor(red: 0.2, green: 0.8, blue: 0.35, alpha: 0.82)
            zone.strokeColor = SKColor.white.withAlphaComponent(0.9)
            zone.lineWidth = 4
            zone.zPosition = 10
            addChild(zone)
            cutZones.append(zone)
        }
    }
    
    private func spawnFallingObjects() {
        let count = 1
        let indices = Array(0..<cutZones.count).shuffled().prefix(count)
        
        for i in indices {
            let zone = cutZones[i]
            let fallingObject = SKShapeNode(rectOf: CGSize(width: 44, height: 44), cornerRadius: 12)
            fallingObject.position = CGPoint(x: zone.position.x, y: size.height + 44)
            fallingObject.fillColor = SKColor(red: 0.92, green: 0.22, blue: 0.22, alpha: 1)
            fallingObject.strokeColor = SKColor.white.withAlphaComponent(1.0)
            fallingObject.lineWidth = 3
            fallingObject.name = "fallingBlock"
            fallingObject.zPosition = 20
            addChild(fallingObject)
            
            let moveDown = SKAction.moveTo(y: zone.position.y, duration: 2.8)
            let remove = SKAction.removeFromParent()
            fallingObject.run(SKAction.sequence([moveDown, remove]))
        }
    }
    
    private func setupScoreLabel() {
        scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.fontSize = 36
        scoreLabel.fontColor = SKColor.white.withAlphaComponent(0.9)
        scoreLabel.position = CGPoint(x: frame.midX, y: frame.maxY - 80)
        scoreLabel.text = "Poäng: 0"
        addChild(scoreLabel)
    }
    
    private func setupPerfectLabel() {
        perfectLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        perfectLabel.fontSize = 48
        perfectLabel.fontColor = SKColor.white
        perfectLabel.position = CGPoint(x: frame.midX, y: frame.midY + 120)
        perfectLabel.alpha = 0
        perfectLabel.text = "Perfect!"
        addChild(perfectLabel)
    }
    
    private func setupMissLabel() {
        missLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        missLabel.fontSize = 48
        missLabel.fontColor = SKColor.red
        missLabel.position = CGPoint(x: frame.midX, y: frame.midY + 60)
        missLabel.alpha = 0
        missLabel.text = "Miss!"
        addChild(missLabel)
    }
    
    private func updateScore() {
        currentScore += 1
        scoreLabel.text = "Poäng: \(currentScore)"
        scoreLabel.fontSize = 40
        scoreLabel.fontColor = SKColor.green.withAlphaComponent(0.9)
    }
    
    private func showPerfectEffect() {
        // Show "Perfect!" label with fade in and fade out, animate pop effect
        perfectLabel.alpha = 1
        perfectLabel.setScale(1.5)
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.2)
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        let group = SKAction.group([scaleDown, fadeOut])
        perfectLabel.run(group)
    }
    
    private func showMissEffect() {
        // Show "Miss!" label with fade in and fade out
        missLabel.alpha = 1
        let fadeOut = SKAction.fadeOut(withDuration: 0.6)
        missLabel.run(fadeOut)
        
        // Red screen flash
        let flash = SKShapeNode(rect: frame)
        flash.fillColor = SKColor.red.withAlphaComponent(0.3)
        flash.zPosition = 100
        addChild(flash)
        let flashOut = SKAction.fadeOut(withDuration: 0.4)
        flash.run(flashOut) {
            flash.removeFromParent()
        }
    }
    
    private func endGame() {
        currentScore = 0
        scoreLabel.text = "Poäng: 0"
        showMissEffect()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        // Find nodes at touch location
        let touchedNodes = nodes(at: location)
        // Filter all fallingBlock nodes
        let blocks = touchedNodes.compactMap { $0 as? SKShapeNode }.filter { $0.name == "fallingBlock" }
        var slicedAny = false
        for block in blocks {
            let isInZone = cutZones.contains { zone in
                let zoneRect = zone.frame.insetBy(dx: -60, dy: -40)
                return zoneRect.intersects(block.frame)
            }
            if isInZone {
                sliceBlock(block)
                updateScore()
                showPerfectEffect()
                slicedAny = true
            }
        }
        if !slicedAny {
            showMissEffect()
        }
    }

    // Slice animation: splits the block in half with an animation and removes original
    private func sliceBlock(_ block: SKShapeNode) {
        let size = block.frame.size
        let leftHalf = SKShapeNode(rectOf: CGSize(width: size.width / 2, height: size.height), cornerRadius: block.frame.height / 4)
        leftHalf.position = CGPoint(x: block.position.x - size.width / 4, y: block.position.y)
        leftHalf.fillColor = block.fillColor
        leftHalf.strokeColor = SKColor.white.withAlphaComponent(0.7)
        leftHalf.lineWidth = 2
        leftHalf.zPosition = block.zPosition + 1
        addChild(leftHalf)
        
        let rightHalf = SKShapeNode(rectOf: CGSize(width: size.width / 2, height: size.height), cornerRadius: block.frame.height / 4)
        rightHalf.position = CGPoint(x: block.position.x + size.width / 4, y: block.position.y)
        rightHalf.fillColor = block.fillColor
        rightHalf.strokeColor = SKColor.white.withAlphaComponent(0.7)
        rightHalf.lineWidth = 2
        rightHalf.zPosition = block.zPosition + 1
        addChild(rightHalf)
        
        // Remove the original block
        block.removeFromParent()
        
        // Animate halves: move apart, rotate, fade out, then remove
        let moveLeft = SKAction.group([
            SKAction.moveBy(x: -50, y: 40, duration: 0.5),
            SKAction.rotate(byAngle: -.pi / 3, duration: 0.5),
            SKAction.fadeOut(withDuration: 0.5)
        ])
        let moveRight = SKAction.group([
            SKAction.moveBy(x: 50, y: 40, duration: 0.5),
            SKAction.rotate(byAngle: .pi / 3, duration: 0.5),
            SKAction.fadeOut(withDuration: 0.5)
        ])
        leftHalf.run(moveLeft) { leftHalf.removeFromParent() }
        rightHalf.run(moveRight) { rightHalf.removeFromParent() }
    }
}
