//
//  ViewController.swift
//  SpokeStackFrameworkExample
//
//  Created by Cory D. Wiles on 10/8/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import UIKit
import SpokeStack

class ViewController: UIViewController {

    // MARK: Outlets
    
    @IBOutlet weak var googleButton: UIButton!
    
    @IBOutlet weak var appleButton: UIButton!
    
    @IBOutlet weak var wakeWordButton: UIButton!
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        self.wakeWordButton.isEnabled = false
    }
    
    @IBAction func googleAction(_ sender: Any) {
    
        let googleViewController: GoogleViewController = GoogleViewController()
        let navigationViewController: UINavigationController = UINavigationController(rootViewController: googleViewController)
        
        self.present(navigationViewController, animated: true, completion: nil)
    }

    @IBAction func appleAxction(_ sender: Any) {
    
        let appleViewController: AppleViewController = AppleViewController()
        let navigationViewController: UINavigationController = UINavigationController(rootViewController: appleViewController)
        
        self.present(navigationViewController, animated: true, completion: nil)
    }
    
    @IBAction func wakeWordAction(_ sender: Any) {
        
        let wakeWordViewController: WakeWordViewController = WakeWordViewController()
        let navigationViewController: UINavigationController = UINavigationController(rootViewController: wakeWordViewController)
        
        self.present(navigationViewController, animated: true, completion: nil)
    }
    
    @objc func dismissViewController(_ sender: Any?) -> Void {
        self.dismiss(animated: true, completion: nil)
    }
}
