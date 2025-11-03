//
//  ShoppingListItemRow.swift
//  balli
//
//  Individual shopping list item row with check/uncheck, notes, and swipe-to-delete
//

import SwiftUI

struct ShoppingListItemRow: View {
    let item: ShoppingListItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    @State private var showingNotes = false
    
    private var isCompleted: Bool {
        item.isCompleted
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main item row
            HStack(spacing: ResponsiveDesign.Spacing.small) {
                // Checkbox
                Button(action: onToggle) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isCompleted ? AppTheme.success : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isCompleted)
                
                // Item content
                VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xxSmall) {
                    // Item name and quantity
                    HStack {
                        Text(item.displayName)
                            .font(.system(size: 25, weight: .semibold, design: .rounded))
                            .foregroundColor(isCompleted ? .secondary : .primary)
                            .strikethrough(isCompleted)
                            .animation(.easeInOut(duration: 0.2), value: isCompleted)

                        Spacer()

                        // Category icon
                        Text(item.categoryIcon)
                            .font(.caption)
                    }

                    // Category and brand
                    HStack {
                        Text(item.displayCategory)
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)

                        if let brand = item.brand, !brand.isEmpty {
                            Text("• \(brand)")
                                .font(.system(size: 9, weight: .regular, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Notes indicator
                        if item.hasNotes {
                            Button(action: {
                                withAnimation(.spring()) {
                                    showingNotes.toggle()
                                }
                            }) {
                                Image(systemName: showingNotes ? "note.text.badge.plus" : "note.text")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.primaryPurple)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Edit button
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Completion date for completed items
                    if isCompleted, let completedDate = item.dateCompleted {
                        Text(completedDate, style: .relative)
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary.opacity(0.7))
                            .italic()
                    }
                }
                
                Spacer()
            }
            .padding(ResponsiveDesign.Spacing.medium)
            .background(
                RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium, style: .continuous)
                    .fill(isCompleted ? AppTheme.success.opacity(0.05) : .clear)
            )
            .glassEffect(
                isCompleted ? .regular : .regular.interactive(),
                in: RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium, style: .continuous)
            )
            .opacity(isCompleted ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.3), value: isCompleted)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                // Delete action
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                
                // Edit action
                Button(action: onEdit) {
                    Label("Düzenle", systemImage: "pencil")
                }
                .tint(AppTheme.primaryPurple)
            }
            
            // Notes section (expandable)
            if showingNotes && item.hasNotes {
                VStack(alignment: .leading, spacing: ResponsiveDesign.Spacing.xSmall) {
                    Divider()
                        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                    
                    HStack {
                        Image(systemName: "note.text")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("Notlar:")
                            .font(.system(size: 9, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)

                        Spacer()
                    }
                    .padding(.horizontal, ResponsiveDesign.Spacing.medium)

                    Text(item.notes ?? "")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, ResponsiveDesign.Spacing.medium)
                        .padding(.bottom, ResponsiveDesign.Spacing.small)
                }
                .background(
                    RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium, style: .continuous)
                        .fill(AppTheme.primaryPurple.opacity(0.05))
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .scale(scale: 0.95).combined(with: .opacity)
                ))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: ResponsiveDesign.CornerRadius.medium, style: .continuous))
    }
}

#Preview("Incomplete Item") {
    let context = PersistenceController.preview.container.viewContext
    let item = ShoppingListItem.create(
        name: "Süt",
        category: "Süt Ürünleri",
        quantity: "1 litre",
        notes: "Yarım yağlı olsun",
        in: context
    )
    
    VStack {
        ShoppingListItemRow(
            item: item,
            onToggle: { },
            onEdit: { },
            onDelete: { }
        )
        .padding()
    }
    .background(Color(.systemGray6))
}

#Preview("Completed Item") {
    let context = PersistenceController.preview.container.viewContext
    let item = ShoppingListItem.create(
        name: "Ekmek",
        category: "Tahıl & Ekmek",
        quantity: "2 adet",
        notes: "Tam buğday ekmeği",
        in: context
    )
    
    // Setup the item state
    let _ = {
        item.isCompleted = true
        item.dateCompleted = Date().addingTimeInterval(-3600) // 1 hour ago
    }()
    
    VStack {
        ShoppingListItemRow(
            item: item,
            onToggle: { },
            onEdit: { },
            onDelete: { }
        )
        .padding()
    }
    .background(Color(.systemGray6))
}