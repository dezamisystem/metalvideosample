//
//  MTLTexture_extension.swift
//  metalvideosample
//
//  Created by 庄俊亮 on 2019/11/03.
//  Copyright © 2019 庄俊亮. All rights reserved.
//

import Metal

extension MTLTexture {
 
    func threadGroupCount() -> MTLSize {
        return MTLSizeMake(8, 8, 1)
    }
 
    func threadGroups() -> MTLSize {
        let groupCount = threadGroupCount()
        return MTLSizeMake(Int(self.width) / groupCount.width, Int(self.height) / groupCount.height, 1)
    }
}
