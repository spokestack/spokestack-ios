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
    @objc public var wakewords: String = "spokestack, spoke stack"
    /// A comma-separated list of space-separated wakeword keyword phrases to detect, which defaults to no phrases (just individual keywords).
    /// - Remark: ex: "up dog,dog dog"
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `AppleWakewordRecognizer`
    @objc public var wakePhrases: String = "spokestack"
    @available(*, deprecated, message: "Training is no longer supported for convolutional wakeword models, use TFLiteWakewordRecognizer instead.")
    /// The length of the wakeword phraser's sliding window, in milliseconds - this value should be long enough to fit the longest supported phrase.
    /// - SeeAlso: `CoreMLWakewordRecognizer`
    public var wakePhraseLength: Int = 2000
    @available(*, deprecated, message: "Training is no longer supported for convolutional wakeword models, use TFLiteWakewordRecognizer instead.")
    /// The length of the posterior smoothing window to use with the wakeword classifier's outputs, in milliseconds.
    /// - SeeAlso: `CoreMLWakewordRecognizer`
    public var wakeSmoothLength: Int = 50
    /// The name of the window function to apply to each audio frame before calculating the STFT.
    /// - Remark: Currently the "hann" window is supported.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    public var fftWindowType: SignalProcessing.FFTWindowType = .hann
    /// The desired linear Root Mean Squared (RMS) signal energy, which is used for signal normalization and should be tuned to the RMS target used during wakeword model training.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var rmsTarget: Float = 0.08
    /// The Exponentially Weighted Moving Average (EWMA) update rate for the current  Root Mean Squared (RMS) signal energy (0 for no RMS normalization).
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var rmsAlpha: Float = 0.1
    /// The size of the signal window used to calculate the STFT, in number of samples - should be a power of 2 for maximum efficiency.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var fftWindowSize: Int = 512
    /// The length of time to skip each time the overlapping STFT is calculated, in milliseconds.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var fftHopLength: Int = 10
    /// The length of a frame in the mel spectrogram used as an input to the wakeword recognizer encoder, in milliseconds.
    /// - Remark: for CoreML: 400, for TFLite: 10
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var melFrameLength: Int = 10
    /// The number of filterbank components in each mel spectrogram frame sent to the wakeword recognizer.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var melFrameWidth: Int = 40
    /// The size of the wakeword recognizer's encoder state output.
    /// - SeeAlso: `TFLiteWakewordRecognizer`, `encodeWidth`
    /// - Remarks: Defaults to matching the `encodeWidth` value.
    @objc public var stateWidth: Int = 128
    /// The size of the wakeword recognizer's encoder window output.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var encodeWidth: Int = 128
    /// The length of the sliding window of encoder output used as an input to the wakeword recognizer classifier, in milliseconds.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var encodeLength: Int = 1000
    /// The threshold of the wakeword recognizer classifier's posterior output, above which the wakeword recognizer activates the pipeline, in the range [0, 1].
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var wakeThreshold: Float = 0.9
    /// The minimum length of an activation, in milliseconds. Used to ignore a Voice Activity Detector (VAD) deactivation after the wakeword.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var wakeActiveMin: Int = 2000
    /// The maximum length of an activation, in milliseconds. Used to time out the speech pipeline activation.
    /// - Remarks: Defaults to 5 seconds to improve perceived responsiveness, although most NLUs use a longer timeout (eg 7s).
    /// - SeeAlso: `AppleSpeechRecognizer`, `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var wakeActiveMax: Int = 5000
    /// Indicate to the VAD the level of permissiveness to non-speech activation.
    /// - SeeAlso: `AppleWakewordRecognizer`, `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    public var vadMode: VADMode = VADMode.Restrictive
    /// Delay between a VAD deactivation and the delivery of the recognition results.
    /// - SeeAlso: `AppleWakewordRecognizer`
    /// - Remark: unique to iOS
    @objc public var vadFallDelay: Int = 800
    /// Audio sampling rate, in Hz.
    public var sampleRate = 16000
    /// Audio frame width, in milliseconds.
    /// - ToDo: Should be renamed wakeFrameWidth.
    @objc public var frameWidth: Int = 20
    /// Length of time to allow an Apple ASR request to run, in milliseconds.
    /// - SeeAlso: `AppleWakewordRecognizer`
    /// - Remark: Apple has an undocumented limit of 60000ms per request.
    ///           Unique to iOS.
    @objc public var wakewordRequestTimeout: Int = 50000
    /// The pre-emphasis filter weight to apply to the normalized audio signal, in a range of [0, 1].
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var preEmphasis: Float = 0.97
    /// The filename of the machine learning model used for the filtering step.
    /// - Remarks: Both the file name and the file path are configurable to allow for flexibility in constructing the path that the recognizer will attempt to load the model from.
    @objc public var filterModelName: String = "Filter"
    /// The filename of the machine learning model used for the encoding step.
    /// - Remarks: Both the file name and the file path are configurable to allow for flexibility in constructing the path that the recognizer will attempt to load the model from.
    @objc public var encodeModelName: String = "Encode"
    /// The filename of the machine learning model used for the detect step.
    /// - Remarks: Both the file name and the file path are configurable to allow for flexibility in constructing the path that the recognizer will attempt to load the model from.
    @objc public var detectModelName: String = "Detect"
    /// The filesystem path to the machine learning model for the filtering step.
    @objc public var filterModelPath: String = "Filter.lite"
    /// The filesystem path to the machine learning model for the encoding step.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var encodeModelPath: String = "Encode.lite"
    /// The filesystem path to the machine learning model for the detect step.
    /// - SeeAlso: `CoreMLWakewordRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var detectModelPath: String = "Detect.lite"
    /// Text To Speech API authorization key
    @objc public var authorization: String = "Key f854fbf30a5f40c189ecb1b38bc78059"
    /// Debugging trace levels, for simple filtering.
    @objc public var tracing: Trace.Level = Trace.Level.NONE
}
