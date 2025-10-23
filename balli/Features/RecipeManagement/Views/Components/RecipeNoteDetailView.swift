//
//  RecipeNoteDetailView.swift
//  balli
//
//  Full-screen modal to display balli's recipe notes
//  Uses markdown rendering for formatted content
//

import SwiftUI

/// Modal view to display the full AI-generated recipe note
struct RecipeNoteDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let note: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Note content with markdown support
                    MarkdownText(
                        content: note,
                        fontSize: 17,
                        enableSelection: true,
                        sourceCount: 0,
                        sources: [],
                        headerFontSize: 17 * 1.8,
                        fontName: "Manrope",
                        headerFontName: "Playfair Display"
                    )
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
            .background(Color(.secondarySystemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if title == "balli'nin notu" {
                        BalliNoteTitle(size: 20)
                    } else {
                        Text(title)
                            .font(.sfRounded(20, weight: .semiBold))
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28, weight: .regular, design: .rounded))
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Recipe Note Detail") {
    RecipeNoteDetailView(
        title: "balli'nin notu",
        note: """
        Dilara'cım, bu tarif tam sana göre! Kırmızı mercimek hem doyurucu hem de kan şekerini dengelemede harika bir yardımcı.

        ## Neden Bu Tarif Özel?

        - **Düşük Glisemik İndeks**: Mercimek, lif açısından zengin olduğu için kan şekerine yavaş geçer
        - **Protein Deposu**: Bir porsiyonda yaklaşık 18g protein var
        - **Kolay Hazırlık**: 30 dakikada hazır olur

        ## İpuçları

        Pişirirken biraz limon suyu ekle, demir emilimini artırır. Afiyet olsun! 💜
        """
    )
}

#Preview("Short Note") {
    RecipeNoteDetailView(
        title: "balli'nin notu",
        note: "Bu tarif kan şekerine çok uygun, tereddütsüz deneyebilirsin!"
    )
}

#Preview("Long Note") {
    RecipeNoteDetailView(
        title: "balli'nin notu",
        note: """
        # Detaylı Analiz

        Dilara'cım, bu tarifte kullanılan malzemelerin her biri seninle paylaştığımız kan şekeri hedeflerine göre özenle seçilmiş.

        ## Besin Değerleri

        - **Karbonhidrat**: 45g (karmaşık karbonhidrat)
        - **Protein**: 18g
        - **Lif**: 12g
        - **Yağ**: 8g (sağlıklı yağlar)

        ## Glisemik Yük

        Bu tarifte kullanılan mercimek düşük glisemik indeksli bir besin. Bu, kan şekerinin yavaş ve kontrollü bir şekilde yükselmesini sağlar.

        ## Pişirme İpuçları

        1. Mercimekleri önceden ıslatmana gerek yok
        2. Pişirirken köpüğü alırsan daha berrak bir çorba elde edersin
        3. Limon eklemek hem lezzet verir hem de besin emilimini artırır

        ## Servis Önerisi

        Üzerine biraz taze nane ve limon rendesi ekleyebilirsin. Yanında tam buğday ekmeği ile servis yapabilirsin ama ölçülü ol!

        Afiyet olsun canım! 💜
        """
    )
}
