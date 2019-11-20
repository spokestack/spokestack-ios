//
//  TTSViewController.swift
//  SpokestackFrameworkExample
//
//  Created by Noel Weichbrodt on 11/20/19.
//  Copyright © 2019 Pylon AI, Inc. All rights reserved.
//

import UIKit
import Spokestack
import AVFoundation

class TTSViewController: UIViewController {
    
    lazy var synthesizeButton: UIButton = {
        
        let button: UIButton = UIButton(frame: .zero)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Synthesize", for: .normal)
        button.addTarget(self,
                         action: #selector(TTSViewController.synthesizeAction),
                         for: .touchUpInside)
        button.setTitleColor(.purple, for: .normal)
        
        return button
    }()
    
    lazy var playButton: UIButton = {
        
        let button: UIButton = UIButton(frame: .zero)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Play", for: .normal)
        button.addTarget(self,
                         action: #selector(TTSViewController.playAction(_:)),
                         for: .touchUpInside)
        
        button.setTitleColor(.purple, for: .normal)
        
        
        return button
    }()
    
    lazy var ttsInput: UITextField = {
        let textField = UITextField(frame: CGRect(x: 20, y: 100, width: 300, height: 40))
        textField.placeholder = "Enter text to synthesize."
        textField.font = UIFont.systemFont(ofSize: 15)
        textField.borderStyle = UITextField.BorderStyle.roundedRect
        textField.autocorrectionType = UITextAutocorrectionType.no
        textField.keyboardType = UIKeyboardType.default
        textField.returnKeyType = UIReturnKeyType.done
        textField.clearButtonMode = UITextField.ViewMode.whileEditing
        textField.contentVerticalAlignment = UIControl.ContentVerticalAlignment.center
        return textField
    }()
    
    private var tts: TextToSpeech?
    private var streamingFile: URL?
    private var player : AVPlayer?
    
    override func loadView() {
        
        super.loadView()
        self.view.backgroundColor = .white
        self.title = "Text to Speech"
        
        let doneBarButtonItem: UIBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done,
                                                                 target: self,
                                                                 action: #selector(TTSViewController.dismissViewController(_:)))
        self.navigationItem.rightBarButtonItem = doneBarButtonItem
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(self.synthesizeButton)
        self.view.addSubview(self.playButton)
        
        self.synthesizeButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        self.synthesizeButton.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor).isActive = true
        self.synthesizeButton.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor).isActive = true
        
        self.playButton.topAnchor.constraint(equalTo: self.synthesizeButton.bottomAnchor, constant: 50.0).isActive = true
        self.playButton.leftAnchor.constraint(equalTo: self.synthesizeButton.leftAnchor).isActive = true
        self.playButton.rightAnchor.constraint(equalTo: self.synthesizeButton.rightAnchor).isActive = true
        
        self.view.addSubview(ttsInput)
        
        let config = SpeechConfiguration()
        config.tracing = .DEBUG
        
        self.tts = TextToSpeech(self, configuration: config)
    }
    
    @objc func synthesizeAction(_ sender: Any) {
        print("synthesize")
        var text = self.ttsInput.text ?? ""
        if (text == "") { text = "You didn't enter any text to synthesize." }
        let input = TextToSpeechInput(text)
        self.tts?.synthesize(input)
    }
    
    @objc func playAction(_ sender: Any) {
        print("play")
        let playerItem = AVPlayerItem(url: self.streamingFile!)
        self.player = AVPlayer(playerItem: playerItem)
        self.player?.play()
    }
    
    @objc func dismissViewController(_ sender: Any?) -> Void {
        self.dismiss(animated: true, completion: nil)
    }
}

extension TTSViewController: TextToSpeechDelegate {
    func success(url: URL) {
        print(url)
        self.streamingFile = url
    }
    
    func failure(error: Error) {
        print(error)
    }
    
    func didTrace(_ trace: String) {
        print(trace)
    }
    
    
}
