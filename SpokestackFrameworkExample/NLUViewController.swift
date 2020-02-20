//
//  NLUViewController.swift
//  SpokestackFrameworkExample
//
//  Created by Noel Weichbrodt on 1/28/20.
//  Copyright © 2020 Pylon AI, Inc. All rights reserved.
//

import Foundation
import UIKit
import Spokestack
import AVFoundation

class NLUViewController: UIViewController {
    // MARK: Button declarations
    
    lazy var predictButton: UIButton = {
        let button: UIButton = UIButton(frame: .zero)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Predict", for: .normal)
        button.addTarget(self,
                         action: #selector(NLUViewController.predictAction),
                         for: .touchUpInside)
        button.setTitleColor(.purple, for: .normal)
        return button
    }()

    lazy var nluInput: UITextField = {
        let textField = UITextField(frame: CGRect(x: 20, y: 100, width: 300, height: 40))
        textField.placeholder = "Enter text to classify."
        textField.font = UIFont.systemFont(ofSize: 15)
        textField.borderStyle = UITextField.BorderStyle.roundedRect
        textField.autocorrectionType = UITextAutocorrectionType.no
        textField.keyboardType = UIKeyboardType.default
        textField.returnKeyType = UIReturnKeyType.done
        textField.clearButtonMode = UITextField.ViewMode.whileEditing
        textField.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        return textField
    }()
    
    // MARK: Private variables
    
    private var nlu: TensorflowNLU?
    let configuration = SpeechConfiguration()
    
    // MARK: UIViewController implementation
    
    override func loadView() {
        super.loadView()
        self.view.backgroundColor = .white
        self.title = "NLU"
        let doneBarButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                                 target: self,
                                                                 action: #selector(NLUViewController.dismissViewController(_:)))
        self.navigationItem.rightBarButtonItem = doneBarButtonItem
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addSubview(self.predictButton)
        self.view.addSubview(nluInput)

        self.predictButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        self.predictButton.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor).isActive = true
        self.predictButton.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor).isActive = true

        self.configuration.tracing = .DEBUG
        
        guard let modelPath = Bundle(for: type(of: self)).path(forResource: "nlu", ofType: "tflite") else {
            print("could not find nlu.tflite in bundle \(self.debugDescription)")
            return
        }
        self.configuration.nluModelPath = modelPath

        guard let vocabPath = Bundle(for: type(of: self)).path(forResource: "vocab", ofType: "txt") else {
            print("could not find vocab.txt in bundle \(self.debugDescription)")
            return
        }
        self.configuration.nluVocabularyPath = vocabPath
        
        guard let metadataPath = Bundle(for: type(of: self)).path(forResource: "nlu", ofType: "json") else {
            print("could not find nlu.json in bundle \(self.debugDescription)")
            return
        }
        self.configuration.nluModelMetadataPath = metadataPath

        self.nlu = try! TensorflowNLU(self, configuration: configuration)
    }
    
    @objc func dismissViewController(_ sender: Any?) -> Void {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Button Actions

    @objc func predictAction(_ sender: Any) {
        var text = self.nluInput.text ?? ""
        if (text == "") { text = "turn the lights on in the kitchen" }
        // I give this app a ten
        // Call 1234567890
        self.nlu?.classify(utterance: text, context: [:])
    }
}

// MARK: NLUDelegate implementation

extension NLUViewController: NLUDelegate {
    func classification(result: NLUResult) {
        print("Classification: \(result.intent) \(result.confidence) \(result.slots)")
    }
    
    func didTrace(_ trace: String) {
        print("Trace: \(trace)")
    }
    
    func failure(error: Error) {
        print("Failure: \(error)")
    }
    
}
