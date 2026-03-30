import Foundation
import SQLite3

struct SMSMessage {
    let rowID: Int64
    let text: String
    let sender: String
}

class SMSMonitor {
    private let dbPath: String
    private(set) var lastRowID: Int64 = 0

    // MARK: - Regex Patterns

    private static let codePattern: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: """
                (?:\
                (?:验证码|校验码|动态码|安全码|确认码|提取码|登录码|认证码)\
                |(?:verification\\s*code|security\\s*code|\
                confirm(?:ation)?\\s*code|\
                code\\s*is|code\\s*[:：]|your\\s*code|PIN\\s*code)\
                )[：:）)\\s\\]】]*(\\d{4,8})
                """,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        )
    }()

    private static let keywordPattern: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: "验证码|校验码|动态码|code|verify|OTP|认证|登录码",
            options: .caseInsensitive
        )
    }()

    private static let digitPattern: NSRegularExpression = {
        try! NSRegularExpression(
            pattern: "(?<!\\d)(\\d{4,8})(?!\\d)",
            options: []
        )
    }()

    // MARK: - Init

    init() {
        self.dbPath = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Messages/chat.db")
    }

    // MARK: - Database Access

    private func openDB() -> OpaquePointer? {
        var db: OpaquePointer?
        let uri = "file:\(dbPath)?mode=ro"
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI
        guard sqlite3_open_v2(uri, &db, flags, nil) == SQLITE_OK else {
            if let db = db { sqlite3_close(db) }
            return nil
        }
        return db
    }

    func checkAccess() -> Bool {
        guard FileManager.default.fileExists(atPath: dbPath) else { return false }
        guard let db = openDB() else { return false }
        sqlite3_close(db)
        return true
    }

    func getMaxRowID() -> Int64 {
        guard let db = openDB() else { return 0 }
        defer { sqlite3_close(db) }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT MAX(ROWID) FROM message", -1, &stmt, nil) == SQLITE_OK else {
            return 0
        }
        defer { sqlite3_finalize(stmt) }

        if sqlite3_step(stmt) == SQLITE_ROW {
            return sqlite3_column_int64(stmt, 0)
        }
        return 0
    }

    func initializeBaseline() {
        lastRowID = getMaxRowID()
    }

    func fetchNewMessages() -> [SMSMessage] {
        guard let db = openDB() else { return [] }
        defer { sqlite3_close(db) }

        let sql = """
            SELECT message.ROWID, message.text, COALESCE(handle.id, '') AS sender
            FROM message
            LEFT JOIN handle ON message.handle_id = handle.ROWID
            WHERE message.ROWID > ?
              AND message.is_from_me = 0
            ORDER BY message.ROWID ASC
            """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_int64(stmt, 1, lastRowID)

        var messages: [SMSMessage] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowID = sqlite3_column_int64(stmt, 0)
            let text: String
            if let cStr = sqlite3_column_text(stmt, 1) {
                text = String(cString: cStr)
            } else {
                lastRowID = max(lastRowID, rowID)
                continue
            }
            let sender: String
            if let cStr = sqlite3_column_text(stmt, 2) {
                sender = String(cString: cStr)
            } else {
                sender = ""
            }
            lastRowID = max(lastRowID, rowID)
            messages.append(SMSMessage(rowID: rowID, text: text, sender: sender))
        }
        return messages
    }

    // MARK: - Code Extraction

    static func extractCode(from text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)

        // Primary: keyword followed by digits
        if let match = codePattern.firstMatch(in: text, options: [], range: range),
           match.numberOfRanges > 1,
           let codeRange = Range(match.range(at: 1), in: text) {
            return String(text[codeRange])
        }

        // Fallback: keyword present + standalone digits
        if keywordPattern.firstMatch(in: text, options: [], range: range) != nil,
           let match = digitPattern.firstMatch(in: text, options: [], range: range),
           match.numberOfRanges > 0,
           let codeRange = Range(match.range(at: 1), in: text) {
            return String(text[codeRange])
        }

        return nil
    }
}
