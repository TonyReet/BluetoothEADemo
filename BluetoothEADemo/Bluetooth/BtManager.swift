//
//  BtManager.swift
//  ExternalAccessorySample
//
//  Created by tonyreet on 2020/9/4.
//  Copyright © 2020 philips.respironics. All rights reserved.
//

import Foundation
import ExternalAccessory
import CoreBluetooth
import UIKit

public class BtManager: NSObject {
    static  let shared = BtManager()
    private let accessoryManager = EAAccessoryManager.shared()
    private var accessory: EAAccessory?
    private var session: EASession?
    
    private var centralManager: CBCentralManager?
    
    // 支持设备
    private lazy var supportedProtocolsStrings: Array<String> = {
        let mainBundle = Bundle.main
        
        return mainBundle.object(forInfoDictionaryKey: "UISupportedExternalAccessoryProtocols") as! Array<String>
    }()
    
    // 读取字符串
    private var originalInData = NSMutableString()
    
    // 连接状态
    public var btConnected: BtConnectState = .DISCONNECT
    
    // 事件类型
    public var eventType: BtEventType = .PERMISSION_FAILED
    
    // 写数据
    private var writeData = NSMutableData()
    
    // 连接之前写一次指令，每次重连的时候重置此状态
    private var stoppedWriteAttempt = true
    
    // 保持设备连接指令
    private let keepDeviceConnect = "vw 331 1"

    // 是否打开蓝牙
    public var isBTOpened = false
    
    // eventType改变的回调
    public var eventTypeChangeClosure: ((_ eventType: BtEventType, _ contentStr: String?) -> Void)?
    
    // 刷新连接的设备
    public var refreshClosure: (() -> ())?
    
    // 所有蓝牙设备
    public var btDevices = Array<BtDevice>(){
        didSet{
            if btDevices.isEmpty == true {
  
                sendEventToDart(.CANCEL_DISCOVERY)
            }
        }
    }
    
    public var connectDevice: BtDevice?
    
    public override init() {
        super.init()

        centralManager = CBCentralManager.init(delegate: self, queue: nil, options: nil)
    }
    
    public func refreshBtDevices()->Array<BtDevice>{
        var btDevices = Array<BtDevice>()
        for accessory in accessoryManager.connectedAccessories {
            
            let macAddress: String = (accessory.value(forKey: "macAddress") ?? "") as! String
            let name = accessory.name

            // 查找协议
            var supportedProtocol:String?
            for index in 0..<accessory.protocolStrings.count{
                let protocolString = accessory.protocolStrings[index]
                if protocolString.contains("com.allflex"){
                    supportedProtocol = protocolString
                }
            }
            
            let serialNumber = accessory.serialNumber;
            var snNumber:String? = serialNumber.components(separatedBy: " ").last
            snNumber = snNumber != nil ? "_\(snNumber!)" : ""
        
            let deviceName = "\(name)\(snNumber!)"
            let btDevice = BtDevice(mac: macAddress, deviceName: deviceName, supportedProtocol: supportedProtocol,connectionID: accessory.connectionID, accessory: accessory)
            
            btDevices.append(btDevice)
        }
        
        for index in 0..<btDevices.count{
            print(debug: "设备名字\(btDevices[index].deviceName ?? "")")
        }
        
        print(debug: "设备数量:\(btDevices.count)")
        
        self.btDevices = btDevices
        
        return btDevices
    }

    // 根据mac地址，查找protocol连接设备
    public func connect(_ deviceMacAddress: String?) {
        accessoryDidDisconnect()
        
        guard let deviceMacAddress = deviceMacAddress else {return}
        
        for btDevice in btDevices {
            if deviceMacAddress == btDevice.mac {
                self.accessory = btDevice.accessory
                
                openSession(btDevice.supportedProtocol)
                break
            }
        }
    }
    
    // 开启session
    func openSession(_ supportedProtocol: String!) {
        print(debug: "protocolString:\(self.session?.protocolString ?? ""),supportedProtocol:\(String(describing: supportedProtocol))")
        
        guard  let accessory = self.accessory else {
            print(debug: "accessory is nil")
            return
        }
        
        // 已经连接
        if self.session?.protocolString == supportedProtocol {
            print(debug: "session is connecting")
            return
        }
        
        // 是否能够创建
        guard let newSession = EASession(accessory: accessory, forProtocol: supportedProtocol) else {
            print(debug: "failed to create a session")
            return
        }
        
        // 成功以后再设置delegate
        accessory.delegate = self
        
        session = newSession
        session?.inputStream?.delegate = self
        session?.inputStream?.schedule(in: RunLoop.current, forMode: .default)
        session?.inputStream?.open()
        session?.outputStream?.delegate = self
        session?.outputStream?.schedule(in: RunLoop.current, forMode: .default)
        session?.outputStream?.open()
        
        let macAddress: String = (accessory.value(forKey: "macAddress") ?? "") as! String
        connectDevice = btDevices.filter{ $0.mac == macAddress}.first
        
        // 重置状态
        stoppedWriteAttempt = true
        writeData = NSMutableData()
        btConnected = .DISCONNECT

        // 设备保持连接
        sendCommandToReader(keepDeviceConnect)
        
        // 如果10秒以后没有连接成功，发送一个连接失败的消息，关闭Loading
        perform(#selector(sendEventConnectFail), with: nil, afterDelay: 10)
    }
    
    // 发送命令
    private func sendCommandToReader(_ command:String) {
        if command.isEmpty {return}
        
        print(debug: "sendCommand:\(command)")
        
        let formatCommand: String! = "\(command)\r\n"
        
        guard let commandData = formatCommand.data(using: String.Encoding.utf8) else {
            print(debug: "command convert to data fail")
            return
        }
        
        writeData.append(commandData)
        
        writeDataToReader()
    }
    
    // 写入数据
    private func writeDataToReader() {
        if stoppedWriteAttempt == false {return}
        
        guard let outputStream = session?.outputStream else {return}
        
        let bufData = [UInt8](writeData)
        var len = writeData.length
        
        if len > 0 && outputStream.hasSpaceAvailable {
            stoppedWriteAttempt = false
            
            len = outputStream.write(bufData, maxLength: writeData.length)
            
            let string = String(data: writeData as Data, encoding: String.Encoding.utf8)
            print(debug: "writeDataToReader, string = \(String(describing: string)), \(len) bytes written")
        }else {
            stoppedWriteAttempt = true
        }
    }
    
    // 读数据
    private func readDataFromReader(){
        guard let inputStream = session?.inputStream else {return }
        
        let maxLen = 1024
        var buf = [UInt8].init(repeating: 0x00, count: maxLen)
        let bufLen = inputStream.read(&buf, maxLength: maxLen)
        
        if bufLen <= 0 {return }
        
        let bufferValues = NSMutableString(format: "%i", buf[0])
        
        for index in 1..<bufLen {
            bufferValues.appendFormat(",%i", buf[index])
        }
        
        guard let dataString = NSString(bytes: buf, length: bufLen, encoding: String.Encoding.isoLatin1.rawValue) as String? else {return }
        
        originalInData.append(dataString)
        
        print(debug: "received \(String(describing: bufLen)) bytes")
        
        processReceivedData()
    }
    
    // 处理接收数据
    private func processReceivedData(){
        print(debug: "===== originalInData = \(originalInData) ======");
        
        let endPos = originalInData.range(of: "\r\n").location
        
        if btConnected == .CONNECTED {
            
            // LPR新设备自动断开发送的消息
            if originalInData.contains("Disconnect") {
                sendEventToDart(.DISCONNECT)
                accessoryDidDisconnect()
                return
            }
            
            readRfidIfConnected(endPos)
            
            return;
        }
        
        firstReadDataAfterWrite(endPos)
    }
    
    // 如果已经连接，读取数据
    private func readRfidIfConnected(_ inputEndPos: Int){
        var endPos = inputEndPos
        
        var readData: String = ""
        while endPos != NSNotFound {
            let dataString = originalInData.substring(to: endPos)
            
            // 读取失败
            if dataString.contains("ERR") || dataString.isEmpty {
                
                // GPR设备连接成功的字符串是:ERR(NOT_SUPPORTED)，也是成功
                if !dataString.contains("NOT_SUPPORTED") {
                    print(debug:"read_headers failed str: \(originalInData)")
                    break
                }
            }
            
            //GPR数据是重复的，重复的就不添加
            if readData != dataString {
                readData.append(dataString)
            }

            originalInData.deleteCharacters(in: NSRange(location: 0, length: endPos + 2))
            
            print(debug: "dataString:\(dataString)")
            
            endPos = originalInData.range(of: "\r\n").location
        }
        
        let rfId = convertToRfid(readData as NSString)
        
        sendEventToDart(.READ_RFID, contentStr: rfId)
        print(debug: "readData: \(readData),rfId: \(rfId)")
    }
    
    // 读写入数据后的第一次数据
    private func firstReadDataAfterWrite(_ inputEndPos: Int){
        var endPos = inputEndPos
        
        // search for terminating <CR><LF> and grab all characters prior
        var connectRight = false
        while endPos != NSNotFound {
            let dataString:NSString = originalInData.substring(to: endPos) as NSString
            originalInData.deleteCharacters(in: NSRange(location: 0, length: endPos + 2))
            
            print(debug: "firstReadDataAfterWrite:\(dataString)")
            
            // 如果出错可以结束
            if dataString.contains("ERR") {
                // GPR设备连接成功的字符串是:ERR(NOT_SUPPORTED)，也是成功
                if dataString.contains("NOT_SUPPORTED") {
                    connectRight = true
                }
                
                break
            }
            
            // 如果获取到OK可以结束
            if dataString.contains("OK(") {
                connectRight = true
                break
            }
            
            endPos = originalInData.range(of: "\r\n").location
        }
        
        // 确定连接没问题
        if connectRight {
            deviceConnect()
        }else {
            connectIfIsNewLPR()
        }
    }
    
    private func connectIfIsNewLPR(){
        // 判断是否是LPR
        if connectDevice?.deviceName?.contains("LPR") == false {
            return
        }
        
        // 获取固件版本
        guard let firmwareRevision = self.accessory?.firmwareRevision,
            firmwareRevision.contains(".") == true else {
            return
        }
        
        guard let firstVersionNum = Int(String(firmwareRevision.split(separator: ".").first ?? "0")) else {return}
        
        if firstVersionNum >= 2 {
            deviceConnect()
        }
    }
    
    private func deviceConnect(){
        // 如果连接成功，取消发送"连接失败"消息
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(sendEventConnectFail), object: nil)
        originalInData = NSMutableString()//清空
        
        btConnected = .CONNECTED
        
        sendCommandToReader("get_current")
        
        sendEventToDart(.CONNECT_SUCCESS, contentStr: connectDevice?.deviceName)
    }
    
    // 通知断开连接后，清空
    public func accessoryDidDisconnect(){
        
        print(debug: "accessoryDidDisconnect")
        
        if let session = self.session  {
            session.inputStream?.close()
            session.outputStream?.close()
        }

        self.btConnected = .DISCONNECT
        self.connectDevice = nil
        self.accessory = nil
        self.session = nil
    }
    
    // RFID提取规则
    private func convertToRfid(_ readData: NSString)->String{
        var rfidNumber = readData
        
        let commaPos = readData.range(of: ",").location
        if commaPos != NSNotFound {
            rfidNumber = rfidNumber.substring(to: commaPos) as NSString
        }
        
        // remove spaces and other unwanted characters
        let doNotWant = CharacterSet.alphanumerics.inverted
        rfidNumber = rfidNumber.components(separatedBy: doNotWant).joined(separator: "") as NSString
        
        // strip timestamp (final 12 characters) if it has been appended
        if rfidNumber.length >= 27 {
            rfidNumber = rfidNumber.substring(from: rfidNumber.length - 12) as NSString
        }
        
        // take right-most 15 characters
        if rfidNumber.length >= 15 {
            rfidNumber = rfidNumber.substring(from: rfidNumber.length - 15) as NSString
        }
        
        return rfidNumber as String
    }
}

// MARK: flutter Plugin
extension BtManager {
    public func sendEventToDart(_ eventType: BtEventType, contentStr: String? = "", saveEvent: Bool? = true){
        if saveEvent == true {
            self.eventType = eventType
        }
        
        guard let eventTypeChangeClosure = eventTypeChangeClosure else {return}
        
        eventTypeChangeClosure(eventType,contentStr)
    }
    
    public func openBT(){
        // 保证在主线程
        DispatchQueue.main.async {
            var url: URL?
            
            // 没有权限
            if self.eventType == .PERMISSION_FAILED {
                url = URL(string: UIApplication.openSettingsURLString)
            }else{
                // 如果有权限没有开蓝牙
                if self.eventType != .DISCONNECT {return}
                
                self.sendEventToDart(.iOS_SKIP_BTCONNECT, saveEvent: false)
                
                return
            }

            guard let openUrl = url else {return}
            
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(openUrl, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.openURL(openUrl)
            }
        }
    }
    
    private func flutterRefreshDevice(){
        guard  let refreshClosure = refreshClosure else {
            return
        }
        
        refreshClosure()
    }
    
    @objc
    private func sendEventConnectFail(){
        sendEventToDart(.CONNECT_FAIL)
    }
}

// MARK: input output delegate
extension BtManager: StreamDelegate {
    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch (eventCode) {
        case Stream.Event.hasBytesAvailable:
            readDataFromReader()
        case Stream.Event.hasSpaceAvailable:
            writeDataToReader()
        case Stream.Event.errorOccurred:
            print(debug: "Error in communicating with the gadget")
        default:
            break
        }
    }
}

extension BtManager: EAAccessoryDelegate {
    public func accessoryDidDisconnect(_ accessory: EAAccessory) {
        guard let connectDevice = self.connectDevice else {
            return
        }
        
        if connectDevice.connectionID != accessory.connectionID {
            return
        }
        
        sendEventToDart(.DISCONNECT)
        accessoryDidDisconnect()
    }
}

extension BtManager: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {

        var eventType: BtEventType = .OPEN_SUCCESS
        // 打印，辅助测试
        switch central.state {
        case .poweredOn:
            eventType = .OPEN_SUCCESS
            print(debug: "centralManagerState: 蓝牙开启且可用")
        case .unknown:
            eventType = .CONNECT_FAIL
            print(debug: "centralManagerState: 手机没有识别到蓝牙，请检查手机。")
        case .resetting:
            eventType = .CONNECT_FAIL
            print(debug: "centralManagerState: 手机蓝牙已断开连接，重置中。")
        case .unsupported:
            eventType = .CONNECT_FAIL
            print(debug: "centralManagerState: 手机不支持蓝牙功能，请更换手机。")
        case .poweredOff:
            eventType = .DISCONNECT
            accessoryDidDisconnect()
            print(debug: "centralManagerState: 手机蓝牙功能关闭，请前往设置打开蓝牙及控制中心打开蓝牙。")
            break
        case .unauthorized:
            print(debug: "centralManagerState: 手机蓝牙功能没有权限，请前往设置。")
            eventType = .PERMISSION_FAILED
        default:
            print(debug: "其他类型")
            break
        }
        
        sendEventToDart(eventType)
        
        isBTOpened = central.state == .poweredOn
    }
}

// MARK: 通知
extension BtManager{
    public func registerBtNotifications(){
        EAAccessoryManager.shared().registerForLocalNotifications()
        
        NotificationCenter.default.addObserver(self, selector:  #selector(didConnectAccessory(_:)), name: Notification.Name.EAAccessoryDidConnect, object: nil)
    }
    
    public func removeBtNotifications(){
        EAAccessoryManager.shared().unregisterForLocalNotifications()
        NotificationCenter.default.removeObserver(self, name: Notification.Name.EAAccessoryDidConnect, object: nil)
    }
    
    @objc
    private func didConnectAccessory(_ notification: NSNotification) {
        print(debug: "开始连接")
        
        flutterRefreshDevice()
    }
}
