//
//  ViewController.swift
//  metalvideosample
//
//  Created by 庄俊亮 on 2019/11/02.
//  Copyright © 2019 庄俊亮. All rights reserved.
//

import UIKit
import AVFoundation
import MetalKit

class ViewController: UIViewController {

	@IBOutlet weak var forVideoView: UIView!
		
	lazy var contentUrl: URL = {
		let path = Bundle.main.path(forResource: "PropertyList", ofType: "plist")
		if let path = path {
			let dict = NSDictionary(contentsOfFile: path)
			if let dict = dict {
				let value = dict["content_url"]
				if let text = value as? String {
					return URL(string: text)!
				}
			}
		}
		return URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")!
	}()
	
	private var metalView: MetalView!
	
	private let avPlayer = AVPlayer()
	
	lazy var avPlayerItemVideoOutput: AVPlayerItemVideoOutput = {
		let attributes = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
		return AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
	}()
	
	override func viewDidLoad() {
		super.viewDidLoad()
		// Do any additional setup after loading the view.

		let avAsset = AVURLAsset(url: self.contentUrl)
		let avPlayerItem = AVPlayerItem(asset: avAsset)
		avPlayerItem.add(self.avPlayerItemVideoOutput)
		self.avPlayer.replaceCurrentItem(with: avPlayerItem)
	}

	lazy var displayLink: CADisplayLink = {
		let dl = CADisplayLink(target: self, selector: #selector(readBuffer(_:)))
		dl.add(to: .current, forMode: .default)
		dl.isPaused = true
		return dl
	}()

	@objc private func readBuffer(_ sender: CADisplayLink) {
		
		var currentTime = CMTime.invalid
		let nextVSync = sender.timestamp + sender.duration
		currentTime = self.avPlayerItemVideoOutput.itemTime(forHostTime: nextVSync)
		
		if avPlayerItemVideoOutput.hasNewPixelBuffer(forItemTime: currentTime),
			let pixelBuffer = avPlayerItemVideoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) {
			
			self.metalView.pixelBuffer = pixelBuffer
		}
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
			
		// Set metal view frame
		self.metalView = MetalView(frame: CGRect(origin: CGPoint.zero, size: self.forVideoView.frame.size)) { (error) in
			if let error = error {
				debugPrint("Metal Error : \(error.domain)")
			}
		}
		self.forVideoView.addSubview(metalView)
		
		//  Resume the display link
		displayLink.isPaused = false
		// Set notification
		NotificationCenter.default.addObserver(self,
											   selector: #selector(avPlayerDidReachEnd(_:)),
											   name: .AVPlayerItemDidPlayToEndTime,
											   object: nil)
		// Start to play
		self.avPlayer.play()
	}
	
	@objc private func avPlayerDidReachEnd(_ notification: Notification) {
		// Infinity Loop
		self.avPlayer.seek(to: CMTime.zero) { (isFinished) in
			
			var clipTypeIndex = self.metalView.clipType.rawValue
			clipTypeIndex += 1
			if clipTypeIndex > VideoRender.ClipType.right.rawValue {
				clipTypeIndex = VideoRender.ClipType.all.rawValue
			}
			if let newClipType = VideoRender.ClipType(rawValue: clipTypeIndex) {
				self.metalView.clipType = newClipType
			}
			
			self.avPlayer.play()
		}
	}
}

