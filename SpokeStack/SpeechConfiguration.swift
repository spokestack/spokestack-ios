//
//  SpeechConfiguration.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 12/4/18.
//  Copyright © 2018 Pylon AI, Inc. All rights reserved.
//

import Foundation

/// Configuration properties for the pipeline abstraction to pass down to implementations.
@objc public class SpeechConfiguration: NSObject {
    /// A comma-separated list of wakeword keywords, in the order they appear in the classifier outputs, not including the null (non-keyword) class.
    /// - Remark: ex: "up,dog"
    /// - Warning: cannot contain spaces
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `AppleWakewordRecognizer`
    @objc public var wakewords: String = "marvin"
    /// A comma-separated list of space-separated wakeword keyword phrases to detect, which defaults to no phrases (just individual keywords).
    /// - Remark: ex: "up dog,dog dog"
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `AppleWakewordRecognizer`
    @objc public var wakePhrases: String = "marvin"
    /// The length of the wakeword phraser's sliding window, in milliseconds - this value should be long enough to fit the longest supported phrase.
    /// - SeeAlso: `CoreMLWakewordRecognizer`
    public var wakePhraseLength: Int = 2000
    /// The length of the posterior smoothing window to use with the wakeword classifier's outputs, in milliseconds.
    /// - SeeAlso: `CoreMLWakewordRecognizer`
    public var wakeSmoothLength: Int = 50
    /// The name of the windowing function to apply to each audio frame before calculating the STFT.
    /// - Remark: Currently the "hann" window is supported.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    public var fftWindowType: SignalProcessing.FFTWindowType = .hann
    /// The desired linear Root Mean Squared (RMS) signal energy, which is used for signal normalization and should be tuned to the RMS target used during wakeword model training.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var rmsTarget: Float = 0.08
    /// The Exponentially-Weighted Moving Average (EWMA) update rate for the current RMS signal energy (0 for no RMS normalization).
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var rmsAlpha: Float = 0.1
    /// The size of the signal window used to calculate the STFT, in number of samples - should be a power of 2 for maximum efficiency.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var fftWindowSize: Int = 512
    /// The length of time to skip each time the overlapping STFT is calculated, in milliseconds.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var fftHopLength: Int = 10
    /// The length of the mel spectrogram used as an input to the wakeword recognizer encoder, in milliseconds.
    /// - Remark: for CoreML: 400, for TFLite: 10
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var melFrameLength: Int = 10
    /// The size of each mel spectrogram frame in the wakeword recognizer, in number of filterbank components.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var melFrameWidth: Int = 40
    /// The size of the encoder state in the wakeword recognizer, in vector units (defaults to encodeWidth).
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var stateWidth: Int = 128
    /// The length of the sliding window of encoder output used as an input to the wakeword recognizer classifier, in milliseconds.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var encodeLength: Int = 1000
    /// The size of the wakeword recognizer encoder output, in vector units.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var encodeWidth: Int = 128
    ///The threshold of the wakeword recognizer classifier's posterior output, above which the wakeword recognizer activates the pipeline, in the range [0, 1].
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var wakeThreshold: Float = 0.9
    /// The minimum length of an activation, in milliseconds, used to ignore a VAD deactivation after the wakeword.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var wakeActiveMin: Int = 600
    /// The maximum length of an activation, in milliseconds, used to time out the activation.
    /// - SeeAlso: `AppleWakewordRecognizer`, `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var wakeActiveMax: Int = 5000
    /// Indicate to the Voice Activity Detector the level of permissiveness to non-speech activation.
    /// - SeeAlso: `AppleWakewordRecognizer`, `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    public var vadMode: VADMode = VADMode.HighlyPermissive
    /// Delay between a VAD deactivation and the delivery of the recognition results.
    /// - SeeAlso: `AppleWakewordRecognizer`
    /// - Remark: unique to iOS
    @objc public var vadFallDelay: Int = 600
    /// Audio sampling rate, in Hz.
    public var sampleRate = 16000
    /// Audio frame width, in ms.
    /// - ToDo: Should be renamed wakeFrameWidth.
    @objc public var frameWidth: Int = 20
    /// Length of time in ms to allow an Apple ASR request to run.
    /// - SeeAlso: `AppleWakewordRecognizer`
    /// - Remark: Apple has an undocumented limit of 60000ms per request.
    ///           Unique to iOS.
    @objc public var wakewordRequestTimeout: Int = 50000
    /// The pre-emphasis filter weight to apply to the normalized audio signal (0 for no pre-emphasis).
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var preEmphasis: Float = 0.97
    /// The machine learning model file name for the filtering step.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var filterModelName: String = "Filter"
    /// The machine learning model file name for the encoding step.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var encodeModelName: String = "Encode"
    /// The machine learning model file name for the detect step.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var detectModelName: String = "Detect"
    /// The file system path to the machine learning model for the filtering step.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var filterModelPath: String = "Filter.model"
    /// The file system path to the machine learning model for the encoding step.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var encodeModelPath: String = "Encode.model"
    /// The file system path to the machine learning model for the detect step.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var detectModelPath: String = "Detect.model"
    /// Debugging trace levels, for simple filtering.
    @objc public var tracing: Trace.Level = Trace.Level.NONE
}
