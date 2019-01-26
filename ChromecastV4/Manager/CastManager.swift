//
//  CastManager.swift
//  ChromecastV4
//
//  Created by Luthfi Fathur Rahman on 27/01/19.
//  Copyright © 2019 Imperio Teknologi Indonesia. All rights reserved.
//

import Foundation
import GoogleCast

enum CastSessionStatus {
    case started
    case resumed
    case ended
    case failedToStart
    case alreadyConnected
}

protocol CastManagerAvailableDeviceDelegate: class {
    func reloadAvailableDeviceData()
}

protocol CastManagerSeekLocalPlayerDelegate: class {
    func seekLocalPlayer(to time: TimeInterval)
}

protocol CastManagerDidUpdateMediaStatusDelegate: class {
    func gckDidUpdateMediaStatus(mediaInfo: GCKMediaInformation?)
}

class CastManager: NSObject {
    
    static let shared = CastManager()
    
    weak var availableDeviceDelegate: CastManagerAvailableDeviceDelegate?
    weak var seekLocalPlayerDelegate: CastManagerSeekLocalPlayerDelegate?
    weak var didUpdateMediaStatusDelegate: CastManagerDidUpdateMediaStatusDelegate?
    
    private let kReceiverAppID = kGCKDefaultMediaReceiverApplicationID
    private let kDebugLoggingEnabled = true
    
    var sessionManager: GCKSessionManager!
    var hasConnectionEstablished: Bool {
        let castSession = sessionManager.currentCastSession
        if castSession != nil {
            return true
        } else {
            return false
        }
    }
    private var sessionStatusListener: ((CastSessionStatus) -> Void)?
    var sessionStatus: CastSessionStatus! {
        didSet {
            sessionStatusListener?(sessionStatus)
        }
    }
    private var gckMediaInformation: GCKMediaInformation?
    
    var discoveryManager: GCKDiscoveryManager!
    private var availableDevices = [GCKDevice]()
    var deviceCategory = String()
    
    // MARK: - Init
    
    func initialise() {
        initialiseContext()
        initialiseDiscovery()
        createSessionManager()
        setupCastLogging()
        style()
        miniControllerStyle()
        styleConnectionController()
    }
    
    private func initialiseContext() {
        let criteria = GCKDiscoveryCriteria(applicationID: kReceiverAppID)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        GCKCastContext.setSharedInstanceWith(options)
        GCKCastContext.sharedInstance().useDefaultExpandedMediaControls = true
    }
    
    private func createSessionManager() {
        sessionManager = GCKCastContext.sharedInstance().sessionManager
        sessionManager.add(self)
    }
    
    private func initialiseDiscovery() {
        discoveryManager = GCKCastContext.sharedInstance().discoveryManager
        discoveryManager.add(self)
        discoveryManager.passiveScan = true
        discoveryManager.startDiscovery()
    }
    
    private func setupCastLogging() {
        let logFilter = GCKLoggerFilter()
        let classesToLog = ["GCKDeviceScanner", "GCKDeviceProvider", "GCKDiscoveryManager", "GCKCastChannel", "GCKMediaControlChannel", "GCKUICastButton", "GCKUIMediaController", "NSMutableDictionary"]
        logFilter.setLoggingLevel(.verbose, forClasses: classesToLog)
        GCKLogger.sharedInstance().filter = logFilter
        GCKLogger.sharedInstance().delegate = self
    }
    
    private func addRemoteMediaListerner() {
        guard let currSession = sessionManager.currentCastSession else {
            return
        }
        currSession.remoteMediaClient?.add(self)
    }
    
    private func removeRemoteMediaListener() {
        guard let currSession = sessionManager.currentCastSession else {
            return
        }
        currSession.remoteMediaClient?.remove(self)
    }
    
    func addSessionStatusListener(listener: @escaping (CastSessionStatus) -> Void) {
        self.sessionStatusListener = listener
    }
    
    //styling connection list view and expanded media control view
    private func style() {
        let castStyle = GCKUIStyle.sharedInstance()
        castStyle.castViews.backgroundColor = .black
        castStyle.castViews.bodyTextColor = .white
        castStyle.castViews.buttonTextColor = .white
        castStyle.castViews.headingTextColor = .white
        castStyle.castViews.captionTextColor = .white
        castStyle.castViews.iconTintColor = .white
        
        castStyle.apply()
    }
    
    private func styleConnectionController() {
        let castStyle = GCKUIStyle.sharedInstance()
        //castStyle.castViews.deviceControl.connectionController.buttonTextColor = .nodesColor
        castStyle.apply()
    }
    
    //Styling mini controller
    private func miniControllerStyle() {
        let castStyle = GCKUIStyle.sharedInstance()
        castStyle.castViews.mediaControl.miniController.backgroundColor = .darkGray
        castStyle.castViews.mediaControl.miniController.bodyTextColor = .white
        castStyle.castViews.mediaControl.miniController.buttonTextColor = .white
        castStyle.castViews.mediaControl.miniController.headingTextColor = .white
        castStyle.castViews.mediaControl.miniController.captionTextColor = .white
        castStyle.castViews.mediaControl.miniController.iconTintColor = .white
        
        castStyle.apply()
    }
    
    func getAvailableDevices() -> [GCKDevice] {
        return availableDevices
    }
    
    func getMediaInfo() -> GCKMediaInformation? {
        return gckMediaInformation
    }
    
    func setMediaInfo(with mediaInfo: GCKMediaInformation?) {
        self.gckMediaInformation = mediaInfo
    }
    
    // MARK: - Build Meta
    
    func buildMediaInformation(contentID: String, title: String, description: String, studio: String, duration: TimeInterval, movieUrl: String, streamType: GCKMediaStreamType, thumbnailUrl: String?, customData: Any?) -> GCKMediaInformation {
        let metadata = buildMetadata(title: title, description: description, studio: studio, thumbnailUrl: thumbnailUrl)
        
        let mediaInfoBuilder = GCKMediaInformationBuilder()
        mediaInfoBuilder.contentID = contentID
        mediaInfoBuilder.streamType = streamType
        mediaInfoBuilder.contentType = ""
        mediaInfoBuilder.metadata = metadata
        mediaInfoBuilder.adBreaks = nil
        mediaInfoBuilder.adBreakClips = nil
        mediaInfoBuilder.streamDuration = duration
        mediaInfoBuilder.mediaTracks = nil
        mediaInfoBuilder.textTrackStyle = nil
        mediaInfoBuilder.customData = nil
        let mediaInfo = mediaInfoBuilder.build()
        
        return mediaInfo
    }
    
    private func buildMetadata(title: String, description: String, studio: String, thumbnailUrl: String?) -> GCKMediaMetadata {
        let metadata = GCKMediaMetadata.init(metadataType: .movie)
        metadata.setString(title, forKey: kGCKMetadataKeyTitle)
        metadata.setString(description, forKey: "description")
        let deviceName = sessionManager.currentCastSession?.device.friendlyName ?? studio
        metadata.setString(deviceName, forKey: kGCKMetadataKeyStudio)
        
        if let thumbnailUrl = thumbnailUrl, let url = URL(string: thumbnailUrl) {
            metadata.addImage(GCKImage.init(url: url, width: 480, height: 360))
        }
        
        return metadata
    }
    
    // MARK: - Start
    
    func startSelectedItemRemotely(_ mediaInfo: GCKMediaInformation, at time: TimeInterval, completion: (Bool) -> Void) {
        let castSession = sessionManager.currentCastSession
        
        if castSession != nil {
            let options = GCKMediaLoadOptions()
            options.playPosition = time
            castSession?.remoteMediaClient?.loadMedia(mediaInfo, with: options)
            completion(true)
            
            sessionStatus = .alreadyConnected
        } else {
            completion(false)
        }
    }
    
    // MARK: - Play/Resume
    
    func playSelectedItemRemotely(to time: TimeInterval?, completion: (Bool) -> Void) {
        let castSession = sessionManager.currentCastSession
        if castSession != nil {
            let remoteClient = castSession?.remoteMediaClient
            if let time = time {
                let options = GCKMediaSeekOptions()
                options.interval = time
                options.resumeState = .play
                remoteClient?.seek(with: options)
            } else {
                remoteClient?.play()
            }
            completion(true)
        } else {
            completion(false)
        }
    }
    
    // MARK: - Pause
    
    func pauseSelectedItemRemotely(at time: TimeInterval?, completion: (Bool) -> Void) {
        let castSession = sessionManager.currentCastSession
        if castSession != nil {
            let remoteClient = castSession?.remoteMediaClient
            if let time = time {
                let options = GCKMediaSeekOptions()
                options.interval = time
                options.resumeState = .pause
                remoteClient?.seek(with: options)
            } else {
                remoteClient?.pause()
            }
            completion(true)
        } else {
            completion(false)
        }
    }
    
    // MARK: - Update Current Time
    
    func getCurrentPlaybackTime(completion: (TimeInterval?) -> Void) {
        let castSession = sessionManager.currentCastSession
        if castSession != nil {
            let remoteClient = castSession?.remoteMediaClient
            let currentTime = remoteClient?.approximateStreamPosition()
            completion(currentTime)
        } else {
            completion(nil)
        }
    }
    
    // MARK: - Buffering status
    
    func getMediaPlayerState(completion: (GCKMediaPlayerState) -> Void) {
        if let castSession = sessionManager.currentCastSession,
            let remoteClient = castSession.remoteMediaClient,
            let mediaStatus = remoteClient.mediaStatus {
            completion(mediaStatus.playerState)
        }
        
        completion(GCKMediaPlayerState.unknown)
    }
}

// MARK: - GCKDiscoveryManagerListener
extension CastManager: GCKDiscoveryManagerListener {
    func didStartDiscovery(forDeviceCategory deviceCategory: String) {
        self.deviceCategory = deviceCategory
    }
    
    func didUpdateDeviceList() {
        print("\(discoveryManager.deviceCount) device(s) has been discovered")
    }
    
    func didInsert(_ device: GCKDevice, at index: UInt) {
        availableDevices.append(device)
        availableDeviceDelegate?.reloadAvailableDeviceData()
    }
    
    func didRemoveDevice(at index: UInt) {
        availableDevices.remove(at: Int(index))
        availableDeviceDelegate?.reloadAvailableDeviceData()
    }
}

// MARK: - Device Operation
extension CastManager {
    func connectToDevice(device: GCKDevice) {
        if discoveryManager.deviceCount == 0 && sessionManager.hasConnectedCastSession(){
            return
        }
        
        sessionManager.startSession(with: device)
    }
    
    func disconnectFromCurrentDevice() {
        if sessionManager.hasConnectedCastSession() {
            removeRemoteMediaListener()
            sessionManager.endSession()
        }
    }
}

// MARK: - GCKSessionManagerListener
extension CastManager: GCKSessionManagerListener {
    public func sessionManager(_ sessionManager: GCKSessionManager, didStart session: GCKSession) {
        print("sessionManager started")
        sessionStatus = .started
        addRemoteMediaListerner()
    }
    
    public func sessionManager(_ sessionManager: GCKSessionManager, didResumeSession session: GCKSession) {
        print("sessionManager resumed")
        sessionStatus = .resumed
    }
    
    public func sessionManager(_ sessionManager: GCKSessionManager, didEnd session: GCKSession, withError error: Error?) {
        print("sessionManager ended")
        sessionStatus = .ended
    }
    
    public func sessionManager(_ sessionManager: GCKSessionManager, didFailToStart session: GCKSession, withError error: Error) {
        print("sessionManager failed to start")
        sessionStatus = .failedToStart
    }
    
    public func sessionManager(_ sessionManager: GCKSessionManager, didSuspend session: GCKSession, with reason: GCKConnectionSuspendReason) {
        print("sessionManager suspended")
        sessionStatus = .ended
    }
}

extension CastManager: GCKRemoteMediaClientListener {
    func remoteMediaClient(_ client: GCKRemoteMediaClient, didUpdate mediaStatus: GCKMediaStatus?) {
        didUpdateMediaStatusDelegate?.gckDidUpdateMediaStatus(mediaInfo: mediaStatus?.mediaInformation)
        setMediaInfo(with: mediaStatus?.mediaInformation)
    }
}

extension CastManager: GCKLoggerDelegate {
    func logMessage(_ message: String, at level: GCKLoggerLevel, fromFunction function: String, location: String) {
        if (kDebugLoggingEnabled) {
            print(function + " - " + message)
        }
    }
}
