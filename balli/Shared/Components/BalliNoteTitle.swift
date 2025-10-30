//
//  BalliNoteTitle.swift
//  balli
//
//  Custom text view for "balli'nin notu" using two fonts:
//  - "balli" in Galano Grotesque Alt SemiBold
//  - "'nin notu" in Playfair Display Bold Italic
//

import SwiftUI

/// Title text that combines Galano and Playfair fonts for "balli'nin notu" or custom text
struct BalliNoteTitle: View {
    let size: CGFloat
    let customText: String?

    init(size: CGFloat = 17, customText: String? = nil) {
        self.size = size
        self.customText = customText
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("balli")
                .font(.custom("GalanoGrotesqueAlt-SemiBold", size: size))
                .offset(y:1.4)

            // Use custom text if provided, otherwise default to "'nin notu"
            if let customText = customText, customText == "balli'nin Tarif Analizi" {
                Text("'nin Tarif Analizi")
                    .font(.custom("Playfair Display", size: size))
                    .fontWeight(.bold)
                    .italic()
            } else {
                Text("'nin notu")
                    .font(.custom("Playfair Display", size: size))
                    .fontWeight(.bold)
                    .italic()
            }
        }
    }
}

#Preview("Different Sizes") {
    VStack(spacing: 20) {
        BalliNoteTitle(size: 34)
        BalliNoteTitle(size: 24)
        BalliNoteTitle(size: 17)
        BalliNoteTitle(size: 14)
    }
    .padding()
}

#Preview("In Context") {
    VStack(alignment: .leading, spacing: 8) {
        BalliNoteTitle(size: 16)
            .foregroundColor(.primary)

        Text("Dilara'cım, bu tarif tam sana göre...")
            .font(.sfRounded(14, weight: .regular))
            .foregroundColor(.secondary)
            .lineLimit(2)
    }
    .padding()
    .background(Color(.secondarySystemBackground))
}
