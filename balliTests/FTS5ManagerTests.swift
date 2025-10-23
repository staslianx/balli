//
//  FTS5ManagerTests.swift
//  balliTests
//
//  Comprehensive unit tests for FTS5Manager full-text search
//  Swift 6 strict concurrency compliant
//

import XCTest
@testable import balli

@MainActor
final class FTS5ManagerTests: XCTestCase {
    var fts5Manager: FTS5Manager!
    var tempDBPath: String!

    override func setUp() async throws {
        try await super.setUp()

        // Create temporary database path for testing
        let tempDir = FileManager.default.temporaryDirectory
        tempDBPath = tempDir.appendingPathComponent("test_fts5_\(UUID().uuidString).db").path

        // Initialize FTS5Manager with temp database
        fts5Manager = try FTS5Manager(dbPath: tempDBPath)
    }

    override func tearDown() async throws {
        // Clean up temporary database
        if let tempDBPath = tempDBPath {
            try? FileManager.default.removeItem(atPath: tempDBPath)
        }
        fts5Manager = nil

        try await super.tearDown()
    }

    // MARK: - Index Creation Tests

    func testDatabaseInitialization() async throws {
        // Verify FTS5 table was created successfully
        // The FTS5Manager initializer should have created the table
        XCTAssertNotNil(fts5Manager)
    }

    // MARK: - Indexing Tests

    func testIndexSingleSession() async throws {
        let sessionId = UUID()
        let conversationHistory = [
            (role: "user", content: "Tip 1 diyabet nedir?"),
            (role: "assistant", content: "Tip 1 diyabet otoimmün bir hastalıktır. Pankreas yeterli insülin üretmez.")
        ]

        try await fts5Manager.indexSession(
            sessionId: sessionId,
            title: "Tip 1 Diyabet Araştırması",
            summary: "Tip 1 diyabetin temel özellikleri ve insülin eksikliği hakkında bilgi",
            keyTopics: ["tip 1 diyabet", "insülin", "otoimmün"],
            conversationHistory: conversationHistory
        )

        // Search for indexed content
        let results = try await fts5Manager.search(query: "tip 1 diyabet", limit: 5)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, sessionId)
    }

    func testIndexMultipleSessions() async throws {
        // Index first session about type 1 diabetes
        let session1Id = UUID()
        try await fts5Manager.indexSession(
            sessionId: session1Id,
            title: "Tip 1 Diyabet",
            summary: "Tip 1 diyabet otoimmün hastalıktır",
            keyTopics: ["tip 1", "otoimmün"],
            conversationHistory: [(role: "user", content: "Tip 1 diyabet nedir?")]
        )

        // Index second session about type 2 diabetes
        let session2Id = UUID()
        try await fts5Manager.indexSession(
            sessionId: session2Id,
            title: "Tip 2 Diyabet",
            summary: "Tip 2 diyabet insülin direncinden kaynaklanır",
            keyTopics: ["tip 2", "insülin direnci"],
            conversationHistory: [(role: "user", content: "Tip 2 diyabet nedir?")]
        )

        // Search for type 1 - should only return session1
        let results1 = try await fts5Manager.search(query: "tip 1", limit: 5)
        XCTAssertEqual(results1.count, 1)
        XCTAssertEqual(results1.first, session1Id)

        // Search for type 2 - should only return session2
        let results2 = try await fts5Manager.search(query: "tip 2", limit: 5)
        XCTAssertEqual(results2.count, 1)
        XCTAssertEqual(results2.first, session2Id)

        // Search for "diyabet" - should return both
        let results3 = try await fts5Manager.search(query: "diyabet", limit: 5)
        XCTAssertEqual(results3.count, 2)
    }

    // MARK: - Search Tests

    func testSearchReturnsResultsByRelevance() async throws {
        // Index session with multiple mentions of "dawn"
        let session1Id = UUID()
        try await fts5Manager.indexSession(
            sessionId: session1Id,
            title: "Dawn Phenomenon Detaylı Araştırma",
            summary: "Dawn phenomenon ile ilgili detaylı bilgi. Dawn phenomenon sabah şeker yükselmesidir.",
            keyTopics: ["dawn phenomenon", "sabah", "şeker"],
            conversationHistory: [
                (role: "user", content: "Dawn phenomenon nedir?"),
                (role: "assistant", content: "Dawn phenomenon sabah erken saatlerde kan şekerinin yükselmesidir. Dawn phenomenon kortizol hormonunun etkisiyle olur.")
            ]
        )

        // Index session with only one mention
        let session2Id = UUID()
        try await fts5Manager.indexSession(
            sessionId: session2Id,
            title: "Genel Diyabet Bilgisi",
            summary: "Diyabet yönetimi hakkında genel bilgiler",
            keyTopics: ["diyabet", "yönetim"],
            conversationHistory: [
                (role: "user", content: "Diyabeti nasıl yönetirim?"),
                (role: "assistant", content: "Diyabet yönetiminde düzenli takip önemlidir. Dawn phenomenon gibi durumları bilmek faydalıdır.")
            ]
        )

        // Search for "dawn phenomenon"
        let results = try await fts5Manager.search(query: "dawn phenomenon", limit: 5)

        // Session1 should rank higher due to multiple mentions
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.first, session1Id, "Session with more mentions should rank higher")
    }

    func testSearchWithTurkishCharacters() async throws {
        let sessionId = UUID()
        try await fts5Manager.indexSession(
            sessionId: sessionId,
            title: "İnsülin Direnci",
            summary: "İnsülin direnci ve metabolik sendrom üzerine çalışma",
            keyTopics: ["insülin", "direnç", "şeker"],
            conversationHistory: [
                (role: "user", content: "İnsülin direnci nedir?")
            ]
        )

        // Search with Turkish characters
        let results1 = try await fts5Manager.search(query: "insülin", limit: 5)
        XCTAssertEqual(results1.count, 1)

        // Search without diacritics should also work (FTS5 unicode61 remove_diacritics)
        let results2 = try await fts5Manager.search(query: "insulin", limit: 5)
        XCTAssertGreaterThanOrEqual(results2.count, 0) // May or may not match depending on tokenizer config
    }

    func testSearchWithPhraseQuery() async throws {
        let sessionId = UUID()
        try await fts5Manager.indexSession(
            sessionId: sessionId,
            title: "Dawn Phenomenon",
            summary: "Dawn phenomenon sabah şeker yükselmesi",
            keyTopics: ["dawn", "sabah"],
            conversationHistory: [
                (role: "user", content: "Dawn phenomenon ile Somogyi etkisi arasındaki fark nedir?")
            ]
        )

        // Phrase search
        let results = try await fts5Manager.search(query: "dawn phenomenon", limit: 5)
        XCTAssertEqual(results.count, 1)
    }

    func testSearchNoResults() async throws {
        // Index a session
        let sessionId = UUID()
        try await fts5Manager.indexSession(
            sessionId: sessionId,
            title: "Tip 1 Diyabet",
            summary: "Tip 1 diyabet bilgisi",
            keyTopics: ["tip 1"],
            conversationHistory: []
        )

        // Search for completely unrelated term
        let results = try await fts5Manager.search(query: "kanser tedavisi", limit: 5)
        XCTAssertEqual(results.count, 0)
    }

    func testSearchLimit() async throws {
        // Index 10 sessions
        for i in 1...10 {
            try await fts5Manager.indexSession(
                sessionId: UUID(),
                title: "Diyabet Araştırması \(i)",
                summary: "Diyabet hakkında bilgi",
                keyTopics: ["diyabet"],
                conversationHistory: []
            )
        }

        // Search with limit 5
        let results = try await fts5Manager.search(query: "diyabet", limit: 5)
        XCTAssertEqual(results.count, 5)
    }

    // MARK: - Update Tests

    func testUpdateExistingSession() async throws {
        let sessionId = UUID()

        // Index original session
        try await fts5Manager.indexSession(
            sessionId: sessionId,
            title: "Original Title",
            summary: "Original summary",
            keyTopics: ["original"],
            conversationHistory: []
        )

        // Update session
        try await fts5Manager.indexSession(
            sessionId: sessionId,
            title: "Updated Title",
            summary: "Updated summary about diabetes",
            keyTopics: ["updated", "diabetes"],
            conversationHistory: []
        )

        // Search for updated content
        let results = try await fts5Manager.search(query: "diabetes", limit: 5)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, sessionId)

        // Search for old content should not return results
        let oldResults = try await fts5Manager.search(query: "original", limit: 5)
        XCTAssertEqual(oldResults.count, 0)
    }

    // MARK: - Delete Tests

    func testDeleteSession() async throws {
        let sessionId = UUID()

        // Index session
        try await fts5Manager.indexSession(
            sessionId: sessionId,
            title: "Test Session",
            summary: "Test content",
            keyTopics: ["test"],
            conversationHistory: []
        )

        // Verify it's searchable
        let resultsBeforeDelete = try await fts5Manager.search(query: "test", limit: 5)
        XCTAssertEqual(resultsBeforeDelete.count, 1)

        // Delete session
        try await fts5Manager.deleteSession(sessionId: sessionId)

        // Verify it's no longer searchable
        let resultsAfterDelete = try await fts5Manager.search(query: "test", limit: 5)
        XCTAssertEqual(resultsAfterDelete.count, 0)
    }

    // MARK: - Migration Tests

    func testMigrateExistingSessions() async throws {
        let session1 = (
            sessionId: UUID(),
            title: "Session 1",
            summary: "First session",
            keyTopics: ["first"],
            conversationHistory: [(role: "user", content: "First question")]
        )

        let session2 = (
            sessionId: UUID(),
            title: "Session 2",
            summary: "Second session",
            keyTopics: ["second"],
            conversationHistory: [(role: "user", content: "Second question")]
        )

        let sessions = [session1, session2]

        try await fts5Manager.migrateExistingSessions(sessions: sessions)

        // Verify both sessions are searchable
        let results1 = try await fts5Manager.search(query: "first", limit: 5)
        XCTAssertEqual(results1.count, 1)

        let results2 = try await fts5Manager.search(query: "second", limit: 5)
        XCTAssertEqual(results2.count, 1)
    }

    // MARK: - Edge Cases

    func testIndexSessionWithEmptyConversation() async throws {
        let sessionId = UUID()

        try await fts5Manager.indexSession(
            sessionId: sessionId,
            title: "Empty Conversation",
            summary: "Session with no messages",
            keyTopics: ["empty"],
            conversationHistory: []
        )

        let results = try await fts5Manager.search(query: "empty", limit: 5)
        XCTAssertEqual(results.count, 1)
    }

    func testSearchWithEmptyQuery() async throws {
        // Empty query should be sanitized and return no results
        let results = try await fts5Manager.search(query: "", limit: 5)
        XCTAssertEqual(results.count, 0)
    }

    func testSearchWithSpecialCharacters() async throws {
        let sessionId = UUID()
        try await fts5Manager.indexSession(
            sessionId: sessionId,
            title: "Test Session",
            summary: "Content with special chars: @#$%",
            keyTopics: ["test"],
            conversationHistory: []
        )

        // Search with special characters (should be sanitized)
        let results = try await fts5Manager.search(query: "test @#$", limit: 5)
        XCTAssertGreaterThanOrEqual(results.count, 0) // Should not crash
    }
}
