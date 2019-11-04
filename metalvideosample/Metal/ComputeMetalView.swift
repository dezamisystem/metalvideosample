//
//  ComputeMetalView.swift
//  metalvideosample
//
//  Created by 庄俊亮 on 2019/11/03.
//  Copyright © 2019 庄俊亮. All rights reserved.
//

import MetalKit

class ComputeMetalView: MTKView {

	var pixelBuffer: CVPixelBuffer? {
		didSet {
			if let buffer = self.pixelBuffer {
				let width = CVPixelBufferGetWidth(buffer)
				let height = CVPixelBufferGetHeight(buffer)
				self.drawableSize = CGSize(width: CGFloat(width), height: CGFloat(height))
			}
			setNeedsDisplay()
		}
	}

	// for Compute pipeline
	private var textureCache: CVMetalTextureCache?
	private var commandQueue: MTLCommandQueue? = nil
	private var computePipelineState: MTLComputePipelineState? = nil

	// MARK: - Construct
	required init(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	init(frame frameRect: CGRect) {
		// Get the default metal device.
		let metalDevice = MTLCreateSystemDefaultDevice()!
		// Create a command queue.
		self.commandQueue = metalDevice.makeCommandQueue()!
		// Create the metal library containing the shaders
		let library = metalDevice.makeDefaultLibrary()
		// Create a function with a specific name.
		let function = library!.makeFunction(name: "colorKernel")!
		// Create a compute pipeline with the above function.
		self.computePipelineState = try! metalDevice.makeComputePipelineState(function: function)
		// Initialize the cache to convert the pixel buffer into a Metal texture.
		var texCache: CVMetalTextureCache?
		guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &texCache) == kCVReturnSuccess else {
			fatalError("Unable to allocate texture cache.")
		}
		self.textureCache = texCache
		
		// Initialize super.
		super.init(frame: frameRect, device: metalDevice)

		// Assign the metal device to this view.
		self.device = metalDevice
		// Enable the current drawable texture read/write.
		self.framebufferOnly = false
		// Disable drawable auto-resize.
		self.autoResizeDrawable = false
		// Set the content mode to aspect fit.
		self.contentMode = .scaleAspectFit //.scaleToFill //.
		// Change drawing mode based on setNeedsDisplay().
		self.enableSetNeedsDisplay = true
		self.isPaused = true
		// Set the content scale factor to the screen scale.
		self.contentScaleFactor = UIScreen.main.scale
	}

    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
		autoreleasepool {
			if rect.width > 0 && rect.height > 0 {
				self.render()
			}
		}
    }
    
	private func render() {
		// Create a video image texture.
		guard let inputTexture = VideoRender.getTexture(pixelBuffer: self.pixelBuffer, textureCache: self.textureCache, pixelFormat: .bgra8Unorm) else {
			return
		}
		// Check if Core Animation provided a drawable.
		guard let drawable: CAMetalDrawable = self.currentDrawable else {
			return
		}
		// Check compute pipeline state.
		guard let pipeline = self.computePipelineState else {
			return
		}
		// Create a command buffer.
		guard let commandBuffer = self.commandQueue?.makeCommandBuffer() else {
			return
		}
		// Create a compute command encoder.
		guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
			return
		}
		// Set the compute pipeline state for the command encoder.
		encoder.setComputePipelineState(pipeline)
		// Set the input and output textures for the compute shader.
		encoder.setTexture(inputTexture, index: 0)
		encoder.setTexture(drawable.texture, index: 1)
		// Encode a threadgroup's execution of a compute function
		encoder.dispatchThreadgroups(inputTexture.threadGroups(),
									 threadsPerThreadgroup: inputTexture.threadGroupCount())
		// End the encoding of the command.
		encoder.endEncoding()
		// Register the current drawable for rendering.
		commandBuffer.present(drawable)
		// Commit the command buffer for execution.
		commandBuffer.commit()
		// Wait to end.
        commandBuffer.waitUntilCompleted()
	}

}
