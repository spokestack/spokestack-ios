//
//  ViewController.swift
//  SpokeStackFrameworkExample
//
//  Created by Cory D. Wiles on 10/8/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import UIKit

struct GoogleConfiguration: GoogleRecognizerConfiguration {
    
    public var host: String {
        return "speech.google.com"
    }
    
    public var apiKey: String {
        return "AIzaSyAX01kY6iygg04-dexAr-cR9ZdYSMemWL0"
    }
    
    public var enableWordTimeOffsets: Bool {
        return true
    }
    
    public var maxAlternatives: Int32 {
        return 30
    }
    
    public var singleUtterance: Bool {
        return false
    }
    
    public var interimResults: Bool {
        return true
    }
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }


}

