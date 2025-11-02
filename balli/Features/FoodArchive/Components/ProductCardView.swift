//
//  ProductCardView.swift
//  balli
//
//  Reusable product card component
//

import SwiftUI

struct ProductCardView: View {
    let brand: String
    let name: String
    let portion: String
    let carbs: String
    let width: CGFloat?
    let height: CGFloat?
    let isFavorite: Bool
    let impactLevel: ImpactLevel?
    let onToggleFavorite: (() -> Void)?
    let onDelete: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme

    init(
        brand: String,
        name: String,
        portion: String,
        carbs: String,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        isFavorite: Bool = false,
        impactLevel: ImpactLevel? = nil,
        onToggleFavorite: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.brand = brand
        self.name = name
        self.portion = portion
        self.carbs = carbs
        self.width = width
        self.height = height
        self.isFavorite = isFavorite
        self.impactLevel = impactLevel
        self.onToggleFavorite = onToggleFavorite
        self.onDelete = onDelete
    }
    
    // Determine product category based on name and brand
    private func getCategoryIcon() -> String {
        // Check if it's a recipe card (brand is "Tarif")
        if brand.lowercased() == "tarif" {
            return "fork.knife"
        }
        
        let combinedText = "\(name.lowercased()) \(brand.lowercased())"
        
        // Check for snacks, chocolate, chips
        let snackKeywords = ["çikolata", "chocolate", "cips", "chips", "kraker", "cracker", 
                             "bisküvi", "biscuit", "cookie", "gofret", "wafer", "şeker", 
                             "candy", "jelibon", "marshmallow", "kek", "cake", "tatlı", "dessert",
                             "dondurma", "ice cream", "çubuk", "bar", "snack", "atıştırmalık"]
        for keyword in snackKeywords {
            if combinedText.contains(keyword) {
                return "sparkles"
            }
        }
        
        // Check for vegetables
        let vegetableKeywords = ["sebze", "vegetable", "salata", "salad", "domates", "tomato",
                                 "patates", "potato", "havuç", "carrot", "biber", "pepper",
                                 "patlıcan", "eggplant", "kabak", "zucchini", "squash", "ıspanak",
                                 "spinach", "marul", "lettuce", "brokoli", "broccoli", "lahana",
                                 "cabbage", "pırasa", "leek", "soğan", "onion", "sarımsak", "garlic"]
        for keyword in vegetableKeywords {
            if combinedText.contains(keyword) {
                return "carrot.fill"
            }
        }
        
        // Check for liquids/beverages
        let liquidKeywords = ["su", "water", "içecek", "drink", "beverage", "süt", "milk",
                             "ayran", "kola", "cola", "soda", "meyve suyu", "juice", "çay",
                             "tea", "kahve", "coffee", "şurup", "syrup", "sos", "sauce",
                             "yoğurt", "yogurt", "kefir", "smoothie", "shake", "limonata"]
        for keyword in liquidKeywords {
            if combinedText.contains(keyword) {
                return "drop.fill"
            }
        }
        
        // Check for recipes/meals
        let recipeKeywords = ["tarif", "recipe", "yemek", "meal", "dish", "pilav", "rice",
                             "makarna", "pasta", "çorba", "soup", "köfte", "meatball",
                             "döner", "kebap", "kebab", "pizza", "burger", "sandwich",
                             "omlet", "omelette", "börek", "pide", "lahmacun", "mantı"]
        for keyword in recipeKeywords {
            if combinedText.contains(keyword) {
                return "fork.knife"
            }
        }
        
        // Default icon for general food products
        return "cart.fill"
    }
    
    @MainActor
    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.height(8)) {
            // Top section with brand, name and icon
            HStack(alignment: .top, spacing: ResponsiveDesign.height(8)) {
                VStack(alignment: .leading, spacing: ResponsiveDesign.height(4)) {
                    // Product Brand - allow wrapping for wide cards (recipes)
                    Text(brand)
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(26), weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit((width ?? 0) > ResponsiveDesign.width(250) ? nil : 1)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: false, vertical: false)

                    // Product Name - allow wrapping for recipe cards
                    Text(name)
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(16), weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .lineLimit(3)  // Allow up to 3 lines for long recipe names
                        .multilineTextAlignment(.leading)
                        .minimumScaleFactor(0.85)  // Allow text to shrink slightly if needed
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Impact level icon or category icon - top right with proper spacing
                if let impactLevel = impactLevel {
                    Image(systemName: impactLevel.cardSymbolName)
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(20), weight: .semibold))
                        .foregroundColor(AppTheme.primaryPurple)
                        .frame(width: ResponsiveDesign.Font.scaledSize(24), height: ResponsiveDesign.Font.scaledSize(24), alignment: .center)
                } else {
                    Image(systemName: getCategoryIcon())
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(20)))
                        .foregroundColor(AppTheme.primaryPurple)
                        .frame(width: ResponsiveDesign.Font.scaledSize(24), height: ResponsiveDesign.Font.scaledSize(24), alignment: .center)
                }
            }
            
            // Only add spacer for square cards, not for wide recipe cards
            if (width ?? 0) < ResponsiveDesign.width(250) {
                Spacer()
            }
            
            // Bottom section with portion and carbs
            VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xSmall) {
                // Portion size
                Text(portion)
                    .font(.system(size: ResponsiveDesign.Font.scaledSize(14), weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)

                // Carb value with favorite icon aligned
                HStack(alignment: .center, spacing: ResponsiveDesign.Spacing.small) {
                    // Carb value - extract just the number with monospaced digits
                    Text(carbs.replacingOccurrences(of: " gr Karb.", with: "gr"))
                        .font(.system(size: ResponsiveDesign.Font.scaledSize(32), weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Spacer()

                    // Favorite indicator - aligned with carb value
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: ResponsiveDesign.Font.scaledSize(20)))
                            .foregroundColor(Color(red: 1, green: 0.85, blue: 0, opacity: 1))
                    }
                }
            }
        }
        .padding(ResponsiveDesign.height(20))
        .frame(width: width ?? ResponsiveDesign.Components.productCardSize,
               height: height ?? width ?? ResponsiveDesign.Components.productCardSize,
               alignment: .leading)
        .background(.clear)
        .contentShape(Rectangle())
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.card, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: ResponsiveDesign.height(8), x: 0, y: ResponsiveDesign.height(4))
        .contextMenu {
            // Favorite toggle button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    onToggleFavorite?()
                }
            }) {
                Label(
                    isFavorite ? "Favorilerden Çıkar" : "Favorilere Ekle",
                    systemImage: isFavorite ? "star.fill" : "star"
                )
            }

            // Delete button
            Button(role: .destructive, action: {
                onDelete?()
            }) {
                Label("Sil", systemImage: "trash")
            }
        }
    }
}

#Preview {
    ProductCardView(
        brand: "Delly",
        name: "Topçuk",
        portion: "100g'da",
        carbs: "30 gr Karb."
    )
}
