//
//  ViewController.swift
//  Nano2Challenge-2
//
//  Created by Bryan Vernanda on 15/05/24.
//

import UIKit
import SceneKit
import ARKit
import GameplayKit
import Combine

enum CollisionTypes: Int {
    case zombie = 1
    case castle = 2
    case arrow = 4
}

class ViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate, ObservableObject {

    @IBOutlet var sceneView: ARSCNView!
    
    private var spawnTimer: DispatchSourceTimer?
    private var currentZPosition: Float = -5
    private let randomSource = GKRandomSource()
    private var limitZombies = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView = ARManager.shared.sceneView
        sceneView.frame = self.view.frame
        self.view.addSubview(sceneView)
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Show world anchor
//        sceneView.debugOptions = .showBoundingBoxes
        
        sceneView.scene.physicsWorld.contactDelegate = self
    }
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        if (contact.nodeA.physicsBody?.categoryBitMask == CollisionTypes.castle.rawValue) && (contact.nodeB.physicsBody?.categoryBitMask == CollisionTypes.zombie.rawValue) {
//            print("Zombie hit the castle!")
            contact.nodeB.removeFromParentNode()
//            print("node B removed")
        } else if (contact.nodeA.physicsBody?.categoryBitMask == CollisionTypes.zombie.rawValue) && (contact.nodeB.physicsBody?.categoryBitMask == CollisionTypes.castle.rawValue) {
//            print("Zombie hit the castle!")
            contact.nodeA.removeFromParentNode()
//            print("node A removed")
        }
        
        if (contact.nodeA.physicsBody?.categoryBitMask == CollisionTypes.arrow.rawValue) && (contact.nodeB.physicsBody?.categoryBitMask == CollisionTypes.zombie.rawValue) {
//            handleZombieHit(contact: contact.nodeB)
            contact.nodeA.removeFromParentNode()
            (contact.nodeB as? Zombie)?.takeDamage()
        } else if (contact.nodeA.physicsBody?.categoryBitMask == CollisionTypes.zombie.rawValue) && (contact.nodeB.physicsBody?.categoryBitMask == CollisionTypes.arrow.rawValue) {
//            handleZombieHit(contact: contact.nodeA)
            contact.nodeB.removeFromParentNode()
            (contact.nodeA as? Zombie)?.takeDamage()
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal

        // Run the view's session
        sceneView.session.run(configuration)
        
        // Create an anchor at the world origin
        let anchor = ARAnchor(name: "zombieAnchor", transform: matrix_identity_float4x4)
        sceneView.session.add(anchor: anchor)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
        
        // Invalidate the timer when the view disappears
        spawnTimer?.cancel()
        spawnTimer = nil
    }

    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if anchor.name == "zombieAnchor" {
            // Add the castle to the scene
            addCastle(for: node)
            
            // Start spawning zombies at regular intervals
            startSpawningZombies(for: node)
            
            // Attack button
            subscribeToActionStream(for: node)
        }
    }
    
    private var cancellable: Set<AnyCancellable> = []
    
    func subscribeToActionStream(for node: SCNNode) {
        ARManager.shared
            .actionStream
            .sink { [weak self] action in //to make sure no app crashing or memory leaks, use weak self
                switch action {
                    case .attackButton:
                        self?.attackBowButton(for: node)
                }
            }//this is a subscribe, so customARView get inform whenever contentview sends an ARAction
            .store(in: &cancellable)
    }
    
    private func startSpawningZombies(for parentNode: SCNNode) {
        // Create a dispatch timer to spawn zombies every 2 seconds
        spawnTimer = DispatchSource.makeTimerSource()
        spawnTimer?.schedule(deadline: .now(), repeating: 2.0)
        spawnTimer?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Generate a random x position between -5 and 5
                let randomXPosition = Float(self.randomSource.nextInt(upperBound: 11)) - 5.0
//                print("Spawning zombie at x: \(randomXPosition), z: \(self.currentZPosition)")
                
                // Spawn a zombie at the current position & limit the zombies
                if self.limitZombies < 5 {
//                    print("Spawning zombie at x: \(randomXPosition), z: \(self.currentZPosition)")
                    self.spawnZombie(at: SCNVector3(x: randomXPosition, y: -0.5, z: self.currentZPosition), for: parentNode)
                    self.limitZombies += 1
                }
            }
        }
        spawnTimer?.resume()
    }
    
    func spawnZombie(at position: SCNVector3, for parentNode: SCNNode) {
        let zombie = Zombie(at: position)
        parentNode.addChildNode(zombie)
    }
    
    func addCastle(for parentNode: SCNNode) {
        let castle = Castle()
        parentNode.addChildNode(castle)
    }
    
    func attackBowButton(for parentNode: SCNNode) {
        guard let currentFrame = sceneView.session.currentFrame else { return }
        
        // Get the camera transform
        let cameraTransform = currentFrame.camera.transform
        let cameraPosition = SCNVector3(cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z)
        
        // Set the arrow's orientation to match the camera's orientation
        let cameraOrientation = SCNVector3(-cameraTransform.columns.2.x, -cameraTransform.columns.2.y, -cameraTransform.columns.2.z)
        
        // send the camera position and orientation to the arrow to be launched
        let arrow = Arrow(at: cameraPosition, at: cameraOrientation)
        arrow.look(at: SCNVector3(cameraPosition.x + cameraOrientation.x, cameraPosition.y + cameraOrientation.y, cameraPosition.z + cameraOrientation.z))
        
        // Add the arrow to the scene
        parentNode.addChildNode(arrow)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
}





