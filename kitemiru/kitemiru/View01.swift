//
//  View01.swift
//  kitemiru
//
//  Created by 濵田　悠樹 on 2024/08/14.
//

import SwiftUI
import Vision

// TODO: ファイル名変更, 今は仮置きの名称

struct View01: View {
    @State var coreMLRequest: VNCoreMLRequest?
    @State var factType: FaceType = .all

    @State private var detectTime: CGFloat = 0.0
    @State private var inputUIImage: UIImage? = .init(named: "face01")
    @State private var outputUIImage: UIImage? = .init(named: "face01")
    private let imageWidth: CGFloat = 150

    var body: some View {
        VStack(spacing: 24) {
            segmentationResult()
            PhotoPickerView(selectedImage: $inputUIImage)
        }
        .padding()
        .onAppear {
            initCoreMLModel()
            segmentation()
        }
        .onChange(of: inputUIImage) {
            segmentation()
        }
    }

    // MARK: - ui components

    private func segmentationResult() -> some View {
        Group {
            HStack(spacing: 12) {
                Image(uiImage: inputUIImage!)
                    .resizable()
                    .frame(width: imageWidth, height: imageWidth)

                Image(uiImage: outputUIImage!)
                    .resizable()
                    .frame(width: imageWidth, height: imageWidth)
            }

            ZStack {
                Image(uiImage: inputUIImage!)
                    .resizable()
                    .frame(width: imageWidth + 100, height: imageWidth + 100)

                Image(uiImage: outputUIImage!)
                    .resizable()
                    .frame(width: imageWidth + 100, height: imageWidth + 100)
                    .opacity(0.5)
            }

            Text("Time: \(detectTime)ms")
        }
    }

    // MARK: - logics

    private func segmentation() {
        let correctOrientImage = getCorrectOrientationUIImage(uiImage: inputUIImage!)
        inputUIImage = correctOrientImage
        inference(uiImage: correctOrientImage)
    }

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

    private func getCorrectOrientationUIImage(uiImage:UIImage) -> UIImage {
        var newImage = UIImage()
        let ciContext = CIContext()
        switch uiImage.imageOrientation.rawValue {
        case 1:
            guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.down),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}

            newImage = UIImage(cgImage: cgImage)
        case 3:
            guard let orientedCIImage = CIImage(image: uiImage)?.oriented(CGImagePropertyOrientation.right),
                  let cgImage = ciContext.createCGImage(orientedCIImage, from: orientedCIImage.extent) else { return uiImage}
            newImage = UIImage(cgImage: cgImage)
        default:
            newImage = uiImage
        }
        return newImage
    }

    private func inference(uiImage: UIImage) {
        
        guard let coreMLRequest = coreMLRequest else {fatalError("Model initialization failed.")}
        guard let pixcelBuffer = uiImage.pixelBuffer() else { fatalError("Image failed.") }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixcelBuffer)   // CIImageは回転情報を持たないためCVPixelBufferを採用

        do {
            try handler.perform([coreMLRequest])
            detectTime = 0.0
            let startTime = Date()
            guard let result = coreMLRequest.results?.first as? VNCoreMLFeatureValueObservation else {fatalError("Inference failed.")}
            detectTime = Date().timeIntervalSince(startTime) * 1_000   // ms
            let ciImage = CIImage(cvPixelBuffer: pixcelBuffer)
            let multiArray = result.featureValue.multiArrayValue
            guard let  outputCGImage = multiArray?.cgImage(min: 0, max: 18, channel: nil, outputType: factType.rawValue) else {fatalError("Image processing failed.")}
            let outputCIImage = CIImage(cgImage: outputCGImage).resize(as: ciImage.extent.size)
            let context = CIContext()
            guard let safeCGImage = context.createCGImage(outputCIImage, from: outputCIImage.extent) else {fatalError("Image processing failed.")}
            DispatchQueue.main.async {
                outputUIImage = UIImage(cgImage: safeCGImage)
            }
        } catch let error {
            print(error)
        }
    }
}

#Preview {
    View01()
}
