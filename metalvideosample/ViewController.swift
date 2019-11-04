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
	
	static let contentUrlString = "https://dezamisystem.com/movie/hls/blazingstar01.m3u8"
	private var contentUrl: URL = {
		let url = URL(string: ViewController.contentUrlString)
		return url!
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

