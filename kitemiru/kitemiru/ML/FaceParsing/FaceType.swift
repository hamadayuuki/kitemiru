//
//  FaceType.swift
//  kitemiru
//
//  Created by 濵田　悠樹 on 2024/08/15.
//

enum FaceType: Int, CaseIterable {
    typealias RawValue = Int
    case all = 0
    case skin = 1
    case eyeBrowLeft = 2
    case eyeBrowRight = 3
    case eyeLeft = 4
    case eyeRight = 5
    case nose = 10
    case teeth = 11
    case lipUpper = 12
    case lipLower = 13
    case neck = 14
    case cloth = 16
    case hair = 17
    case hat = 18
}
