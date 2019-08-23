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
    
    @IBOutlet weak var appleButton: UIButton!
    
    @IBOutlet weak var wakeWordButton: UIButton!

    @IBOutlet weak var coreMLWakewordButton: UIButton!
    
    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        self.wakeWordButton.isEnabled = true
    }

    @IBAction func appleAction(_ sender: Any) {
    
        let appleViewController: AppleViewController = AppleViewController()
        let navigationViewController: UINavigationController = UINavigationController(rootViewController: appleViewController)
        
        self.present(navigationViewController, animated: true, completion: nil)
    }
    
    @IBAction func wakeWordAction(_ sender: Any) {
        
        let controller: WakeWordViewController = WakeWordViewController()
        let navigationViewController: UINavigationController = UINavigationController(rootViewController: controller)
        
        self.present(navigationViewController, animated: true, completion: nil)
    }

    @IBAction func coreMLWakewordAction(_ sender: Any) {
        
        let controller: CoreMLViewController = CoreMLViewController()
        let navigationViewController: UINavigationController = UINavigationController(rootViewController: controller)
        
        self.present(navigationViewController, animated: true, completion: nil)
    }
    
    @IBAction func tensorFlowWakewordAction(_ sender: Any) {
        
        let controller: TFLiteViewController = TFLiteViewController()
        let navigationViewController: UINavigationController = UINavigationController(rootViewController: controller)
        
        self.present(navigationViewController, animated: true, completion: nil)
    }
    
    @objc func dismissViewController(_ sender: Any?) -> Void {
        self.dismiss(animated: true, completion: nil)
    }
}

