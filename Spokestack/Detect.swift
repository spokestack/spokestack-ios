//
// Detect.swift
//
// This file was automatically generated and should not be edited.
//

import CoreML


/// Model Prediction Input Type
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class DetectInput : MLFeatureProvider {

    /// melspec_inputs__0 as 1 x 40 x 40 3-dimensional array of doubles
    var melspec_inputs__0: MLMultiArray

    var featureNames: Set<String> {
        get {
            return ["melspec_inputs__0"]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "melspec_inputs__0") {
            return MLFeatureValue(multiArray: melspec_inputs__0)
        }
        return nil
    }
    
    init(melspec_inputs__0: MLMultiArray) {
        self.melspec_inputs__0 = melspec_inputs__0
    }
}

/// Model Prediction Output Type
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class DetectOutput : MLFeatureProvider {

    /// Source provided by CoreML

    private let provider : MLFeatureProvider


    /// detect_outputs__0 as 3 element vector of doubles
    lazy var detect_outputs__0: MLMultiArray = {
        [unowned self] in return self.provider.featureValue(for: "detect_outputs__0")!.multiArrayValue
    }()!

    var featureNames: Set<String> {
        return self.provider.featureNames
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return self.provider.featureValue(for: featureName)
    }

    init(detect_outputs__0: MLMultiArray) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["detect_outputs__0" : MLFeatureValue(multiArray: detect_outputs__0)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


/// Class for model loading and prediction
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class Detect {
    var model: MLModel

/// URL of model assuming it was installed in the same bundle as this class
    class var urlOfModelInThisBundle : URL {
        let bundle = Bundle(for: Detect.self)
        return bundle.url(forResource: "Detect", withExtension:"mlmodelc")!
    }

    /**
        Construct a model with explicit path to mlmodelc file
        - parameters:
           - url: the file url of the model
           - throws: an NSError object that describes the problem
    */
    init(contentsOf url: URL) throws {
        self.model = try MLModel(contentsOf: url)
    }

    /// Construct a model that automatically loads the model from the app's bundle
    convenience init() {
        try! self.init(contentsOf: type(of:self).urlOfModelInThisBundle)
    }

    /**
        Construct a model with configuration
        - parameters:
           - configuration: the desired model configuration
           - throws: an NSError object that describes the problem
    */
    @available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)
    convenience init(configuration: MLModelConfiguration) throws {
        try self.init(contentsOf: type(of:self).urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct a model with explicit path to mlmodelc file and configuration
        - parameters:
           - url: the file url of the model
           - configuration: the desired model configuration
           - throws: an NSError object that describes the problem
    */
    @available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)
    init(contentsOf url: URL, configuration: MLModelConfiguration) throws {
        self.model = try MLModel(contentsOf: url, configuration: configuration)
    }

    /**
        Make a prediction using the structured interface
        - parameters:
           - input: the input to the prediction as DetectInput
        - throws: an NSError object that describes the problem
        - returns: the result of the prediction as DetectOutput
    */
    func prediction(input: DetectInput) throws -> DetectOutput {
        return try self.prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface
        - parameters:
           - input: the input to the prediction as DetectInput
           - options: prediction options
        - throws: an NSError object that describes the problem
        - returns: the result of the prediction as DetectOutput
    */
    func prediction(input: DetectInput, options: MLPredictionOptions) throws -> DetectOutput {
        let outFeatures = try model.prediction(from: input, options:options)
        return DetectOutput(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface
        - parameters:
            - melspec_inputs__0 as 1 x 40 x 40 3-dimensional array of doubles
        - throws: an NSError object that describes the problem
        - returns: the result of the prediction as DetectOutput
    */
    func prediction(melspec_inputs__0: MLMultiArray) throws -> DetectOutput {
        let input_ = DetectInput(melspec_inputs__0: melspec_inputs__0)
        return try self.prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface
        - parameters:
           - inputs: the inputs to the prediction as [DetectInput]
           - options: prediction options
        - throws: an NSError object that describes the problem
        - returns: the result of the prediction as [DetectOutput]
    */
    @available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)
    func predictions(inputs: [DetectInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [DetectOutput] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [DetectOutput] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result =  DetectOutput(features: outProvider)
            results.append(result)
        }
        return results
    }
}
