import Foundation

/// A restriction on what a range of cells may contain.
///
/// Only list validations are modelled, because they are the only kind with a
/// visible control. Every kind is preserved through a save regardless.
public struct DataValidation: Sendable {
    public var ranges: [CellRange]
    public var values: [String]

    public init(ranges: [CellRange], values: [String]) {
        self.ranges = ranges
        self.values = values
    }

    public func covers(_ address: CellAddress) -> Bool {
        ranges.contains { $0.contains(address) }
    }
}

extension Worksheet {
    /// The list a cell is restricted to, if it is restricted to one.
    public func listValidation(at address: CellAddress) -> DataValidation? {
        validations.first { $0.covers(address) }
    }
}

enum DataValidationReader {
    /// Parses the `dataValidations` fragment the reader kept.
    static func read(_ fragment: String?) -> [DataValidation] {
        guard let fragment, let root = try? XMLDocument.parse(Data(fragment.utf8)) else { return [] }

        return root.elements(named: "dataValidation").compactMap { node in
            guard node.attributes.attribute("type") == "list",
                  let reference = node.attributes.attribute("sqref") else { return nil }
            // One validation can cover several ranges, separated by spaces.
            let ranges = reference.split(separator: " ").compactMap { CellRange(a1: String($0)) }
            guard !ranges.isEmpty else { return nil }

            guard let formula = node.firstElement(named: "formula1")?.textContent else { return nil }
            let values = parseList(formula)
            guard !values.isEmpty else { return nil }
            return DataValidation(ranges: ranges, values: values)
        }
    }

    /// An inline list is a quoted, comma-separated literal. A formula pointing
    /// at a range of cells is left alone: the editor does not resolve it.
    private static func parseList(_ formula: String) -> [String] {
        let trimmed = formula.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 else { return [] }
        return String(trimmed.dropFirst().dropLast())
            .split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
