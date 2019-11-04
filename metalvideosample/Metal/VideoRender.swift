//
//  VideoRender.swift
//  metalvideosample
//
//  Created by 庄俊亮 on 2019/11/03.
//  Copyright © 2019 庄俊亮. All rights reserved.
//

import UIKit
import Metal

class VideoRender: NSObject {

	enum ClipType: Int {
		case all = 0
		case left = 1
		case right = 2
	}

	static var verticesArray: [Float] = {
		// (x,y,z,w)*4
		let xyzwArray: [Float] = [-1, -1, 0, 1,
								   1, -1, 0, 1,
								   -1,  1, 0, 1,
								   1,  1, 0, 1]
		return xyzwArray
	}()
	
	static var verticesArrayForHalf: [Float] = {
		// (x,y,z,w)*4
		let xyzwArray: [Float] = [-0.5, -1, 0, 1,
								  0.5, -1, 0, 1,
								  -0.5,  1, 0, 1,
								  0.5,  1, 0, 1]
		return xyzwArray
	}()
	
	static var coordinatesArray: [Float] = {
		// (u,v)*4
		let uvArray: [Float] = [0, 1,
								1, 1,
								0, 0,
								1, 0]
		return uvArray
	}()
	
	static var coordinatesArrayForLeft: [Float] = {
		// (u,v)*4
		let uvArray: [Float] = [0, 1,
								0.5, 1,
								0, 0,
								0.5, 0]
		return uvArray
	}()
	
	static var coordinatesArrayForRight: [Float] = {
		// (u,v)*4
		let uvArray: [Float] = [0.5, 1,
								1, 1,
								0.5, 0,
								1, 0]
		return uvArray
	}()
	
	internal class func getTexture(pixelBuffer: CVPixelBuffer?, textureCache: CVMetalTextureCache?, pixelFormat: MTLPixelFormat) -> MTLTexture? {
		
		guard let buffer = pixelBuffer else {
			return nil
		}
		guard let cache = textureCache else {
			return nil
		}
		
		// Get width and height for the pixel buffer
		let width = CVPixelBufferGetWidth(buffer)
		let height = CVPixelBufferGetHeight(buffer)
		var cvTextureOut: CVMetalTexture?
		CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault,
												  cache,
												  buffer, nil,
												  pixelFormat,
												  width,
												  height,
												  0,
												  &cvTextureOut)
		guard let cvTexture = cvTextureOut,
			let texture = CVMetalTextureGetTexture(cvTexture) else {
			return nil
		}

		return texture
	}
}
