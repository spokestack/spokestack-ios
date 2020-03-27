//
//  TTSViewController.swift
//  SpokestackFrameworkExample
//
//  Created by Noel Weichbrodt on 11/20/19.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import UIKit
import Spokestack
import AVFoundation

class TTSViewController: UIViewController {
    
    // MARK: Button declarations
    
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
    
    lazy var speakButton: UIButton = {
        
        let button: UIButton = UIButton(frame: .zero)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Speak", for: .normal)
        button.addTarget(self,
                         action: #selector(TTSViewController.speakAction(_:)),
                         for: .touchUpInside)
        
        button.setTitleColor(.purple, for: .normal)
        
        
        return button
    }()
    
    lazy var testButton: UIButton = {
        
        let button: UIButton = UIButton(frame: .zero)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Test", for: .normal)
        button.addTarget(self,
                         action: #selector(TTSViewController.testAction(_:)),
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
    
    // MARK: Private variables
    
    private var tts: TextToSpeech?
    let configuration = SpeechConfiguration()
    private var streamingFile: URL?
    private var player : AVPlayer = AVPlayer()
    private var playerItem: AVPlayerItem?
    private var amTesting: Bool = false
    
    private var startTime = CACurrentMediaTime()
    let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    // MARK: UIViewController implementation
    
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
        self.view.addSubview(self.speakButton)
        self.view.addSubview(self.testButton)
        
        self.synthesizeButton.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        self.synthesizeButton.leftAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leftAnchor).isActive = true
        self.synthesizeButton.rightAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.rightAnchor).isActive = true
        
        self.playButton.topAnchor.constraint(equalTo: self.synthesizeButton.bottomAnchor, constant: 50.0).isActive = true
        self.playButton.leftAnchor.constraint(equalTo: self.synthesizeButton.leftAnchor).isActive = true
        self.playButton.rightAnchor.constraint(equalTo: self.synthesizeButton.rightAnchor).isActive = true
        
        self.speakButton.topAnchor.constraint(equalTo: self.playButton.bottomAnchor, constant: 50.0).isActive = true
        self.speakButton.leftAnchor.constraint(equalTo: self.playButton.leftAnchor).isActive = true
        self.speakButton.rightAnchor.constraint(equalTo: self.playButton.rightAnchor).isActive = true
        
        self.testButton.topAnchor.constraint(equalTo: self.speakButton.bottomAnchor, constant: 50.0).isActive = true
        self.testButton.leftAnchor.constraint(equalTo: self.speakButton.leftAnchor).isActive = true
        self.testButton.rightAnchor.constraint(equalTo: self.speakButton.rightAnchor).isActive = true
        
        self.view.addSubview(ttsInput)
        
        self.player.automaticallyWaitsToMinimizeStalling = false
        
        self.configuration.tracing = .DEBUG
        
        self.tts = TextToSpeech(self, configuration: configuration)
    }
    
    @objc func dismissViewController(_ sender: Any?) -> Void {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: Button Actions
    
    @objc func synthesizeAction(_ sender: Any) {
        print("synthesize")
        var text = self.ttsInput.text ?? ""
        if (text == "") { text = "You didn't enter any text to synthesize." }
        let input = TextToSpeechInput("<speak>\(text)</speak>")
        input.inputFormat = .ssml
        self.tts?.synthesize(input)
    }
    
    @objc func playAction(_ sender: Any) {
        print("play")
        guard let streamingFile = self.streamingFile else {
            return
        }
        let playerItem = AVPlayerItem(url: streamingFile)
        self.player = AVPlayer(playerItem: playerItem)
        self.player.play()
    }
    
    @objc func speakAction(_ sender: Any) {
        print("speak")
        var text = self.ttsInput.text ?? ""
        if (text == "") { text = "You didn't enter any text to synthesize." }
        let input = TextToSpeechInput(text)
        self.tts?.speak(input)
    }
    
    @objc func testAction(_ sender: Any) {
        Trace.trace(Trace.Level.PERF, config: self.configuration, message: "test: current media time \(CACurrentMediaTime())", delegate: self, caller: self)
        let text = NumberFormatter.localizedString(from: NSNumber(value: CACurrentMediaTime()), number:  NumberFormatter.Style.spellOut) + ". "
        let repeatingText = String(repeating: text, count: 5)
        //        Trace.trace(Trace.Level.DEBUG, configLevel: self.configuration.tracing, message: "test input text \(repeatingText)", delegate: self, caller: self)
        self.ttsInput.text = repeatingText
        self.amTesting = true
        synthesizeAction(self)
        TICK() // synthesize timer
    }
}

// MARK: Test functions

extension TTSViewController {
    
    private func TICK() { startTime = CACurrentMediaTime() }
    private func TOCK(function: String = #function, file: String = #file, line: Int = #line, level: Trace.Level = .PERF){
        if self.configuration.tracing.rawValue <= Trace.Level.PERF.rawValue {
            print("\(function) Time: \(CACurrentMediaTime()-startTime)\nLine:\(line) File: \(file)")
        }
    }
    
    /**
     Initiates a test run with internal timing and status marks for measuring the request/response and playback of a HTTP2 chunked streaming audio file.
     
     Timeline for playback of a streaming audio file:
     - The very first chunk of audio (time to first byte) is received upon the first change in `#keyPath(AVPlayerItem.duration)`
     - The AVPlayerItem becomes available to play at the first change to `#keyPath(AVPlayerItem.status)`
     - The AVPlayerItem buffer is no longer blocking playback at `#keyPath(AVPlayerItem.isPlaybackBufferEmpty)`
     - The AVPlayerItem has completed playing at `#selector(self.playerDidFinishPlaying(sender:))`
     
     Things that don't work if you're trying to force the AVPlayer to start playback on a stream as quickly as possible:
     - `self.playerItem!.preferredForwardBufferDuration = 1 // has no effect on when playback will begin`
     - `#keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp) // guesses wrong about the qos of a streaming chunk service`
     -  `self.player.playImmediately(atRate: 1.0) // same effect as self.player.play(), no matter what other options are set or what state it's called from`
     - `self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate && self.player.reasonForWaitingToPlay == AVPlayer.WaitingReason.toMinimizeStalls // equivalent to #keyPath(AVPlayerItem.isPlaybackBufferFull)`
     - `#keyPath(AVPlayer.reasonForWaitingToPlay) // only applicable once playback has started, not to making the playback start`
     - `#keyPath(AVPlayerItem.loadedTimeRanges) // useful for monitoring the speed/timing of the buffer getting filled, but not actionable`
     - `#keyPath(AVPlayer.status) // does not fire during normal test case`
     */
    func playTest() {
        TICK() // play timer
        self.playerItem = AVPlayerItem(url: self.streamingFile!) //URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")!)
        self.playerItem!.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.duration), options: [.old, .new], context: nil)
        self.playerItem!.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: nil)
        self.playerItem!.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackBufferEmpty), options: [.old, .new], context: nil)
        self.player.replaceCurrentItem(with: self.playerItem!)
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying(sender:)), name: .AVPlayerItemDidPlayToEndTime, object: self.playerItem!)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let current = self.player.currentItem else {
            return
        }
        switch keyPath {
        case #keyPath(AVPlayerItem.duration):
            self.playerItemBeginLoading()
            Trace.trace(Trace.Level.DEBUG, config: self.configuration, message: "test item duration time change \(change!)", delegate: self, caller: self) //\(current.status.rawValue)")
            break
        case #keyPath(AVPlayerItem.status):
            self.playerItemStatusChange()
            Trace.trace(Trace.Level.DEBUG, config: self.configuration, message: "test item status time change \(change!)", delegate: self, caller: self) //\(current.status.rawValue)")
            break
        case #keyPath(AVPlayerItem.isPlaybackBufferEmpty):
            self.playerItemBeginPlaying()
            self.player.play()
            Trace.trace(Trace.Level.DEBUG, config: self.configuration, message: "test item buffer empty time change \(current.isPlaybackBufferEmpty)", delegate: self, caller: self)
            break
        default:
            break
        }
    }
    
    func playerItemBeginLoading() {
        TOCK() // player item time to first byte
    }
    
    func playerItemBeginPlaying() {
        TOCK() // player item was buffered enough to begin playback
    }
    
    func playerItemStatusChange() {
        TOCK() // player item status change
    }
    
    @objc func playerDidFinishPlaying(sender: Notification) {
        TOCK() // play timer
        self.amTesting = false
    }
}

// MARK: TextToSpeechDelegate implementation

extension TTSViewController: TextToSpeechDelegate {
    
    func didBeginSpeaking() {
        print("didBeginSpeaking")
    }
    
    func didFinishSpeaking() {
        print("didFinishSpeaking")
    }
    
    func success(result: TextToSpeechResult) {
        TOCK() // synthesize timer
        guard let url = result.url else {
            return
        }
        self.streamingFile = url
        if (self.amTesting) {
            self.playTest()
            //self.download(url)
        }
    }
    
    func download(_ url: URL) {
        let destinationUrl = documentsUrl.appendingPathComponent(url.lastPathComponent)
        TICK() // download timer
        let urlData = NSData(contentsOf: url)
        urlData!.write(to: destinationUrl, atomically: false)
        TOCK() // download timer
        Trace.trace(Trace.Level.DEBUG, config: self.configuration, message: "test downloaded to \(destinationUrl)", delegate: self, caller: self)
    }
    
    func failure(error: Error) {
        print(error)
    }
    
    func didTrace(_ trace: String) {
        print(trace)
    }
    
    
}
