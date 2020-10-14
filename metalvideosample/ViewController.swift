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

    enum Result {
        case success(AVPlayer)
        case failed
    }
    
	@IBOutlet weak var forVideoView: UIView!
    
    var videoSheetView: UIView = UIView(frame: CGRect.zero)
    
    /// Lazy Content URL
	lazy var contentUrl: URL = {
		let path = Bundle.main.path(forResource: "PropertyList", ofType: "plist")
		if let path = path {
			let dict = NSDictionary(contentsOfFile: path)
			if let dict = dict {
				let value = dict["content_url"]
                if let urlText = value as? String {
                    MyLog.debug("content_url = \(urlText)")
					return URL(string: urlText)!
				}
			}
		}
		return URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")!
	}()
	
	private var metalView: MetalView?
	
	private let avPlayer = AVPlayer()
    private var avPlayerItem: AVPlayerItem?
    private var avPlayerItemStatusObservation: NSKeyValueObservation?
    
    /// Lazy AVPlayerItemVideoOutput
	lazy var avPlayerItemVideoOutput: AVPlayerItemVideoOutput = {
		let attributes = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
		return AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
	}()
	
	override func viewDidLoad() {
		super.viewDidLoad()
        MyLog.debug("")
        
		// Do any additional setup after loading the view.
        self.videoSheetView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 1)
        self.view.addSubview(self.videoSheetView)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(orientationChanged),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
        readyPlayerItem()
	}
    
    /// 端末向き変化時
    @objc func orientationChanged() {

        let orientation = UIDevice.current.orientation
        let isFlat = orientation.isFlat
        var isLandscape = orientation.isLandscape
        var isPortrait = orientation.isPortrait
        if !isLandscape && !isPortrait {
            isPortrait = UIScreen.main.bounds.width < UIScreen.main.bounds.height;
            isLandscape = !isPortrait
        }
        MyLog.debug("flat=\(isFlat), landscape=\(isLandscape), portrait=\(isPortrait)")

        if isPortrait {
            self.videoSheetView.frame = self.forVideoView.frame
        }
        else {
            self.videoSheetView.frame = self.view.frame
        }
        self.metalView?.frame.size = self.videoSheetView.frame.size
    }
    
    /// Ready AVPlayerItem
    private func readyPlayerItem() {
        
        let avAsset = AVURLAsset(url: self.contentUrl)
        self.avPlayerItem = AVPlayerItem(asset: avAsset)
        self.avPlayerItem!.add(self.avPlayerItemVideoOutput)
        self.avPlayer.replaceCurrentItem(with: self.avPlayerItem)
        self.avPlayerItem!.preferredForwardBufferDuration = 10
        self.startPlayerItemStatusObservation()
    }
    
    /// Lazy CADisplayLink
	lazy var displayLink: CADisplayLink = {
		let dl = CADisplayLink(target: self, selector: #selector(readBuffer(_:)))
		dl.add(to: .current, forMode: .default)
		dl.isPaused = true
		return dl
	}()
    
    /// 映像バッファ読み込み
    /// - Parameter sender: ディスプレイリンク
	@objc private func readBuffer(_ sender: CADisplayLink) {
		
		var currentTime = CMTime.invalid
		let nextVSync = sender.timestamp + sender.duration
		currentTime = self.avPlayerItemVideoOutput.itemTime(forHostTime: nextVSync)
		
		if avPlayerItemVideoOutput.hasNewPixelBuffer(forItemTime: currentTime),
			let pixelBuffer = avPlayerItemVideoOutput.copyPixelBuffer(forItemTime: currentTime, itemTimeForDisplay: nil) {
			
			self.metalView?.pixelBuffer = pixelBuffer
		}
	}
    
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
        MyLog.debug("")

        self.readyToPlay()
	}
    
    /// Ready to play
    private func readyToPlay() {
        
        // Set metal view frame
        self.metalView = MetalView(frame: CGRect(origin: CGPoint.zero, size: self.videoSheetView.frame.size)) { (error) in
            if let error = error {
                MyLog.debug("Metal Error : \(error.domain)")
            }
        }
        self.videoSheetView.addSubview(metalView!)
        
        //  Resume the display link
        displayLink.isPaused = false
        // Set notification
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(avPlayerDidReachEnd(_:)),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(avPlayerDidErrorLog(_:)),
                                               name: .AVPlayerItemNewErrorLogEntry,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(avPlayerDidPlaybackStalled(_:)),
                                               name: .AVPlayerItemPlaybackStalled,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(avPlayerDidFailedToPlaytoEndTime(_:)),
                                               name: .AVPlayerItemFailedToPlayToEndTime,
                                               object: nil)
    }
    
    /// Callback : AVPlayerItemDidPlayToEndTime
    /// - Parameter notification: from AVPlayerItemDidPlayToEndTime
	@objc private func avPlayerDidReachEnd(_ notification: Notification) {
		// Infinity Loop
		self.avPlayer.seek(to: CMTime.zero) { (isFinished) in
			
            guard let metalView = self.metalView else {
                return
            }
			var clipTypeIndex = metalView.clipType.rawValue
			clipTypeIndex += 1
			if clipTypeIndex > VideoRender.ClipType.right.rawValue {
				clipTypeIndex = VideoRender.ClipType.all.rawValue
			}
			if let newClipType = VideoRender.ClipType(rawValue: clipTypeIndex) {
				metalView.clipType = newClipType
			}
			
			self.avPlayer.play()
		}
	}
    
    /// Callback : AVPlayerItemNewErrorLogEntry
    /// - Parameter notification: from AVPlayerItemNewErrorLogEntry
    @objc private func avPlayerDidErrorLog(_ notification: Notification) {
        
        MyLog.debug("")
        if let userInfo = notification.userInfo {
            MyLog.debug("+++ UserInfo +++")
            for (key,value) in userInfo {
                MyLog.debug("\(key) : \(value)")
            }
        }
        if let errorLog = avPlayerItem?.errorLog() {
            MyLog.debug("+++ ErrorLog +++")            
            MyLog.debug("\(errorLog)")
        }
    }
    
    /// Callback : AVPlayerItemPlaybackStalled
    /// - Parameter notification: from AVPlayerItemPlaybackStalled
    @objc private func avPlayerDidPlaybackStalled(_ notification: Notification) {
        
        MyLog.debug("")
        if let userInfo = notification.userInfo {
            MyLog.debug("+++ UserInfo +++")
            MyLog.debug(userInfo)
        }
        if let errorLog = avPlayerItem?.errorLog() {
            MyLog.debug("+++ ErrorLog +++")
            MyLog.debug(errorLog)
        }
    }
    
    /// Callback : AVPlayerItemFailedToPlayToEndTime
    /// - Parameter notification: from AVPlayerItemFailedToPlayToEndTime
    @objc private func avPlayerDidFailedToPlaytoEndTime(_ notification: Notification) {
        
        MyLog.debug("")
        if let userInfo = notification.userInfo {
            MyLog.debug("+++ UserInfo +++")
            MyLog.debug(userInfo)
        }
        if let errorLog = avPlayerItem?.errorLog() {
            MyLog.debug("+++ ErrorLog +++")
            MyLog.debug(errorLog)
        }
    }
    
    /// 監視開始
    private func startPlayerItemStatusObservation() {
        
        guard self.avPlayerItemStatusObservation == nil else {
            return
        }
        guard let playerItem = self.avPlayerItem else {
            return
        }
                
        self.avPlayerItemStatusObservation = playerItem.observe(\.status) { item, change in
            switch item.status {
            case .readyToPlay:
                MyLog.debug("readyToPlay")
                MyLog.debug("playerItem.isPlaybackBufferEmpty = \(playerItem.isPlaybackBufferEmpty)")
                MyLog.debug("playerItem.isPlaybackBufferFull = \(playerItem.isPlaybackBufferFull)")
                // Start to play
                self.avPlayer.play()
            case .failed:
                MyLog.debug("failed")
            default:
                break
            }
        }
    }
}

