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

    private let imageSizeS = CGSize(width: 100, height: 100)
    private let imageSizeM = CGSize(width: 250, height: 250)
    @State private var coordinateUIImage: UIImage? = nil
    @State private var coordFaceObservations: VNFaceObservation? = nil
    @State private var userFaceUIImage: UIImage? = UIImage(named: "detectedFace01")
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
            faceDetectRectangles()
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
}

#Preview {
    FaceSegmentationView()
}
