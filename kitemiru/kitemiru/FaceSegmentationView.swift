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
    @State var factType: FaceType = .hair

    private let imageSizeS = CGSize(width: 100, height: 100)
    private let imageSizeM = CGSize(width: 250, height: 250)
    @State private var coordinateUIImage: UIImage? = nil
    @State private var coordFaceObservations: VNFaceObservation? = nil
    @State private var userFaceUIImage: UIImage? = UIImage(named: "detectedFace01")
    @State private var segmentedUserFaceCGImage: CGImage? = nil
    @State private var targetUIImage: UIImage? = nil

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

            PhotoPickerView(selectedImage: $coordinateUIImage)
        }
        .onAppear {
            initCoreMLModel()
        }
        .onChange(of: coordinateUIImage) {
            userFaceUIImage = UIImage(named: "detectedFace01")
            faceDetectRectangles()
            segmentation(uiImage: userFaceUIImage!)
            clearUserFaceBackground()
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
            guard let  outputCGImage = multiArray?.cgImage(min: 0, max: 18, channel: nil, outputType: factType.rawValue) else {fatalError("Image processing failed.")}
            segmentedUserFaceCGImage = outputCGImage
            let outputCIImage = CIImage(cgImage: outputCGImage).resize(as: ciImage.extent.size)
            let context = CIContext()
            guard let safeCGImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else {fatalError("Image processing failed.")}
            userFaceUIImage = UIImage(cgImage: safeCGImage)
        } catch let error {
            print(error)
        }
    }

    private func clearUserFaceBackground() {
        guard let segmentedUserFaceCGImage else { return }
        let data = segmentedUserFaceCGImage.dataProvider!.data
        let length = CFDataGetLength(data)
        var rawData: [UInt8] = .init(repeating: 0, count: length)
        CFDataGetBytes(data, CFRange(location: 0, length: length), &rawData)
        let segmentedUserFacePixelData = rawData

        guard let uiImage = userFaceUIImage else { return }
        guard let cgImage = uiImage.cgImage else { return }
        let width = cgImage.width
        let height = cgImage.height

        // ピクセルバッファを準備
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        var pixelData = [UInt8](repeating: 0, count: Int(height * width * bytesPerPixel))

        guard let context = CGContext(data: &pixelData,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: bitsPerComponent,
                                      bytesPerRow: bytesPerRow,
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }

        // 画像を描画してピクセルデータを取得
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 左半分のピクセルデータを透明に置き換える
        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel

//                print(segmentedUserFacePixelData[pixelIndex + 0])
//                print(segmentedUserFacePixelData[pixelIndex + 1])
//                print(segmentedUserFacePixelData[pixelIndex + 2])
//                print(segmentedUserFacePixelData[pixelIndex + 3])
//                print()

                if segmentedUserFacePixelData[pixelIndex + 0] == 0 &&
                    segmentedUserFacePixelData[pixelIndex + 1] == 0 &&
                    segmentedUserFacePixelData[pixelIndex + 2] == 0 {
                    pixelData[pixelIndex + 0] = 0 // R
                    pixelData[pixelIndex + 1] = 0 // G
                    pixelData[pixelIndex + 2] = 0 // B
                    pixelData[pixelIndex + 3] = 0 // A (透明)
                }
            }
        }
        guard let newCgImage = context.makeImage() else { return }
        userFaceUIImage = UIImage(cgImage: newCgImage)
    }

}

#Preview {
    FaceSegmentationView()
}
