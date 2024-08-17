//
//  KitemiruViewState.swift
//  kitemiru
//
//  Created by 濵田　悠樹 on 2024/08/17.
//

import Observation
import Vision
import UIKit

@Observable
final class KitemiruViewState {
    private let segmentation: Segmentation = .init()
    private let detectFaceReactangle: DetectFaceReactangle = .init()

    var coordinateUIImage: UIImage? = nil
    var coordFaceObservations: VNFaceObservation? = nil
    var userFaceUIImage: UIImage?

    init(_ userFaceUIImage: UIImage? = .init(named: "detectedFace01")) {
        // TODO: - ユーザーの顔データは画面初期化時から渡しておく
        self.userFaceUIImage = userFaceUIImage
    }

    func selectedCoordinate(selectedUIImage: UIImage?) {
        guard let selectedUIImage else { return }
        coordinateUIImage = selectedUIImage
        userFaceUIImage = UIImage(named: "detectedFace01")   // リセット
        let faceObservation = detectFaceReactangle.predict(coordinateUIImage: coordinateUIImage!)
        let amplifyedFaceObservation = amplifyFaceObservation(observation: faceObservation)
        coordFaceObservations = amplifyedFaceObservation
        let face: Face = segmentation.predict(uiImage: userFaceUIImage!)
        userFaceUIImage = maskedImage(uiImage: userFaceUIImage!, face: face)
    }

    private func amplifyFaceObservation(observation: VNFaceObservation) -> VNFaceObservation {
        // 髪を含めて切り抜きたいので切り抜き範囲を上,左,右に拡大. アスペクト比は固定となるよう拡大.
        let scale: CGFloat = 1.6
        let boundingBox = observation.boundingBox
        let newWidth = boundingBox.width * scale
        let newHeight = boundingBox.height * scale
        let newX = boundingBox.midX - (newWidth/2)
        let newY = boundingBox.midY - (boundingBox.height/2)
        let newBoundingBox = CGRect(
            x: newX,
            y: newY,
            width: newWidth,
            height: newHeight
        )
        return VNFaceObservation(boundingBox: newBoundingBox)
    }

    private func maskedImage(uiImage: UIImage, face: Face) -> UIImage {
        let imageSize: CGSize = .init(width: 512, height: 512)   // mlからの出力サイズが (512,512) のため
        let beginImage = CIImage(cgImage: uiImage.cgImage!).resize(as: imageSize)
        let bgImage = CIImage(cgImage: uiImage.cgImage!).settingAlphaOne(in: .zero)   // 透明

        // 空のUIImageを初期化
        let renderer = UIGraphicsImageRenderer(size: imageSize)
        var faceMaskedUIImage = renderer.image { _ in
            UIColor.clear.setFill()
            UIRectFill(CGRect(origin: .zero, size: imageSize))
        }

        for ciImage in face.ciImages {
            let maskedCIImage = CIFilter(name: "CIBlendWithMask", parameters: [
                kCIInputImageKey: beginImage,
                kCIInputBackgroundImageKey: bgImage,
                kCIInputMaskImageKey: ciImage.resize(as: imageSize)
            ])?.outputImage
            let maskedCGImage: CGImage = maskedCIImage!.toCGImage()!
            let maskedUIImage: UIImage = UIImage(cgImage: maskedCGImage)
            faceMaskedUIImage = faceMaskedUIImage.composite(image: maskedUIImage)!
        }
        return faceMaskedUIImage
    }

}
