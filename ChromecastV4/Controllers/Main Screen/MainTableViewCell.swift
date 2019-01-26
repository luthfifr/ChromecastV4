//
//  MainTableViewCell.swift
//  ChromecastV4
//
//  Created by Luthfi Fathur Rahman on 27/01/19.
//  Copyright © 2019 Imperio Teknologi Indonesia. All rights reserved.
//

import UIKit

class MainTableViewCell: UITableViewCell {
    
    @IBOutlet weak var imgView: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        imgView.image = UIImage(named: "imagePlaceholder")
        imgView.tintColor = .white
        imgView.contentMode = .scaleToFill
    }
    
}
