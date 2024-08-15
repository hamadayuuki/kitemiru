//
//  HomeView.swift
//  kitemiru
//
//  Created by 濵田　悠樹 on 2024/08/15.
//

import SwiftUI

struct HomeView: View {
    @State private var selection: ViewType = .kitemiru

    var body: some View {
        VStack(spacing: 24) {
            Picker("View", selection: self.$selection) {
                Text("kitemiru").tag(ViewType.kitemiru)
                Text("pickup").tag(ViewType.pickup)
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(height: 20)
            .padding(.horizontal, 24)

            switch selection {
            case .kitemiru:
                View01()
            case .pickup:
                View02()
            }
        }
        .frame(height: 600, alignment: .top)
    }
}

enum ViewType {
    case kitemiru
    case pickup
}

#Preview {
    HomeView()
}
