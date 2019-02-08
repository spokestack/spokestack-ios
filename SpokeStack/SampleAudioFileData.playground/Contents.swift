import UIKit
import AVKit
import PlaygroundSupport

let testFileName: String = "up_dog"

guard let testAudioURL: URL = Bundle.main.url(forResource: testFileName, withExtension: "m4a") else {
    fatalError("File not found")
}

print("testAudio \(testAudioURL) and directory \(playgroundSharedDataDirectory)")

do {
    
    let file: AVAudioFile = try! AVAudioFile(forReading: testAudioURL, commonFormat: .pcmFormatInt16, interleaved: true)
    let buf: AVAudioPCMBuffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,frameCapacity: AVAudioFrameCount(file.length))!

    try file.read(into: buf)
//    try file.read(into: buf, frameCount: 512)
    let floatArray: Array<Int16> = Array(UnsafeBufferPointer(start: buf.int16ChannelData![0], count: Int(buf.frameLength)))

    print("floatArray \(floatArray)")


//    let logName: String = testFileName + "_" + UUID().uuidString + ".txt"
//    let sharedDocumentURL: URL = playgroundSharedDataDirectory
//    let logContents: String = floatArray.compactMap({ String($0) }).joined(separator:",")
//    let newFileUrl: URL = sharedDocumentURL.appendingPathComponent(logName)
//
//    try logContents.write(to: newFileUrl, atomically: true, encoding: .utf8)

} catch let error {

    print("error \(error)")
}

