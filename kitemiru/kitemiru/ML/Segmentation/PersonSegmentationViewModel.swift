//
//  PersonSegmentationViewModel.swift
//  kitemiru
//
//  Created by yuki.hamada on 2025/03/27.
//

import SwiftUI
import PhotosUI
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit  // UIImageや保存機能でUIKitを使用

/// ViewModel: 画像のセグメンテーション処理と結果画像の管理
@MainActor  // UI更新を含むためMainActor上で動作
class PersonSegmentationViewModel: ObservableObject {
    // 入力画像、マスク画像、切り抜き画像を保持（UI更新のためPublished）
    @Published var originalImage: UIImage? = nil
    @Published var maskImage: UIImage? = nil
    @Published var cutoutImage: UIImage? = nil
    @Published var isProcessing: Bool = false  // 処理中フラグ

    // Visionリクエスト（人物セグメンテーション）
    private let segmentationRequest: VNGeneratePersonSegmentationRequest = {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .accurate  // 静止画に対しては高精度設定
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8  // マスクをグレースケール出力
        return request
    }()

    // Core Imageコンテキスト（CIImageをCGImage/UIImageに変換するため使用）
    private let ciContext = CIContext()

    /// 渡されたUIImageに対し人物セグメンテーションを実行し、結果のマスク画像と切り抜き画像を生成
    func segmentPerson(in uiImage: UIImage) {
        // ① 処理中フラグをONにし、入力画像を保持
        self.isProcessing = true
        self.originalImage = uiImage

        // ② 重いVision処理はバックグラウンドスレッドで実行
        // TODO: Swift Concurrency へ書き換え
        DispatchQueue.global(qos: .userInitiated).async {
            // UIImageからCGImageを取り出し、Vision用ハンドラを作成
            guard let cgImage = uiImage.cgImage else {
                DispatchQueue.main.async { self.isProcessing = false }
                return
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                // TODO: Modelへ移行する。Visionを使った処理はModelの責務。
                // Visionリクエストを実行し人物マスクを取得
                try handler.perform([self.segmentationRequest])
                guard let result = self.segmentationRequest.results?.first as? VNPixelBufferObservation else {
                    // マスクが取得できない場合
                    print("人物マスクの生成に失敗しました")
                    DispatchQueue.main.async { self.isProcessing = false }
                    return
                }

                // TODO: 画像変換（③〜⑥）をメソッド化して扱いやすくする
                // ③ マスクのPixelBufferからCIImageを生成
                let maskCI = CIImage(cvPixelBuffer: result.pixelBuffer)
                // 元画像のCIImageを生成
                let originalCI = CIImage(cgImage: cgImage)

                // ④ マスク画像を元画像のサイズにリサイズ（整合性を保つため）
                let maskSize = originalCI.extent.size
                let scaleX = maskSize.width / maskCI.extent.width
                let scaleY = maskSize.height / maskCI.extent.height

                // マスク画像を元画像のサイズにスケーリング
                let resizedMaskCI = maskCI.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

                // サイズを元画像にぴったり合わせてクロップ
                let maskResized = resizedMaskCI.cropped(to: originalCI.extent)

                // ⑤ Core Imageのブレンドフィルタで元画像から人物部分を切り抜き
                // 透明な背景画像（背景用CIImage）を作成
                let transparentBG = CIImage(color: .clear).cropped(to: originalCI.extent)
                // CIBlendWithMaskフィルタを使用してマスクで合成
                let blendFilter = CIFilter.blendWithMask()
                blendFilter.inputImage = originalCI            // 元の人物画像
                blendFilter.backgroundImage = transparentBG    // 背景は透明
                blendFilter.maskImage = maskResized            // マスク（人物部分が白）
                guard let outputCI = blendFilter.outputImage else {
                    print("画像のブレンドに失敗しました")
                    DispatchQueue.main.async { self.isProcessing = false }
                    return
                }

                // ⑥ CIImageをUIImageに変換（マスク画像も同様に変換）
                // マスクCI画像は白=人物silhouette、黒=背景になるよう背景を黒で合成
                let maskWithBlackBG = maskResized.composited(over: CIImage(color: .black).cropped(to: originalCI.extent))
                // CIContextを使ってそれぞれCGImageに変換し、UIImage化
                let maskCG = self.ciContext.createCGImage(maskWithBlackBG, from: originalCI.extent)
                let cutoutCG = self.ciContext.createCGImage(outputCI, from: originalCI.extent)
                let maskUIImage = maskCG.flatMap { UIImage(cgImage: $0) }
                let cutoutUIImage = cutoutCG.flatMap { UIImage(cgImage: $0) }

                // ⑦ メインスレッドで結果を更新（Publishedプロパティ更新）
                DispatchQueue.main.async {
                    self.maskImage = maskUIImage
                    self.cutoutImage = cutoutUIImage
                    self.isProcessing = false  // 処理終了
                }
            } catch {
                // Visionリクエスト実行中のエラー
                print("Visionによる人物セグメンテーション中にエラー: \(error)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
        }
    }

    /// 渡されたUIImageをフォトライブラリに保存
    func saveImageToLibrary(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        // ↑コールバック指定も可能（保存完了時に通知を受ける場合）&#8203;:contentReference[oaicite:1]{index=1}
    }
}

