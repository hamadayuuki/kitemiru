//
//  DetectFaceReactangle.swift
//  kitemiru
//
//  Created by 濵田　悠樹 on 2024/08/17.
//

import UIKit
import Vision

final class DetectFaceReactangle {

    func predict(coordinateUIImage: UIImage) -> VNFaceObservation {
        guard let pixcelBuffer = coordinateUIImage.pixelBuffer() else { fatalError("Image failed.") }
        let faceDetectionRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixcelBuffer)   // CIImageは回転情報を持たないためCVPixelBufferを採用

        do {
            try handler.perform([faceDetectionRequest])
            guard let observations: [VNFaceObservation] = faceDetectionRequest.results else { fatalError("call faceDetectionRequest.results") }
            let observation: VNFaceObservation = observations.first!
            return observation
        } catch {
            print(error.localizedDescription)
            fatalError(#function)
        }
    }
    
}
