//
//  BtEvent.swift
//  ExternalAccessorySample
//
//  Created by tonyreet on 2020/8/15.
//  Copyright © 2020 philips.respironics. All rights reserved.
//

import Foundation

public struct BtEvent: Codable {
    private let eventType: Int?
    
    private let contentStr: String?

    public init(eventType: Int?, contentStr: String?) {
        self.eventType = eventType
        self.contentStr = contentStr
    }
    
}
