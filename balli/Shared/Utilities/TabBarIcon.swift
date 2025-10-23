//
//  TabBarIcon.swift
//  balli
//
//  Custom tab bar icon helper for proper sizing
//

import SwiftUI

struct TabBarIcon: View {
    let imageName: String
    let text: String
    
    var body: some View {
        VStack(spacing: 2) {
            Image(imageName)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 25, height: 25)
            Text(text)
                .font(.system(size: 10))
        }
    }
}

// Extension to create properly sized tab icons
extension Image {
    func tabBarIconStyle() -> some View {
        self
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
    }
}