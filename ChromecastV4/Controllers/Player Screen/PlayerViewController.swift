//
//  PlayerViewController.swift
//  ChromecastV4
//
//  Created by Luthfi Fathur Rahman on 27/01/19.
//  Copyright © 2019 Imperio Teknologi Indonesia. All rights reserved.
//

import UIKit
import GoogleCast
import AVFoundation

let kPrefShowStreamTimeRemaining: String = "show_stream_time_remaining"

enum PlaybackState {
    case created
    case createdCast
    case playCast
    case play
    case pauseCast
    case pause
    case finishedCast
    case finished
}

class PlayerViewController: UIViewController {
    
    
    @IBOutlet weak var audioVideoView: UIView!
    @IBOutlet weak var avControllerView: UIView!
    
    @IBOutlet weak var btnStop: UIButton!
    @IBOutlet weak var btnPlayPause: UIButton!
    @IBOutlet weak var lblCurrDuration: UILabel!
    @IBOutlet weak var timeSeeker: UISlider!
    @IBOutlet weak var lblFullDuration: UILabel!
    
    private let castManager = CastManager.shared
    
    private var player: AVPlayer!
    private var playerLayer: AVPlayerLayer!
    private var timeObserver: Any!
    var selectedIndexPath: IndexPath?
    
    private var playbackState: PlaybackState = .created
    private let videoURL = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
    var imageURL: String?
    
    private var mediaControlsContainerView: UIView!
    private var miniMediaControlsHeightConstraint: NSLayoutConstraint!
    private var miniMediaControlsViewController: GCKUIMiniMediaControlsViewController!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let castButton = GCKUICastButton(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        castButton.tintColor = UIColor.black
        castButton.triggersDefaultCastDialog = true
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: castButton)
        
        castManager.seekLocalPlayerDelegate = self
        
        createContainer()
        createMiniMediaControl()
        
        listenForCastConnection()
        
        if castManager.hasConnectionEstablished {
            playbackState = .createdCast
        }
        
        player = AVPlayer(url: URL(string: videoURL)!)
        player.currentItem?.addObserver(self, forKeyPath: "duration", options: [.new, .initial], context: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        addTimeObserver()
        playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        
        audioVideoView.layer.addSublayer(playerLayer)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        if player != nil && !castManager.sessionManager.hasConnectedCastSession() {
            playVideo()
        }
        
        if mediaControlsContainerView != nil {
            updateControlBarsVisibility()
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if playerLayer != nil {
            playerLayer.frame = audioVideoView.bounds
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        
        if player != nil {
            btnStop(self)
            //player.currentItem?.removeObserver(self, forKeyPath: "duration")
            //player.removeTimeObserver(timeObserver)
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "duration", let duration = player.currentItem?.asset.duration, duration.seconds > 0.0 {
            lblFullDuration.text = getTimeString(from: duration)
        }
    }
    
    @objc private func playVideo() {
        player.play()
        btnPlayPause.setImage(UIImage(named: "icon_pause"), for: .normal)
        self.enableActionBtns(true)
    }
    
    @objc private func playerDidFinishPlaying(notification: NSNotification) {
        btnStop(self)
    }
    
    @IBAction func timeSeeker(_ sender: UISlider) {
        player.pause()
        player.seek(to: CMTimeMake(Int64(sender.value*1000), 1000))
        perform(#selector(playVideo), with: nil, afterDelay: 0.5)
    }
    
    @IBAction func btnStop(_ sender: Any) {
        player.pause()
        player.seek(to: CMTimeMake(0, 1))
        btnPlayPause.setImage(UIImage(named: "icon_play"), for: .normal)
    }
    
    @IBAction func btnPlayPause(_ sender: Any) {
        if #available(iOS 10.0, *) {
            if player.timeControlStatus == .playing {
                player.pause()
                btnPlayPause.setImage(UIImage(named: "icon_play"), for: .normal)
            } else if player.timeControlStatus == .paused {
                playVideo()
            }
        } else {
            if player.rate != 0.0 {
                player.pause()
                btnPlayPause.setImage(UIImage(named: "icon_play"), for: .normal)
            } else {
                playVideo()
            }
        }
    }
    
    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        let mainQueue = DispatchQueue.main
        player.addPeriodicTimeObserver(forInterval: interval, queue: mainQueue, using: { [weak self] time in
            guard let currItem = self?.player.currentItem else {
                return
            }
            
            self?.timeSeeker.maximumValue = Float(currItem.duration.seconds)
            self?.timeSeeker.minimumValue = 0
            let currTime = currItem.currentTime()
            self?.timeSeeker.value = Float(currTime.seconds)
            self?.lblCurrDuration.text = self?.getTimeString(from: currTime)
        })
    }
    
    private func getTimeString(from time: CMTime) -> String {
        let totalSec = CMTimeGetSeconds(time)
        let hrs = Int(totalSec / 3600)
        let mnt = Int((Int(totalSec) % 3600) / 60)
        let sec = Int(totalSec.truncatingRemainder(dividingBy: 60))
        
        if hrs > 0 {
            return String(format: "%02d:%02d:%02d", hrs, mnt, sec)
        } else {
            return String(format: "%02d:%02d", mnt, sec)
        }
    }
}

// MARK: - GCKUIMiniMediaControlsViewController
extension PlayerViewController {
    private func createContainer() {
        mediaControlsContainerView = UIView(frame: CGRect(x: 0, y: view.frame.maxY, width: view.frame.width, height: 0))
        mediaControlsContainerView.accessibilityIdentifier = "mediaControlsContainerView"
        view.addSubview(mediaControlsContainerView)
        mediaControlsContainerView.translatesAutoresizingMaskIntoConstraints = false
        mediaControlsContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        mediaControlsContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        mediaControlsContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        miniMediaControlsHeightConstraint = mediaControlsContainerView.heightAnchor.constraint(equalToConstant: 0)
        miniMediaControlsHeightConstraint.isActive = true
    }
    
    private func createMiniMediaControl() {
        let castContext = GCKCastContext.sharedInstance()
        miniMediaControlsViewController = castContext.createMiniMediaControlsViewController()
        miniMediaControlsViewController.delegate = self
        mediaControlsContainerView.alpha = 0
        miniMediaControlsViewController.view.alpha = 0
        miniMediaControlsHeightConstraint.constant = miniMediaControlsViewController.minHeight
        installViewController(miniMediaControlsViewController, inContainerView: mediaControlsContainerView)
        
        updateControlBarsVisibility()
    }
    
    private func updateControlBarsVisibility() {
        if miniMediaControlsViewController.active {
            miniMediaControlsHeightConstraint.constant = miniMediaControlsViewController.minHeight
            view.bringSubview(toFront: mediaControlsContainerView)
        } else {
            miniMediaControlsHeightConstraint.constant = 0
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            self.view.layoutIfNeeded()
        }) { _ in
            self.mediaControlsContainerView.alpha = 1
            self.miniMediaControlsViewController.view.alpha = 1
        }
    }
    
    private func installViewController(_ viewController: UIViewController?, inContainerView containerView: UIView) {
        if let viewController = viewController {
            viewController.view.isHidden = true
            addChildViewController(viewController)
            viewController.view.frame = containerView.bounds
            containerView.addSubview(viewController.view)
            viewController.didMove(toParentViewController: self)
            viewController.view.isHidden = false
        }
    }
}

// MARK: - GCKUIMiniMediaControlsViewControllerDelegate
extension PlayerViewController: GCKUIMiniMediaControlsViewControllerDelegate {
    func miniMediaControlsViewController(_ miniMediaControlsViewController: GCKUIMiniMediaControlsViewController, shouldAppear: Bool) {
        updateControlBarsVisibility()
    }
}

extension PlayerViewController {
    private func listenForCastConnection() {
        let sessionStatusListener: (CastSessionStatus) -> Void = { status in
            switch status {
            case .started:
                self.startCastPlay()
            case .resumed:
                self.continueCastPlay()
            case .ended, .failedToStart:
                if self.playbackState == .playCast {
                    self.playbackState = .pause
                    //self.startPlayer(nil)
                } else if self.playbackState == .pauseCast {
                    self.playbackState = .play
                    //self.pausePlayer(nil)
                }
            default: break
            }
        }
        
        castManager.addSessionStatusListener(listener: sessionStatusListener)
        
    }
    
    private func startCastPlay() {
        guard let currentItem = player.currentItem else { return }
        let currentTime = player.currentTime().seconds
        let duration = currentItem.asset.duration.seconds
        playbackState = .playCast
        player.pause()
        let castMediaInfo = castManager.buildMediaInformation(contentID: videoURL, title: "Big Buck Bunny (2008)", description: "", studio: "", duration: duration, streamType: GCKMediaStreamType.buffered, thumbnailUrl: imageURL, customData: nil)
        castManager.startSelectedItemRemotely(castMediaInfo, at: currentTime, completion: { done in
            if !done {
                self.playbackState = .pause
                self.startPlayer(nil)
            } else {
                //self.scheduleCastTimer()
                self.enableActionBtns(false)
            }
        })
    }
    
    private func continueCastPlay() {
        playbackState = .playCast
        castManager.playSelectedItemRemotely(to: nil) { (done) in
            if !done {
                self.playbackState = .pause
                self.startPlayer(nil)
            }
        }
    }
    
    private func pauseCastPlay() {
        playbackState = .pauseCast
        castManager.pauseSelectedItemRemotely(at: nil) { (done) in
            if !done {
                self.playbackState = .pause
                self.startPlayer(nil)
            }
        }
    }
    
    @objc private func startPlayer(_ sender: Any?) {
        if playbackState == .pause || playbackState == .created {
            //scheduleLocalTimer()
            player.play()
            playbackState = .play
        } else if playbackState == .createdCast {
            ///scheduleCastTimer()
            startCastPlay()
        } else {
            //scheduleCastTimer()
            player.pause()
            playbackState = .playCast
            continueCastPlay()
        }
        
        //btnPlayPause(self)
    }
    
    // MARK: Pause Player
    
    @objc private func pausePlayer(_ sender: Any?) {
        if playbackState == .play {
            player.pause()
            playbackState = .pause
        } else {
            player.pause()
            playbackState = .pauseCast
            pauseCastPlay()
        }
        
        //btnPlayPause(self)
    }
    
    private func enableActionBtns(_ enabled: Bool) {
        btnStop.isEnabled = enabled
        btnPlayPause.isEnabled = enabled
    }
}

extension PlayerViewController: CastManagerSeekLocalPlayerDelegate {
    func seekLocalPlayer(to time: TimeInterval) {
        if let visibleVC = navigationController?.visibleViewController, visibleVC is PlayerViewController {
            player.seek(to: CMTimeMake(Int64(time*1000), 1000))
            perform(#selector(playVideo), with: nil, afterDelay: 0.5)
        } else {
            btnStop(self)
        }
    }
}
