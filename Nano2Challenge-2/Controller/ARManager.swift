//
//  ARManager.swift
//  Nano2Challenge-2
//
//  Created by Bryan Vernanda on 17/05/24.
//

import Foundation
import ARKit
import Combine

enum ARAction {
    case attackButton
}

class ARManager {
    static let shared = ARManager()
    
    private init() {
        sceneView = ARSCNView()
    }
    
    let sceneView: ARSCNView
    var actionStream = PassthroughSubject<ARAction, Never>()
}