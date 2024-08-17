//
//  KitemiruView.swift
//  kitemiru
//
//  Created by 濵田　悠樹 on 2024/08/15.
//

import SwiftUI
import Vision

struct KitemiruView: View {

    @State private var state: KitemiruViewState = .init()
    @State private var selectedUIImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 24) {
            if let uiImage = state.coordinateUIImage,
               let userFaceUIImage = state.userFaceUIImage,
               let observation = state.coordFaceObservations {
                Image(uiImage: uiImage)
                    .resizable()
                    .frame(width: 200, height: 300)
                    .overlay(
                        GeometryReader { geometry in
                            userFace(uiImage: userFaceUIImage, observation: observation, geometry: geometry)
                        }
                    )
            }

            PhotoPickerView(selectedImage: $selectedUIImage)
        }
        .onChange(of: selectedUIImage) {
            state.selectedCoordinate(selectedUIImage: selectedUIImage)
        }
    }

    // MARK: - ui components

    private func userFace(uiImage: UIImage, observation: VNFaceObservation, geometry: GeometryProxy) -> some View {
        ZStack {
            Image(uiImage: uiImage)
                .resizable()
                .frame(width: faceFrame(for: observation, in: geometry).width, height: faceFrame(for: observation, in: geometry).height)
                .position(x: faceFrame(for: observation, in: geometry).midX, y: faceFrame(for: observation, in: geometry).midY)
                .scaledToFit()
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
    KitemiruView()
}
