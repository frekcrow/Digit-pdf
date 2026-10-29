import Foundation

// MARK: - Number Formatting

public enum CellNumberFormat: String, CaseIterable, Codable, Identifiable {
    case general = "General"
    case currency = "Currency ($)"
    case percentage = "Percentage (%)"
    case number = "Number (0.00)"

    public var id: String { rawValue }

    public func format(value: Double) -> String {
        switch self {
        case .general:
            return value.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", value) : String(format: "%.2f", value)
        case .currency:
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = Locale(identifier: "en_US")
            return formatter.string(from: NSNumber(value: value)) ?? String(format: "$%.2f", value)
        case .percentage:
            return String(format: "%.1f%%", value * 100.0)
        case .number:
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 2
            return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
        }
    }
}

// MARK: - Spreadsheet Data Model

public struct SpreadsheetData: Codable, Equatable {
    public var headers: [String]
    public var rows: [[String]]
    public var columnFormats: [CellNumberFormat]

    public init(headers: [String] = ["A", "B", "C", "D", "E"], rows: [[String]] = [], columnFormats: [CellNumberFormat] = []) {
        self.headers = headers.isEmpty ? ["A", "B", "C", "D", "E"] : headers
        self.rows = rows
        if columnFormats.count == self.headers.count {
            self.columnFormats = columnFormats
        } else {
            self.columnFormats = Array(repeating: .general, count: self.headers.count)
        }
    }

    public var columnCount: Int { headers.count }
    public var rowCount: Int { rows.count }

    public func cellValue(row: Int, col: Int) -> String {
        guard row >= 0, row < rows.count, col >= 0, col < rows[row].count else { return "" }
        return rows[row][col]
    }

    public mutating func setCell(row: Int, col: Int, value: String) {
        ensureDimensions(minRows: row + 1, minCols: col + 1)
        rows[row][col] = value
    }

    public mutating func addRow(after index: Int? = nil) {
        let emptyRow = Array(repeating: "", count: columnCount)
        if let idx = index, idx >= 0, idx < rows.count {
            rows.insert(emptyRow, at: idx + 1)
        } else {
            rows.append(emptyRow)
        }
    }

    public mutating func deleteRow(at index: Int) {
        guard index >= 0, index < rows.count, rows.count > 1 else { return }
        rows.remove(at: index)
    }

    public mutating func addColumn(named name: String? = nil) {
        let newLetter = SpreadsheetFormulaEngine.columnName(for: columnCount)
        headers.append(name ?? newLetter)
        columnFormats.append(.general)
        for i in 0..<rows.count {
            rows[i].append("")
        }
    }

    public mutating func deleteColumn(at index: Int) {
        guard index >= 0, index < headers.count, headers.count > 1 else { return }
        headers.remove(at: index)
        if index < columnFormats.count {
            columnFormats.remove(at: index)
        }
        for i in 0..<rows.count {
            if index < rows[i].count {
                rows[i].remove(at: index)
            }
        }
    }

    public mutating func ensureDimensions(minRows: Int, minCols: Int) {
        while headers.count < minCols {
            addColumn()
        }
        while rows.count < minRows {
            addRow()
        }
        for r in 0..<rows.count {
            while rows[r].count < headers.count {
                rows[r].append("")
            }
        }
    }

    // MARK: - Calculation & Evaluation

    public func evaluatedCell(row: Int, col: Int) -> String {
        let raw = cellValue(row: row, col: col)
        guard raw.hasPrefix("=") else {
            // Apply formatting if raw is a pure number and column has a special format
            if let num = Double(raw), col < columnFormats.count, columnFormats[col] != .general {
                return columnFormats[col].format(value: num)
            }
            return raw
        }
        let result = SpreadsheetFormulaEngine.evaluate(formula: raw, in: self)
        if let num = Double(result), col < columnFormats.count, columnFormats[col] != .general {
            return columnFormats[col].format(value: num)
        }
        return result
    }

    public func columnStats(col: Int) -> (sum: Double, avg: Double, count: Int) {
        guard col >= 0, col < columnCount else { return (0, 0, 0) }
        var sum: Double = 0
        var count = 0
        for r in 0..<rowCount {
            let valStr = evaluatedCell(row: r, col: col)
            // Strip any currency signs or commas
            let clean = valStr.replacingOccurrences(of: "$", with: "")
                              .replacingOccurrences(of: ",", with: "")
                              .trimmingCharacters(in: .whitespaces)
            if let num = Double(clean) {
                sum += num
                count += 1
            }
        }
        let avg = count > 0 ? (sum / Double(count)) : 0
        return (sum, avg, count)
    }

    // MARK: - CSV Serialization & Parsing

    public func toCSV() -> String {
        var lines: [String] = []
        // Header
        let escapedHeaders = headers.map { SpreadsheetFormulaEngine.escapeCSVCell($0) }
        lines.append(escapedHeaders.joined(separator: ","))

        // Rows
        for row in rows {
            let escapedRow = row.map { SpreadsheetFormulaEngine.escapeCSVCell($0) }
            lines.append(escapedRow.joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    public static func fromCSV(_ csvText: String) -> SpreadsheetData {
        let rawLines = csvText.components(separatedBy: .newlines)
        var parsedRows: [[String]] = []

        for line in rawLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            let delimiter: Character
            if trimmed.contains("\t") {
                delimiter = "\t"
            } else if trimmed.contains(";") && !trimmed.contains(",") {
                delimiter = ";"
            } else {
                delimiter = ","
            }

            let cells = trimmed.split(separator: delimiter, omittingEmptySubsequences: false).map { cell -> String in
                var clean = cell.trimmingCharacters(in: .whitespaces)
                if clean.hasPrefix("\"") && clean.hasSuffix("\"") && clean.count >= 2 {
                    clean.removeFirst()
                    clean.removeLast()
                    clean = clean.replacingOccurrences(of: "\"\"", with: "\"")
                }
                return clean
            }
            parsedRows.append(cells)
        }

        guard !parsedRows.isEmpty else {
            return defaultTemplate()
        }

        let headers = parsedRows.first ?? ["A", "B", "C", "D", "E"]
        let dataRows = Array(parsedRows.dropFirst())

        var data = SpreadsheetData(headers: headers, rows: dataRows)
        data.ensureDimensions(minRows: max(dataRows.count, 6), minCols: headers.count)
        return data
    }

    // MARK: - Templates

    public static func defaultTemplate() -> SpreadsheetData {
        let headers = ["Item", "Category", "Quantity", "Unit Price", "Total"]
        let rows = [
            ["Office Desk", "Furniture", "2", "249.99", "=C1*D1"],
            ["Ergonomic Chair", "Furniture", "2", "189.50", "=C2*D2"],
            ["External Monitor", "Electronics", "3", "320.00", "=C3*D3"],
            ["Wireless Keyboard", "Accessories", "3", "45.00", "=C4*D4"],
            ["USB-C Cable", "Accessories", "5", "14.99", "=C5*D5"],
            ["Total Expenses", "Summary", "", "", "=SUM(E1:E5)"]
        ]
        var sheet = SpreadsheetData(
            headers: headers,
            rows: rows,
            columnFormats: [.general, .general, .number, .currency, .currency]
        )
        sheet.ensureDimensions(minRows: 8, minCols: 5)
        return sheet
    }

    public static func blankGrid(rows: Int = 10, cols: Int = 6) -> SpreadsheetData {
        let headers = (0..<cols).map { SpreadsheetFormulaEngine.columnName(for: $0) }
        let grid = (0..<rows).map { _ in Array(repeating: "", count: cols) }
        return SpreadsheetData(headers: headers, rows: grid)
    }
}

// MARK: - Formula Evaluation Engine

public enum SpreadsheetFormulaEngine {

    public static func columnName(for index: Int) -> String {
        var n = index
        var name = ""
        while n >= 0 {
            let remainder = n % 26
            name = String(UnicodeScalar(65 + remainder)!) + name
            n = (n / 26) - 1
        }
        return name
    }

    public static func columnIndex(for letter: String) -> Int? {
        let upper = letter.uppercased().trimmingCharacters(in: .whitespaces)
        guard !upper.isEmpty else { return nil }
        var sum = 0
        for char in upper.unicodeScalars {
            guard char.value >= 65 && char.value <= 90 else { return nil }
            sum = sum * 26 + Int(char.value - 64)
        }
        return sum - 1
    }

    public static func parseCellReference(_ ref: String) -> (row: Int, col: Int)? {
        let trimmed = ref.trimmingCharacters(in: .whitespaces).uppercased()
        let letters = trimmed.prefix { $0.isLetter }
        let numbers = trimmed.drop { $0.isLetter }

        guard !letters.isEmpty, !numbers.isEmpty,
              let col = columnIndex(for: String(letters)),
              let rowNum = Int(numbers), rowNum > 0 else {
            return nil
        }
        return (row: rowNum - 1, col: col)
    }

    public static func evaluate(formula: String, in sheet: SpreadsheetData) -> String {
        let clean = formula.trimmingCharacters(in: .whitespaces)
        guard clean.hasPrefix("=") else { return clean }
        let expr = String(clean.dropFirst()).trimmingCharacters(in: .whitespaces).uppercased()

        // Handle Functions: SUM, AVERAGE, AVG, COUNT, MIN, MAX
        if let (funcName, rangeStr) = parseFunction(expr) {
            let values = extractValues(range: rangeStr, in: sheet)
            switch funcName {
            case "SUM":
                let sum = values.reduce(0, +)
                return formatDouble(sum)
            case "AVERAGE", "AVG":
                guard !values.isEmpty else { return "0" }
                let avg = values.reduce(0, +) / Double(values.count)
                return formatDouble(avg)
            case "COUNT":
                return "\(values.count)"
            case "MIN":
                guard let m = values.min() else { return "0" }
                return formatDouble(m)
            case "MAX":
                guard let m = values.max() else { return "0" }
                return formatDouble(m)
            default:
                return "#NAME?"
            }
        }

        // Handle Simple Arithmetic: A1+B1, A1*D1, A1-B1, A1/B1
        for op in ["+", "-", "*", "/"] as [Character] {
            if let opIndex = expr.firstIndex(of: op) {
                let leftStr = String(expr[..<opIndex]).trimmingCharacters(in: .whitespaces)
                let rightStr = String(expr[expr.index(after: opIndex)...]).trimmingCharacters(in: .whitespaces)

                let leftVal = resolveValue(token: leftStr, in: sheet)
                let rightVal = resolveValue(token: rightStr, in: sheet)

                guard let l = leftVal, let r = rightVal else {
                    return "#VALUE!"
                }

                switch op {
                case "+": return formatDouble(l + r)
                case "-": return formatDouble(l - r)
                case "*": return formatDouble(l * r)
                case "/": return r == 0 ? "#DIV/0!" : formatDouble(l / r)
                default: break
                }
            }
        }

        // Handle single cell reference: =A1
        if let cell = parseCellReference(expr) {
            let val = sheet.cellValue(row: cell.row, col: cell.col)
            if val.hasPrefix("=") {
                return evaluate(formula: val, in: sheet)
            }
            return val
        }

        return "#VALUE!"
    }

    private static func parseFunction(_ expr: String) -> (funcName: String, range: String)? {
        guard let openParen = expr.firstIndex(of: "("),
              let closeParen = expr.lastIndex(of: ")"),
              openParen < closeParen else {
            return nil
        }
        let funcName = String(expr[..<openParen]).trimmingCharacters(in: .whitespaces)
        let inside = String(expr[expr.index(after: openParen)..<closeParen]).trimmingCharacters(in: .whitespaces)
        return (funcName, inside)
    }

    private static func extractValues(range: String, in sheet: SpreadsheetData) -> [Double] {
        var values: [Double] = []
        if range.contains(":") {
            let parts = range.split(separator: ":").map { String($0) }
            if parts.count == 2,
               let start = parseCellReference(parts[0]),
               let end = parseCellReference(parts[1]) {
                let minR = min(start.row, end.row)
                let maxR = max(start.row, end.row)
                let minC = min(start.col, end.col)
                let maxC = max(start.col, end.col)

                for r in minR...maxR {
                    for c in minC...maxC {
                        let cellStr = sheet.evaluatedCell(row: r, col: c)
                        let clean = cellStr.replacingOccurrences(of: "$", with: "")
                                           .replacingOccurrences(of: ",", with: "")
                                           .trimmingCharacters(in: .whitespaces)
                        if let d = Double(clean) {
                            values.append(d)
                        }
                    }
                }
            }
        } else {
            let tokens = range.split(separator: ",").map { String($0) }
            for token in tokens {
                if let d = resolveValue(token: token, in: sheet) {
                    values.append(d)
                }
            }
        }
        return values
    }

    private static func resolveValue(token: String, in sheet: SpreadsheetData) -> Double? {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        if let num = Double(trimmed) {
            return num
        }
        if let cell = parseCellReference(trimmed) {
            let raw = sheet.evaluatedCell(row: cell.row, col: cell.col)
            let clean = raw.replacingOccurrences(of: "$", with: "")
                           .replacingOccurrences(of: ",", with: "")
                           .trimmingCharacters(in: .whitespaces)
            return Double(clean)
        }
        return nil
    }

    private static func formatDouble(_ val: Double) -> String {
        if val.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", val)
        }
        return String(format: "%.2f", val)
    }

    public static func escapeCSVCell(_ text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespaces)
        if clean.contains(",") || clean.contains("\"") || clean.contains("\n") || clean.contains("\r") {
            let doubled = clean.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(doubled)\""
        }
        return clean
    }
}
