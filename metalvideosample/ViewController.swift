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

@objc class CountObject: NSObject {
    @objc dynamic var count: Int = 0
}

@objc class CountContainer: NSObject {
    @objc dynamic var object = CountObject()
}

class ViewController: UIViewController {

    enum Result {
        case success(AVPlayer)
        case failed
    }
    
	@IBOutlet weak var forVideoView: UIView!
    
    var videoSheetView = UIView(frame: CGRect.zero)
    var seekSlider = CustomSlider(frame: CGRect.zero)
    var videoIndicatorView = UIActivityIndicatorView()
    
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
    private var avPlayerItemTimedMetadataObservation: NSKeyValueObservation?
    private var avPlayerItemPresentationSizeObservation: NSKeyValueObservation?
    private var timeObserverToken: Any?
    private var ratePrevSeek: Float = 0
    private var seekCountContainer = CountContainer()
    private var calledSeekObservation: NSKeyValueObservation?

    /// Lazy AVPlayerItemVideoOutput
	lazy var avPlayerItemVideoOutput: AVPlayerItemVideoOutput = {
		let attributes = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
		return AVPlayerItemVideoOutput(pixelBufferAttributes: attributes)
	}()
	
	override func viewDidLoad() {
		super.viewDidLoad()
        MyLog.debug("")
        
		// Do any additional setup after loading the view.
        self.videoSheetView.backgroundColor = UIColor(red: 0, green: 0, blue: 0.5, alpha: 1)
        self.view.addSubview(self.videoSheetView)
        
        // Notifications
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(orientationChanged),
                                               name: UIDevice.orientationDidChangeNotification,
                                               object: nil)
        readyPlayerItem()
	}
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let topSafeArea: CGFloat
        let bottomSafeArea: CGFloat
        let leftSafeArea: CGFloat
        let rightSafeArea: CGFloat
        topSafeArea = self.view.safeAreaInsets.top
        bottomSafeArea = self.view.safeAreaInsets.bottom
        leftSafeArea = self.view.safeAreaInsets.left
        rightSafeArea = self.view.safeAreaInsets.right
        MyLog.debug("topSafeArea = \(topSafeArea), bottomSafeArea = \(bottomSafeArea), leftSafeArea = \(leftSafeArea), rightSafeArea = \(rightSafeArea)")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        MyLog.debug("")

        self.readyToPlay()
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

        updateMetalViewFrame()
    }
    
    /// MetalViewフレーム更新
    private func updateMetalViewFrame() {

        let orientation = UIDevice.current.orientation
        let isFlat = orientation.isFlat
        var isLandscape = orientation.isLandscape
        var isPortrait = orientation.isPortrait
        if !isLandscape && !isPortrait {
            isPortrait = UIScreen.main.bounds.width < UIScreen.main.bounds.height;
            isLandscape = !isPortrait
        }
        if !isFlat {
            // Video Sheet View
            if isPortrait {
                self.videoSheetView.frame = self.forVideoView.frame
            }
            else {
                let baseFrame = self.view.frame
                let width = baseFrame.size.width - self.view.safeAreaInsets.left - self.view.safeAreaInsets.right
                let height = baseFrame.size.height - self.view.safeAreaInsets.top - self.view.safeAreaInsets.bottom
                let pos_x = baseFrame.origin.x + self.view.safeAreaInsets.left
                let pos_y = baseFrame.origin.y + self.view.safeAreaInsets.top
                self.videoSheetView.frame = CGRect(x: pos_x, y: pos_y, width: width, height: height)
            }
            // metal View
            self.metalView?.frame.size = self.videoSheetView.frame.size
            // Slider
            let seekHeight: CGFloat = 20
            self.seekSlider.frame = CGRect(x: self.videoSheetView.frame.origin.x,
                                           y: self.videoSheetView.frame.height - seekHeight - 20,
                                           width: self.videoSheetView.frame.width,
                                           height: seekHeight)
            // Indicator
            self.videoIndicatorView.center = self.videoSheetView.center
        }
    }
    
    /// Ready AVPlayerItem
    private func readyPlayerItem() {
        
        let avAsset = AVURLAsset(url: self.contentUrl)
        self.avPlayerItem = AVPlayerItem(asset: avAsset)
        self.avPlayerItem!.add(self.avPlayerItemVideoOutput)
        self.avPlayer.replaceCurrentItem(with: self.avPlayerItem)
        self.avPlayerItem!.preferredForwardBufferDuration = 10
        self.startPlayerItemStatusObservation()
        #if TEST_METADATA
        self.startPlayerItemTimedMetadataObservation()
        #endif
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
    
    // TODO: MetalView clip
    private func clipTestMetalView() {
        
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
    }
    
    /// Ready to play
    private func readyToPlay() {
        
        // Set metal view frame
        self.metalView = MetalView(frame: CGRect(origin: CGPoint.zero, size: self.videoSheetView.frame.size)) { (error) in
            if let error = error {
                MyLog.debug("Metal Error : \(error.domain)")
            }
        }
        self.updateMetalViewFrame()
        self.videoSheetView.addSubview(self.metalView!)
        // Slider
        self.seekSlider.backgroundColor = UIColor(white: 0.75, alpha: 1)
        self.seekSlider.isContinuous = true
        self.seekSlider.addTarget(self, action: #selector(onSeekBegin(_:)), for: UIControl.Event.touchDown)
        self.seekSlider.addTarget(self, action: #selector(onSeekMove(_:)), for: UIControl.Event.valueChanged)
        self.seekSlider.addTarget(self, action: #selector(onSeekEnd(_:)), for: UIControl.Event.touchUpInside)
        self.seekSlider.addTarget(self, action: #selector(onSeekEnd(_:)), for: UIControl.Event.touchCancel)
        self.videoSheetView.addSubview(self.seekSlider)
        // Indicator
        self.videoIndicatorView.style = .whiteLarge
        self.videoIndicatorView.hidesWhenStopped = true
        self.videoSheetView.addSubview(self.videoIndicatorView)
        self.videoIndicatorView.startAnimating()

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
    
    /// シーク実行
    /// - Parameters:
    ///   - value: 位置％
    ///   - completion: クロージャー
    private func seekWithSliderValue(value: Float, completion: @escaping (_ result: Bool)->Void) {

        guard let playerItem = self.avPlayer.currentItem else {
            return
        }
        let duration = playerItem.asset.duration
        let durationSeconds = CMTimeGetSeconds(duration)
        let positionSeconds = durationSeconds * Float64(value)
        let position = CMTimeMakeWithSeconds(positionSeconds, preferredTimescale: Int32(NSEC_PER_SEC))
        MyLog.debug("Seek position = \(positionSeconds)[s]")
        // シーク（コンマ秒単位まで指定）
        self.avPlayer.seek(to: position, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero) { result in

            // Syncronized
            let serialQueue = DispatchQueue(label: "com.dezamisystem.seek", qos: .userInitiated)
            serialQueue.sync {
                completion(result)
            }
        }
    }
        
    /// シーク開始時
    /// - Parameter sender: 送り主
    @objc func onSeekBegin(_ sender: UITapGestureRecognizer) {
        MyLog.debug("")
        
        // シークバー移動の停止
        self.removePeriodicTimeObserver()
        // シークサムネイルの変更
        self.seekSlider.value = self.seekSlider.touchedValue
        // Indicator
        self.videoIndicatorView.startAnimating()
    }
    
    /// シーク移動時
    /// - Parameter sender: 送り主
    @objc func onSeekMove(_ sender: UITapGestureRecognizer) {
        MyLog.debug()
        
        // シーク開始
        self.seekCountContainer.object.count += 1
        self.seekWithSliderValue(value: self.seekSlider.value) {[weak self] _ in
            // シーク完了
            guard let `self` = self else {
                return
            }
            self.seekCountContainer.object.count -= 1
        }
    }
    
    /// シーク終了時
    /// - Parameter sender: 送り主
    @objc func onSeekEnd(_ sender: UITapGestureRecognizer) {
        MyLog.debug()
        
        // シーク完了の監視
        guard self.calledSeekObservation == nil else {
            return
        }
        self.calledSeekObservation = self.seekCountContainer.object.observe(\.count) {[weak self] owner, changed in
            MyLog.debug("Called Seek Count = \(owner.count)")
            guard owner.count <= 0 else {
                return
            }
            guard let `self` = self else {
                return
            }
            // シークバー移動の開始
            self.addPeriodicTimeObserver()
            // シーク完了監視の終了
            self.calledSeekObservation?.invalidate()
            self.calledSeekObservation = nil
            // Main Thread
            DispatchQueue.main.async {[weak self] in
                self?.videoIndicatorView.stopAnimating()
            }
        }
    }
    
    /// Callback : AVPlayerItemDidPlayToEndTime
    /// - Parameter notification: from AVPlayerItemDidPlayToEndTime
	@objc private func avPlayerDidReachEnd(_ notification: Notification) {
        
		// Infinity Loop
        let rate = self.avPlayer.rate
		self.avPlayer.seek(to: CMTime.zero) { (isFinished) in
            self.avPlayer.rate = rate
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
    
    /// 監視開始・AVPlayerItem.status
    private func startPlayerItemStatusObservation() {
        
        guard self.avPlayerItemStatusObservation == nil else {
            return
        }
        guard let playerItem = self.avPlayerItem else {
            return
        }
        self.avPlayerItemStatusObservation = playerItem.observe(\.status) {[weak self] item, change in
            switch item.status {
            case .readyToPlay:
                MyLog.debug("readyToPlay")
                MyLog.debug("playerItem.isPlaybackBufferEmpty = \(item.isPlaybackBufferEmpty)")
                MyLog.debug("playerItem.isPlaybackBufferFull = \(item.isPlaybackBufferFull)")
                    
                // Start to play
                self?.startPlayerItemPresentationSizeObservation()
                self?.avPlayer.play()
                    
                // Start to update UI
                self?.addPeriodicTimeObserver()
                
                // Remove ovserver
                self?.avPlayerItemStatusObservation?.invalidate()
                self?.avPlayerItemStatusObservation = nil
                
                // Main Thread
                DispatchQueue.main.async {[weak self] in
                    self?.videoIndicatorView.stopAnimating()
                }
                
            case .failed:
                MyLog.debug("failed")
            default:
                break
            }
        }
    }
    
    /// 監視開始・ポジション
    func addPeriodicTimeObserver() {
        
        let time = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        self.timeObserverToken = self.avPlayer.addPeriodicTimeObserver(forInterval: time, queue: .main, using: { [weak self] time in
            guard let playerItem = self?.avPlayerItem else {
                return
            }
            let duration = playerItem.duration.seconds
            let seconds = time.seconds
            let percent = seconds / duration
            self?.seekSlider.value = Float(percent)
        })
    }
    
    /// 監視終了・ポジション
    func removePeriodicTimeObserver() {
        
        guard let token = self.timeObserverToken else {
            return
        }
        self.avPlayer.removeTimeObserver(token)
        self.timeObserverToken = nil
    }
    
    /// 監視開始・AVPlayerItem.timedMetadata
    private func startPlayerItemTimedMetadataObservation() {
        
        guard self.avPlayerItemTimedMetadataObservation == nil else {
            return
        }
        guard let playerItem = self.avPlayerItem else {
            return
        }
        self.avPlayerItemTimedMetadataObservation = playerItem.observe(\.timedMetadata) { item, change in
            if let timedMetadata = item.timedMetadata {
                for meta in timedMetadata {
                    MyLog.debug("\(meta)")
                }
            }
        }
    }
    
    /// 監視開始・AVPlayerItem.presentationSize
    private func startPlayerItemPresentationSizeObservation() {
        
        guard self.avPlayerItemPresentationSizeObservation == nil else {
            return
        }
        guard let playerItem = self.avPlayerItem else {
            return
        }
        self.avPlayerItemPresentationSizeObservation = playerItem.observe(\.presentationSize) { item, change in
            MyLog.debug("\(item.presentationSize)")
        }
    }
    
    /// ビットレートテスト
    private func testBitrate() {
        guard let playerItem = self.avPlayerItem else {
            return
        }
        playerItem.preferredPeakBitRate = 5280160
    }
    
}

