//
//  CustomSlider.swift
//  Copyright (c) 2020 東亜プリン秘密研究所. All rights reserved.
//

import UIKit

class CustomSlider: UISlider {

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        // thumb以外のタッチイベントを有効にする
        return true
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // タッチイベント判定エリアを広げる
        var wideBounds = bounds
        wideBounds.size.height += 10.0
        return wideBounds.contains(point)
    }
    
    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */

}
