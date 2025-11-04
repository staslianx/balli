//
//  AboutView.swift
//  balli
//
//  About app information view
//  Swift 6 strict concurrency compliant
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack {
            Spacer()

            // Centered Balli text logo
            Image("balli-text-logo")
                .resizable()
                .scaledToFit()
                .frame(width: 200)

            Spacer()

            // Bottom Anaxonic Labs logo (smaller)
            Image("anaxonic-labs")
                .resizable()
                .scaledToFit()
                .frame(width: 250)
                .padding(.bottom, 0)
        }
        .navigationTitle("Hakkında")
        .navigationBarTitleDisplayMode(.inline)
    }
}
