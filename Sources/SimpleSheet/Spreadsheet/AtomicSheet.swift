//
//  AtomicSheet.swift
//
//
//  Created by Adhiraj Singh on 5/11/20.
//

import Foundation

public class AtomicSheet: SheetInteractable {
    public let spreadsheetId: String
    public let authenticator: Authenticator?
    public let sheetTitle: String
    /// How long after an error should a re-upload be attempted
    public var reUploadInterval: TimeInterval = 30.seconds
    /// How long to wait after an operation before attempting an upload
    public var uploadInterval: TimeInterval = 1.second

    private(set) public var isSheetLoaded = false

    private var isShutdown = false

    private var sheetId: Int!

    private(set) public var end: Sheet.Location = .cell(0, 0)
    private(set) public var data: [[String]] = .init()

    private var operationQueue = [Spreadsheet.Operation]()
    internal var uploading = false

    private let start: Sheet.Location = .cell(0, 0)
    private let serialQueue: DispatchQueue = .init(label: "write_queue", attributes: [])

    public let client: URLSession!

    public init(
        spreadsheetId: String,
        sheetTitle: String,
        using authenticator: Authenticator,
        client: URLSession
    ) {
        self.spreadsheetId = spreadsheetId
        self.authenticator = authenticator
        self.sheetTitle = sheetTitle
        self.client = client
        Task {
            do {
                try await beginUpload()
            } catch {

            }
        }
    }
    public func get() -> [[String]] {
        self.data
    }

    public func append(rows: [[String]]) throws {
        try operate(op: .appendCells(sheetId: sheetId, rows: rows)) {
            if rows.filter({ $0.count - 1 >= self.end.col! }).count > 0 {
                throw OperationError.outOfBounds
            }
            data.append(contentsOf: rows)
            end = end + (0, rows.count)
        }
    }
    public func append(dimension dim: Sheet.Dimension, size: Int) throws {
        try operate(op: .append(sheetId: sheetId, size: size, dimension: dim)) {
            if dim == .columns {
                end = end + (size, 0)
            } else {
                end = end + (0, size)
            }
        }
    }
    public func delete(dimension dim: Sheet.Dimension, range: Range<Int>) throws {
        try operate(op: .delete(sheetId: sheetId, range: range, dimension: dim)) {
            let count = range.upperBound - range.lowerBound
            if dim == .columns {
                for i in 0..<data.count {
                    data[i].removeSubrange(range)
                }
                end = end + (-count, 0)
            } else {
                data.removeSubrange(range)
                end = end + (0, -count)
            }
        }
    }
    public func insert(dimension dim: Sheet.Dimension, range: Range<Int>) throws {
        try operate(op: .insert(sheetId: sheetId, range: range, dimension: dim)) {
            let count = range.upperBound - range.lowerBound
            if dim == .columns {
                for i in 0..<data.count {
                    data[i].insert(contentsOf: [String](repeating: "", count: count), at: range.lowerBound)
                }
                end = end + (count, 0)
            } else {
                data.insert(contentsOf: (0..<count).map { _ in [String]() }, at: range.lowerBound)
                end = end + (0, count)
            }
        }
    }
    public func move(dimension dim: Sheet.Dimension, range: Range<Int>, to index: Int) throws {
        try operate(op: .move(sheetId: sheetId, range: range, to: index, dimension: dim)) {
            let count = range.upperBound - range.lowerBound
            if dim == .columns {
                fatalError("not implemented yet")
            } else {
                if range.contains(index) {
                    throw OperationError.invalidMove
                }
                if !data.indices.contains(range.lowerBound) || !data.indices.contains(range.upperBound)
                    || !data.indices.contains(index)
                {
                    throw OperationError.outOfBounds
                }
                let rows = range.map { _ in data.remove(at: range.lowerBound) }

                if index < range.lowerBound {
                    self.data.insert(contentsOf: rows, at: index)
                } else if index > range.upperBound {
                    self.data.insert(contentsOf: rows, at: index - count)
                }

            }
        }
    }
    public func set(rows: [[String]], at loc: Sheet.Location) throws {
        try operate(op: .updateCells(sheetId: sheetId, rows: rows, start: loc)) {
            let celledLoc = loc.celled()
            if celledLoc.row! + rows.count - 1 >= end.row! {
                throw OperationError.outOfBounds
            }
            if celledLoc.row! + rows.count > data.count {
                let rem = celledLoc.row! + rows.count - data.count
                data.append(contentsOf: [[String]](repeating: [], count: rem))
            }
            for i in 0..<rows.count {
                let di = i + celledLoc.row!
                let maxCol = celledLoc.col! + rows[i].count
                if maxCol - 1 >= end.col! {
                    throw OperationError.outOfBounds
                }
                if maxCol > data[di].count {
                    data[di].append(contentsOf: [String](repeating: "", count: maxCol - data[di].count))
                }
                for j in celledLoc.col!..<data[di].count {
                    data[di][j] = rows[i][j - celledLoc.col!]
                }
            }
        }
    }
    public func clear() throws {
        try operate(op: .clear(sheetId: sheetId)) { data.removeAll() }
    }

    public func shutdownSync() {
        self.isShutdown = true
    }

    func operate(op: Spreadsheet.Operation, _ exec: () throws -> Void) throws {
        if isShutdown { fatalError("operation called on shut down sheet") }
        try exec()
        operationQueue.append(op)
    }

    func beginUpload() async throws {
        if !self.uploading, self.operationQueue.count > 0 {
            self.uploading = true

            let index = try await self.upload(till: self.operationQueue.count, ops: self.operationQueue)
            self.operationQueue.removeSubrange(0..<index)
            self.uploading = false
            try await self.beginUpload()
        }
    }

    private func upload(till index: Int, ops: [Spreadsheet.Operation]) async throws -> Int {
        let workTill: Int

        if ops.first!.load == true {
            workTill = 1
        } else {
            workTill = index
            let _ = try await batchUpdate(operations: .init(requests: ops))
        }

        return workTill
    }

    private func load() async throws {
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [
            URLQueryItem(
                name: "fields", value: "sheets.properties,sheets.data.rowData.values.userEnteredValue"),
            URLQueryItem(name: "ranges", value: sheetTitle),
        ]
        let url = comps.url!
        let headers = try await queryParameters()
        let spreadSheet: Spreadsheet = try await HTTPProxy.execute(on: client, url: url, headers: headers, parameters: headers, method: .get)
        var sheet = spreadSheet.sheets.first
        if sheet == nil {
            let result = try await self.batchUpdate(.addSheet(title: self.sheetTitle, grid: nil))
            sheet = Sheet(properties: result.replies.first!.addSheet!.properties!, data: nil)
        }

        self.sheetId = sheet!.properties.sheetId
        self.data = sheet!.data?[0].rowData?.map { $0.values.map { $0.toString() } } ?? []
        self.end = .cell(
            sheet!.properties.gridProperties!.columnCount,
            sheet!.properties.gridProperties!.rowCount)
        self.isSheetLoaded = true
    }

    private struct SheetsObject: Codable {
        let sheets: [Sheet]
    }
}

public enum OperationError: Error {
    case outOfBounds
    case invalidMove
}

