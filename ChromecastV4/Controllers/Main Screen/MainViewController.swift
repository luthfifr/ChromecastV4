//
//  MainViewController.swift
//  ChromecastV4
//
//  Created by Luthfi Fathur Rahman on 27/01/19.
//  Copyright © 2019 Imperio Teknologi Indonesia. All rights reserved.
//

import UIKit
import GoogleCast
import SDWebImage

class MainViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    private var mediaControlsContainerView: UIView!
    private var miniMediaControlsHeightConstraint: NSLayoutConstraint!
    private var miniMediaControlsViewController: GCKUIMiniMediaControlsViewController!
    
    private var castManager = CastManager.shared
    
    private let imageURL = "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/images/BigBuckBunny.jpg"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        let castButton = GCKUICastButton(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
//        castButton.tintColor = UIColor.black
//        castButton.triggersDefaultCastDialog = true
//        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: castButton)
        
        title = "Main"
        
        createContainer()
        createMiniMediaControl()
        
        setupTableViewCell()
        tableView.tableFooterView = UIView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if mediaControlsContainerView != nil {
            updateControlBarsVisibility()
        }
    }
    
    private func setupTableViewCell() {
        let mainCell = String(describing: MainTableViewCell.self)
        let mainCellNib = UINib(nibName: mainCell, bundle: nil)
        tableView.register(mainCellNib, forCellReuseIdentifier: mainCell)
    }
    
    // MARK: - GCKUIMiniMediaControlsViewController
    
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

extension MainViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: MainTableViewCell.self), for: indexPath) as! MainTableViewCell
        
        if let urlImg = URL(string: imageURL) {
            cell.imgView.sd_setImage(with: urlImg, completed: nil)
        } else {
            cell.imgView.image = UIImage(named: "imagePlaceholder")
        }
        
        cell.lblTitle.text = "Big Buck Bunny (2008)"
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 110.0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let playerVC = PlayerViewController.init(nibName: String(describing: PlayerViewController.self), bundle: nil)
        playerVC.selectedIndexPath = indexPath
        playerVC.imageURL = imageURL
        navigationController?.pushViewController(playerVC, animated: true)
    }
    
}


// MARK: - GCKUIMiniMediaControlsViewControllerDelegate
extension MainViewController: GCKUIMiniMediaControlsViewControllerDelegate {
    func miniMediaControlsViewController(_ miniMediaControlsViewController: GCKUIMiniMediaControlsViewController, shouldAppear: Bool) {
        updateControlBarsVisibility()
    }
}
