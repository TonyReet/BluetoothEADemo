//
//  ViewController.swift
//  BluetoothEADemo
//
//  Created by tonyreet on 2020/8/31.
//  Copyright © 2020 tonyreet. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    private lazy var tableView = { () -> UITableView in
        let tableView = UITableView()
        tableView.delegate = self
        tableView.dataSource = self
        
        return tableView
    }()
    
    private let accessoryList:Array<BtDevice> = BtManager.shared.refreshBtDevices()
    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(tableView)
        tableView.frame = view.bounds
    }
}

extension ViewController : UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accessoryList.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
     let cell = tableView.dequeueReusableCell(withIdentifier: "AccessoryCell", for: indexPath)
     

        var accessoryName = accessoryList[indexPath.row].deviceName
        if accessoryName == nil  || accessoryName == "" {
            accessoryName = "Unknown Accessory"
        }
        
        cell.textLabel?.text = accessoryName
     
         return cell
     }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let accessory = accessoryList[indexPath.row]
        
        // 通过mac地址连接
        BtManager.shared.connect(accessory.mac)
        
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}

