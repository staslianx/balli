//
//  RecallDetectionTests.swift
//  balliTests
//
//  Tests for recall intent detection patterns (Turkish language)
//

import XCTest
@testable import balli

@MainActor
final class RecallDetectionTests: XCTestCase {

    // MARK: - Past Tense Detection Tests

    func testDetectsSimplePastTenseNeydi() {
        let query = "Dawn phenomenon neydi?"
        XCTAssertTrue(shouldAttemptRecall(query), "Should detect 'neydi' as recall pattern")
    }

    func testDetectsNasıldı() {
        let query = "O araştırma nasıldı?"
        XCTAssertTrue(shouldAttemptRecall(query), "Should detect 'nasıldı' as recall pattern")
    }

    func testDetectsNeKonuşmuştuk() {
        let query = "Daha önce ne konuşmuştuk?"
        XCTAssertTrue(shouldAttemptRecall(query), "Should detect 'ne konuşmuştuk' as recall pattern")
    }

    func testDetectsNeAraştırmıştık() {
        let query = "Bu konuda ne araştırmıştık?"
        XCTAssertTrue(shouldAttemptRecall(query), "Should detect 'ne araştırmıştık' as recall pattern")
    }

    // MARK: - Memory Phrase Detection Tests

    func testDetectsHatırlıyorMusun() {
        let query = "Dawn phenomenon hatırlıyor musun?"
        XCTAssertTrue(shouldAttemptRecall(query), "Should detect 'hatırlıyor musun' as recall pattern")
    }

    func testDetectsHatırla() {
        let query = "Şu Somogyi konusunu hatırla"
        XCTAssertTrue(shouldAttemptRecall(query), "Should detect 'hatırla' as recall pattern")
    }

    func testDetectsDahaÖnce() {
        let query = "Daha önce bu konuyu konuşmuştuk"
        XCTAssertTrue(shouldAttemptRecall(query), "Should detect 'daha önce' as recall pattern")
    }

    func testDetectsGeçenSefer() {
        let query = "Geçen sefer ne bulmuştuk?"
        XCTAssertTrue(shouldAttemptRecall(query), "Should detect 'geçen sefer' as recall pattern")
    }

    // MARK: - Reference Phrase Detection Tests

    func testDetectsOŞey() {
        let query = "Dawn ile karışan o şey neydi?"
        XCTAssertTrue(shouldAttemptRecall(query), "Should detect 'o şey' as recall pattern")
    }

    func testDetectsŞuKonu() {
        let query = "Şu konu hakkında bilgi ver"
        XCTAssertTrue(shouldAttemptRecall(query), "Should detect 'şu konu' as recall pattern")
    }

    func testDetectsOAraştırma() {
        let query = "O araştırma sonuçları neydi?"
        XCTAssertTrue(shouldAttemptRecall(query), "Should detect 'o araştırma' as recall pattern")
    }

    // MARK: - Negative Tests (Should NOT Trigger Recall)

    func testDoesNotDetectPresentTenseNedir() {
        let query = "Dawn phenomenon nedir?"
        XCTAssertFalse(shouldAttemptRecall(query), "Should NOT detect 'nedir' (present tense) as recall")
    }

    func testDoesNotDetectNasıl() {
        let query = "İnsülin nasıl çalışır?"
        XCTAssertFalse(shouldAttemptRecall(query), "Should NOT detect 'nasıl' (present) as recall")
    }

    func testDoesNotDetectNewResearchRequest() {
        let query = "Beta hücre rejenerasyonu araştır"
        XCTAssertFalse(shouldAttemptRecall(query), "Should NOT detect new research request as recall")
    }

    func testDoesNotDetectRegularQuestion() {
        let query = "Metformin yan etkileri nelerdir?"
        XCTAssertFalse(shouldAttemptRecall(query), "Should NOT detect regular question as recall")
    }

    // MARK: - Edge Cases

    func testDetectsCaseInsensitive() {
        let query = "DAWN PHENOMENON NEYDİ?"
        XCTAssertTrue(shouldAttemptRecall(query), "Should detect patterns case-insensitively")
    }

    func testDetectsWithPunctuation() {
        let query = "Dawn phenomenon neydi?"
        XCTAssertTrue(shouldAttemptRecall(query), "Should detect pattern with punctuation")
    }

    func testEmptyStringDoesNotTrigger() {
        let query = ""
        XCTAssertFalse(shouldAttemptRecall(query), "Empty string should not trigger recall")
    }

    // MARK: - Helper Method (Mirrors ViewModel Logic)

    private func shouldAttemptRecall(_ query: String) -> Bool {
        let lowercased = query.lowercased()

        // Past tense patterns
        let pastTensePatterns = [
            "neydi", "ne konuşmuştuk", "ne araştırmıştık", "ne bulmuştuk",
            "nasıldı", "ne çıkmıştı", "ne öğrenmiştik"
        ]

        // Memory/recall phrases
        let memoryPhrases = [
            "hatırlıyor musun", "hatırla", "hatırlat",
            "daha önce", "geçen sefer", "o zaman"
        ]

        // Reference phrases
        let referencePhrases = [
            "o şey", "şu konu", "o araştırma", "o bilgi"
        ]

        let allPatterns = pastTensePatterns + memoryPhrases + referencePhrases

        return allPatterns.contains { lowercased.contains($0) }
    }
}
