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
