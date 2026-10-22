import Foundation
import SQLite3

/// A value that can be bound to a SQLite statement.
public enum SQLValue: Equatable {
    case null
    case int(Int64)
    case double(Double)
    case text(String)
    case blob(Data)

    public static func bool(_ value: Bool) -> SQLValue { .int(value ? 1 : 0) }
    public static func optionalInt(_ value: Int?) -> SQLValue { value.map { .int(Int64($0)) } ?? .null }
    public static func optionalText(_ value: String?) -> SQLValue { value.map { .text($0) } ?? .null }
}

/// A single row returned from a query.
public struct SQLRow {
    private let values: [String: SQLValue]
    private let orderedKeys: [String]

    init(values: [String: SQLValue], orderedKeys: [String]) {
        self.values = values
        self.orderedKeys = orderedKeys
    }

    public var keys: [String] { orderedKeys }

    public func value(_ column: String) -> SQLValue { values[column] ?? .null }

    public func string(_ column: String) -> String? {
        switch value(column) {
        case let .text(text): return text
        case let .int(number): return String(number)
        case let .double(number): return String(number)
        case let .blob(data): return String(data: data, encoding: .utf8)
        case .null: return nil
        }
    }

    public func int(_ column: String) -> Int? {
        switch value(column) {
        case let .int(number): return Int(number)
        case let .double(number): return Int(number)
        case let .text(text): return Int(text)
        case .blob, .null: return nil
        }
    }

    /// The value of a column addressed by its position.
    public func value(at index: Int) -> SQLValue {
        guard orderedKeys.indices.contains(index) else { return .null }
        return values[orderedKeys[index]] ?? .null
    }

    public func int(at index: Int) -> Int? {
        switch value(at: index) {
        case let .int(number): return Int(number)
        case let .double(number): return Int(number)
        case let .text(text): return Int(text)
        case .blob, .null: return nil
        }
    }

    public func int64(_ column: String) -> Int64? {
        switch value(column) {
        case let .int(number): return number
        case let .double(number): return Int64(number)
        case let .text(text): return Int64(text)
        case .blob, .null: return nil
        }
    }

    public func bool(_ column: String) -> Bool {
        (int(column) ?? 0) != 0
    }

    public func double(_ column: String) -> Double? {
        switch value(column) {
        case let .double(number): return number
        case let .int(number): return Double(number)
        case let .text(text): return Double(text)
        case .blob, .null: return nil
        }
    }

    public func data(_ column: String) -> Data? {
        if case let .blob(data) = value(column) { return data }
        return nil
    }
}

/// Errors surfaced by the SQLite layer.
public enum SQLiteError: Error, CustomStringConvertible {
    case openFailed(String)
    case statementFailed(String)
    case bindingFailed(String)

    public var description: String {
        switch self {
        case let .openFailed(message): return "Unable to open database: \(message)"
        case let .statementFailed(message): return "SQLite statement failed: \(message)"
        case let .bindingFailed(message): return "SQLite binding failed: \(message)"
        }
    }
}

/// A thin, thread-safe wrapper over the SQLite C API.
public final class SQLiteConnection {
    /// The file the database lives in.
    public let path: String

    private var handle: OpaquePointer?
    /// A recursive lock keeps the connection thread safe while still allowing
    /// the repository to run queries inside a transaction.
    private let lock = NSRecursiveLock()

    /// Creates (or opens) a database file, enabling WAL journalling.
    public init(path: String) throws {
        self.path = path
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let status = sqlite3_open_v2(path, &db, flags, nil)
        guard status == SQLITE_OK, let db else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let db { sqlite3_close(db) }
            throw SQLiteError.openFailed(message)
        }
        handle = db

        // Mirrors the pragmas used by the previous better-sqlite3 build.
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA busy_timeout = 5000;")
    }

    deinit {
        if let handle { sqlite3_close(handle) }
    }

    /// Closes the database.
    public func close() {
        lock.lock()
        defer { lock.unlock() }
        guard let handle else { return }
        sqlite3_close(handle)
        self.handle = nil
    }

    /// A consistent SQLite backup, including uncheckpointed WAL content.
    public func backup(to destination: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let handle else { throw SQLiteError.statementFailed("database is closed") }
        var target: OpaquePointer?
        guard sqlite3_open(destination.path, &target) == SQLITE_OK, let target else {
            if let target { sqlite3_close(target) }
            throw SQLiteError.openFailed("Cannot create migration backup.")
        }
        defer { sqlite3_close(target) }
        guard let backup = sqlite3_backup_init(target, "main", handle, "main") else {
            throw SQLiteError.statementFailed(String(cString: sqlite3_errmsg(target)))
        }
        let status = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        guard status == SQLITE_DONE, finish == SQLITE_OK else {
            throw SQLiteError.statementFailed("Cannot finish migration backup.")
        }
    }

    /// Runs a statement that returns no rows.
    public func execute(_ sql: String, _ bindings: [SQLValue] = []) throws {
        lock.lock()
        defer { lock.unlock() }
        try executeLocked(sql, bindings)
    }

    /// Runs a script that may contain several statements.
    ///
    /// `sqlite3_prepare_v2` only compiles the first statement of a script, so
    /// multi statement scripts have to go through `sqlite3_exec`.
    public func executeScript(_ sql: String) throws {
        lock.lock()
        defer { lock.unlock() }
        guard handle != nil else { throw SQLiteError.statementFailed("database is closed") }
        var errorMessage: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
        guard status == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "unknown error"
            sqlite3_free(errorMessage)
            throw SQLiteError.statementFailed(message)
        }
    }

    /// Runs a query and materialises every row.
    public func query(_ sql: String, _ bindings: [SQLValue] = []) throws -> [SQLRow] {
        lock.lock()
        defer { lock.unlock() }
        return try queryLocked(sql, bindings)
    }

    /// Returns the first column of the first row as an integer.
    public func scalarInt(_ sql: String, _ bindings: [SQLValue] = []) throws -> Int {
        let rows = try query(sql, bindings)
        guard let row = rows.first else { return 0 }
        return row.int(at: 0) ?? 0
    }

    /// Runs `body` inside a transaction, rolling back on error.
    ///
    /// The body may call `execute` and `query` again: the lock is recursive, so
    /// the nested calls join the running transaction.
    public func transaction<T>(_ body: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        try executeLocked("BEGIN IMMEDIATE;", [])
        do {
            let result = try body()
            try executeLocked("COMMIT;", [])
            return result
        } catch {
            try? executeLocked("ROLLBACK;", [])
            throw error
        }
    }

    // MARK: - Locked internals

    private func executeLocked(_ sql: String, _ bindings: [SQLValue]) throws {
        let statement = try prepareLocked(sql)
        defer { sqlite3_finalize(statement) }
        try bind(statement, bindings)
        let status = sqlite3_step(statement)
        guard status == SQLITE_DONE || status == SQLITE_ROW else {
            throw SQLiteError.statementFailed(errorMessage)
        }
    }

    private func queryLocked(_ sql: String, _ bindings: [SQLValue]) throws -> [SQLRow] {
        let statement = try prepareLocked(sql)
        defer { sqlite3_finalize(statement) }
        try bind(statement, bindings)

        var rows: [SQLRow] = []
        while true {
            let status = sqlite3_step(statement)
            if status == SQLITE_ROW {
                rows.append(try readRow(statement))
            } else if status == SQLITE_DONE {
                break
            } else {
                throw SQLiteError.statementFailed(errorMessage)
            }
        }
        return rows
    }

    private func prepareLocked(_ sql: String) throws -> OpaquePointer {
        guard let handle else { throw SQLiteError.statementFailed("database is closed") }
        var statement: OpaquePointer?
        let status = sqlite3_prepare_v2(handle, sql, -1, &statement, nil)
        guard status == SQLITE_OK, let statement else {
            throw SQLiteError.statementFailed(errorMessage)
        }
        return statement
    }

    private func bind(_ statement: OpaquePointer, _ bindings: [SQLValue]) throws {
        for (offset, value) in bindings.enumerated() {
            let index = Int32(offset + 1)
            let status: Int32
            switch value {
            case .null:
                status = sqlite3_bind_null(statement, index)
            case let .int(number):
                status = sqlite3_bind_int64(statement, index, number)
            case let .double(number):
                status = sqlite3_bind_double(statement, index, number)
            case let .text(text):
                status = text.utf8CString.withUnsafeBufferPointer { buffer in
                    sqlite3_bind_text(statement, index, buffer.baseAddress, Int32(buffer.count - 1), SQLITE_TRANSIENT)
                }
            case let .blob(data):
                status = data.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(buffer.count), SQLITE_TRANSIENT)
                }
            }
            guard status == SQLITE_OK else {
                throw SQLiteError.bindingFailed(errorMessage)
            }
        }
    }

    private func readRow(_ statement: OpaquePointer) throws -> SQLRow {
        let columnCount = sqlite3_column_count(statement)
        var values: [String: SQLValue] = [:]
        var orderedKeys: [String] = []
        orderedKeys.reserveCapacity(Int(columnCount))

        for column in 0..<columnCount {
            let name = String(cString: sqlite3_column_name(statement, column))
            orderedKeys.append(name)
            switch sqlite3_column_type(statement, column) {
            case SQLITE_INTEGER:
                values[name] = .int(sqlite3_column_int64(statement, column))
            case SQLITE_FLOAT:
                values[name] = .double(sqlite3_column_double(statement, column))
            case SQLITE_TEXT:
                if let pointer = sqlite3_column_text(statement, column) {
                    values[name] = .text(String(decoding: UnsafeBufferPointer(start: pointer, count: Int(sqlite3_column_bytes(statement, column))), as: UTF8.self))
                } else {
                    values[name] = .null
                }
            case SQLITE_BLOB:
                let count = Int(sqlite3_column_bytes(statement, column))
                if let pointer = sqlite3_column_blob(statement, column), count > 0 {
                    values[name] = .blob(Data(bytes: pointer, count: count))
                } else {
                    values[name] = .blob(Data())
                }
            default:
                values[name] = .null
            }
        }
        return SQLRow(values: values, orderedKeys: orderedKeys)
    }

    private var errorMessage: String {
        guard let handle else { return "database is closed" }
        return String(cString: sqlite3_errmsg(handle))
    }
}

/// `sqlite3_bind_*` requires a destructor that does not deallocate the buffer.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
