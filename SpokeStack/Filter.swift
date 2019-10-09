//
// Filter.swift
//
// This file was automatically generated and should not be edited.
//

import CoreML


/// Model Prediction Input Type
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class FilterInput : MLFeatureProvider {

    /// linspec_inputs__0 as 257 x 1 x 1 3-dimensional array of doubles
    var linspec_inputs__0: MLMultiArray

    var featureNames: Set<String> {
        get {
            return ["linspec_inputs__0"]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "linspec_inputs__0") {
            return MLFeatureValue(multiArray: linspec_inputs__0)
        }
        return nil
    }
    
    init(linspec_inputs__0: MLMultiArray) {
        self.linspec_inputs__0 = linspec_inputs__0
    }
}

/// Model Prediction Output Type
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class FilterOutput : MLFeatureProvider {

    /// Source provided by CoreML

    private let provider : MLFeatureProvider


    /// melspec_outputs__0 as 1 x 1 x 40 3-dimensional array of doubles
    lazy var melspec_outputs__0: MLMultiArray = {
        [unowned self] in return self.provider.featureValue(for: "melspec_outputs__0")!.multiArrayValue
    }()!

    var featureNames: Set<String> {
        return self.provider.featureNames
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return self.provider.featureValue(for: featureName)
    }

    init(melspec_outputs__0: MLMultiArray) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["melspec_outputs__0" : MLFeatureValue(multiArray: melspec_outputs__0)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


/// Class for model loading and prediction
@available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
class Filter {
    var model: MLModel

/// URL of model assuming it was installed in the same bundle as this class
    class var urlOfModelInThisBundle : URL {
        let bundle = Bundle(for: Filter.self)
        return bundle.url(forResource: "Filter", withExtension:"mlmodelc")!
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
           - input: the input to the prediction as FilterInput
        - throws: an NSError object that describes the problem
        - returns: the result of the prediction as FilterOutput
    */
    func prediction(input: FilterInput) throws -> FilterOutput {
        return try self.prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface
        - parameters:
           - input: the input to the prediction as FilterInput
           - options: prediction options
        - throws: an NSError object that describes the problem
        - returns: the result of the prediction as FilterOutput
    */
    func prediction(input: FilterInput, options: MLPredictionOptions) throws -> FilterOutput {
        let outFeatures = try model.prediction(from: input, options:options)
        return FilterOutput(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface
        - parameters:
            - linspec_inputs__0 as 257 x 1 x 1 3-dimensional array of doubles
        - throws: an NSError object that describes the problem
        - returns: the result of the prediction as FilterOutput
    */
    func prediction(linspec_inputs__0: MLMultiArray) throws -> FilterOutput {
        let input_ = FilterInput(linspec_inputs__0: linspec_inputs__0)
        return try self.prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface
        - parameters:
           - inputs: the inputs to the prediction as [FilterInput]
           - options: prediction options
        - throws: an NSError object that describes the problem
        - returns: the result of the prediction as [FilterOutput]
    */
    @available(macOS 10.14, iOS 12.0, tvOS 12.0, watchOS 5.0, *)
    func predictions(inputs: [FilterInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [FilterOutput] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [FilterOutput] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result =  FilterOutput(features: outProvider)
            results.append(result)
        }
        return results
    }
}
