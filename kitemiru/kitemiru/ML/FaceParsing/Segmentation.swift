//
//  Segmentation.swift
//  kitemiru
//
//  Created by 濵田　悠樹 on 2024/08/17.
//

import UIKit
import Vision

final class Segmentation {
    var coreMLRequest: VNCoreMLRequest? = nil

    init() {
        do {
            let model = try faceParsing(configuration: MLModelConfiguration()).model
            let vnCoreMLModel = try VNCoreMLModel(for: model)
            let request = VNCoreMLRequest(model: vnCoreMLModel)
            request.imageCropAndScaleOption = .scaleFill
            self.coreMLRequest = request
        } catch let error {
            print(error)
        }
    }

    func predict(uiImage: UIImage) -> Face {
        guard let pixcelBuffer = uiImage.pixelBuffer() else { fatalError("Image failed.") }
        let ciImage = CIImage(cvPixelBuffer: pixcelBuffer)

        guard let coreMLRequest = coreMLRequest else { fatalError("Model initialization failed.") }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixcelBuffer)   // CIImageは回転情報を持たないためCVPixelBufferを採用

        do {
            try handler.perform([coreMLRequest])
            guard let result = coreMLRequest.results?.first as? VNCoreMLFeatureValueObservation else {fatalError("Inference failed.")}

            let multiArray = result.featureValue.multiArrayValue
            let face = Face()
            for faceType in face.types {
                guard let cgImage = multiArray?.cgImage(min: 0, max: 18, channel: nil, outputType: faceType.rawValue) else {fatalError("Image processing failed.")}
                let ciImage = CIImage(cgImage: cgImage)
                face.ciImages.append(ciImage)
            }
            return face
        } catch let error {
            print(error)
            fatalError(#function)
        }
    }
}
