//
//  FaceSegmentationView.swift
//  kitemiru
//
//  Created by 濵田　悠樹 on 2024/08/15.
//

import SwiftUI
import Vision

struct FaceSegmentationView: View {
    @State var coreMLRequest: VNCoreMLRequest?
    @State var factType: FaceType = .all
    @State private var faceObservations: [VNFaceObservation] = []

    private let imageSizeS = CGSize(width: 100, height: 100)
    private let imageSizeM = CGSize(width: 250, height: 250)
    @State private var inputUIImage: UIImage? = .init(named: "face01")
    @State private var reactangsUIImage: UIImage? = nil
    @State private var detectedUIImage: UIImage? = nil
    // TODO: 画像によっては、segmentedFaceUIImage の向きがおかしくなるので原因調査から対応する
    /// 顔切り抜き+セグメンテーション
    @State private var segmentedFaceUIImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                Image(uiImage: inputUIImage!)
                    .resizable()
                    .frame(width: imageSizeS.width, height: imageSizeS.height)

                Image(uiImage: inputUIImage!)
                    .resizable()
                    .frame(width: imageSizeS.width, height: imageSizeS.height)
                    .overlay(
                        GeometryReader { geometry in
                            reactangles(geometry: geometry)
                        }
                    )

                if let detectedUIImage {
                    Image(uiImage: detectedUIImage)
                        .resizable()
                        .frame(width: imageSizeS.width, height: imageSizeS.height)
                }
            }

            if let segmentedFaceUIImage {
                Image(uiImage: segmentedFaceUIImage)
                    .resizable()
                    .frame(width: imageSizeM.width, height: imageSizeM.height)
            }

            PhotoPickerView(selectedImage: $inputUIImage)
        }
        .onAppear {
            initCoreMLModel()
            faceDetectRectangles()
        }
        .onChange(of: detectedUIImage) {
            guard let detectedUIImage else { return }
            segmentation(uiImage: detectedUIImage)
        }
        .onChange(of: inputUIImage) {
            faceDetectRectangles()
            guard let detectedUIImage else { return }
            segmentation(uiImage: detectedUIImage)
        }
    }

    // MARK: - ui components

    private func reactangles(geometry: GeometryProxy) -> some View {
        ZStack {
            ForEach(faceObservations, id: \.self) { observation in
                Rectangle()
                    .stroke(Color.blue, lineWidth: 2)
                    .frame(
                        width: boundingBox(observation: observation, imageSize: geometry.size).width,
                        height: boundingBox(observation: observation, imageSize: geometry.size).height
                    )
                    .position(
                        x: boundingBox(observation: observation, imageSize: geometry.size).minX,
                        y: boundingBox(observation: observation, imageSize: geometry.size).minY
                    )
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

    private func segmentation(uiImage: UIImage) {
        guard let coreMLRequest = coreMLRequest else {fatalError("Model initialization failed.")}
        guard let pixcelBuffer = uiImage.pixelBuffer() else { fatalError("Image failed.") }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixcelBuffer)   // CIImageは回転情報を持たないためCVPixelBufferを採用

        do {
            try handler.perform([coreMLRequest])
            guard let result = coreMLRequest.results?.first as? VNCoreMLFeatureValueObservation else {fatalError("Inference failed.")}
            let ciImage = CIImage(cvPixelBuffer: pixcelBuffer)
            let multiArray = result.featureValue.multiArrayValue
            guard let  outputCGImage = multiArray?.cgImage(min: 0, max: 18, channel: nil, outputType: factType.rawValue) else {fatalError("Image processing failed.")}
            let outputCIImage = CIImage(cgImage: outputCGImage).resize(as: ciImage.extent.size)
            let context = CIContext()
            guard let safeCGImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else {fatalError("Image processing failed.")}
            segmentedFaceUIImage = UIImage(cgImage: safeCGImage)
        } catch let error {
            print(error)
        }
    }

    private func faceDetectRectangles() {
        guard let uiImage = inputUIImage else { fatalError("inputUIImage failed") }
        guard let pixcelBuffer = uiImage.pixelBuffer() else { fatalError("Image failed.") }
        let faceDetectionRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixcelBuffer)   // CIImageは回転情報を持たないためCVPixelBufferを採用

        do {
            try handler.perform([faceDetectionRequest])
            guard let observations: [VNFaceObservation] = faceDetectionRequest.results else { return }
            // 髪を含めて切り抜きたいので切り抜き範囲を上,左,右に拡大. アスペクト比は固定となるよう拡大.
            let scale: CGFloat = 1.6
            faceObservations = observations.map { observation in
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
            cropFace(uiImage: inputUIImage!, observation: faceObservations.first!)   // observations のnilチェック終わってる
        } catch {
            print(error.localizedDescription)
        }
    }

    private func boundingBox(observation: VNFaceObservation, imageSize: CGSize) -> CGRect {
        let width: CGFloat = observation.boundingBox.width * imageSize.width
        let height: CGFloat = observation.boundingBox.height * imageSize.height
        return CGRect(
            x: observation.boundingBox.minX * imageSize.width + width / 2,
            y: (1 - observation.boundingBox.minY) * imageSize.height - height / 2,
            width: width,
            height: height
        )
    }

    private func cropFace(uiImage: UIImage, observation: VNFaceObservation) {
        guard let cgImage = uiImage.cgImage else { return }
        let boundingBox = observation.boundingBox
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        let cropRect = CGRect(
            x: boundingBox.minX * imageSize.width,
            y: (1 - boundingBox.maxY) * imageSize.height,
            width: boundingBox.width * imageSize.width,
            height: boundingBox.height * imageSize.height
        )

        if let croppedCgImage = cgImage.cropping(to: cropRect) {
            let croppedUIImage = UIImage(cgImage: croppedCgImage)
            detectedUIImage = resizeImage(image: croppedUIImage, targetSize: CGSize(width: 512, height: 512))   // セグメンテーションの入力が512,512
        }
    }

    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return resizedImage
    }
}

#Preview {
    FaceSegmentationView()
}
