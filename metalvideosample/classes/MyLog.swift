//
//  MyLog.swift
//  myblecheck01
//
//  Created by 庄俊亮 on 2018/12/16.
//  Copyright © 2018 庄俊亮. All rights reserved.
//

import UIKit

class MyLog: NSObject {
	
	internal class func debug(_ obj: Any = "",
							  function: String = #function,
							  file: String = #file,
							  line: Int = #line) {
        #if DEBUG
		var filename = file
		if let match = filename.range(of: "[^/]*$", options: .regularExpression) {
			
			filename = String(filename[match])
		}
		debugPrint("MyLog.debug : \(filename) L\(line) \(function) : \(obj)")
        #endif
	}
}
