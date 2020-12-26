//
//  CustomSlider.swift
//  Copyright (c) 2020 東亜プリン秘密研究所. All rights reserved.
//

import UIKit

class CustomSlider: UISlider {

    private(set) var touchedValue: Float = 0
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        
        let tapPoint = touch.location(in: self)
        let sliderLength = bounds.width - bounds.origin.x
        let tapOriginX = tapPoint.x - bounds.origin.x
        let percent = Float(tapOriginX / sliderLength)
        touchedValue = min(max(percent, 0), 1)
        
        // thumb以外のタッチイベントを有効にする
        return true
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // タッチイベント判定エリアを広げる
        var wideBounds = bounds
        wideBounds.size.height += 10.0
        return wideBounds.contains(point)
    }
    
}
