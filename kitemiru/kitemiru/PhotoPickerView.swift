//
//  PhotoPickerView.swift
//  kitemiru
//
//  Created by 濵田　悠樹 on 2024/08/14.
//

import SwiftUI
import PhotosUI

// TODO: 顔画像を写真フォルダから取得する場合は、顔領域を切り取る処理を追加する
struct PhotoPickerView: View {
    @Binding var selectedImage: UIImage?
    @State private var isPickerPresented = false

    var body: some View {
        ZStack {
            Button("写真フォルダから画像を選択") {
                isPickerPresented = true
            }
            .padding()
            .photosPicker(isPresented: $isPickerPresented, selection: $selectedImage)
        }
    }
}

extension View {
    func photosPicker(isPresented: Binding<Bool>, selection: Binding<UIImage?>) -> some View {
        self.sheet(isPresented: isPresented) {
            PHPickerViewController.View(selection: selection)
        }
    }
}

extension PHPickerViewController {
    struct View: UIViewControllerRepresentable {
        @Binding var selection: UIImage?

        func makeUIViewController(context: Context) -> PHPickerViewController {
            var config = PHPickerConfiguration()
            config.filter = .images
            config.selectionLimit = 1

            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }

        class Coordinator: NSObject, PHPickerViewControllerDelegate {
            let parent: View

            init(_ parent: View) {
                self.parent = parent
            }

            func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                picker.dismiss(animated: true)

                if let provider = results.first?.itemProvider, provider.canLoadObject(ofClass: UIImage.self) {
                    provider.loadObject(ofClass: UIImage.self) { image, _ in
                        DispatchQueue.main.async {
                            self.parent.selection = image as? UIImage
                        }
                    }
                }
            }
        }
    }
}
