//
//  ModelDataHandler.swift
//  tf-cam
//
//  Created by hrbysnk on 2021/01/27.
//

import UIKit
import Accelerate
import CoreImage
import TensorFlowLite


struct Result {
  let inferenceTime: Double
  let predictions: [Prediction]
}

struct Prediction {
  let confidence: Float
  let className: String
  let rect: CGRect
  let displayColor: UIColor
}

typealias FileInfo = (name: String, ext: String)

enum MobileNetSSD {
  static let modelInfo: FileInfo = (name: "model", ext: "tflite")
  static let labelsInfo: FileInfo = (name: "labels", ext: "txt")
}


class ModelDataHandler: NSObject {

  // MARK: Internal properties
  // The current thread count used by the TensorFlow Lite Interpreter.
  let threadCount: Int
  let threadCountLimit = 10

  let threshold: Float = 0.5

  // MARK: Model parameters
  let batchSize = 1
  let inputChannels = 3
  let inputWidth = 300
  let inputHeight = 300

  // image mean and std for floating model.
  let imageMean: Float = 127.5
  let imageStd:  Float = 127.5

  // MARK: Private properties
  private var labels: [String] = []

  // TensorFlow Lite `Interpreter` object.
  private var interpreter: Interpreter


  // MARK: Initialization
  /*
   モデルとラベルの読み込みに成功したらインスタンスが作成される
   */
  init?(modelFileInfo: FileInfo, labelsFileInfo: FileInfo, threadCount: Int = 1) {

    guard let modelPath = Bundle.main.path(forResource: modelFileInfo.name, ofType: modelFileInfo.ext) else {
      print("Failed to load the model file with name: \(modelFileInfo.name)")
      return nil
    }

    self.threadCount = threadCount
    var options = Interpreter.Options()
    options.threadCount = threadCount

    do {
      interpreter = try Interpreter(modelPath: modelPath, options: options)
      try interpreter.allocateTensors()
    } catch let error {
      print("Failed to create the interpreter with error: \(error.localizedDescription)")
      return nil
    }

    super.init()

    loadLabels(fileInfo: labelsFileInfo)
  }

  /*
   ラベルを読み込む
   */
  private func loadLabels(fileInfo: FileInfo) {
    let fileName = fileInfo.name
    let fileExtension = fileInfo.ext

    guard let fileURL = Bundle.main.url(forResource: fileName, withExtension: fileExtension) else {
      fatalError("Labels file not found. Please add \(fileName).\(fileExtension) and try again.")
    }

    do {
      let contents = try String(contentsOf: fileURL, encoding: .utf8)
      labels = contents.components(separatedBy: .newlines)
    } catch {
      fatalError("Labels file named \(fileName).\(fileExtension) cannot be read. Please add a valid file and try again.")
    }
  }

  /*
   与えられたフレームに対して物体検出を行う
   */
  func runModel(onFrame pixelBuffer: CVPixelBuffer) -> Result? {
    let imageWidth = CVPixelBufferGetWidth(pixelBuffer)
    let imageHeight = CVPixelBufferGetHeight(pixelBuffer)
    let sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
    assert(sourcePixelFormat == kCVPixelFormatType_32ARGB || sourcePixelFormat == kCVPixelFormatType_32BGRA || sourcePixelFormat == kCVPixelFormatType_32RGBA)

    let imageChannels = 4
    assert(imageChannels >= inputChannels)

    let scaledSize = CGSize(width: inputWidth, height: inputHeight)
    guard let scaledPixelBuffer = pixelBuffer.resized(to: scaledSize) else {
      return nil
    }

    let interval: TimeInterval
    let outputBoundingBoxes: Tensor
    let outputClasses: Tensor
    let outputScores: Tensor
    let outputCount: Tensor

    do {
      let inputTensor = try interpreter.input(at: 0)

      // Removes the alpha component from the image buffer to get RGB data.
      guard let rgbData = rgbDataFromBuffer(
        scaledPixelBuffer,
        byteCount: batchSize * inputWidth * inputHeight * inputChannels,
        isModelQuantized: inputTensor.dataType == .uInt8
      ) else {
        print("Failed to convert the image buffer to RGB data.")
        return nil
      }

      // Copies the RGB data to the input `Tensor`.
      try interpreter.copy(rgbData, toInputAt: 0)

      // Runs inference by invoking the `Interpreter`.
      let startDate = Date()
      try interpreter.invoke()
      interval = Date().timeIntervalSince(startDate) * 1000

      outputBoundingBoxes = try interpreter.output(at: 0)
      outputClasses = try interpreter.output(at: 1)
      outputScores = try interpreter.output(at: 2)
      outputCount = try interpreter.output(at: 3)
    } catch let error {
      print("Failed to invoke the interpreter with error: \(error.localizedDescription)")
      return nil
    }

    let predictionArray = formatPredictions(
      boundingBoxes: [Float](unsafeData: outputBoundingBoxes.data) ?? [],
      outputClasses: [Float](unsafeData: outputClasses.data) ?? [],
      outputScores: [Float](unsafeData: outputScores.data) ?? [],
      outputCount: Int(([Float](unsafeData: outputCount.data) ?? [0])[0]),
      width: CGFloat(imageWidth),
      height: CGFloat(imageHeight)
    )

    let result = Result(inferenceTime: interval, predictions: predictionArray)
    return result
  }

  /// Returns RGB data representation of the given image buffer with the specified `byteCount`.
  ///
  /// - Parameters
  ///   - buffer: The BGRA pixel buffer to convert to RGB data.
  ///   - byteCount: The expected byte count for the RGB data: `batchSize * imageWidth * imageHeight * componentsCount`.
  ///   - isModelQuantized: Whether the model is quantized (i.e. fixed point values rather than floating point values).
  ///
  /// - Returns: The RGB data representation of the image buffer or `nil` if the buffer could not be converted.
  ///
  private func rgbDataFromBuffer(_ buffer: CVPixelBuffer, byteCount: Int, isModelQuantized: Bool) -> Data? {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer {
      CVPixelBufferUnlockBaseAddress(buffer, .readOnly)
    }
    guard let sourceData = CVPixelBufferGetBaseAddress(buffer) else {
      return nil
    }

    let width = CVPixelBufferGetWidth(buffer)
    let height = CVPixelBufferGetHeight(buffer)
    let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    let destinationChannelCount = 3
    let destinationBytesPerRow = destinationChannelCount * width

    var sourceBuffer = vImage_Buffer(data: sourceData, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: sourceBytesPerRow)

    guard let destinationData = malloc(height * destinationBytesPerRow) else {
      print("Error: out of memory")
      return nil
    }

    defer {
      free(destinationData)
    }

    var destinationBuffer = vImage_Buffer(data: destinationData, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: destinationBytesPerRow)

    if (CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA) {
      vImageConvert_BGRA8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
    } else if (CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32ARGB) {
      vImageConvert_ARGB8888toRGB888(&sourceBuffer, &destinationBuffer, UInt32(kvImageNoFlags))
    }

    let byteData = Data(bytes: destinationBuffer.data, count: destinationBuffer.rowBytes * height)
    if isModelQuantized {
      return byteData
    }

    // Converts to floats if not quantized
    let bytes = Array<UInt8>(unsafeData: byteData)!
    var floats = [Float]()
    for i in 0..<bytes.count {
      floats.append((Float(bytes[i]) - imageMean) / imageStd)
    }
    return Data(copyingBufferOf: floats)
  }

  /*
   確信度が閾値以下のものを除いて降順ソートした結果を返す
   */
  func formatPredictions(boundingBoxes: [Float], outputClasses: [Float], outputScores: [Float], outputCount: Int, width: CGFloat, height: CGFloat) -> [Prediction] {
    var predictionArray: [Prediction] = []

    if (outputCount == 0) {
      return predictionArray
    }

    for i in 0...outputCount - 1 {
      let score = outputScores[i]

      guard score >= threshold else {
        continue
      }

      let outputClassIndex = Int(outputClasses[i])
      let outputClass = labels[outputClassIndex + 1]

      var rect: CGRect = CGRect.zero
      rect.origin.y = CGFloat(boundingBoxes[4*i])
      rect.origin.x = CGFloat(boundingBoxes[4*i+1])
      rect.size.height = CGFloat(boundingBoxes[4*i+2]) - rect.origin.y
      rect.size.width = CGFloat(boundingBoxes[4*i+3]) - rect.origin.x

      let newRect = rect.applying(CGAffineTransform(scaleX: width, y: height))

      let colorToAssign = colorForClass(withIndex: outputClassIndex + 1)

      let prediction = Prediction(confidence: score, className: outputClass, rect: newRect, displayColor: colorToAssign)
      predictionArray.append(prediction)
    }

    predictionArray.sort { (first, second) -> Bool in
      return first.confidence > second.confidence
    }

    return predictionArray
  }

  /*
   クラスに色を割り当てる
   */
  private func colorForClass(withIndex index: Int) -> UIColor {
    let hueValue = Float(index) / Float(labels.count)
    let colorToAssign = UIColor.init(hue: CGFloat(hueValue), saturation: 1, brightness: 0.5, alpha: 1.0)
    return colorToAssign
  }
}


// MARK: Extensions

extension CVPixelBuffer {

  // Returns scaled pixel buffer.
  func resized(to size: CGSize) -> CVPixelBuffer? {

    let imageWidth = CVPixelBufferGetWidth(self)
    let imageHeight = CVPixelBufferGetHeight(self)

    let pixelBufferType = CVPixelBufferGetPixelFormatType(self)

    assert(pixelBufferType == kCVPixelFormatType_32BGRA || pixelBufferType == kCVPixelFormatType_32ARGB)

    let inputImageRowBytes = CVPixelBufferGetBytesPerRow(self)
    let imageChannels = 4

    CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))

    guard let inputBaseAddress = CVPixelBufferGetBaseAddress(self) else {
      return nil
    }

    var inputVImageBuffer = vImage_Buffer(data: inputBaseAddress, height: UInt(imageHeight), width: UInt(imageWidth), rowBytes: inputImageRowBytes)

    let scaledImageRowBytes = Int(size.width) * imageChannels
    guard let scaledImageBytes = malloc(Int(size.height) * scaledImageRowBytes) else {
      return nil
    }

    var scaledVImageBuffer = vImage_Buffer(data: scaledImageBytes, height: UInt(size.height), width: UInt(size.width), rowBytes: scaledImageRowBytes)

    let scaleError = vImageScale_ARGB8888(&inputVImageBuffer, &scaledVImageBuffer, nil, vImage_Flags(0))

    CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))

    guard scaleError == kvImageNoError else {
      return nil
    }

    let releaseCallBack: CVPixelBufferReleaseBytesCallback = { mutablePointer, pointer in

      if let pointer = pointer {
        free(UnsafeMutableRawPointer(mutating: pointer))
      }
    }

    var scaledPixelBuffer: CVPixelBuffer?

    let conversionStatus = CVPixelBufferCreateWithBytes(nil, Int(size.width), Int(size.height), pixelBufferType, scaledImageBytes, scaledImageRowBytes, releaseCallBack, nil, nil, &scaledPixelBuffer)

    guard conversionStatus == kCVReturnSuccess else {
      free(scaledImageBytes)
      return nil
    }

    return scaledPixelBuffer
  }

}

extension Data {
  /// Creates a new buffer by copying the buffer pointer of the given array.
  /// - Parameter array: An array with elements of type `T`.
  ///
  init<T>(copyingBufferOf array: [T]) {
    self = array.withUnsafeBufferPointer(Data.init)
  }
}

extension Array {
  /// Creates a new array from the given unsafe data.
  /// - Parameter unsafeData: The data containing the bytes to turn into an array.
  ///
  init?(unsafeData: Data) {
    guard unsafeData.count % MemoryLayout<Element>.stride == 0 else { return nil }
    #if swift(>=5.0)
    self = unsafeData.withUnsafeBytes { .init($0.bindMemory(to: Element.self)) }
    #else
    self = unsafeData.withUnsafeBytes {
      .init(UnsafeBufferPointer<Element>(
        start: $0,
        count: unsafeData.count / MemoryLayout<Element>.stride
      ))
    }
    #endif  // swift(>=5.0)
  }
}
