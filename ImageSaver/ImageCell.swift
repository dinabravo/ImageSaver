//
//  ImageCell.swift
//  ImageSaver
//
//  Created by Igor Stojakovic on 03/11/2017.
//  Copyright © 2017 stojakovic. All rights reserved.
//

import UIKit

class ImageCell: UITableViewCell {

    @IBOutlet weak var previewImage: UIImageView!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
