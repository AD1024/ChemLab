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

class ViewController: UIViewController, ARSCNViewDelegate {
    
    // CoreML
    private var visionRequests = [VNRequest]()
    private let dispatchQueue = DispatchQueue(label: "com.mikehe.requeue")
    
    @IBOutlet weak var startReaction: UIButton!
    
    @IBOutlet weak var resultDebugText: UILabel!
    
    // Scene
    private var result: String = "..."
    private var confidence: Float = -0.01
    private let resultTextViewDepth: Float = 0.05
    private var infoCardShowed: Bool = false
    private var viewHeight: CGFloat = 1024.0
    private var viewWidth: CGFloat = 768.0
    
    // Vars
    private var lastResult: String = "..."
    private var atomList: [String] = ["H", "O", "C", "Cl", "Na"]
    private var atomRadius: [String:Double] = ["H": 0.005, "O": 0.010, "C": 0.008, "Cl": 0.015, "Na": 0.006]
    private let electronCourseRadius: [String:Double] = ["H": 0.010, "O": 0.015, "C": 0.013, "Cl": 0.020, "Na": 0.011]
    private let atomColor: [String:UIColor] = ["H": .white, "O": .red, "Cl": .green, "Na": .purple, "C": .black]
    private let electronCount: [String:Int] = ["H": 1, "O": 2, "C": 4, "Cl": 7, "Na": 1]
    private var hasDetectedNoticifation: Bool = false
    
    
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
        self.resultDebugText.text = "Indentified Text"
        self.sceneView.autoenablesDefaultLighting = true
        self.viewWidth = sceneView.frame.width
        self.viewHeight = sceneView.frame.height
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
    
    @objc func clearScene(gestureRecognizer: UIGestureRecognizer) {
        self.sceneView.scene.rootNode.childNodes.map({
            $0.removeFromParentNode()
        })
    }
    
    
    @objc func createAtomByTapping(gestureRecognizer: UIGestureRecognizer) {
        let HitTestResults : [ARHitTestResult] = sceneView.hitTest(gestureRecognizer.location(in: gestureRecognizer.view), types: ARHitTestResult.ResultType.featurePoint)
        
        if let closestResult = HitTestResults.first {
            if atomList.contains(self.resultDebugText.text!) {
                let transform : matrix_float4x4 = closestResult.worldTransform
                let position : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
                let atomName = self.resultDebugText.text!
                guard let wrapperNode = AtomUtil.makeAtomWithElectrons(name: atomName, radius: self.atomRadius[atomName]!, color: self.atomColor[atomName]!, numberOfElectrons: self.electronCount[atomName]!, electronOrbitRadius: self.electronCourseRadius[atomName]!, position: position) else {
                    return
                }
                self.sceneView.scene.rootNode.addChildNode(wrapperNode)
            }
        } else {
            self.noticeInfo("Initializing...", autoClear: true, autoClearTime: 4)
            print("Pending detection...")
        }
    }
    
    func loopQRCodeIdentification() {
        dispatchQueue.asyncAfter(deadline: DispatchTime.now() + TimeInterval(1.5), execute: {
            self.performQRCodeIdentificatation()
            self.loopQRCodeIdentification()
        })
    }
    
    func performQRCodeIdentificatation() {
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
//        ocrImage = self.prepareImageForCrop(using: ocrImage)
        if ocrImage.size.height > 0 && ocrImage.size.width > 0 {
            let barcodeRequest = VNDetectBarcodesRequest(completionHandler: {request, error in
                guard let resultSet = request.results else { return }
                for result in resultSet {
                    if let barcode = result as? VNBarcodeObservation {
                        print("Symbology: \(barcode.symbology.rawValue)")
                        if let ans = barcode.payloadStringValue {
                            DispatchQueue.main.async {
                                if self.atomList.contains(ans) {
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