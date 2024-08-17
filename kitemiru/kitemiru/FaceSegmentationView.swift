//
//  FaceSegmentationView.swift
//  kitemiru
//
//  Created by 濵田　悠樹 on 2024/08/15.
//

import SwiftUI
import Vision

private class Face {
    var types: [FaceType] = FaceType.allCases
    var ciImages: [CIImage] = []
}

struct FaceSegmentationView: View {
    @State var coreMLRequest: VNCoreMLRequest?
    /// 顔のセグメンテーション結果を格納する
    private let faceCIImages: [CIImage] = []   // FaceType.all, .skin のCIImageが入る

    private let imageSizeS = CGSize(width: 100, height: 100)
    private let imageSizeM = CGSize(width: 250, height: 250)
    @State private var coordinateUIImage: UIImage? = nil
    @State private var coordFaceObservations: VNFaceObservation? = nil
    @State private var allAndSkinObservation: [VNFaceObservation]? = nil

    @State private var inputUIImage: UIImage? = UIImage(named: "detectedFace01")
    @State private var userFaceUIImage: UIImage? = UIImage(named: "detectedFace01")
    @State private var targetUIImage: UIImage? = nil
    @State private var maskedUIImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 24) {
            if let coordinateUIImage, let coordFaceObservations {
                Image(uiImage: coordinateUIImage)
                    .resizable()
                    .frame(width: 200, height: 300)
                    .scaledToFit()
                    .overlay(
                        GeometryReader { geometry in
                            userFace(geometry: geometry)
                        }
                    )
            }

            if let maskedUIImage {
                Image(uiImage: maskedUIImage)
                    .resizable()
                    .frame(width: 200, height: 300)
            }

            PhotoPickerView(selectedImage: $coordinateUIImage)
        }
        .onAppear {
            initCoreMLModel()
        }
        .onChange(of: coordinateUIImage) {
            userFaceUIImage = UIImage(named: "detectedFace01")
            faceDetectRectangles()
            segmentation(uiImage: userFaceUIImage!)
        }
    }

    // MARK: - ui components

    private func userFace(geometry: GeometryProxy) -> some View {
        ZStack {
            if let userFaceUIImage, let observation = coordFaceObservations {
                Image(uiImage: userFaceUIImage)
                    .resizable()
                    .frame(width: faceFrame(for: observation, in: geometry).width, height: faceFrame(for: observation, in: geometry).height)
                    .position(x: faceFrame(for: observation, in: geometry).midX, y: faceFrame(for: observation, in: geometry).midY)
                    .scaledToFit()
            }
        }
    }

    // MARK: - logic

    private func initCoreMLModel() {
        do {
            let model = try faceParsing(configuration: MLModelConfiguration()).model
            let vnCoreMLModel = try VNCoreMLModel(for: model)
            let request = VNCoreMLRequest(model: vnCoreMLModel)
            request.imageCropAndScaleOption = .scaleFill
            coreMLRequest = request
        } catch let error {
            print(error)
        }
    }

    private func faceDetectRectangles() {
        guard let coordinateUIImage else { return }
        guard let pixcelBuffer = coordinateUIImage.pixelBuffer() else { fatalError("Image failed.") }
        let faceDetectionRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixcelBuffer)   // CIImageは回転情報を持たないためCVPixelBufferを採用

        do {
            try handler.perform([faceDetectionRequest])
            guard let observations: [VNFaceObservation] = faceDetectionRequest.results else { return }
            let observation: VNFaceObservation = observations.first!

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
            coordFaceObservations = VNFaceObservation(boundingBox: newBoundingBox)
        } catch {
            print(error.localizedDescription)
        }
    }

    private func faceFrame(for observation: VNFaceObservation, in geometry: GeometryProxy) -> CGRect {
        let imageSize = geometry.size
        let boundingBox = observation.boundingBox

        let width = boundingBox.width * imageSize.width
        let height = boundingBox.height * imageSize.height
        let x = boundingBox.minX * imageSize.width
        let y = (1 - boundingBox.maxY) * imageSize.height

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func segmentation(uiImage: UIImage) {
        guard let coreMLRequest = coreMLRequest else {fatalError("Model initialization failed.")}
        guard let pixcelBuffer = uiImage.pixelBuffer() else { fatalError("Image failed.") }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixcelBuffer)   // CIImageは回転情報を持たないためCVPixelBufferを採用

        do {
            try handler.perform([coreMLRequest])
            guard let result = coreMLRequest.results?.first as? VNCoreMLFeatureValueObservation else {fatalError("Inference failed.")}
            let ciImage = CIImage(cvPixelBuffer: pixcelBuffer)
            let multiArray = result.featureValue.multiArrayValue
            
            let face = Face()
            for faceType in face.types {
                guard let cgImage = multiArray?.cgImage(min: 0, max: 18, channel: nil, outputType: faceType.rawValue) else {fatalError("Image processing failed.")}
                let ciImage = CIImage(cgImage: cgImage)
                face.ciImages.append(ciImage)
            }
            maskedImage(face: face)
//            let context = CIContext()
//            guard let safeCGImage = context.createCGImage(allCIImage, from: allCIImage.extent) else {fatalError("Image processing failed.")}
//            userFaceUIImage = UIImage(cgImage: safeCGImage)
        } catch let error {
            print(error)
        }
    }

    private func maskedImage(face: Face) {
        let imageSize: CGSize = .init(width: 512, height: 512)
        let beginImage = CIImage(cgImage: inputUIImage!.cgImage!).resize(as: imageSize)
        let bgImage = CIImage(cgImage: inputUIImage!.cgImage!).settingAlphaOne(in: .zero)   // 透明
        
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
        userFaceUIImage = faceMaskedUIImage
    }

}

#Preview {
    FaceSegmentationView()
}
