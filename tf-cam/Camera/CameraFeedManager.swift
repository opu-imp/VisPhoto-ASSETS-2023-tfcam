//
//  CameraFeedManager.swift
//  tf-cam
//
//  Created by hrbysnk on 2021/01/24.
//

import UIKit
import AVFoundation

protocol CameraFeedManagerDelegate: AnyObject {

  func setInitialVideoOrientation()

  func didOutput(pixelBuffer: CVPixelBuffer)

  func presentCameraAuthorizationFailedAlert()

  func presentCameraConfigurationFailedAlert()

}

private enum SessionSetupResult {
  case success
  case authorizationFailed
  case configurationFailed
}

/**
 カメラ関連の機能を管理するクラス
 */
class CameraFeedManager: NSObject {

  let session: AVCaptureSession = AVCaptureSession()
  private let previewView: PreviewView
  private let sessionQueue = DispatchQueue(label: "session queue")
  private var setupResult: SessionSetupResult = .success
  private var isSessionRunning = false

  var videoDataOutput = AVCaptureVideoDataOutput()
  private let photoOutput = AVCapturePhotoOutput()

  weak var delegate: CameraFeedManagerDelegate?

  init(previewView: PreviewView) {
    self.previewView = previewView
    super.init()

    self.previewView.session = session

    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      self.setupResult = .success

    case .notDetermined:
      self.sessionQueue.suspend()
      AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
        if !granted {
            self.setupResult = .authorizationFailed
        }
        self.sessionQueue.resume()
      })

    default:
      self.setupResult = .authorizationFailed
    }

    self.sessionQueue.async {
      self.configureSession()
    }
  }

  /**
   セッションの設定をする
   */
  private func configureSession() {
    guard setupResult == .success else {
      return
    }

    session.beginConfiguration()

    session.sessionPreset = .photo

    guard addVideoDeviceInput() == true else {
      self.session.commitConfiguration()
      self.setupResult = .configurationFailed
      return
    }

    guard addVideoDataOutput() else {
      self.session.commitConfiguration()
      self.setupResult = .configurationFailed
      return
    }
    
    guard addPhotoOutput() else {
      self.session.commitConfiguration()
      self.setupResult = .configurationFailed
      return
    }

    session.commitConfiguration()
    self.setupResult = .success
  }

  /**
   カメラの設定が成功していたらセッションを開始する
   */
  func checkCameraConfigurationAndStartSession() {
    sessionQueue.async {
      switch self.setupResult {
      case .success:
        self.startSession()
        DispatchQueue.main.async {
          self.delegate?.setInitialVideoOrientation()
        }
      case .authorizationFailed:
        DispatchQueue.main.async {
          self.delegate?.presentCameraAuthorizationFailedAlert()
        }
      case .configurationFailed:
        DispatchQueue.main.async {
          self.delegate?.presentCameraConfigurationFailedAlert()
        }
      }
    }
  }

  /**
   セッションを開始する
   */
  private func startSession() {
    self.session.startRunning()
    self.isSessionRunning = self.session.isRunning
  }

  /**
   セッションを停止する
   */
  func stopSession() {
    sessionQueue.async {
      if self.session.isRunning {
        self.session.stopRunning()
        self.isSessionRunning = self.session.isRunning
      }
    }
  }

  private func addVideoDeviceInput() -> Bool {
    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
      fatalError("The default video device is unavailable.")
    }

    do {
      let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
      if session.canAddInput(videoDeviceInput) {
        session.addInput(videoDeviceInput)
        return true
      }
      else {
        print("Could not add video device input to the session.")
        return false
      }
    }
    catch {
      fatalError("Could not create video device input.")
    }
  }

  private func addVideoDataOutput() -> Bool {
    let sampleBufferQueue = DispatchQueue(label: "sample buffer queue")
    videoDataOutput.setSampleBufferDelegate(self, queue: sampleBufferQueue)
    videoDataOutput.alwaysDiscardsLateVideoFrames = true
    videoDataOutput.videoSettings = [String(kCVPixelBufferPixelFormatTypeKey) : kCMPixelFormat_32BGRA]

    if session.canAddOutput(videoDataOutput) {
      session.addOutput(videoDataOutput)
      return true
    } else {
      print("Could not add video data output to the session.")
      return false
    }
  }
  
  private func addPhotoOutput() -> Bool {
    if session.canAddOutput(photoOutput) {
      session.addOutput(photoOutput)
      return true
    } else {
      print("Could not add photo output to the session.")
      return false
    }
  }
  
  func capturePhoto() {
    let videoPreviewLayerOrientation = previewView.previewLayer.connection?.videoOrientation

    sessionQueue.async {
      if let photoOutputConnection = self.photoOutput.connection(with: .video) {
        photoOutputConnection.videoOrientation = videoPreviewLayerOrientation!
      }
      
      let photoSettings = AVCapturePhotoSettings()
      photoSettings.isHighResolutionPhotoEnabled = false
      self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
  }

}

/**
 AVCaptureVideoDataOutputSampleBufferDelegate
 */
extension CameraFeedManager: AVCaptureVideoDataOutputSampleBufferDelegate {

  func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

    let pixelBuffer: CVPixelBuffer? = CMSampleBufferGetImageBuffer(sampleBuffer)

    guard let imagePixelBuffer = pixelBuffer else {
      return
    }

    delegate?.didOutput(pixelBuffer: imagePixelBuffer)
  }
}

/**
 AVCapturePhotoCaptureDelegate
 */
extension CameraFeedManager: AVCapturePhotoCaptureDelegate {

  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    let imageData = photo.fileDataRepresentation()
    let image = UIImage(data: imageData!)
    UIImageWriteToSavedPhotosAlbum(image!, self, nil, nil)
  }

}
