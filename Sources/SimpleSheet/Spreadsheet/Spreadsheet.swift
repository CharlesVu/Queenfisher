import Foundation

/// Class to read & write to a google spreadsheet
public class Spreadsheet: SheetInteractable, Decodable {
    /// The ID of the spreadsheet. This field is read-only
    public let spreadsheetId: String
    /// Overall properties of a spreadsheet
    public let properties: Properties
    /// The url of the spreadsheet. This field is read-only
    public let spreadsheetUrl: URL
    /// The sheets that are part of a spreadsheet
    private(set) public var sheets: [Sheet]
    /// Method to authenticate for the spreadsheet
    private(set) public var authenticator: Authenticator?
    private(set) public var client: URLSession!
    public let queue = DispatchQueue.global()

    // Custom decoding init to allow `DispatchQueue` & `Authenticator` properties
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spreadsheetId = try container.decode(String.self, forKey: CodingKeys.spreadsheetId)
        properties = try container.decode(Properties.self, forKey: CodingKeys.properties)
        spreadsheetUrl = try container.decode(URL.self, forKey: CodingKeys.spreadsheetUrl)
        sheets = try container.decode([Sheet].self, forKey: CodingKeys.sheets)
    }
    /**
     Retreive a spreadsheet (only way to get a spreadsheet)
     - Parameter spreadsheetId: The ID of the spreadsheet you want to load
     - Parameter authenticator: Authentication method to get the spreadsheet & to use on all successive operations on the spreadsheet
     */
    public static func fetch(
        _ spreadsheetId: String, using authenticator: Authenticator, client: URLSession
    ) async throws -> Spreadsheet {
        let url = sheetsApiUrl.appendingPathComponent(spreadsheetId)
        let headers = try await authenticator.authenticationHeader(scope: .sheets, client: client)
        let spreadsheet: Spreadsheet = try await HTTPProxy.execute(on: client, url: url, headers: headers, parameters: headers, method: .get)

        spreadsheet.authenticator = authenticator
        spreadsheet.client = client
        return spreadsheet
    }

    /// Get the sheet for the specified `title`
    public func sheet(forTitle title: String) -> Sheet? {
        sheets.first(where: { $0.properties.title == title })
    }

    /// Write many cells at once.
    public func writeRows(
        sheetId: Int,
        rows: [[String]],
        starting from: Sheet.Location
    ) async throws -> Spreadsheet.UpdateResponse {
        try await batchUpdate(.updateCells(sheetId: sheetId, rows: rows, start: from))
    }

    /// Adds a sheet.
    public func create(
        title: String,
        dimensions grid: Sheet.Properties.Grid?
    ) async throws -> Spreadsheet.UpdateResponse {
        let update = try await batchUpdate(.addSheet(title: title, grid: grid))
        let addSheet = update.replies.first!.addSheet!.properties!
        sheets.append(.init(properties: addSheet, data: nil))

        return update
    }

    /// Deletes a sheet.
    public func delete(sheetId: Int) async throws -> Spreadsheet.UpdateResponse {
        let update = try await batchUpdate(.deleteSheet(sheetId: sheetId))
        sheets.removeAll(where: { $0.properties.sheetId == sheetId })
        return update
    }

    /// Deletes rows or columns in a sheet.
    public func delete(
        sheetId: Int,
        range: Range<Int>,
        dimension: Sheet.Dimension
    ) async throws -> Spreadsheet.UpdateResponse {
        try await batchUpdate(.delete(sheetId: sheetId, range: range, dimension: dimension))
    }

    /// Inserts new rows or columns in a sheet.
    public func insert(
        sheetId: Int,
        range: Range<Int>,
        dimension: Sheet.Dimension
    ) async throws -> Spreadsheet.UpdateResponse {
        try await batchUpdate(.insert(sheetId: sheetId, range: range, dimension: dimension))
    }

    /// Appends dimensions to the end of a sheet.
    public func append(
        sheetId: Int,
        size: Int,
        dimension: Sheet.Dimension
    ) async throws -> Spreadsheet.UpdateResponse{
        try await batchUpdate(.append(sheetId: sheetId, size: size, dimension: dimension))
    }

    /// Moves rows or columns to another location in a sheet.
    public func move(
        sheetId: Int,
        range: Range<Int>,
        to dest: Int,
        dimension: Sheet.Dimension
    ) async throws -> Spreadsheet.UpdateResponse {
        try await batchUpdate(.move(sheetId: sheetId, range: range, to: dest, dimension: dimension))
    }
    /// Appends cells after the last row with data in a sheet.
    public func appendRows(sheetId: Int, rows: [[String]]) async throws -> Spreadsheet.UpdateResponse {
        try await batchUpdate(.appendCells(sheetId: sheetId, rows: rows))
    }
    /// Clears the sheet.
    public func clear(sheetId: Int) async throws -> Spreadsheet.UpdateResponse {
        try await batchUpdate(.clear(sheetId: sheetId))
    }

    /// Properties of a spreadsheet
    public struct Properties: Codable {
        /// The title of the spreadsheet
        let title: String
        /// The locale of the spreadsheet
        let locale: String
        /// The time zone of the spreadsheet, in CLDR format such as `America/New_York`.
        /// If the time zone isn't recognized, this may be a custom time zone such as `GMT-07:00`
        let timeZone: String
    }

    public enum CodingKeys: String, CodingKey {
        case spreadsheetId = "spreadsheetId"
        case properties = "properties"
        case spreadsheetUrl = "spreadsheetUrl"
        case sheets = "sheets"
    }
}
