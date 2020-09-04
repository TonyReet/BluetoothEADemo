//
//  BtEventType.swift
//  ExternalAccessorySample
//
//  Created by tonyreet on 2020/9/4.
//  Copyright © 2020 philips.respironics. All rights reserved.
//

import Foundation

public enum BtEventType:Int {
    case OPEN_SUCCESS = 0 // 打开蓝牙成功,iOS应该不会使用此状态，因为蓝牙打开关闭不能监听 0
    case OPEN_FAIL = 1 //打开蓝牙失败,iOS应该不会使用此状态，因为蓝牙打开关闭不能监听 1
    
    case CONNECT_SUCCESS = 2 // 连接成功 2
    case CONNECT_FAIL = 3  // 连接失败
    case READ_RFID = 4 // 读取RFID
    case DISCONNECT = 5 // 断开
    case FOUND_DEVICE = 6 // 发现设备
    case CANCEL_DISCOVERY = 7 // 取消，没有可使用设备
    case PERMISSION_FAILED = 8// 没有权限
    case iOS_SKIP_BTCONNECT = 9 // iOS跳转蓝牙连接
}
