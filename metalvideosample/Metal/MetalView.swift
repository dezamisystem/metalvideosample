//
//  MetalView.swift
//  metalvideosample
//
//  Created by 庄俊亮 on 2019/11/03.
//  Copyright © 2019 庄俊亮. All rights reserved.
//

import MetalKit

class MetalView: MTKView {

//	enum ClipType {
//		case all
//		case left
//		case right
//	}
	
	// MARK: - Global methods
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
	
	private(set) var metalError: NSError? = nil

	// MARK: - Local methods
	private var textureCache: CVMetalTextureCache? = nil
	private var commandQueue: MTLCommandQueue? = nil
	private let pixelFormat: MTLPixelFormat = .bgra8Unorm

	// for Render Pipeline
    private var vertexBuffer: MTLBuffer? = nil
	private var vertexBufferForHalf: MTLBuffer? = nil
	
    private var texCoordBuffer: MTLBuffer? = nil
	private var texCoordBufferForLeft: MTLBuffer? = nil
	private var texCoordBufferForRight: MTLBuffer? = nil
	
    private var renderPipeline: MTLRenderPipelineState? = nil
    private let renderPassDescriptor = MTLRenderPassDescriptor()

	var clipType: VideoRender.ClipType = .all
	
	// MARK: - Construct
	required init(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	init(frame frameRect: CGRect, callback: (NSError?) -> Void) {
		// Get the default metal device.
		guard let metalDevice = MTLCreateSystemDefaultDevice() else {
			super.init(frame: frameRect, device: nil)
			self.metalError = NSError(domain: "Metal Device is nil.", code: -1, userInfo: nil)
			callback(self.metalError)
			return
		}
		// Create a command queue.
		self.commandQueue = metalDevice.makeCommandQueue()
		// Initialize the cache to convert the pixel buffer into a Metal texture.
		var texCache: CVMetalTextureCache?
		guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &texCache) == kCVReturnSuccess else {
			super.init(frame: frameRect, device: nil)
			self.metalError = NSError(domain: "Unable to allocate texture cache.", code: -1, userInfo: nil)
			callback(self.metalError)
			return
		}
		self.textureCache = texCache
		
		// Initialize super.
		super.init(frame: frameRect, device: metalDevice)

		// Enable the current drawable texture read/write.
		self.framebufferOnly = false
		// Disable drawable auto-resize.
		self.autoResizeDrawable = false
		// Set the content mode to aspect fit.
		self.contentMode = .scaleAspectFit
		// Change drawing mode based on setNeedsDisplay().
		self.enableSetNeedsDisplay = true
		self.isPaused = true
		// Set the content scale factor to the screen scale.
		self.contentScaleFactor = UIScreen.main.scale
		
		// Init shader
		makeBuffers()
		makePipeline()
		
		callback(nil)
	}
	
    private func makeBuffers() {
				
		self.vertexBuffer = self.makeBuffer(array: VideoRender.verticesArray)
        
		self.vertexBufferForHalf = self.makeBuffer(array: VideoRender.verticesArrayForHalf)
				
		self.texCoordBuffer = self.makeBuffer(array: VideoRender.coordinatesArray)
				
		self.texCoordBufferForLeft = self.makeBuffer(array: VideoRender.coordinatesArrayForLeft)
		
		self.texCoordBufferForRight = self.makeBuffer(array: VideoRender.coordinatesArrayForRight)
    }
	
	private func makeBuffer(array: [Float]) -> MTLBuffer? {
		let size = array.count * MemoryLayout<Float>.size
		return self.device?.makeBuffer(bytes: array, length: size, options: [])
	}

    private func makePipeline() {
		guard let library = self.device?.makeDefaultLibrary() else {
			return
		}
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "vertexShader")
        descriptor.fragmentFunction = library.makeFunction(name: "fragmentShader")
		descriptor.colorAttachments[0].pixelFormat = self.pixelFormat
		self.renderPipeline = try? self.device?.makeRenderPipelineState(descriptor: descriptor)
    }
	
	// MARK: - Draw
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
		guard let inputTexture = VideoRender.getTexture(pixelBuffer: self.pixelBuffer, textureCache: self.textureCache, pixelFormat: self.pixelFormat) else {
			return
		}
		// Check if Core Animation provided a drawable.
        guard let drawable = self.currentDrawable else {
			return
		}
		// Create a command buffer.
		guard let commandBuffer = self.commandQueue?.makeCommandBuffer() else {
			return
		}
		// Check pipeline.
		guard let renderPipeline = self.renderPipeline else {
			return
		}
		// Set Shader Buffer
		var vBuffer: MTLBuffer? = nil
		var cBuffer: MTLBuffer? = nil
		switch self.clipType {
		case .all:
			vBuffer = self.vertexBuffer
			cBuffer = self.texCoordBuffer
			break
		case .left:
			vBuffer = self.vertexBufferForHalf
			cBuffer = self.texCoordBufferForLeft
			break
		case .right:
			vBuffer = self.vertexBufferForHalf
			cBuffer = self.texCoordBufferForRight
			break
		}
		guard let bufferOfVertex = vBuffer, let bufferOfCoordinate = cBuffer else {
			return
		}
		// Set render texture.
		self.renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadAction.clear
		self.renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreAction.store
		self.renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
		self.renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        // Creatr encoder.
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
			return
		}
		// Start to shade
        renderEncoder.setRenderPipelineState(renderPipeline)
        renderEncoder.setVertexBuffer(bufferOfVertex, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(bufferOfCoordinate, offset: 0, index: 1)
        renderEncoder.setFragmentTexture(inputTexture, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
		// End the encoding of the command.
        renderEncoder.endEncoding()
		// Register the current drawable for rendering.
        commandBuffer.present(drawable)
		// Commit the command buffer for execution.
        commandBuffer.commit()
		// Wait to end.
        commandBuffer.waitUntilCompleted()
	}
	
}
