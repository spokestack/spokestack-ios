//
//  WakewordRecognizer.swift
//  SpokeStack
//
//  Created by Noel Weichbrodt on 2/5/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import Foundation

public protocol WakewordRecognizer: AnyObject {
    
    func activate() -> Void
        
    func deactivate() -> Void
    
    func didError(_ error: Error) -> Void
}
