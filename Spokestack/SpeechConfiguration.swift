//
//  SpeechConfiguration.swift
//  Spokestack
//
//  Created by Cory D. Wiles on 12/4/18.
//  Copyright © 2020 Spokestack, Inc. All rights reserved.
//

import Foundation

/// Configuration properties for Spokestack modules.
@objc public class SpeechConfiguration: NSObject {
    /// A comma-separated list of wakeword keywords
    /// - Remark: ex: "up,dog"
    /// - Warning: cannot contain spaces
    /// - SeeAlso: `AppleWakewordRecognizer`
    @objc public var wakewords: String = "spokestack, spoke stack, smokestack, smoke stack"
    /// The name of the window function to apply to each audio frame before calculating the STFT.
    /// - Remark: Currently the "hann" window is supported.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    public var fftWindowType: SignalProcessing.FFTWindowType = .hann
    /// The desired linear Root Mean Squared (RMS) signal energy, which is used for signal normalization and should be tuned to the RMS target used during wakeword model training.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @available(*, deprecated, message: "RMS normalization is no longer used during wakeword recognition.")
    @objc public var rmsTarget: Float = 0.08
    /// The Exponentially Weighted Moving Average (EWMA) update rate for the current  Root Mean Squared (RMS) signal energy (0 for no RMS normalization).
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @available(*, deprecated, message: "RMS normalization is no longer used during wakeword recognition.")
    @objc public var rmsAlpha: Float = 0.0
    /// The size of the signal window used to calculate the STFT, in number of samples - should be a power of 2 for maximum efficiency.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var fftWindowSize: Int = 512
    /// The length of time to skip each time the overlapping STFT is calculated, in milliseconds.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var fftHopLength: Int = 10
    /// The length of a frame in the mel spectrogram used as an input to the wakeword recognizer encoder, in milliseconds.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var melFrameLength: Int = 10
    /// The number of filterbank components in each mel spectrogram frame sent to the wakeword recognizer.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
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
    @objc public var wakeThreshold: Float = 0.8
    /// The minimum length of an activation, in milliseconds. Used to ignore a Voice Activity Detector (VAD) deactivation after the wakeword.
    /// - SeeAlso: TFLiteWakewordRecognizer`
    @objc public var wakeActiveMin: Int = 2000
    /// The maximum length of an activation, in milliseconds. Used to time out the speech pipeline activation.
    /// - Remarks: Defaults to 5 seconds to improve perceived responsiveness, although most NLUs use a longer timeout (eg 7s).
    /// - SeeAlso: `AppleSpeechRecognizer`, `TFLiteWakewordRecognizer`
    @objc public var wakeActiveMax: Int = 5000
    /// Indicate to the VAD the level of permissiveness to non-speech activation.
    /// - SeeAlso: `AppleWakewordRecognizer`, `TFLiteWakewordRecognizer`
    public var vadMode: VADMode = VADMode.Restrictive
    /// Delay between a VAD deactivation and the delivery of the recognition results.
    /// - SeeAlso: `AppleSpeechRecognizer`
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
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var preEmphasis: Float = 0.97
    /// The filename of the machine learning model used for the filtering step.
    /// - Remarks: Both the file name and the file path are configurable to allow for flexibility in constructing the path that the recognizer will attempt to load the model from.
    @objc public var filterModelName: String = "filter"
    /// The filename of the machine learning model used for the encoding step.
    /// - Remarks: Both the file name and the file path are configurable to allow for flexibility in constructing the path that the recognizer will attempt to load the model from.
    @objc public var encodeModelName: String = "encode"
    /// The filename of the machine learning model used for the detect step.
    /// - Remarks: Both the file name and the file path are configurable to allow for flexibility in constructing the path that the recognizer will attempt to load the model from.
    @objc public var detectModelName: String = "detect"
    /// The filesystem path to the machine learning model for the filtering step.
    @objc public var filterModelPath: String = "filter.tflite"
    /// The filesystem path to the machine learning model for the encoding step.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var encodeModelPath: String = "encode.tflite"
    /// The filesystem path to the machine learning model for the detect step.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var detectModelPath: String = "detect.tflite"
    /// Text To Speech API client identifier key.
    /// - SeeAlso: `TextToSpeech`
    @objc public var apiId: String = "f0bc990c-e9db-4a0c-a2b1-6a6395a3d97e"
    /// Text To Speech API client secret key.
    /// - SeeAlso: `TextToSpeech`
    @objc public var apiSecret: String = "5BD5483F573D691A15CFA493C1782F451D4BD666E39A9E7B2EBE287E6A72C6B6"
    /// The filesystem path to the vocabulary used for tokenizer encoding.
    /// - SeeAlso: `Tokenizer`
    @objc public var nluVocabularyPath: String = "vocab.txt"
    /// The index in the vocabulary of the terminator token. Determined  by the NLU vocabulary.
    /// - SeeAlso: `BertTokenizer`
    @objc public var nluTerminatorTokenIndex: Int = 102
    /// The index in the vocabulary of the terminator token. Determined  by the NLU vocabulary.
    /// - SeeAlso: `BertTokenizer`
    @objc public var nluPaddingTokenIndex: Int = 0
    /// The filesystem path to the machine learning model for Natural Language Understanding processing.
    /// - SeeAlso: `TensorflowNLU`
    @objc public var nluModelPath: String = "nlu.tflite"
    /// The filesystem path to the model metadata for Natural Language Understanding processing.
    /// - SeeAlso: `TensorflowNLU`
    @objc public var nluModelMetadataPath: String = "nlu.json"
    /// The maximum utterance length the NLU can process. Determined  by the NLU model.
    /// - SeeAlso: `BertTokenizer`
    @objc public var nluMaxTokenLength: Int = 50
    /// Debugging trace levels, for simple filtering.
    @objc public var tracing: Trace.Level = Trace.Level.NONE
    /// Delegate events will be sent using the specified dispatch queue.
    @objc public var delegateDispatchQueue: DispatchQueue = DispatchQueue.global(qos: .userInitiated)
    /// The dynamic size of the buffer in use by the `AudioEngine`.
    internal var audioEngineBufferSize: UInt32 = 320
    /// Automatically run Spokestack's NLU classification on ASR transcripts for clients that use the `Spokestack` facade.
    /// - Note: Requires  `NLUTensorflow` to be correctly configured, notably with `nluModelPath`, `nluModelMetadataPath`, and `nluVocabularyPath`.
    /// - SeeAlso: `Spokestack`, `NLUTensorflow`, `nluModelPath`, `nluModelMetadataPath`, and `nluVocabularyPath`
    @objc public var automaticallyClassifyTranscript = true
    /// The filename of the machine learning model used for the filtering step of the keyword recognizer.
    /// - Remarks: Both the file name and the file path are configurable to allow for flexibility in constructing the path that the recognizer will attempt to load the model from.
    /// - SeeAlso: `TFLiteKeywordRecognizer`
    @objc public var keywordFilterModelName: String = "KeywordFilter"
    /// The filename of the machine learning model used for the encoding step of the keyword recognizer.
    /// - Remarks: Both the file name and the file path are configurable to allow for flexibility in constructing the path that the recognizer will attempt to load the model from.
    /// - SeeAlso: `TFLiteKeywordRecognizer`
    @objc public var keywordEncodeModelName: String = "KeywordEncode"
    /// The filename of the machine learning model used for the detect step of the keyword recognizer.
    /// - Remarks: Both the file name and the file path are configurable to allow for flexibility in constructing the path that the recognizer will attempt to load the model from.
    /// - SeeAlso: `TFLiteKeywordRecognizer`
    @objc public var keywordDetectModelName: String = "KeywordDetect"
    /// The filename of the model metadata for keyword recognition
    /// - Remarks: Both the file name and the file path are configurable to allow for flexibility in constructing the path that the recognizer will attempt to load the model from.
    /// - SeeAlso: `TFLiteKeywordRecognizer`
    @objc public var keywordMetadataName: String = "KeywordMetadata"
    /// The filesystem path to the machine learning model for the filtering step of the keyword recognizer.
    /// - SeeAlso: `TFLiteKeywordRecognizer`
    @objc public var keywordFilterModelPath: String = "KeywordFilter.tflite"
    /// The filesystem path to the machine learning model for the encoding step of the keyword recognizer.
    /// - SeeAlso: `TFLiteKeywordRecognizer`
    @objc public var keywordEncodeModelPath: String = "KeywordEncode.tflite"
    /// The filesystem path to the machine learning model for the detect step of the keyword recognizer.
    /// - SeeAlso: `TFLiteKeywordRecognizer`
    @objc public var keywordDetectModelPath: String = "KeywordDetect.tflite"
    /// The threshold of the keyword recognizer's posterior output, above which the keyword recognizer emits a recognition event for the most probable keyword.
    /// - SeeAlso: `TFLiteKeywordRecognizer`
    @objc public var keywordThreshold: Float = 0.5
    /// The filesystem path to the model metadata for keyword recognition
    /// - SeeAlso: `TFLiteKeywordRecognizer`
    @objc public var keywordMetadataPath: String = "metadata.json"
    /// A comma-separated list of keywords to recognize.
    /// - Remark: ex: "yes,no"
    /// - Warning: Cannot contain spaces. Will be ignored in favor of `keywordMetadataPath` if available.
    /// - SeeAlso: `TFLiteKeywordRecognizer`
    @objc public var keywords: String = ""
    /// The name of the window function to apply to each audio frame before calculating the STFT.
    /// - Remark: Currently the "hann" window is supported.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    public var keywordFFTWindowType: SignalProcessing.FFTWindowType = .hann
    /// The size of the signal window used to calculate the STFT, in number of samples - should be a power of 2 for maximum efficiency.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var keywordFFTWindowSize: Int = 512
    /// The length of time to skip each time the overlapping STFT is calculated, in milliseconds.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var keywordFFTHopLength: Int = 10
    /// The length of a frame in the mel spectrogram used as an input to the wakeword recognizer encoder, in milliseconds.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var keywordMelFrameLength: Int = 110
    /// The number of filterbank components in each mel spectrogram frame sent to the wakeword recognizer.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var keywordMelFrameWidth: Int = 40
    /// The size of the wakeword recognizer's encoder window output.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var keywordEncodeWidth: Int = 128
    /// The length of the sliding window of encoder output used as an input to the wakeword recognizer classifier, in milliseconds.
    /// - SeeAlso: `TFLiteWakewordRecognizer`
    @objc public var keywordEncodeLength: Int = 1000
    /// Timeout in seconds used for semaphore waits in the speech pipeline
    /// - Warning: There is not normally a need to change this value.
    /// - SeeAlso: `AudioController`, `AppleWakewordRecognizer`, `AppleSpeechRecognizer`
    @objc public var semaphoreTimeout: Double = 1
}
