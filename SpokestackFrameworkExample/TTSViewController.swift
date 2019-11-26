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
    private var playerItem: AVPlayerItem?
    
    var startTime = CACurrentMediaTime()
    let documentsUrl =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    func TICK() { startTime = CACurrentMediaTime() }
    func TOCK(function: String = #function, file: String = #file, line: Int = #line){
        print("\(function) Time: \(CACurrentMediaTime()-startTime)\nLine:\(line) File: \(file)")
    }
    
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
        config.tracing = .INFO
        
        self.tts = TextToSpeech(self, configuration: config)
        print("current media time \(CACurrentMediaTime())")
    }

    @objc func synthesizeAction(_ sender: Any) {
        print("synthesize")
        let text = NumberFormatter.localizedString(from: NSNumber(value: CACurrentMediaTime()), number:  NumberFormatter.Style.spellOut) + ". "
        let repeatingText = String(repeating: text, count: 5)
        print("text \(repeatingText)")
        let input = TextToSpeechInput(repeatingText)
        TICK() // synthesize timer
        self.tts?.synthesize(input)
    }
    
    @objc func playAction(_ sender: Any) {
        print("play")
        TICK() // play timer
        DispatchQueue.main.async {
            self.playerItem = AVPlayerItem(url: self.streamingFile!) //URL(string: "http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8")!)
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: self.player?.currentItem)
            self.playerItem!.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.duration), options: [.old, .new], context: nil)
            self.playerItem!.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: nil)
            self.playerItem!.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackBufferFull), options: [.old, .new], context: nil)
            self.playerItem!.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackBufferEmpty), options: [.old, .new], context: nil)
            self.playerItem!.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp), options: [.old, .new], context: nil)
            self.playerItem!.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.loadedTimeRanges), options: [.old, .new], context: nil)
            self.playerItem!.preferredForwardBufferDuration = 0.5
            self.player = AVPlayer(playerItem: self.playerItem!)
            self.player!.addObserver(self, forKeyPath: #keyPath(AVPlayer.timeControlStatus), options: [.old, .new], context: nil)
            self.player!.addObserver(self, forKeyPath: #keyPath(AVPlayer.reasonForWaitingToPlay), options: [.old, .new], context: nil)
            self.player!.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.old, .new], context: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying(sender:)), name: .AVPlayerItemDidPlayToEndTime, object: self.playerItem!)
            //self.player!.automaticallyWaitsToMinimizeStalling = false // setting this seems to stall the player at AVPlayerItem.status.ReadyToPlay no matter the order.
            self.player!.playImmediately(atRate: 1.0)
        }
        //self.player = AVPlayer(url: self.streamingFile!)
        //self.player?.play()
    }
    
    @objc func dismissViewController(_ sender: Any?) -> Void {
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func playerDidFinishPlaying(sender: Notification) {
        TOCK() // play timer
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let player = self.player else {
            return
        }
        guard let current = player.currentItem else {
            return
        }
        switch keyPath {
        case #keyPath(AVPlayerItem.duration):
            self.playerItemBeginLoading()
            // print("item duration time change \(change!)") // does not apply to HLS streams?
            break
        case #keyPath(AVPlayerItem.status):
            self.playerItemBeginPlaying()
            print("item status time change \(change!)")//\(current.status.rawValue)")
        case  #keyPath(AVPlayerItem.isPlaybackBufferFull):
            print("item buffer full time change \(change!)")//\(current.isPlaybackBufferFull)")
            break
        case #keyPath(AVPlayerItem.isPlaybackBufferEmpty):
            print("item buffer empty time change \(change!)")//\(current.isPlaybackBufferEmpty)")
            break
        case #keyPath(AVPlayerItem.isPlaybackLikelyToKeepUp):
            print("item buffer sufficient time change \(change!)")//\(current.isPlaybackLikelyToKeepUp)")
            break
        case #keyPath(AVPlayerItem.loadedTimeRanges):
            print("item loaded time range change \(change!)")
            break
        case #keyPath(AVPlayer.timeControlStatus):
            print("player time control status \(change!)")
            break
        case #keyPath(AVPlayer.reasonForWaitingToPlay):
            print("player time reason for waiting to play \(change!)")
            break
        case #keyPath(AVPlayer.status):
            print("player time status \(change!)")
            break
        default:
            break
        }
    }
    
    func playerItemBeginLoading() {
        TOCK() // player item time to first byte
        print("buffer sufficient time? \(String(describing: self.player?.currentItem?.isPlaybackLikelyToKeepUp))")
        //self.player?.automaticallyWaitsToMinimizeStalling = false
        //self.player?.playImmediately(atRate: 1.0)
    }
    
    func playerItemBeginPlaying() {
        TOCK() // player item was buffered enough to begin playback
    }
}

extension TTSViewController: TextToSpeechDelegate {
    func success(url: URL) {
        TOCK() // synthesize timer
        print(url)
        self.streamingFile = url
                
        playAction(self)
        
        //download(url)
    }
    
    func download(_ url: URL) {
        let destinationUrl = documentsUrl.appendingPathComponent(url.lastPathComponent)
        TICK() // download timer
        let urlData = NSData(contentsOf: url)
        urlData!.write(to: destinationUrl, atomically: false)
        TOCK() // download timer
        print("downloaded to \(destinationUrl)")
    }
    
    func failure(error: Error) {
        print(error)
    }
    
    func didTrace(_ trace: String) {
        print(trace)
    }
    
    
}
