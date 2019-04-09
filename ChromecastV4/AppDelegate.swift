//
//  AppDelegate.swift
//  ChromecastV4
//
//  Created by Luthfi Fathur Rahman on 26/01/19.
//  Copyright © 2019 Imperio Teknologi Indonesia. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    let castManager = CastManager.shared

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window?.clipsToBounds = true
        
        castManager.initialise()
        
        let firstVC = MainViewController.init(nibName: String(describing: MainViewController.self), bundle: nil)
        let navVC = UINavigationController.init(rootViewController: firstVC)
        navVC.navigationBar.layer.shadowOpacity = 0.3
        navVC.navigationBar.layer.shadowOffset = CGSize(width: 0, height: 1)
        navVC.navigationBar.layer.shadowRadius = 5
        navVC.navigationBar.layer.masksToBounds = false
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = .clear
        window?.rootViewController = navVC
        window?.makeKeyAndVisible()
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        if castManager.sessionManager != nil {
            castManager.sessionManager.suspendSession(with: .appBackgrounded)
        }
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        //stop cast device discovery activity
        if castManager.discoveryManager != nil {
            if castManager.discoveryManager.isDiscoveryActive(forDeviceCategory: castManager.deviceCategory) {
                castManager.discoveryManager.stopDiscovery()
            }
        }
        
        if castManager.sessionManager != nil {
            if castManager.sessionManager.hasConnectedCastSession() {
                castManager.sessionManager.suspendSession(with: .appTerminated)
                castManager.sessionManager.endSessionAndStopCasting(true)
            }
        }
    }


}

