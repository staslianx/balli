//
//  PreviewMockData.swift
//  balli
//
//  Comprehensive mock data for Xcode previews
//  Swift 6 strict concurrency compliant
//

import Foundation
import SwiftUI

/// Centralized mock data for previews
@MainActor
enum PreviewMockData {

    // MARK: - Research Feature Mock Data

    enum Research {
        static let sampleSources: [ResearchSource] = [
            ResearchSource(
                id: "1",
                url: URL(string: "https://pubmed.ncbi.nlm.nih.gov/12345678")!,
                domain: "pubmed.ncbi.nlm.nih.gov",
                title: "Beta Cell Regeneration in Type 1 Diabetes: A Systematic Review",
                snippet: "Recent advances in beta cell regeneration show promising results for Type 1 diabetes treatment.",
                publishDate: Date().addingTimeInterval(-30*24*60*60), // 30 days ago
                author: "Smith et al.",
                credibilityBadge: .peerReviewed,
                faviconURL: URL(string: "https://www.google.com/s2/favicons?domain=pubmed.ncbi.nlm.nih.gov&sz=32")
            ),
            ResearchSource(
                id: "2",
                url: URL(string: "https://www.who.int/news/item/2024-01-15-diabetes-guidelines")!,
                domain: "who.int",
                title: "WHO Updates Diabetes Management Guidelines 2024",
                snippet: "World Health Organization releases updated guidelines for diabetes management and prevention.",
                publishDate: Date().addingTimeInterval(-60*24*60*60), // 60 days ago
                author: "World Health Organization",
                credibilityBadge: .government,
                faviconURL: URL(string: "https://www.google.com/s2/favicons?domain=who.int&sz=32")
            ),
            ResearchSource(
                id: "3",
                url: URL(string: "https://www.mayoclinic.org/diseases-conditions/diabetes/expert-answers")!,
                domain: "mayoclinic.org",
                title: "Managing Blood Sugar Levels: Expert Answers",
                snippet: "Mayo Clinic experts provide comprehensive answers about blood sugar management.",
                publishDate: Date().addingTimeInterval(-15*24*60*60), // 15 days ago
                author: "Mayo Clinic Staff",
                credibilityBadge: .medicalSource,
                faviconURL: URL(string: "https://www.google.com/s2/favicons?domain=mayoclinic.org&sz=32")
            ),
            ResearchSource(
                id: "4",
                url: URL(string: "https://scholar.google.com/citations/12345")!,
                domain: "scholar.google.com",
                title: "Advances in Continuous Glucose Monitoring Technology",
                snippet: "Latest research on CGM accuracy and real-time glucose tracking systems.",
                publishDate: Date().addingTimeInterval(-7*24*60*60), // 7 days ago
                author: "Johnson, M.D., et al.",
                credibilityBadge: .academic,
                faviconURL: URL(string: "https://www.google.com/s2/favicons?domain=scholar.google.com&sz=32")
            ),
            ResearchSource(
                id: "5",
                url: URL(string: "https://www.healthline.com/health/diabetes/low-gi-foods")!,
                domain: "healthline.com",
                title: "Low Glycemic Index Foods for Better Blood Sugar Control",
                snippet: "A comprehensive guide to choosing foods with low glycemic impact.",
                publishDate: Date().addingTimeInterval(-3*24*60*60), // 3 days ago
                author: "Healthline Medical Team",
                credibilityBadge: .medicalSource,
                faviconURL: URL(string: "https://www.google.com/s2/favicons?domain=healthline.com&sz=32")
            )
        ]

        static let shortAnswer = SearchAnswer(
            query: "What are the best foods for Type 1 diabetes?",
            content: "For Type 1 diabetes management, focus on **low glycemic index foods** [1] that help maintain stable blood sugar levels:\n\n### Key Food Groups:\n- **Whole grains**: Brown rice, quinoa, oats [2]\n- **Lean proteins**: Chicken, fish, tofu [3]\n- **Non-starchy vegetables**: Leafy greens, broccoli, peppers [4]\n- **Healthy fats**: Avocado, nuts, olive oil [5]\n\nAlways count carbohydrates accurately and adjust insulin accordingly.",
            sources: Array(sampleSources.prefix(5)),
            citations: [],
            timestamp: Date(),
            tokenCount: 247,
            tier: .search
        )

        static let longAnswerWithProTier = SearchAnswer(
            query: "What are the latest research developments in beta cell regeneration for Type 1 diabetes?",
            content: """
## Recent Advances in Beta Cell Regeneration

Beta cell regeneration represents one of the most promising frontiers in Type 1 diabetes research [1]. Recent studies have identified several groundbreaking approaches that could potentially restore insulin production in people with Type 1 diabetes.

### Stem Cell Therapy Approaches

Researchers have made significant progress in converting **pluripotent stem cells** into functional beta cells [2]. Clinical trials are currently underway to test the safety and efficacy of these approaches:

- **Encapsulated cell therapy**: Protecting transplanted cells from immune attack [3]
- **Gene-edited cells**: Creating immune-resistant beta cells [4]
- **Organoid technology**: Growing mini-pancreases in the lab [5]

### Small Molecule Drugs

New drug candidates have shown promise in stimulating beta cell proliferation [1]:

1. **Harmine derivatives**: Promote beta cell replication without side effects
2. **GLP-1 receptor agonists**: May have regenerative properties beyond glucose control
3. **TGF-β inhibitors**: Remove molecular brakes on beta cell growth

### Immunotherapy Integration

The future of beta cell regeneration likely involves **combination therapy** [2]:
- Regenerating beta cells
- Protecting them from autoimmune attack
- Maintaining long-term insulin independence

### Clinical Trial Status

Several phase 2 clinical trials are recruiting participants [3]. Early results suggest that partial beta cell recovery is achievable, with some patients showing reduced insulin requirements.

### Timeline and Outlook

While a complete cure remains years away, incremental improvements are being made. Experts predict that by 2030, we may see **hybrid therapies** combining cell replacement with immunomodulation [4].

The key challenge remains preventing the immune system from destroying new beta cells, but recent advances in immune tolerance are providing new hope [5].
""",
            sources: sampleSources,
            citations: [],
            timestamp: Date(),
            tokenCount: 1247,
            tier: .research
        )

        static let streamingAnswer = SearchAnswer(
            query: "How does exercise affect blood sugar in Type 1 diabetes?",
            content: "Exercise has complex effects on blood sugar in Type 1 diabetes [1]. Both aerobic and resistance training can",
            sources: Array(sampleSources.prefix(3)),
            citations: [],
            timestamp: Date(),
            tokenCount: 45,
            tier: .search
        )

        static let emptySourcesAnswer = SearchAnswer(
            query: "Tell me about carb counting",
            content: "Carbohydrate counting is a meal planning approach that focuses on tracking the grams of carbohydrates you eat. This helps you match your insulin doses to the amount of carbs in your meals.\n\nThe basic principle is that 1 unit of rapid-acting insulin typically covers 10-15 grams of carbohydrates, though this ratio varies by individual.",
            sources: [],
            citations: [],
            timestamp: Date(),
            tokenCount: 120,
            tier: .model
        )

        static let errorAnswer = SearchAnswer(
            query: "Complex medical query that failed",
            content: "",
            sources: [],
            citations: [],
            timestamp: Date(),
            tokenCount: 0,
            tier: nil
        )

        // Comprehensive markdown test content
        static let markdownTestAnswer = SearchAnswer(
            query: "Test all markdown features",
            content: """
## Markdown Feature Test

### Text Formatting
This paragraph contains **bold text**, *italic text*, ***bold and italic***, ~~strikethrough text~~, and `inline code`.

### Code Blocks
Here's a Swift code example:

```swift
func calculateInsulin(carbs: Double, ratio: Double) -> Double {
    return carbs / ratio
}
```

And here's some JSON:

```json
{
  "glucose": 120,
  "unit": "mg/dL"
}
```

### Lists
#### Unordered List
- First item [1]
- Second item with **bold text**
- Third item with `inline code`
  - Nested item 1
  - Nested item 2
    - Deeply nested item

#### Ordered List
1. First numbered item
2. Second numbered item
3. Third numbered item [2]

### Blockquotes
> This is a blockquote with important medical information [3].

### Tables
| Food | Carbs (g) | Protein (g) | Fat (g) |
|:-----|:---------:|:-----------:|--------:|
| Apple | 25 | 0 | 0 |
| Chicken | 0 | 30 | 5 |
| Bread | 15 | 3 | 1 |

### Horizontal Rules
Content above

---

Content below

### Mixed Formatting
You can combine **bold with `inline code`** and *italic with ~~strikethrough~~* in the same paragraph [4].

### Citations
Multiple citations can appear together [1, 2, 3] and work with all formatting.
""",
            sources: Array(sampleSources.prefix(4)),
            citations: [],
            timestamp: Date(),
            tokenCount: 450,
            tier: .search
        )
    }

    // MARK: - Shopping List Mock Data

    enum Shopping {
        // Add shopping list mock data here when implementing those previews
    }

    // MARK: - Camera/Food Entry Mock Data

    enum Camera {
        // Add camera and food entry mock data here
    }

    // MARK: - Health/Glucose Mock Data

    enum Health {
        // Add glucose and health data mocks here
    }
}

// MARK: - Preview Container for Dependencies

/// Container for mock dependencies in previews
@MainActor
struct PreviewContainer {
    /// Mock medical research view model for previews
    static func mockSearchViewModel(
        withAnswers: [SearchAnswer] = [],
        isSearching: Bool = false,
        currentTier: ResponseTier? = nil
    ) -> MedicalResearchViewModel {
        let viewModel = MedicalResearchViewModel()
        // Note: In real implementation, you'd need to expose a way to set these for testing
        // For now, this serves as documentation of what states we want to preview
        return viewModel
    }
}

// MARK: - Preview Trait Extensions
// Note: Custom preview traits are not needed with iOS 26 #Preview macro
// Use traits parameter directly in #Preview, e.g.:
// #Preview(traits: .landscapeLeft) { ... }
// #Preview("Dark Mode", traits: .init(.preferredColorScheme(.dark))) { ... }

// MARK: - Common Preview Modifiers

extension View {
    /// Wrap in NavigationStack for preview
    @MainActor
    func previewInNavigation() -> some View {
        NavigationStack {
            self
        }
    }

    /// Add padding for component preview
    @MainActor
    func previewWithPadding() -> some View {
        self.padding()
    }

    /// Show in both light and dark mode
    @MainActor
    func previewInBothModes() -> some View {
        Group {
            self
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")

            self
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
