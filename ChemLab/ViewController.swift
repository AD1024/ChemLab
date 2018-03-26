//
//  ViewController.swift
//  ChemLab
//
//  Created by Mike He on 2018/3/22.
//  Copyright © 2018年 Deyuan He. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Vision
import TesseractOCR

extension UIImage {
    func detectOrientationDegree () -> CGFloat {
        switch imageOrientation {
        case .right, .rightMirrored:    return 90
        case .left, .leftMirrored:      return -90
        case .up, .upMirrored:          return 180
        case .down, .downMirrored:      return 0
        }
    }
    
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

extension SCNNode {
    
    func addNodeClonesWithNames(fromScene: SCNScene,   nodeNames: [String]  ) {
        for nodename in nodeNames {
            self.addClonedChildNode(node: fromScene.rootNode.childNode(withName: nodename, recursively: true)! )
        }
    }
    
    func addClonedChildNode(node: SCNNode) {
        self.addChildNode(node.clone() as! SCNNode)
    }
}


class ViewController: UIViewController, ARSCNViewDelegate, G8TesseractDelegate {
    
    // CoreML
    private var visionRequests = [VNRequest]()
    private let dispatchQueue = DispatchQueue(label: "com.mikehe.requeue")
    private let ocrInstance = G8Tesseract(language: "eng")
    
    @IBOutlet weak var startReaction: UIButton!
    
    @IBOutlet weak var resultDebugText: UILabel!
    
    // Scene
    private var result: String = "..."
    private var confidence: Float = -0.01
    private let resultTextViewDepth: Float = 0.05
    private var infoCard: ResultTab?
    private var infoCardShowed: Bool = false
    private var viewHeight: CGFloat = 1024.0
    private var viewWidth: CGFloat = 768.0
    
    private var lastResult: String = "..."
    private var atomList: [String] = ["H", "O"]
    private let atomColor: [String:UIColor] = ["H": .cyan, "O": .red, "Cl": .yellow, "Na": .green]
    
    @IBOutlet var sceneView: ARSCNView!
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.createAtomByTapping(gestureRecognizer:)))
        view.addGestureRecognizer(tapGesture)
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(self.clearScene(gestureRecognizer:)))
        view.addGestureRecognizer(longPressRecognizer)
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        let rect = CGRect(x: 0, y: view.frame.height, width: view.frame.width, height: 120)
        infoCard = ResultTab(frame: rect)
        infoCard?.backgroundColor = UIColor.white
        self.view.addSubview(infoCard!)
        self.resultDebugText.text = "Indentified Text"
        self.sceneView.autoenablesDefaultLighting = true
        self.viewWidth = sceneView.frame.width
        self.viewHeight = sceneView.frame.height
        ocrInstance?.engineMode = .tesseractCubeCombined
        ocrInstance?.pageSegmentationMode = .singleLine
        ocrInstance?.delegate = self
        ocrInstance?.charWhitelist = "123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        self.loopOCR()
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
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
    func getAtomScene(name: String) -> SCNScene? {
        if self.atomList.contains(name) {
            let scene = SCNScene(named: "art.scnassets/\(name).scn")
            return scene
        } else {
            print("\(name) is not a valid atom")
            return nil
        }
    }
    
    
    func generateAtomModel(atomName: String) -> SCNNode {
        let constraint = SCNBillboardConstraint()
        constraint.freeAxes = SCNBillboardAxis.Y
        let atomNameTag = SCNText(string: atomName, extrusionDepth: 0.005)
        atomNameTag.font = UIFont(name: "Courier", size: 0.15)
        atomNameTag.alignmentMode = kCAAlignmentCenter
        atomNameTag.firstMaterial?.diffuse.contents = self.atomColor[atomName]
        atomNameTag.firstMaterial?.specular.contents = UIColor.white
        atomNameTag.firstMaterial?.isDoubleSided = true
        atomNameTag.chamferRadius = CGFloat(0.005)
        let (minBound, maxBound) = atomNameTag.boundingBox
        let atomNameTagNode = SCNNode(geometry: atomNameTag)
        atomNameTagNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, 0.12)
        atomNameTagNode.scale = SCNVector3(0.2, 0.2, 0.2)
        let sphere = SCNSphere(radius: 0.010)
        sphere.firstMaterial?.diffuse.contents = self.atomColor[atomName]
        let sphereNode = SCNNode(geometry: sphere)
        let wrapperNode = SCNNode()
        wrapperNode.addChildNode(atomNameTagNode)
        wrapperNode.addChildNode(sphereNode)
        wrapperNode.constraints = [constraint]
        return wrapperNode
    }
    
    @objc func clearScene(gestureRecognizer: UIGestureRecognizer) {
        self.sceneView.scene.rootNode.childNodes.map({
            $0.removeFromParentNode()
        })
    }
    
    func generateElectronNodes(count: Int, courseRadius: Double) -> SCNNode? {
        guard let degree: Double = 2.0 * .pi / Double(count) else {
            return nil
        }
        let wrapper: SCNNode = SCNNode()
        for i in 0..<count {
            let material = SCNSphere(radius: 0.002)
            material.firstMaterial?.diffuse.contents = UIColor.blue
            let electron = SCNNode(geometry: material)
            electron.position = SCNVector3(courseRadius * sin(Double(i) * degree), 0, courseRadius * cos(Double(i) * degree))
            wrapper.addChildNode(electron.clone())
        }
        return wrapper
    }
    
    
    @objc func createAtomByTapping(gestureRecognizer: UIGestureRecognizer) {
//        let screenCenter : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
        let HitTestResults : [ARHitTestResult] = sceneView.hitTest(gestureRecognizer.location(in: gestureRecognizer.view), types: ARHitTestResult.ResultType.featurePoint)
        
        if let closestResult = HitTestResults.first {
            let transform : matrix_float4x4 = closestResult.worldTransform
            let position : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            let atomNode = self.generateAtomModel(atomName: "H")
//            atomNode.position = position
//            sceneView.scene.rootNode.addChildNode(atomNode)
            /*
            let material = SCNSphere(radius: 0.002)
            material.firstMaterial?.diffuse.contents = UIColor.red
            let electron = SCNNode(geometry: material)
            let e_pos = SCNVector3(0.025, 0, 0)
            electron.position = e_pos
            let e_rotationNode = SCNNode()
            let animation = CABasicAnimation(keyPath: "rotation")
            animation.keyPath = "rotation"
            animation.toValue = SCNVector4Make(0, 1, 0, .pi * 2)
            animation.duration = 2.0
            animation.repeatCount = .greatestFiniteMagnitude
            e_rotationNode.addChildNode(electron)
            e_rotationNode.addAnimation(animation, forKey: "rotating")
            let wrapperNode = SCNNode()
            wrapperNode.addChildNode(atomNode)
            wrapperNode.addChildNode(e_rotationNode)
            wrapperNode.position = position */
            let animation = CABasicAnimation(keyPath: "rotation")
            animation.keyPath = "rotation"
            animation.toValue = SCNVector4Make(0, 1, 0, .pi * 2)
            animation.duration = 4.0
            animation.repeatCount = .greatestFiniteMagnitude
            let wrappedElectron = self.generateElectronNodes(count: 7, courseRadius: 0.025)
            wrappedElectron?.addAnimation(animation, forKey: "rotating")
            let wrapperNode = SCNNode()
            wrapperNode.addChildNode(atomNode)
            wrapperNode.addChildNode(wrappedElectron!)
            wrapperNode.position = position
            self.sceneView.scene.rootNode.addChildNode(wrapperNode)
        } else {
            print("Pending detection...")
        }
    }
    
    func loopOCR() {
        dispatchQueue.asyncAfter(deadline: DispatchTime.now() + TimeInterval(1.5), execute: {
            self.performOCR()
            self.loopOCR()
        })
    }
    
    func cropImage(image: UIImage, cropRect: CGRect) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(cropRect.size, false, image.scale)
        let origin = CGPoint(x: 0, y: -self.viewHeight / CGFloat(2.0))
        image.draw(at: origin)
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
    
    func prepareImageForCrop (using image: UIImage) -> UIImage {
        let degreesToRadians: (CGFloat) -> CGFloat = {
            return $0 / 180.0 * CGFloat(Double.pi)
        }
        
        let imageOrientation = image.imageOrientation
        let degree = image.detectOrientationDegree()
        let cropSize = CGSize(width: 400, height: 110)
        
        //Downscale
        let cgImage = image.cgImage!
        
        let width = cropSize.width
        let height = image.size.height / image.size.width * cropSize.width
        
        let bitsPerComponent = cgImage.bitsPerComponent
        let bytesPerRow = cgImage.bytesPerRow
        let colorSpace = cgImage.colorSpace
        let bitmapInfo = cgImage.bitmapInfo
        
        let context = CGContext(data: nil,
                                width: Int(width),
                                height: Int(height),
                                bitsPerComponent: bitsPerComponent,
                                bytesPerRow: bytesPerRow,
                                space: colorSpace!,
                                bitmapInfo: bitmapInfo.rawValue)
        
        context!.interpolationQuality = CGInterpolationQuality.none
        // Rotate the image context
        context?.rotate(by: degreesToRadians(degree));
        // Now, draw the rotated/scaled image into the context
        context?.scaleBy(x: -1.0, y: -1.0)
        
        //Crop
        switch imageOrientation {
        case .right, .rightMirrored:
            context?.draw(cgImage, in: CGRect(x: -height, y: 0, width: height, height: width))
        case .left, .leftMirrored:
            context?.draw(cgImage, in: CGRect(x: 0, y: -width, width: height, height: width))
        case .up, .upMirrored:
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        case .down, .downMirrored:
            context?.draw(cgImage, in: CGRect(x: -width, y: -height, width: width, height: height))
        }
        
        let calculatedFrame = CGRect(x: 0, y: CGFloat((height - cropSize.height)/2.0), width: cropSize.width, height: cropSize.height)
        let scaledCGImage = context?.makeImage()?.cropping(to: calculatedFrame)
        
        
        return UIImage(cgImage: scaledCGImage!)
    }
    
    func performOCR() {
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
        var ocrImage = UIImage(cgImage: cgImage!).image(withRotation: CGFloat(-0.5 * .pi))
        ocrImage = self.prepareImageForCrop(using: ocrImage)
        if ocrImage.size.height > 0 && ocrImage.size.width > 0 {
            ocrInstance?.image = ocrImage.g8_blackAndWhite()
            if (ocrInstance?.recognize())! {
                DispatchQueue.main.async {
                    self.lastResult = (self.ocrInstance?.recognizedText)!
                    self.lastResult = self.lastResult.filter({return $0 != " " && $0 != "\n"})
                    self.resultDebugText.text = self.lastResult
                }
            }
        } else {
            print("No a valid image")
        }
    }
    
    func showInfoCard(_ carName: String) {
        self.infoCard?.carName.text = carName
        if !infoCardShowed {
            UIView.animate(withDuration: 0.3, animations: {
                if let card = self.infoCard {
                    let newY = self.view.frame.height - card.frame.height
                    card.frame.origin = CGPoint(x: 0, y: newY)
                }
            })
            infoCardShowed = true
        }
    }
    
    func VNRequestHandler(request: VNRequest, error: Error?) {
        if error != nil {
            print("Error: \(error?.localizedDescription)")
        } else {
            guard let observations = request.results else {
                print("Not found")
                return
            }
            let classifications = observations[0...1]
                .flatMap({$0 as? VNClassificationObservation})
                .map({($0.identifier, $0.confidence)})
            DispatchQueue.main.async {
                /*
                for item in classifications {
                    print("Identifier:\(item.0)    Confidence: \(item.1)")
                }*/
                var maxn: Float = -1.0
                var identifier: String  = "..."
                for item in classifications {
                    if maxn < item.1 {
                        maxn = item.1
                        identifier = item.0
                    }
                }
                if self.result != identifier && self.confidence < maxn {
                    self.result = identifier
                    self.confidence = maxn
                    print("\(self.result)   \(self.confidence)")
                    // self.showInfoCard(self.result)
                }
            }
        }
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
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
