//
//  ViewController.swift
//  ChemLab
//
//  Created by Mike He on 2018/3/22.
//  Copyright © 2018 Deyuan He. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision

extension UIImage {
    func detectOrientationDegree () -> CGFloat {
        switch imageOrientation {
        case .right, .rightMirrored:    return 90
        case .left, .leftMirrored:      return -90
        case .up, .upMirrored:          return 180
        case .down, .downMirrored:      return 0
        }
    }
    
    ///  Rotate the image
    ///
    ///  - parameter radian: the angle(in rad) to rotate
    ///
    ///  - returns: The rotated image(type UIImages)
    func image(withRotation radians: CGFloat) -> UIImage {
        let cgImage = self.cgImage!
        let LARGEST_SIZE = CGFloat(max(self.size.width, self.size.height))
        let context = CGContext.init(data: nil, width:Int(LARGEST_SIZE), height:Int(LARGEST_SIZE), bitsPerComponent: cgImage.bitsPerComponent, bytesPerRow: 0, space: cgImage.colorSpace!, bitmapInfo: cgImage.bitmapInfo.rawValue)!
        
        var drawRect = CGRect.zero
        drawRect.size = self.size
        let drawOrigin = CGPoint(x: (LARGEST_SIZE - self.size.width) * 0.5,y: (LARGEST_SIZE - self.size.height) * 0.5)
        drawRect.origin = drawOrigin
        var tf = CGAffineTransform.identity
        tf = tf.translatedBy(x: LARGEST_SIZE * 0.5, y: LARGEST_SIZE * 0.5)
        tf = tf.rotated(by: CGFloat(radians))
        tf = tf.translatedBy(x: LARGEST_SIZE * -0.5, y: LARGEST_SIZE * -0.5)
        context.concatenate(tf)
        context.draw(cgImage, in: drawRect)
        var rotatedImage = context.makeImage()!
        
        drawRect = drawRect.applying(tf)
        
        rotatedImage = rotatedImage.cropping(to: drawRect)!
        let resultImage = UIImage(cgImage: rotatedImage)
        return resultImage
    }
}

class ViewController: UIViewController, ARSCNViewDelegate {
    
    // CoreML
    private var visionRequests = [VNRequest]()
    private let dispatchQueue = DispatchQueue(label: "com.mikehe.requeue")
    
    @IBOutlet weak var startReaction: UIButton!                        // Unused button
    
    @IBOutlet weak var resultDebugText: UILabel!                       // the result of QR identification & reaction equation
    
    // Scene
    private let resultTextViewDepth: Float = 0.05                      // the depth of label on atom models
    
    // Vars
    private var lastResult: String = "..."                             // the most recent QR identification result
    private var detectedReaction: [([String: Int], String, Int)] = []  // required atom count & product
//    private var atomAdded: PriorityQueue = PriorityQueue<String>()   // deprecated reaction detection algorithm
    private var atomAdded: [String: Int] = [:]                         // added atom(name:count) @note: remove all of these after performing a reaction
    private var reactedNodes: Set<SCNNode> = []                        // atoms that has performed reaction

    @IBOutlet var sceneView: ARSCNView!                                // AR sceneView
    
    override var prefersStatusBarHidden: Bool {                        // Hide status bar
        return true
    }
    
    // Enable shake detection
    override var canBecomeFirstResponder: Bool {                       // register for shaking detection
        get {
            return true
        }
    }
    
    ///  Get the atom list that contains atoms with {name} that did not reacted yet
    ///
    ///  - parameter name: the name of target atoms
    ///
    ///  - returns: the list of qualified atoms
    func getUnreactedNodeByName(_ name: String) -> [SCNNode] {
        let nodes = self.sceneView.scene.rootNode.childNodes.filter({
            return !self.reactedNodes.contains($0) && $0.name == name
        })
        return nodes
    }
    
    ///  Handle reaction
    ///
    ///  - parameter ***
    ///  - parameter ***
    ///
    ///  - returns: nil
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        var equationSet: Set<Int> = []
        if motion == .motionShake {
            for each in detectedReaction {     // handle all reactions that has been detected
                var atomCount = 0              // count the atom that will be consumed
                for (atom, count) in each.0 {  // each: ([String:Int], String, Int) the requirement of the reaction, the product, the id of the reaction(used to retreat the equation)
                    atomCount += count
                    atomAdded[atom]! -= count  // cost {count} atoms with name {atom}
                }
                equationSet.insert(each.2)     // use Set<String> to prevent duplicated equations
                var atomNodes: [String] = []
                for (atom, count) in each.0 {
                    for _ in 1...count {
                        atomNodes.append(atom)
                    }
                }
                let product = each.1
                if atomCount == 2 {   // If there are only two atoms, move those two together
                    var nodeOne = self.sceneView.scene.rootNode.childNodes.filter({
                        return !self.reactedNodes.contains($0) && $0.name == atomNodes[0]
                    })[0]
                    self.reactedNodes.insert(nodeOne)  // @note: add it into reacted set immidiately !!!
                    let potentialNodetwo = self.sceneView.scene.rootNode.childNodes.filter({return $0.name == atomNodes[1] && !self.reactedNodes.contains($0)})
                    var nodeTwo = potentialNodetwo.map({
                        return (AtomUtils.calcDistance(fi: nodeOne, se: $0), $0)
                    }).sorted(by: {(fi: (Float, SCNNode), se: (Float, SCNNode)) in
                        return fi.0 < se.0             // react with the nearest atom
                    })[0].1
                    self.reactedNodes.insert(nodeTwo)
                    let centerPos: SCNVector3 = AtomUtils.centerOfTwo(fi: nodeOne, se: nodeTwo)
                    if Constants.atomRadius[nodeOne.name!]! > Constants.atomRadius[nodeTwo.name!]! {
                        swap(&nodeOne, &nodeTwo)
                    }
                    // set up animations
                    let moveAnimation = CABasicAnimationBuilder
                        .setKeyPath("position")
                        .setToValue(centerPos)
                        .setDuration(2.0)
                        .setFillMode(kCAFillModeForwards)
                        .isRemovedOnCompletion(false).build()
                    let moveAnimationForSmallerAtom = CABasicAnimationBuilder
                        .setKeyPath("position")
                        .setToValue(AtomUtils.paddingPointForSmallerAtom(centerPos: centerPos, smallerAtomPosition: nodeOne.position, largerAtomRadius: Float(Constants.atomRadius[nodeTwo.name!]!)))
                        .setDuration(2.0)
                        .setFillMode(kCAFillModeForwards)
                        .isRemovedOnCompletion(false).build()
                    let fadeAnimation = CABasicAnimationBuilder
                        .setKeyPath("opacity")
                        .setFillMode(kCAFillModeForwards)
                        .setDuration(1.5)
                        .isRemovedOnCompletion(false)
                        .setToValue(0.0)
                        .build()
                    nodeOne.childNode(withName: "atomNameTag", recursively: true)?.addAnimation(fadeAnimation, forKey: "textFading")
                    nodeTwo.childNode(withName: "atomNameTag", recursively: true)?.addAnimation(fadeAnimation, forKey: "textFading")
                    nodeOne.childNode(withName: "electrons", recursively: true)?.addAnimation(fadeAnimation, forKey: "fading")
                    nodeTwo.childNode(withName: "electrons", recursively: true)?.addAnimation(fadeAnimation, forKey: "fading")
                    nodeOne.addAnimation(moveAnimation, forKey: "moving")
                    nodeTwo.addAnimation(moveAnimationForSmallerAtom, forKey: "moving")
                    let productTextNode = AtomUtils.makeTextNode(msg: product)
                    productTextNode.position = SCNVector3(centerPos.x, centerPos.y - 0.17, centerPos.z)
                    self.sceneView.scene.rootNode.addChildNode(productTextNode)
                } else {
                    // fade all the nodes and then create a new model at the position of {primary node}
                    let fadeAnimation = CABasicAnimationBuilder
                        .setKeyPath("opacity")
                        .setFillMode(kCAFillModeForwards)
                        .setDuration(1.8)
                        .isRemovedOnCompletion(false)
                        .setToValue(0.0)
                        .build()
                    let fadeInAnimation = CABasicAnimationBuilder
                        .setKeyPath("opacity")
                        .setFillMode(kCAFillModeForwards)
                        .setDuration(2.3)
                        .setFromValue(0.0)
                        .isRemovedOnCompletion(false)
                        .setToValue(1.0)
                        .build()
                    atomNodes = atomNodes.sorted(by: {(x: String, y: String) in
                        return Constants.atomRadius[x]! > Constants.atomRadius[y]!
                    })
                    guard let centerNodeName = ReactionDetector.getReactionPrimaryAtom(reactant: Set(atomNodes)) else {
                        print("Unknown reaction! No primary found")
                        return
                    }   // the position that other secondary atoms fly to
                    let centerNodesList = getUnreactedNodeByName(centerNodeName)
                    if centerNodesList.count > 0 {
                        let centerNode = centerNodesList[0]
                        atomNodes.remove(at: atomNodes.index(of: centerNodeName)!)
                        let remaining = Array(atomNodes)
                        reactedNodes.insert(centerNode)
                        let movingAnimation = CABasicAnimationBuilder
                            .setKeyPath("position")
                            .setToValue(centerNode.position)
                            .setFillMode(kCAFillModeForwards)
                            .isRemovedOnCompletion(false)
                            .setDuration(2.0)
                            .build()
                        var remainingNodes: [SCNNode] = []
                        for each in remaining {
                            // find out the remaining nodes
                            let potentialNodes = getUnreactedNodeByName(each)
                            if potentialNodes.count > 0 {
                                let node = potentialNodes[0]
                                reactedNodes.insert(node)
                                remainingNodes.append(node)
                            } else {
                                print("Error while reacting: Insufficient remaining atom") // preventing exhaustion
                                return
                            }
                        }
                        centerNode.addAnimation(fadeAnimation, forKey: "fading")
                        print(remainingNodes.count)
                        // Considering to add callback to remove these nodes
                        for each in remainingNodes {
                            each.addAnimation(movingAnimation, forKey: "moving")
                            each.addAnimation(fadeAnimation, forKey: "fading")
                        }
                        guard let productNode = AtomUtils.makeCombinedAtomsBy(name: product, position: centerNode.position) else {
                            print("\(product) does not have model")
                            return
                        }
                        let productTextNode = AtomUtils.makeTextNode(msg: product)
                        productTextNode.position = SCNVector3(centerNode.position.x, centerNode.position.y - 0.17, centerNode.position.z)
                        productTextNode.addAnimation(fadeInAnimation, forKey: "fadeIn")
                        productNode.addAnimation(fadeInAnimation, forKey: "fadeIn")
                        self.sceneView.scene.rootNode.addChildNode(productNode)
                        self.sceneView.scene.rootNode.addChildNode(productTextNode)
                    }
                }
            }
            self.detectedReaction.removeAll()
        }
        print("End reaction: \(atomAdded)")
        detectedReaction.removeAll()
        let reactionResult = ReactionDetector.translateToEquation(equationSet)
        self.resultDebugText.text = reactionResult
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.becomeFirstResponder()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.createAtomByTapping(gestureRecognizer:)))
        view.addGestureRecognizer(tapGesture)
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.clearScene(gestureRecognizer:)))
        view.addGestureRecognizer(longPressRecognizer)
        // Set the view's delegate
        sceneView.delegate = self
        resultDebugText.numberOfLines = 5
        resultDebugText.lineBreakMode = .byWordWrapping
        let size: CGSize = resultDebugText.sizeThatFits(CGSize(width: resultDebugText.frame.size.width, height: CGFloat(MAXFLOAT)))
        
        resultDebugText.frame = CGRect(x: resultDebugText.frame.origin.x, y: resultDebugText.frame.origin.y, width: resultDebugText.frame.size.width, height: size.height);
        
        
        // hide statistics such as fps and timing information
        sceneView.showsStatistics = false
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Initialize scene and text
        self.resultDebugText.text = "Scan QRCode to Begin experiment! :D"
        self.sceneView.autoenablesDefaultLighting = true
        self.loopQRCodeIdentification()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.navigationController?.setToolbarHidden(true, animated: true)
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        configuration.planeDetection = .horizontal
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        self.resignFirstResponder()
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    /// - Long click to remove everything
    @objc func clearScene(gestureRecognizer: UIGestureRecognizer) {
        self.sceneView.scene.rootNode.childNodes.map({
            $0.removeFromParentNode()
        })
        self.atomAdded.removeAll()
        self.detectedReaction.removeAll()
        self.reactedNodes.removeAll()
    }
    
    /// - tap the scene and create an atom at the position of the tapping point
    @objc func createAtomByTapping(gestureRecognizer: UIGestureRecognizer) {
        let HitTestResults : [ARHitTestResult] = sceneView.hitTest(gestureRecognizer.location(in: gestureRecognizer.view), types: ARHitTestResult.ResultType.featurePoint)
        
        if let closestResult = HitTestResults.first {
            if Constants.atomList.contains(self.lastResult) {
                let transform : matrix_float4x4 = closestResult.worldTransform
                let position : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
                let atomName = self.lastResult
                guard let wrapperNode = AtomUtils.makeAtomWithElectrons(name: atomName, radius: Constants.atomRadius[atomName]!, color: Constants.atomColor[atomName]!, numberOfElectrons: Constants.electronCount[atomName]!, electronOrbitRadius: Constants.electronCourseRadius[atomName]!, position: position) else {
                    return
                }
                
                // update atom counter
                if atomAdded[atomName] == nil {
                    atomAdded[atomName] = 1
                } else {
                    atomAdded[atomName]! += 1
                }
                
                // detect potential reactions
                let dReaction = ReactionDetector.detectReaction(atomAdded)
                detectedReaction = dReaction
                self.sceneView.scene.rootNode.addChildNode(wrapperNode)
            }
        } else {
            self.noticeInfo("Initializing...", autoClear: true, autoClearTime: 4)
            print("Pending detection...")
        }
    }
    
    /// - a loop task to identify QR code
    func loopQRCodeIdentification() {
        dispatchQueue.asyncAfter(deadline: DispatchTime.now() + TimeInterval(1.5), execute: {
            self.performQRCodeIdentificatation()
            self.loopQRCodeIdentification()
        })
    }
    
    func performQRCodeIdentificatation() {
        // get pixel from current frame in AR scene
        let pixel: CVPixelBuffer? = sceneView.session.currentFrame?.capturedImage
        if pixel == nil {
            print("No pixel got")
            return
        }
        let image = CIImage(cvPixelBuffer: pixel!)
        let ciContext = CIContext()
        let cgImage = ciContext.createCGImage(image, from: image.extent)
        if cgImage == nil {
            print("Invalid Image")
            return
        }
        
        // Rotate the image (it is actually unnecessary, but I used OCR previously so this will remain here)
        let ocrImage = UIImage(cgImage: cgImage!).image(withRotation: CGFloat(-0.5 * .pi))
        if ocrImage.size.height > 0 && ocrImage.size.width > 0 {
            let barcodeRequest = VNDetectBarcodesRequest(completionHandler: {request, error in
                guard let resultSet = request.results else { return }
                for result in resultSet {
                    if let barcode = result as? VNBarcodeObservation {
                        if let ans = barcode.payloadStringValue {
                            DispatchQueue.main.async {
                                if Constants.atomList.contains(ans) {
                                    if ans != self.lastResult {
                                        self.clearAllNotice()
                                        self.noticeOnlyText("\(ans) detected! Tap anywhere to place it.")
                                        self.lastResult = ans
                                        self.resultDebugText.text = ans
                                    }
                                }
                            }
                        }
                    }
                }
            })
            let handler = VNImageRequestHandler(cgImage: cgImage!, options: [:])
            guard let _ = try? handler.perform([barcodeRequest]) else{
                print("Error while scanning QRCode")
                return
            }
        } else {
            print("No a valid image")
        }
    }
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {

    }
*/
    
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
