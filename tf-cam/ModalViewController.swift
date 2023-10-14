//
//  ModalViewController.swift
//  tf-cam
//
//  Created by hrbysnk on 2021/12/14.
//

import UIKit

class ModalViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.backgroundColor = .secondarySystemBackground
    
    let label = UILabel()
    label.lineBreakMode = .byWordWrapping
    label.numberOfLines = 0
//    label.text = "使い方の説明"
    label.text = "まず撮影したい物体の種類を選びます。するとアプリがカメラモードに切り替わります。\n\n" + "カメラモードでは、写っている物体を認識し、カメラをどう動かせばよいか教えてくれます。 \n\n" +  "アプリから何も音が出ない場合は、撮影対象がフレーム内に入っていない可能性があります。"
  
    let button = UIButton()
    button.backgroundColor = UIColor.orange
    button.setTitle("閉じる", for: .normal)
    button.setTitleColor(.white, for: .normal)
    button.layer.cornerRadius = 5
    button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
    button.addTarget(self, action: #selector(btnFunc), for: .touchUpInside)
    
    view.addSubview(label)
    label.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(button)
    button.translatesAutoresizingMaskIntoConstraints = false
    
    label.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    label.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 20).isActive = true
    label.rightAnchor.constraint(equalTo: view.rightAnchor, constant: -20).isActive = true
    label.topAnchor.constraint(equalTo: view.topAnchor, constant: 20).isActive = true
    label.bottomAnchor.constraint(equalTo: button.topAnchor, constant: -20).isActive = true
  
    button.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
    button.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20).isActive = true
  }
  
  @objc func btnFunc() {
    self.dismiss(animated: true)
  }
}
