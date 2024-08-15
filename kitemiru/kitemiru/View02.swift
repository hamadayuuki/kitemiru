//
//  View02.swift
//  kitemiru
//
//  Created by 濵田　悠樹 on 2024/08/15.
//

// TODO: ファイル名変更, 今は仮置きの名称

import SwiftUI
import Vision

struct View02: View {
    @State private var inputUIImage: UIImage? = .init(named: "face01")
    @State private var faceObservations: [VNFaceObservation] = []

    var body: some View {
        VStack(spacing: 24) {
            Image(uiImage: inputUIImage!)
                .resizable()
                .frame(width: 250, height: 250)

            Image(uiImage: inputUIImage!)
                .resizable()
                .frame(width: 250, height: 250)
                .overlay(
                    GeometryReader { geometry in
                        reactangles(geometry: geometry)
                    }
                )
        }
        .onAppear {
            faceDetectRectangles()
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

    // MARK: - logics

    private func faceDetectRectangles() {
        guard let uiImage = inputUIImage else { fatalError("inputUIImage failed") }
        guard let ciImage = CIImage(image: uiImage) else { fatalError("Image failed.") }
        let faceDetectionRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])

        do {
            try handler.perform([faceDetectionRequest])
            guard let observations: [VNFaceObservation] = faceDetectionRequest.results else { return }
            faceObservations = observations
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
}

#Preview {
    View02()
}
