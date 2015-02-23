//
//  StationViewController
//  
//
//  Created by Christian Stocker on 13.09.14.
//  Copyright (c) 2014 Christian Stocker. All rights reserved.
//

import UIKit

class StationViewController: UIViewController, UITableViewDelegate {
    
    @IBOutlet weak var titleLabel: UINavigationItem!
    
    
    var station: Station?
    
    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        titleLabel.title = self.station?.name
        
    }
}
