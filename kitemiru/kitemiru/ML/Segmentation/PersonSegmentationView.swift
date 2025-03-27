//
//  PersonSegmentationView.swift
//  kitemiru
//
//  Created by yuki.hamada on 2025/03/27.
//

import SwiftUI
import PhotosUI

struct PersonSegmentationView: View {
    // ViewModelを利用（画面で観測可能なオブジェクトとしてStateObject化）
    @StateObject private var viewModel = PersonSegmentationViewModel()
    // PhotosPickerで選択されたアイテムを保持する状態
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 写真選択ボタン（PhotosPickerを使用）
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Text("写真を選択")
                        .font(.headline)
                        .padding()
                        .background(Color.blue.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.top)
                .onChange(of: selectedPhotoItem) { newItem in
                    // ユーザーが写真を選択した際に呼ばれる
                    guard let item = newItem else { return }
                    // 非同期でPhotosPickerItemからUIImageを取得
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            // 取得したUIImageをViewModelに渡してセグメンテーション開始
                            viewModel.segmentPerson(in: uiImage)
                        }
                    }
                }

                // 処理中はプログレスビューを表示
                if viewModel.isProcessing {
                    ProgressView("人物を検出しています...")
                        .padding()
                }

                // 処理完了後に画像と保存ボタンを表示
                if let original = viewModel.originalImage,
                   let mask = viewModel.maskImage,
                   let cutout = viewModel.cutoutImage,
                   !viewModel.isProcessing {
                    // 結果画像の表示（元画像、マスク、切り抜き）
                    ScrollView {
                        VStack(spacing: 20) {
                            // 入力元画像
                            VStack {
                                Text("入力画像")
                                    .font(.subheadline)
                                Image(uiImage: original)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                Button("この画像を保存") {
                                    viewModel.saveImageToLibrary(original)
                                }
                                .padding(.top, 5)
                            }
                            // マスク画像（白黒）
                            VStack {
                                Text("マスク画像（白=人物）")
                                    .font(.subheadline)
                                Image(uiImage: mask)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                Button("マスク画像を保存") {
                                    viewModel.saveImageToLibrary(mask)
                                }
                                .padding(.top, 5)
                            }
                            // 切り抜き後の人物画像（背景透過）
                            VStack {
                                Text("切り抜き画像（背景透過）")
                                    .font(.subheadline)
                                Image(uiImage: cutout)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 200)
                                    .background(Color.gray.opacity(0.2))  // 背景に薄灰色を敷いて透明部分を視認
                                Button("切り抜き画像を保存") {
                                    viewModel.saveImageToLibrary(cutout)
                                }
                                .padding(.top, 5)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("人物切り抜きデモ")
        }
    }
}

#Preview {
    PersonSegmentationView()
}
