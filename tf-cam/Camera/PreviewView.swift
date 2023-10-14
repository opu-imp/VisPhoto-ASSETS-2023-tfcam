//
//  PreviewView.swift
//  tf-cam
//
//  Created by hrbysnk on 2021/01/24.
//

import UIKit
import AVFoundation

class PreviewView: UIView {

  override class var layerClass: AnyClass {
    return AVCaptureVideoPreviewLayer.self
  }

  var previewLayer: AVCaptureVideoPreviewLayer {
    guard let layer = layer as? AVCaptureVideoPreviewLayer else {
      fatalError("Check PreviewView.layerClass implementation.")
    }
    return layer
  }

  var session: AVCaptureSession? {
    get {
      return previewLayer.session
    }
    set {
      previewLayer.session = newValue
    }
  }

}
