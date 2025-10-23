//
//  BalliTextView.swift
//  balli
//
//  Custom text view for "balli" branding with Galano font
//

import SwiftUI

struct BalliTextView: View {
    let size: CGFloat
    let weight: FontWeight
    
    enum FontWeight {
        case regular
        case medium
        case semiBold
        
        var fontName: String {
            switch self {
            case .regular:
                return "GalanoGrotesqueAlt-Regular"
            case .medium:
                return "GalanoGrotesqueAlt-Medium"
            case .semiBold:
                return "GalanoGrotesqueAlt-SemiBold"
            }
        }
    }
    
    init(size: CGFloat = 17, weight: FontWeight = .medium) {
        self.size = size
        self.weight = weight
    }
    
    var body: some View {
        Text("balli")
            .font(.custom(weight.fontName, size: size))
    }
}

// Custom Label for TabItem
struct BalliTabLabel: View {
    let systemImage: String
    
    var body: some View {
        VStack {
            Image(systemName: systemImage)
            BalliTextView(size: 10, weight: .medium)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BalliTextView(size: 34, weight: .semiBold)
        BalliTextView(size: 17, weight: .medium)
        BalliTextView(size: 10, weight: .regular)
    }
}