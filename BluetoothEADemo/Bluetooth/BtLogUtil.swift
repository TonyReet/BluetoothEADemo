//
//  BtLogUtil.swift
//  ExternalAccessorySample
//
//  Created by tonyreet on 2020/9/4.
//  Copyright © 2020 philips.respironics. All rights reserved.
//

import Foundation

public func print(debug: Any...,
                  function: String = #function,
                  file: String = #file,
                  line: Int = #line) {

    var filename = file
    if let match = filename.range(of: "[^/]*$", options: .regularExpression) {
        filename = String(filename[match])
    }
    Swift.print("Debug Log:\(filename),line:\(line),function:\(function)\n\(debug) \n")
}

