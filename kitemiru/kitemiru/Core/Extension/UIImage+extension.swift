//
//  UIImage+extension.swift
//  kitemiru
//
//  Created by 濵田　悠樹 on 2024/08/17.
//

import UIKit

extension UIImage {
    func composite(image: UIImage) -> UIImage? {

        UIGraphicsBeginImageContextWithOptions(self.size, false, 0)
        self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))

        // 画像を真ん中に重ねる
        let rect = CGRect(x: (self.size.width - image.size.width)/2,
                          y: (self.size.height - image.size.height)/2,
                          width: image.size.width,
                          height: image.size.height)
        image.draw(in: rect)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image
    }
}
