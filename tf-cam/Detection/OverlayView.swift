//
//  OverlayView.swift
//  tf-cam
//
//  Created by hrbysnk on 2021/01/27.
//

import UIKit

/**
 描画用のパラメータ
 */
struct OverlayObject {
  let name: String
  let borderRect: CGRect
  let nameStringSize: CGSize
  let color: UIColor
  let font: UIFont
}

/**
 バウンディングボックスとラベルの表示
 */
class OverlayView: UIView {

  var overlayObjects: [OverlayObject] = []
  private let lineWidth: CGFloat = 3
  private let stringBgAlpha: CGFloat = 0.7
  private let stringFontColor = UIColor.white
  private let stringHorizontalSpacing: CGFloat = 13.0
  private let stringVerticalSpacing: CGFloat = 7.0

  override func draw(_ rect: CGRect) {
    for overlayObject in overlayObjects {
      drawBorders(of: overlayObject)
      drawBackground(of: overlayObject)
      drawName(of: overlayObject)
    }
  }

  func drawBorders(of overlayObject: OverlayObject) {
    let path = UIBezierPath(rect: overlayObject.borderRect)
    path.lineWidth = lineWidth
    overlayObject.color.setStroke()
    path.stroke()
  }

  func drawBackground(of overlayObject: OverlayObject) {
    let stringBgRect = CGRect(
      x: overlayObject.borderRect.origin.x,
      y: overlayObject.borderRect.origin.y ,
      width: overlayObject.nameStringSize.width + 2 * stringHorizontalSpacing,
      height: overlayObject.nameStringSize.height + 2 * stringVerticalSpacing)

    let stringBgPath = UIBezierPath(rect: stringBgRect)

    overlayObject.color.withAlphaComponent(stringBgAlpha).setFill()
    stringBgPath.fill()
  }

  func drawName(of overlayObject: OverlayObject) {
    let stringRect = CGRect(
      x: overlayObject.borderRect.origin.x + stringHorizontalSpacing,
      y: overlayObject.borderRect.origin.y + stringVerticalSpacing,
      width: overlayObject.nameStringSize.width,
      height: overlayObject.nameStringSize.height)

    let attributedString = NSAttributedString(
      string: overlayObject.name,
      attributes: [NSAttributedString.Key.foregroundColor : stringFontColor, NSAttributedString.Key.font : overlayObject.font])

    attributedString.draw(in: stringRect)
  }

}
