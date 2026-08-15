import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

enum LogAction: String {
    case opened    // 输入了原因并放行
    case aborted   // 选择"算了"，忍住了
}

struct LogEvent: Identifiable {
    let id: Int64
    let date: Date
    let bundleID: String
    let appName: String
    let action: LogAction
    let reason: String
}

struct AppSummary: Identifiable {
    var id: String { bundleID }
    let bundleID: String
    let appName: String
    let opened: Int
    let aborted: Int
}

/// 每次"想打开分心应用"的拦截事件都记入 SQLite，用于统计与回顾。
final class EventLog {
    static let shared = EventLog()

    private var db: OpaquePointer?

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Focus", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var handle: OpaquePointer?
        guard sqlite3_open(dir.appendingPathComponent("events.db").path, &handle) == SQLITE_OK,
              handle != nil else { return }
        db = handle
        exec("""
            CREATE TABLE IF NOT EXISTS events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ts REAL NOT NULL,
                bundle_id TEXT NOT NULL,
                app_name TEXT NOT NULL,
                action TEXT NOT NULL,
                reason TEXT NOT NULL
            )
            """)
    }

    deinit {
        if db != nil { sqlite3_close(db) }
    }

    private func exec(_ sql: String) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_step(stmt)
    }

    func record(bundleID: String, appName: String, action: LogAction, reason: String) {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT INTO events(ts, bundle_id, app_name, action, reason) VALUES(?,?,?,?,?)", -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
        sqlite3_bind_text(stmt, 2, bundleID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, appName, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, action.rawValue, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, reason, -1, SQLITE_TRANSIENT)
        sqlite3_step(stmt)
    }

    /// 今天对该应用产生了多少次拦截事件（含放弃）
    func todayCount(bundleID: String) -> Int {
        let start = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM events WHERE bundle_id = ?1 AND ts >= ?2", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, bundleID, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(stmt, 2, start)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    func recentEvents(limit: Int = 200) -> [LogEvent] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT id, ts, bundle_id, app_name, action, reason FROM events ORDER BY id DESC LIMIT ?", -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(limit))

        var events: [LogEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            events.append(LogEvent(
                id: sqlite3_column_int64(stmt, 0),
                date: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
                bundleID: String(cString: sqlite3_column_text(stmt, 2)),
                appName: String(cString: sqlite3_column_text(stmt, 3)),
                action: LogAction(rawValue: String(cString: sqlite3_column_text(stmt, 4))) ?? .opened,
                reason: String(cString: sqlite3_column_text(stmt, 5))
            ))
        }
        return events
    }

    func summary(days: Int = 7) -> [AppSummary] {
        let since = Date().addingTimeInterval(-TimeInterval(days) * 86400).timeIntervalSince1970
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, """
            SELECT bundle_id, MAX(app_name),
                   SUM(CASE WHEN action = 'opened' THEN 1 ELSE 0 END),
                   SUM(CASE WHEN action = 'aborted' THEN 1 ELSE 0 END)
            FROM events WHERE ts >= ?1
            GROUP BY bundle_id
            ORDER BY SUM(1) DESC
            """, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, since)

        var result: [AppSummary] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(AppSummary(
                bundleID: String(cString: sqlite3_column_text(stmt, 0)),
                appName: String(cString: sqlite3_column_text(stmt, 1)),
                opened: Int(sqlite3_column_int64(stmt, 2)),
                aborted: Int(sqlite3_column_int64(stmt, 3))
            ))
        }
        return result
    }
}
