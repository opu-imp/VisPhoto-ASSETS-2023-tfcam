//
//  ViewController.swift
//  tf-cam
//
//  Created by hrbysnk on 2020/10/01.
//

import UIKit

class ViewController: UIViewController {

  var tableView = UITableView()
//  var tableData = [String]()
  var tableData = [[String: String]]()


  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.backgroundColor = UIColor.white
    navigationItem.title = "撮影対象の選択画面"
    
//    guard let fileURL = Bundle.main.url(forResource: "labels", withExtension: "txt") else {
//      fatalError("Could not find file")
//    }
    
    guard let fileURL = Bundle.main.url(forResource: "labels_jp", withExtension: "txt") else {
      fatalError("Could not find file")
    }

    guard let fileContents = try? String(contentsOf: fileURL) else {
      fatalError("Could not read file")
    }

//    let lines = fileContents.components(separatedBy: "\n")
//    for line in lines {
//      if line != "???" && line != "" {
//        tableData.append(line)
//      }
//    }
    
    let lines = fileContents.components(separatedBy: "\n")
    for line in lines {
      let category = line.components(separatedBy: ",")
      if category[0] != "???" && category[0] != "" {
        tableData.append(["label": category[0], "label_jp": category[1]])
      }
    }
    
    let helpBarButtonItem = UIBarButtonItem(
      image: UIImage(systemName: "questionmark.circle"), style: .plain,
      target: self, action: #selector(helpBarButtonTapped(_:)))
    helpBarButtonItem.accessibilityLabel = "使い方"
    self.navigationItem.rightBarButtonItems = [helpBarButtonItem]

    tableView = UITableView()
    tableView.delegate = self
    tableView.dataSource = self
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "item")
    view.addSubview(tableView)
    tableView.translatesAutoresizingMaskIntoConstraints = false
    tableView.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
    tableView.heightAnchor.constraint(equalTo: view.heightAnchor).isActive = true
  }
  
  @objc func helpBarButtonTapped(_ sender: UIBarButtonItem) {
    let vc = ModalViewController()
    vc.modalPresentationStyle = .pageSheet
    present(vc, animated: true, completion: nil)
  }
  
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return tableData.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "item", for: indexPath)
//    cell.textLabel?.text = tableData[indexPath.row]
    cell.textLabel?.text = tableData[indexPath.row]["label_jp"]
    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let category = tableData[indexPath.row]
    print("Cell \(indexPath.row) was pressed (\(category))")
    let vc = SecondViewController()
//    vc.selectedCategory = category
    vc.selectedCategory = tableData[indexPath.row]["label"] ?? ""
    navigationController?.pushViewController(vc, animated: true)
  }

}
