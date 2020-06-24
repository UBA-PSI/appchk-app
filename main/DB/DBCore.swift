import Foundation
import SQLite3

// iOS 9.3 uses SQLite 3.8.10

enum SQLiteError: Error {
	case OpenDatabase(message: String)
	case Prepare(message: String)
	case Step(message: String)
	case Bind(message: String)
}

/// `try? SQLiteDatabase.open()`
var AppDB: SQLiteDatabase? { get { try? SQLiteDatabase.open() } }
typealias SQLiteRowID = sqlite3_int64
/// `0` indicates an unbound edge.
typealias SQLiteRowRange = (start: SQLiteRowID, end: SQLiteRowID)

// MARK: - SQLiteDatabase

class SQLiteDatabase {
	fileprivate var functions = [String: [Int: Function]]()
	private let dbPointer: OpaquePointer?
	private init(dbPointer: OpaquePointer?) {
		self.dbPointer = dbPointer
	}
	
	fileprivate var errorMessage: String {
		if let errorPointer = sqlite3_errmsg(dbPointer) {
			let errorMessage = String(cString: errorPointer)
			return errorMessage
		} else {
			return "No error message provided from sqlite."
		}
	}
	
	deinit {
		sqlite3_close_v2(dbPointer)
	}
	
	static func destroyDatabase(path: String = URL.internalDB().relativePath) {
		if FileManager.default.fileExists(atPath: path) {
			do { try FileManager.default.removeItem(atPath: path) }
			catch { print("Could not destroy database file: \(path)") }
		}
	}
	
	static func open(path: String = URL.internalDB().relativePath) throws -> SQLiteDatabase {
		var db: OpaquePointer?
		if sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK {
			return SQLiteDatabase(dbPointer: db)
		} else {
			defer { sqlite3_close_v2(db) }
			if let errorPointer = sqlite3_errmsg(db) {
				let message = String(cString: errorPointer)
				throw SQLiteError.OpenDatabase(message: message)
			} else {
				throw SQLiteError.OpenDatabase(message: "No error message provided from sqlite.")
			}
		}
	}
	
	func run<T>(sql: String, bind: [DBBinding?] = [], step: (OpaquePointer) throws -> T) throws -> T {
//		print("SQL run: \(sql)")
//		for x in bind where x != nil {
//			print("  -> \(x!)")
//		}
		var statement: OpaquePointer?
		guard sqlite3_prepare_v2(dbPointer, sql, -1, &statement, nil) == SQLITE_OK,
			let stmt = statement else {
				throw SQLiteError.Prepare(message: errorMessage)
		}
		defer { sqlite3_finalize(stmt) }
		var col: Int32 = 0
		for b in bind.compactMap({$0}) {
			col += 1
			guard b.bind(stmt, col) == SQLITE_OK else {
				throw SQLiteError.Bind(message: errorMessage)
			}
		}
		return try step(stmt)
	}
	
	func run(sql: String) throws {
//		print("SQL exec: \(sql)")
		var err: UnsafeMutablePointer<Int8>? = nil
		if sqlite3_exec(dbPointer, sql, nil, nil, &err) != SQLITE_OK {
			let errMsg = (err != nil) ? String(cString: err!) : "Unknown execution error"
			sqlite3_free(err);
			throw SQLiteError.Step(message: errMsg)
		}
	}
	
	func ifStep(_ stmt: OpaquePointer, _ expected: Int32) throws {
		guard sqlite3_step(stmt) == expected else {
			throw SQLiteError.Step(message: errorMessage)
		}
	}
	
	func vacuum() {
		try? run(sql: "VACUUM;")
	}
}


// MARK: - Custom Functions

// let SQLITE_STATIC = unsafeBitCast(0, sqlite3_destructor_type.self)
let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public struct Blob {
    public let bytes: [UInt8]
    public init(bytes: [UInt8]) { self.bytes = bytes }
    public init(bytes: UnsafeRawPointer, length: Int) {
        let i8bufptr = UnsafeBufferPointer(start: bytes.assumingMemoryBound(to: UInt8.self), count: length)
        self.init(bytes: [UInt8](i8bufptr))
    }
}

extension SQLiteDatabase {
	fileprivate typealias Function = @convention(block) (OpaquePointer?, Int32, UnsafeMutablePointer<OpaquePointer?>?) -> Void
    
	func createFunction(_ function: String, argumentCount: UInt? = nil, deterministic: Bool = false, _ block: @escaping (_ args: [Any?]) -> Any?) {
        let argc = argumentCount.map { Int($0) } ?? -1
        let box: Function = { context, argc, argv in
            let arguments: [Any?] = (0..<Int(argc)).map {
                let value = argv![$0]
                switch sqlite3_value_type(value) {
                case SQLITE_BLOB:    return Blob(bytes: sqlite3_value_blob(value), length: Int(sqlite3_value_bytes(value)))
                case SQLITE_FLOAT:   return sqlite3_value_double(value)
                case SQLITE_INTEGER: return sqlite3_value_int64(value)
                case SQLITE_NULL:    return nil
                case SQLITE_TEXT:    return String(cString: UnsafePointer(sqlite3_value_text(value)))
                case let type:       fatalError("unsupported value type: \(type)")
                }
            }
            let result = block(arguments)
            if let r = result as? Blob        { sqlite3_result_blob(context, r.bytes, Int32(r.bytes.count), nil) }
			else if let r = result as? Double { sqlite3_result_double(context, r) }
			else if let r = result as? Int64  { sqlite3_result_int64(context, r) }
			else if let r = result as? Bool   { sqlite3_result_int(context, r ? 1 : 0) }
			else if let r = result as? String { sqlite3_result_text(context, r, Int32(r.count), SQLITE_TRANSIENT) }
			else if result == nil             { sqlite3_result_null(context) }
			else                              { fatalError("unsupported result type: \(String(describing: result))") }
        }
        var flags = SQLITE_UTF8
        if deterministic {
            flags |= SQLITE_DETERMINISTIC
        }
        sqlite3_create_function_v2(dbPointer, function, Int32(argc), flags, unsafeBitCast(box, to: UnsafeMutableRawPointer.self), { context, argc, value in
            let function = unsafeBitCast(sqlite3_user_data(context), to: Function.self)
            function(context, argc, value)
        }, nil, nil, nil)
        if functions[function] == nil { functions[function] = [:] }
        functions[function]?[argc] = box
    }
}


// MARK: - Bindings

protocol DBBinding {
	func bind(_ stmt: OpaquePointer!, _ col: Int32) -> Int32
}

struct BindInt32 : DBBinding {
	let raw: Int32
	init(_ value: Int32) { raw = value }
	func bind(_ stmt: OpaquePointer!, _ col: Int32) -> Int32 { sqlite3_bind_int(stmt, col, raw) }
}

struct BindInt64 : DBBinding {
	let raw: sqlite3_int64
	init(_ value: sqlite3_int64) { raw = value }
	func bind(_ stmt: OpaquePointer!, _ col: Int32) -> Int32 { sqlite3_bind_int64(stmt, col, raw) }
}

struct BindText : DBBinding {
	let raw: String
	init(_ value: String) { raw = value }
	func bind(_ stmt: OpaquePointer!, _ col: Int32) -> Int32 { sqlite3_bind_text(stmt, col, (raw as NSString).utf8String, -1, nil) }
}

struct BindTextOrNil : DBBinding {
	let raw: String?
	init(_ value: String?) { raw = value }
	func bind(_ stmt: OpaquePointer!, _ col: Int32) -> Int32 { sqlite3_bind_text(stmt, col, (raw == nil) ? nil : (raw! as NSString).utf8String, -1, nil) }
}

// MARK: - Easy Access func

extension SQLiteDatabase {
	var numberOfChanges: Int32 { get { sqlite3_changes(dbPointer) } }
	var lastInsertedRow: SQLiteRowID { get { sqlite3_last_insert_rowid(dbPointer) } }
	
	func readText(_ stmt: OpaquePointer, _ col: Int32) -> String? {
		let val = sqlite3_column_text(stmt, col)
		return (val != nil ? String(cString: val!) : nil)
	}
	
	func allRows<T>(_ stmt: OpaquePointer, _ fn: (OpaquePointer) -> T) -> [T] {
		var r: [T] = []
		while (sqlite3_step(stmt) == SQLITE_ROW) { r.append(fn(stmt)) }
		return r
	}
	
	func allRowsKeyed<T,U>(_ stmt: OpaquePointer, _ fn: (OpaquePointer) -> (key: T, value: U)) -> [T:U] {
		var r: [T:U] = [:]
		while (sqlite3_step(stmt) == SQLITE_ROW) { let (k,v) = fn(stmt); r[k] = v }
		return r
	}
}


// MARK: - Prepared Statement

extension SQLiteDatabase {
	func prepare(sql: String) throws -> OpaquePointer {
		var pStmt: OpaquePointer?
		guard sqlite3_prepare_v2(dbPointer, sql, -1, &pStmt, nil) == SQLITE_OK, let S = pStmt else {
			sqlite3_finalize(pStmt)
			throw SQLiteError.Prepare(message: errorMessage)
		}
		return S
	}
	
	@discardableResult func prepared(run pStmt: OpaquePointer!, bind: [DBBinding?] = []) throws -> Int32 {
		defer { sqlite3_reset(pStmt) }
		var col: Int32 = 0
		for b in bind.compactMap({$0}) {
			col += 1
			guard b.bind(pStmt, col) == SQLITE_OK else {
				throw SQLiteError.Bind(message: errorMessage)
			}
		}
		return sqlite3_step(pStmt)
	}
	
	func prepared(finalize pStmt: OpaquePointer!) {
		sqlite3_finalize(pStmt)
	}
}
