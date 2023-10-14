//
//  SecondViewController.swift
//  tf-cam
//
//  Created by hrbysnk on 2020/10/02.
//

import UIKit
import AVFoundation

class SecondViewController: UIViewController {

  var previewView: PreviewView!
  var overlayView: OverlayView!
  var button: UIButton!
  private lazy var cameraFeedManager = CameraFeedManager(previewView: previewView)

  private var modelDataHandler: ModelDataHandler?
    = ModelDataHandler(modelFileInfo: MobileNetSSD.modelInfo, labelsFileInfo: MobileNetSSD.labelsInfo)

  private var result: Result?
  private var previousInferenceTimeMs: TimeInterval = Date.distantPast.timeIntervalSince1970 * 1000
  
  var selectedCategory = ""
  
  // Audio players
  private var player01: AVAudioPlayer?
  private var player02: AVAudioPlayer?
  private var player03: AVAudioPlayer?
  private var player04: AVAudioPlayer?
  private var player05: AVAudioPlayer?
  private var player06: AVAudioPlayer?
  private var playerBeep: AVAudioPlayer?

  // MARK: Constants
  private let displayFont = UIFont.monospacedDigitSystemFont(ofSize: 14, weight: .medium)
  private let edgeOffset: CGFloat = 2.0
  private let delayBetweenInferencesMs: Double = 200.0


  var windowOrientation: UIInterfaceOrientation {
      return view.window?.windowScene?.interfaceOrientation ?? .unknown
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.backgroundColor = .systemBackground
    navigationItem.title = "カメラ画面"

    previewView = PreviewView()
    view.addSubview(previewView)
    previewView.translatesAutoresizingMaskIntoConstraints = false
    previewView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
    previewView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
    
    overlayView = OverlayView()
    overlayView.clearsContextBeforeDrawing = true
    overlayView.backgroundColor = UIColor.clear
    view.addSubview(overlayView)
    
    do {
      player01 = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "voice01", ofType: "mp3")!))
      player02 = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "voice02", ofType: "mp3")!))
      player03 = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "voice03", ofType: "mp3")!))
      player04 = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "voice04", ofType: "mp3")!))
      player05 = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "voice05", ofType: "mp3")!))
      player06 = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "voice06", ofType: "mp3")!))
      playerBeep = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: Bundle.main.path(forResource: "beep", ofType: "mp3")!))
    } catch {
      print("Failed to load mp3 files")
    }
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    cameraFeedManager.delegate = self
    cameraFeedManager.checkCameraConfigurationAndStartSession()
    
    button = UIButton()
    button.backgroundColor = UIColor.clear
    button.setTitle("タップすると写真を撮影できます", for: .normal)
    button.setTitleColor(.black, for: .normal)
    button.addTarget(self, action: #selector(btnFunc), for: .touchUpInside)
    
    view.addSubview(button)
    button.translatesAutoresizingMaskIntoConstraints = false
    button.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
    button.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
  }

  override func viewWillDisappear(_ animated: Bool) {
    cameraFeedManager.stopSession()
    super.viewWillDisappear(animated)
  }

  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
      super.viewWillTransition(to: size, with: coordinator)

      if let previewLayerConnection = previewView.previewLayer.connection {
        let deviceOrientation = UIDevice.current.orientation
        guard let newVideoOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue) else {
          return
        }
        
        if deviceOrientation.isPortrait {
          let w = size.width
          let h = w * (4 / 3)
          let y = (size.height - h) / 2
          overlayView.frame = CGRect(x: 0, y: y, width: w, height: h)
        } else if deviceOrientation.isLandscape {
          let h = size.height
          let w = h * (4 / 3)
          let x = (size.width - w) / 2
          overlayView.frame = CGRect(x: x, y: 0, width: w, height: h)
        }
        
        previewLayerConnection.videoOrientation = newVideoOrientation
        cameraFeedManager.videoDataOutput.connection(with: .video)?.videoOrientation = newVideoOrientation
      }
  }
  
  @objc func btnFunc() {
    self.cameraFeedManager.capturePhoto()
  }

}

// MARK: CameraFeedManagerDelegate Methods
extension SecondViewController: CameraFeedManagerDelegate {

  func setInitialVideoOrientation() {
    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
    if windowOrientation != .unknown {
      if let videoOrientation = AVCaptureVideoOrientation(rawValue: windowOrientation.rawValue) {
        initialVideoOrientation = videoOrientation
        
        if windowOrientation.isPortrait {
          let w = view.bounds.width
          let h = w * (4 / 3)
          let y = (view.bounds.height - h) / 2
          overlayView.frame = CGRect(x: 0, y: y, width: w, height: h)
        } else if windowOrientation.isLandscape {
          let h = view.bounds.height
          let w = h * (4 / 3)
          let x = (view.bounds.width - w) / 2
          overlayView.frame = CGRect(x: x, y: 0, width: w, height: h)
        }
      }
    }

    previewView.previewLayer.connection?.videoOrientation = initialVideoOrientation
    cameraFeedManager.videoDataOutput.connection(with: .video)?.videoOrientation = initialVideoOrientation
  }

  func didOutput(pixelBuffer: CVPixelBuffer) {
    runModel(onPixelBuffer: pixelBuffer)
    
    // 音声フィードバック
    let obj = result?.predictions.first(where: { $0.className == selectedCategory })

    let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
    let imageHeight = CVPixelBufferGetHeight(pixelBuffer)

    if obj != nil {
      if obj?.className == selectedCategory {
        if (obj?.rect.midX)! < CGFloat(imageWidth / 3) {
          player01?.play()
        } else if (obj?.rect.midX)! > CGFloat(imageWidth * 2 / 3) {
          player02?.play()
        } else if (obj?.rect.midY)! < CGFloat(imageHeight / 3) {
          player03?.play()
        } else if (obj?.rect.midY)! > CGFloat(imageHeight * 2 / 3) {
          player04?.play()
        } else if max((obj?.rect.width)! / CGFloat(imageWidth), (obj?.rect.height)! / CGFloat(imageHeight)) < CGFloat(0.3) {
          player05?.play()
        } else if max((obj?.rect.width)! / CGFloat(imageWidth), (obj?.rect.height)! / CGFloat(imageHeight)) > CGFloat(0.8) {
          player06?.play()
        } else {
          playerBeep?.play()
        }
      }
    }
  }

  func presentCameraAuthorizationFailedAlert() {
    let alertController = UIAlertController(
      title: "エラー",
      message: "カメラの使用が許可されていません。設定を変更してください。",
      preferredStyle: .alert
    )

    alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

    alertController.addAction(UIAlertAction(title: "Settings", style: .default) { action in
      UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
    })

    present(alertController, animated: true, completion: nil)
  }

  func presentCameraConfigurationFailedAlert() {
    let alertController = UIAlertController(
      title: "エラー",
      message: "カメラの設定に失敗しました。",
      preferredStyle: .alert
    )

    alertController.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))

    present(alertController, animated: true, completion: nil)
  }

  func runModel(onPixelBuffer pixelBuffer: CVPixelBuffer) {
    let currentTimeMs = Date().timeIntervalSince1970 * 1000

    guard (currentTimeMs - previousInferenceTimeMs) >= delayBetweenInferencesMs else {
      return
    }

    previousInferenceTimeMs = currentTimeMs
    result = self.modelDataHandler?.runModel(onFrame: pixelBuffer)

    guard let displayResult = result else {
      return
    }

    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)

    DispatchQueue.main.async {
      self.drawAfterPerformingCalculations(onPredictions: displayResult.predictions, withImageSize: CGSize(width: CGFloat(width), height: CGFloat(height)))
    }
  }

  /**
   バウンディングボックスを描画する
   */
  func drawAfterPerformingCalculations(onPredictions predictions: [Prediction], withImageSize imageSize: CGSize) {

    self.overlayView.overlayObjects = []
    self.overlayView.setNeedsDisplay()

    guard !predictions.isEmpty else {
      return
    }

    var overlayObjects: [OverlayObject] = []

    for prediction in predictions {

      var convertedRect = prediction.rect.applying(CGAffineTransform(scaleX: self.overlayView.bounds.size.width / imageSize.width, y: self.overlayView.bounds.size.height / imageSize.height))

      if convertedRect.origin.x < 0 {
        convertedRect.origin.x = self.edgeOffset
      }

      if convertedRect.origin.y < 0 {
        convertedRect.origin.y = self.edgeOffset
      }

      if convertedRect.maxX > self.overlayView.bounds.maxX {
        convertedRect.size.width = self.overlayView.bounds.maxX - convertedRect.origin.x - self.edgeOffset
      }

      if convertedRect.maxY > self.overlayView.bounds.maxY {
        convertedRect.size.height = self.overlayView.bounds.maxY - convertedRect.origin.y - self.edgeOffset
      }

      let confidenceValue = Int(prediction.confidence * 100.0)
      let string = "\(prediction.className)  (\(confidenceValue)%)"

      let size = string.size(usingFont: self.displayFont)

      let overlayObject = OverlayObject(name: string, borderRect: convertedRect, nameStringSize: size, color: prediction.displayColor, font: self.displayFont)

      overlayObjects.append(overlayObject)
    }

    self.draw(overlayObjects: overlayObjects)

  }

  func draw(overlayObjects: [OverlayObject]) {
    self.overlayView.overlayObjects = overlayObjects
    self.overlayView.setNeedsDisplay()
  }

}

extension String {
  /**
   指定したフォントの場合の文字列のサイズを返す
   */
  func size(usingFont font: UIFont) -> CGSize {
    let attributedString = NSAttributedString(string: self, attributes: [NSAttributedString.Key.font : font])
    return attributedString.size()
  }
}
