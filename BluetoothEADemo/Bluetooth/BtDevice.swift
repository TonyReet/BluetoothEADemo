//
//  BtDevice.swift
//  ExternalAccessorySample
//
//  Created by tonyreet on 2020/8/15.
//  Copyright © 2020 philips.respironics. All rights reserved.
//

import Foundation
import ExternalAccessory

public struct BtDevice: Codable {
    let mac: String?
    
    let deviceName: String?
    
    // 支持的协议
    var supportedProtocol: String?

    var connectionID: Int?
    
    weak var accessory: EAAccessory?
    
    enum CodingKeys: String, CodingKey {
        case mac, deviceName
    }
}

