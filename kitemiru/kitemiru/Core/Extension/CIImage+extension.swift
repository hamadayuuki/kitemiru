//
//  CIImage+extension.swift
//  kitemiru
//
//  Created by 濵田　悠樹 on 2024/08/14.
//
import UIKit

extension CIImage {
    func resize(as size: CGSize) -> CIImage {
        let selfSize = extent.size
        let transform = CGAffineTransform(scaleX: size.width / selfSize.width, y: size.height / selfSize.height)
        return transformed(by: transform)
    }
}

extension CIImage {
    func toCGImage() -> CGImage? {
        let context = { CIContext(options: nil) }()
        return context.createCGImage(self, from: self.extent)
    }

    func toUIImage(orientation: UIImage.Orientation) -> UIImage? {
        guard let cgImage = self.toCGImage() else { return nil }
        return UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
}
