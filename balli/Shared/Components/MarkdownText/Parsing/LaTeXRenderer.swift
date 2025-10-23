//
//  LaTeXRenderer.swift
//  balli
//
//  Purpose: Render LaTeX mathematical notation to Unicode symbols
//  Converts LaTeX commands to proper mathematical Unicode characters
//  Pure Swift implementation - no external dependencies
//  Swift 6 strict concurrency compliant
//

import Foundation

/// LaTeX renderer for converting LaTeX math notation to Unicode
enum LaTeXRenderer {

    /// Render LaTeX content to Unicode mathematical symbols
    /// Supports common LaTeX commands and converts them to proper mathematical notation
    static func render(_ latex: String) -> String {
        var result = latex

        // First, handle \text{...} commands - extract text content
        // Must be done before other replacements to avoid conflicts
        result = handleTextCommand(result)

        // Handle LaTeX spacing commands before symbol replacements
        result = result.replacingOccurrences(of: "\\ ", with: " ")  // Backslash-space → regular space
        result = result.replacingOccurrences(of: "\\,", with: " ")  // Thin space → regular space
        result = result.replacingOccurrences(of: "\\:", with: " ")  // Medium space → regular space
        result = result.replacingOccurrences(of: "\\;", with: " ")  // Thick space → regular space
        result = result.replacingOccurrences(of: "\\quad", with: "  ") // Quad space → double space
        result = result.replacingOccurrences(of: "\\qquad", with: "    ") // Double quad → quad space
        result = result.replacingOccurrences(of: "\\space", with: " ") // \space → regular space

        // Common LaTeX commands mapped to Unicode
        let latexReplacements: [(String, String)] = [
            // Greek letters (lowercase)
            ("\\\\alpha", "α"), ("\\\\beta", "β"), ("\\\\gamma", "γ"), ("\\\\delta", "δ"),
            ("\\\\epsilon", "ε"), ("\\\\zeta", "ζ"), ("\\\\eta", "η"), ("\\\\theta", "θ"),
            ("\\\\iota", "ι"), ("\\\\kappa", "κ"), ("\\\\lambda", "λ"), ("\\\\mu", "μ"),
            ("\\\\nu", "ν"), ("\\\\xi", "ξ"), ("\\\\pi", "π"), ("\\\\rho", "ρ"),
            ("\\\\sigma", "σ"), ("\\\\tau", "τ"), ("\\\\upsilon", "υ"), ("\\\\phi", "φ"),
            ("\\\\chi", "χ"), ("\\\\psi", "ψ"), ("\\\\omega", "ω"),

            // Greek letters (uppercase)
            ("\\\\Alpha", "Α"), ("\\\\Beta", "Β"), ("\\\\Gamma", "Γ"), ("\\\\Delta", "Δ"),
            ("\\\\Epsilon", "Ε"), ("\\\\Zeta", "Ζ"), ("\\\\Eta", "Η"), ("\\\\Theta", "Θ"),
            ("\\\\Iota", "Ι"), ("\\\\Kappa", "Κ"), ("\\\\Lambda", "Λ"), ("\\\\Mu", "Μ"),
            ("\\\\Nu", "Ν"), ("\\\\Xi", "Ξ"), ("\\\\Pi", "Π"), ("\\\\Rho", "Ρ"),
            ("\\\\Sigma", "Σ"), ("\\\\Tau", "Τ"), ("\\\\Upsilon", "Υ"), ("\\\\Phi", "Φ"),
            ("\\\\Chi", "Χ"), ("\\\\Psi", "Ψ"), ("\\\\Omega", "Ω"),

            // Mathematical operators
            ("\\\\times", "×"), ("\\\\div", "÷"), ("\\\\pm", "±"), ("\\\\mp", "∓"),
            ("\\\\cdot", "·"), ("\\\\ast", "∗"), ("\\\\star", "⋆"),
            ("\\\\circ", "∘"), ("\\\\bullet", "•"),

            // Relations
            ("\\\\leq", "≤"), ("\\\\geq", "≥"), ("\\\\neq", "≠"), ("\\\\approx", "≈"),
            ("\\\\equiv", "≡"), ("\\\\sim", "∼"), ("\\\\simeq", "≃"), ("\\\\cong", "≅"),
            ("\\\\propto", "∝"), ("\\\\ll", "≪"), ("\\\\gg", "≫"),

            // Arrows
            ("\\\\to", "→"), ("\\\\rightarrow", "→"), ("\\\\leftarrow", "←"),
            ("\\\\leftrightarrow", "↔"), ("\\\\Rightarrow", "⇒"), ("\\\\Leftarrow", "⇐"),
            ("\\\\Leftrightarrow", "⇔"), ("\\\\uparrow", "↑"), ("\\\\downarrow", "↓"),

            // Set theory
            ("\\\\in", "∈"), ("\\\\notin", "∉"), ("\\\\subset", "⊂"), ("\\\\supset", "⊃"),
            ("\\\\subseteq", "⊆"), ("\\\\supseteq", "⊇"), ("\\\\cup", "∪"), ("\\\\cap", "∩"),
            ("\\\\emptyset", "∅"), ("\\\\forall", "∀"), ("\\\\exists", "∃"),

            // Calculus
            ("\\\\int", "∫"), ("\\\\iint", "∬"), ("\\\\iiint", "∭"),
            ("\\\\oint", "∮"), ("\\\\partial", "∂"), ("\\\\nabla", "∇"),
            ("\\\\infty", "∞"), ("\\\\sum", "∑"), ("\\\\prod", "∏"),

            // Logic
            ("\\\\neg", "¬"), ("\\\\wedge", "∧"), ("\\\\vee", "∨"),
            ("\\\\implies", "⟹"), ("\\\\iff", "⟺"),

            // Miscellaneous
            ("\\\\angle", "∠"), ("\\\\perp", "⊥"), ("\\\\parallel", "∥"),
            ("\\\\sqrt", "√"), ("\\\\degree", "°"), ("\\\\therefore", "∴"),
            ("\\\\because", "∵"), ("\\\\ldots", "…"), ("\\\\cdots", "⋯")
        ]

        // Apply replacements
        for (latexCommand, unicode) in latexReplacements {
            result = result.replacingOccurrences(of: latexCommand, with: unicode, options: .regularExpression)
        }

        // Handle fractions \frac{a}{b}
        result = handleFractions(result)

        // Handle superscripts ^{text} or ^x
        result = handleSuperscripts(result)

        // Handle subscripts _{text} or _x
        result = handleSubscripts(result)

        // Handle square roots \sqrt{x}
        result = handleSquareRoots(result)

        // Remove remaining backslashes for unsupported commands
        // BUT keep braces for unhandled LaTeX - they're less confusing than raw backslashes
        // Only remove backslash if followed by a word character (LaTeX command)
        result = result.replacingOccurrences(of: "\\\\([a-zA-Z]+)", with: "$1", options: .regularExpression)

        // Remove standalone backslashes (not part of commands)
        result = result.replacingOccurrences(of: "\\", with: "")

        return result
    }

    // MARK: - Private Helper Methods

    /// Handle fractions \frac{numerator}{denominator}
    /// Uses manual parsing to handle nested braces correctly
    private static func handleFractions(_ text: String) -> String {
        var result = text

        // Manual parsing for \frac with brace counting for nested content
        while let fracStart = result.range(of: "\\frac{") {
            var pos = fracStart.upperBound
            var braceDepth = 1
            var numerator = ""

            // Extract numerator with brace counting
            while pos < result.endIndex && braceDepth > 0 {
                let char = result[pos]
                if char == "{" {
                    braceDepth += 1
                    numerator.append(char)
                } else if char == "}" {
                    braceDepth -= 1
                    if braceDepth > 0 {
                        numerator.append(char)
                    }
                } else {
                    numerator.append(char)
                }
                pos = result.index(after: pos)
            }

            // Check for opening brace of denominator
            guard pos < result.endIndex && result[pos] == "{" else {
                break // Malformed fraction
            }

            pos = result.index(after: pos) // Skip opening {
            braceDepth = 1
            var denominator = ""

            // Extract denominator with brace counting
            while pos < result.endIndex && braceDepth > 0 {
                let char = result[pos]
                if char == "{" {
                    braceDepth += 1
                    denominator.append(char)
                } else if char == "}" {
                    braceDepth -= 1
                    if braceDepth > 0 {
                        denominator.append(char)
                    }
                } else {
                    denominator.append(char)
                }
                pos = result.index(after: pos)
            }

            // Replace the fraction
            let fraction = "(\(numerator))/(\(denominator))"
            let replaceRange = fracStart.lowerBound..<pos
            result.replaceSubrange(replaceRange, with: fraction)
        }

        return result
    }

    /// Handle superscripts (exponents) ^{text} or ^x
    private static func handleSuperscripts(_ text: String) -> String {
        var result = text

        // Handle ^{text}
        let bracedPattern = #"\^\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: bracedPattern) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange).reversed()

            for match in matches {
                if match.numberOfRanges == 2,
                   let contentRange = Range(match.range(at: 1), in: result),
                   let fullRange = Range(match.range(at: 0), in: result) {

                    let content = String(result[contentRange])
                    let superscript = convertToSuperscript(content)
                    result.replaceSubrange(fullRange, with: superscript)
                }
            }
        }

        // Handle ^x (single character)
        let singlePattern = #"\^([a-zA-Z0-9])"#
        if let regex = try? NSRegularExpression(pattern: singlePattern) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange).reversed()

            for match in matches {
                if match.numberOfRanges == 2,
                   let charRange = Range(match.range(at: 1), in: result),
                   let fullRange = Range(match.range(at: 0), in: result) {

                    let char = String(result[charRange])
                    let superscript = convertToSuperscript(char)
                    result.replaceSubrange(fullRange, with: superscript)
                }
            }
        }

        return result
    }

    /// Handle subscripts _{text} or _x
    private static func handleSubscripts(_ text: String) -> String {
        var result = text

        // Handle _{text}
        let bracedPattern = #"_\{([^}]+)\}"#
        if let regex = try? NSRegularExpression(pattern: bracedPattern) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange).reversed()

            for match in matches {
                if match.numberOfRanges == 2,
                   let contentRange = Range(match.range(at: 1), in: result),
                   let fullRange = Range(match.range(at: 0), in: result) {

                    let content = String(result[contentRange])
                    let subscript_ = convertToSubscript(content)
                    result.replaceSubrange(fullRange, with: subscript_)
                }
            }
        }

        // Handle _x (single character)
        let singlePattern = #"_([a-zA-Z0-9])"#
        if let regex = try? NSRegularExpression(pattern: singlePattern) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange).reversed()

            for match in matches {
                if match.numberOfRanges == 2,
                   let charRange = Range(match.range(at: 1), in: result),
                   let fullRange = Range(match.range(at: 0), in: result) {

                    let char = String(result[charRange])
                    let subscript_ = convertToSubscript(char)
                    result.replaceSubrange(fullRange, with: subscript_)
                }
            }
        }

        return result
    }

    /// Handle square roots \sqrt{x}
    private static func handleSquareRoots(_ text: String) -> String {
        var result = text
        let pattern = #"\\sqrt\{([^}]+)\}"#

        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsRange = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, range: nsRange).reversed()

            for match in matches {
                if match.numberOfRanges == 2,
                   let contentRange = Range(match.range(at: 1), in: result),
                   let fullRange = Range(match.range(at: 0), in: result) {

                    let content = String(result[contentRange])
                    let sqrt = "√(\(content))"
                    result.replaceSubrange(fullRange, with: sqrt)
                }
            }
        }

        return result
    }

    /// Handle \text{...} commands - extract text content without the command
    private static func handleTextCommand(_ text: String) -> String {
        var result = text
        let pattern = #"\\text\{([^}]*)\}"#

        // Use a loop to handle nested replacements
        var maxIterations = 10 // Prevent infinite loops
        while maxIterations > 0 {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsRange = NSRange(result.startIndex..., in: result)
                let matches = regex.matches(in: result, range: nsRange)

                if matches.isEmpty {
                    break // No more matches
                }

                // Process matches in reverse to maintain string indices
                for match in matches.reversed() {
                    if match.numberOfRanges == 2,
                       let contentRange = Range(match.range(at: 1), in: result),
                       let fullRange = Range(match.range(at: 0), in: result) {

                        let content = String(result[contentRange])
                        result.replaceSubrange(fullRange, with: content)
                    }
                }
            }
            maxIterations -= 1
        }

        return result
    }

    /// Convert text to Unicode superscript characters
    private static func convertToSuperscript(_ text: String) -> String {
        let superscriptMap: [Character: String] = [
            "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
            "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
            "+": "⁺", "-": "⁻", "=": "⁼", "(": "⁽", ")": "⁾",
            "a": "ᵃ", "b": "ᵇ", "c": "ᶜ", "d": "ᵈ", "e": "ᵉ",
            "f": "ᶠ", "g": "ᵍ", "h": "ʰ", "i": "ⁱ", "j": "ʲ",
            "k": "ᵏ", "l": "ˡ", "m": "ᵐ", "n": "ⁿ", "o": "ᵒ",
            "p": "ᵖ", "r": "ʳ", "s": "ˢ", "t": "ᵗ", "u": "ᵘ",
            "v": "ᵛ", "w": "ʷ", "x": "ˣ", "y": "ʸ", "z": "ᶻ"
        ]

        return text.map { superscriptMap[$0] ?? String($0) }.joined()
    }

    /// Convert text to Unicode subscript characters
    private static func convertToSubscript(_ text: String) -> String {
        let subscriptMap: [Character: String] = [
            "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
            "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
            "+": "₊", "-": "₋", "=": "₌", "(": "₍", ")": "₎",
            "a": "ₐ", "e": "ₑ", "h": "ₕ", "i": "ᵢ", "j": "ⱼ",
            "k": "ₖ", "l": "ₗ", "m": "ₘ", "n": "ₙ", "o": "ₒ",
            "p": "ₚ", "r": "ᵣ", "s": "ₛ", "t": "ₜ", "u": "ᵤ",
            "v": "ᵥ", "x": "ₓ"
        ]

        return text.map { subscriptMap[$0] ?? String($0) }.joined()
    }
}
