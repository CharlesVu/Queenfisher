//
//  File.swift
//
//
//  Created by Adhiraj Singh on 5/17/20.
//

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

let sheetsApiUrl = URL(string: "https://sheets.googleapis.com/v4/spreadsheets/")!
/// Generic Spreadsheet with functions to batch update
public protocol SheetInteractable {
    var spreadsheetId: String { get }
    var authenticator: Authenticator? { get }
    var client: URLSession! { get }
}

public enum Dimension: String {
    case row = "ROWS"
    case column = "COLUMNS"
}

extension SheetInteractable {


    public var url: URL { sheetsApiUrl.appendingPathComponent(spreadsheetId) }

    /// Write Columned or Rowed data to the sheet
    public func write(
        sheet: String? = nil, data: [[String]], starting from: Sheet.Location,
        dimension: Sheet.Dimension
    ) async throws -> Spreadsheet.WriteResponse {
        let range = (sheet != nil ? "\(sheet!)!" : "") + from.celled().description

        var url = self.url.appendingPathComponent("values").appendingPathComponent(range)
        var comps = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "valueInputOption", value: "USER_ENTERED")]
        url = comps.url!

        let body = Sheet.ValuesRange(dimension: dimension, range: range, values: data)
        let queryParameters = try await queryParameters()

        return try await HTTPProxy.execute(on: client, url: url, headers: [:], parameters: queryParameters, body: body, method: .get)
    }

    /// Read a sheet
    public func read(
        sheetID: String? = nil,
        dimension: Dimension,
        range: (from: Sheet.Location, to: Sheet.Location)? = nil
    ) async throws -> Sheet.ValuesRange {
        var url = self.url.appendingPathComponent("values")
        if var sheetComp = sheetID {
            if let range = range {
                sheetComp += "!\(range.from.description):\(range.to.description)"
            }
            url.appendPathComponent(sheetComp)
        }
        var headers = try await queryParameters()
        headers["majorDimension"] = dimension.rawValue
        return try await HTTPProxy.execute(on: client, url: url, headers: [:], parameters: headers, method: .get)
    }

    public func batchUpdate(_ operation: Spreadsheet.Operation) async throws -> Spreadsheet.UpdateResponse {
        try await batchUpdate(operations: .init(operation))
    }

    public func batchUpdate(operations: Spreadsheet.Operations) async throws -> Spreadsheet.UpdateResponse {
        let url = sheetsApiUrl.appendingPathComponent(spreadsheetId + ":batchUpdate")
        let queryParameters = try await queryParameters()
        return try await HTTPProxy.execute(on: client, url: url, headers: [:], parameters: queryParameters, body: operations,  method: .post)
    }

    internal func queryParameters() async throws -> [String: String] {
        return try await authenticator!.authenticationHeader(scope: .sheets, client: client!)
    }
}
