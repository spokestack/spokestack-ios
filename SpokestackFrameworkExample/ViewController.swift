//
//  ViewController.swift
//  SpokestackFrameworkExample
//
//  Created by Cory D. Wiles on 10/8/18.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import UIKit
import Spokestack

class ViewController: UIViewController {

    // MARK: Outlets
    
    @IBOutlet weak var appleASRButton: UIButton!
    
    @IBOutlet weak var appleWakewordButton: UIButton!

    @IBOutlet weak var tensorFlowWakewordButton: UIButton!

    // MARK: View Life Cycle
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        self.appleWakewordButton.isEnabled = true
    }

    @IBAction func appleASRAction(_ sender: Any) {
    
        let appleViewController: AppleASRViewController = AppleASRViewController()
        let navigationViewController: UINavigationController = UINavigationController(rootViewController: appleViewController)
        
        self.present(navigationViewController, animated: true, completion: nil)
    }
    
    @IBAction func appleWakewordAction(_ sender: Any) {
        
        let controller: AppleWakewordViewController = AppleWakewordViewController()
        let navigationViewController: UINavigationController = UINavigationController(rootViewController: controller)
        
        self.present(navigationViewController, animated: true, completion: nil)
    }
    
    @IBAction func tensorFlowWakewordAction(_ sender: Any) {
        
        let controller: TFLiteViewController = TFLiteViewController()
        let navigationViewController: UINavigationController = UINavigationController(rootViewController: controller)
        
        self.present(navigationViewController, animated: true, completion: nil)
    }
    
    @IBAction func ttsAction(_ sender: UIButton) {
        let controller: TTSViewController = TTSViewController()
        let navigationViewController: UINavigationController = UINavigationController(rootViewController: controller)
        
        self.present(navigationViewController, animated: true, completion: nil)
    }

    @IBAction func nluAction(_ sender: Any) {
        let controller: NLUViewController = NLUViewController()
        let navigationViewController: UINavigationController = UINavigationController(rootViewController: controller)
        
        self.present(navigationViewController, animated: true, completion: nil)
    }
    
    @objc func dismissViewController(_ sender: Any?) -> Void {
        self.dismiss(animated: true, completion: nil)
    }
}

