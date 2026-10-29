import SwiftUI
import UIKit

/// Interactive 2D spreadsheet editor for TrollDocs ("TrollSheets").
struct SpreadsheetEditorView: View {
    @Binding var document: Document
    var onSave: () -> Void

    @State private var selectedRow: Int = 0
    @State private var selectedCol: Int = 0
    @State private var formulaBarText: String = ""
    @State private var isEditingFormula: Bool = false
    @FocusState private var formulaFocused: Bool

    private let cellWidth: CGFloat = 110
    private let rowHeaderWidth: CGFloat = 40
    private let cellHeight: CGFloat = 34

    var body: some View {
        VStack(spacing: 0) {
            // Formula & Address Bar
            formulaBar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.sheet)

            Divider()
                .background(Theme.rule)

            // Desktop Toolbar / Ribbon
            toolbarRibbon
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Theme.paper)

            Divider()
                .background(Theme.rule)

            // Table Grid Viewport
            gridScrollView
                .background(Theme.paper)

            Divider()
                .background(Theme.rule)

            // Live Calculation Status Bar
            statusBar
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Theme.sheet)
        }
        .onAppear {
            syncFormulaBarWithSelectedCell()
        }
    }

    // MARK: - Formula Bar

    private var formulaBar: some View {
        HStack(spacing: 8) {
            // Cell Address Badge (e.g. "B2")
            Text(currentCellAddress)
                .font(Theme.mono(11, weight: .bold))
                .foregroundColor(Theme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.accentWash)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            // fx indicator
            Text("fx")
                .font(Theme.serif(13, weight: .bold))
                .italic()
                .foregroundColor(Theme.inkSecondary)

            // Formula Text Field
            TextField("Enter value or formula (=SUM(A1:A5))", text: $formulaBarText)
                .font(Theme.mono(12.5))
                .foregroundColor(Theme.ink)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Theme.desk)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .focused($formulaFocused)
                .onSubmit {
                    commitFormula()
                }

            if formulaFocused {
                Button(action: commitFormula) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.accent)
                }
            }
        }
    }

    private var currentCellAddress: String {
        let colLetter = SpreadsheetFormulaEngine.columnName(for: selectedCol)
        return "\(colLetter)\(selectedRow + 1)"
    }

    // MARK: - Toolbar Ribbon

    private var toolbarRibbon: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Quick Formula Insert
                Menu {
                    Button("=SUM(range)") { insertFormulaSnippet("=SUM(") }
                    Button("=AVERAGE(range)") { insertFormulaSnippet("=AVERAGE(") }
                    Button("=COUNT(range)") { insertFormulaSnippet("=COUNT(") }
                    Button("=MIN(range)") { insertFormulaSnippet("=MIN(") }
                    Button("=MAX(range)") { insertFormulaSnippet("=MAX(") }
                } label: {
                    HStack(spacing: 4) {
                        Text("Σ")
                            .font(.system(size: 13, weight: .bold))
                        Text("Functions")
                            .font(Theme.sans(11, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.desk)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundColor(Theme.ink)
                }

                // AutoSum Quick Button
                Button(action: performAutoSum) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.forwardslash.minus")
                            .font(.system(size: 10))
                        Text("AutoSum")
                            .font(Theme.sans(11, weight: .semibold))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.accentWash)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundColor(Theme.accent)
                }

                Divider().frame(height: 18)

                // Row / Column Operations
                Button(action: { document.spreadsheetData.addRow(after: selectedRow); onSave() }) {
                    Label("+ Row", systemImage: "table.row.plus.after")
                        .font(Theme.sans(10.5))
                }
                .foregroundColor(Theme.ink)

                Button(action: { document.spreadsheetData.deleteRow(at: selectedRow); onSave() }) {
                    Label("- Row", systemImage: "table.row.minus")
                        .font(Theme.sans(10.5))
                }
                .foregroundColor(Theme.ink)

                Button(action: { document.spreadsheetData.addColumn(); onSave() }) {
                    Label("+ Col", systemImage: "table.column.plus.after")
                        .font(Theme.sans(10.5))
                }
                .foregroundColor(Theme.ink)

                Button(action: { document.spreadsheetData.deleteColumn(at: selectedCol); onSave() }) {
                    Label("- Col", systemImage: "table.column.minus")
                        .font(Theme.sans(10.5))
                }
                .foregroundColor(Theme.ink)

                Divider().frame(height: 18)

                // Formatting Menu
                Menu {
                    Button("General (Text/Number)") { setColumnFormat(.general) }
                    Button("Currency ($1,234.50)") { setColumnFormat(.currency) }
                    Button("Percentage (12.5%)") { setColumnFormat(.percentage) }
                    Button("Decimal (1,234.00)") { setColumnFormat(.number) }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "number")
                            .font(.system(size: 10))
                        Text("Format Col")
                            .font(Theme.sans(10.5))
                    }
                    .foregroundColor(Theme.ink)
                }
            }
        }
    }

    // MARK: - Grid Scroll View

    private var gridScrollView: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                // Column Header Row
                HStack(spacing: 0) {
                    // Corner Spacer
                    Rectangle()
                        .fill(Theme.desk)
                        .frame(width: rowHeaderWidth, height: cellHeight)
                        .overlay(Rectangle().stroke(Theme.rule, lineWidth: 0.5))

                    ForEach(0..<document.spreadsheetData.columnCount, id: \.self) { c in
                        let letter = SpreadsheetFormulaEngine.columnName(for: c)
                        let headerName = document.spreadsheetData.headers[c]
                        VStack(spacing: 1) {
                            Text(letter)
                                .font(Theme.mono(9, weight: .bold))
                                .foregroundColor(selectedCol == c ? Theme.accent : Theme.inkTertiary)
                            Text(headerName)
                                .font(Theme.sans(10, weight: .semibold))
                                .foregroundColor(Theme.ink)
                                .lineLimit(1)
                        }
                        .frame(width: cellWidth, height: cellHeight)
                        .background(selectedCol == c ? Theme.accentWash : Theme.desk)
                        .overlay(Rectangle().stroke(Theme.rule, lineWidth: 0.5))
                        .onTapGesture {
                            selectedCol = c
                            syncFormulaBarWithSelectedCell()
                        }
                    }
                }

                // Data Rows
                ForEach(0..<document.spreadsheetData.rowCount, id: \.self) { r in
                    HStack(spacing: 0) {
                        // Row Number Header
                        Text("\(r + 1)")
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundColor(selectedRow == r ? Theme.accent : Theme.inkTertiary)
                            .frame(width: rowHeaderWidth, height: cellHeight)
                            .background(selectedRow == r ? Theme.accentWash : Theme.desk)
                            .overlay(Rectangle().stroke(Theme.rule, lineWidth: 0.5))
                            .onTapGesture {
                                selectedRow = r
                                syncFormulaBarWithSelectedCell()
                            }

                        // Data Cells
                        ForEach(0..<document.spreadsheetData.columnCount, id: \.self) { c in
                            let isSelected = (selectedRow == r && selectedCol == c)
                            let displayVal = document.spreadsheetData.evaluatedCell(row: r, col: c)

                            Text(displayVal)
                                .font(Theme.mono(11.5))
                                .foregroundColor(isSelected ? Theme.ink : Theme.inkSecondary)
                                .lineLimit(1)
                                .padding(.horizontal, 6)
                                .frame(width: cellWidth, height: cellHeight, alignment: .leading)
                                .background(isSelected ? Theme.accentWash.opacity(0.6) : Theme.paper)
                                .overlay(
                                    Rectangle()
                                        .stroke(isSelected ? Theme.accent : Theme.rule, lineWidth: isSelected ? 2 : 0.5)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedRow = r
                                    selectedCol = c
                                    syncFormulaBarWithSelectedCell()
                                }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        let stats = document.spreadsheetData.columnStats(col: selectedCol)
        let colLetter = SpreadsheetFormulaEngine.columnName(for: selectedCol)

        return HStack(spacing: 16) {
            Text("Col \(colLetter):")
                .font(Theme.mono(10.5, weight: .bold))
                .foregroundColor(Theme.inkSecondary)

            if stats.count > 0 {
                HStack(spacing: 4) {
                    Text("SUM:")
                        .font(Theme.mono(10, weight: .semibold))
                        .foregroundColor(Theme.inkTertiary)
                    Text(String(format: "%.2f", stats.sum))
                        .font(Theme.mono(10.5, weight: .bold))
                        .foregroundColor(Theme.accent)
                }

                HStack(spacing: 4) {
                    Text("AVG:")
                        .font(Theme.mono(10, weight: .semibold))
                        .foregroundColor(Theme.inkTertiary)
                    Text(String(format: "%.2f", stats.avg))
                        .font(Theme.mono(10.5, weight: .medium))
                        .foregroundColor(Theme.ink)
                }

                HStack(spacing: 4) {
                    Text("COUNT:")
                        .font(Theme.mono(10, weight: .semibold))
                        .foregroundColor(Theme.inkTertiary)
                    Text("\(stats.count)")
                        .font(Theme.mono(10.5, weight: .medium))
                        .foregroundColor(Theme.ink)
                }
            } else {
                Text("\(document.spreadsheetData.rowCount) rows × \(document.spreadsheetData.columnCount) cols")
                    .font(Theme.mono(10))
                    .foregroundColor(Theme.inkTertiary)
            }

            Spacer()

            Text("Auto-Saved")
                .font(Theme.mono(9.5))
                .foregroundColor(Theme.inkTertiary)
        }
    }

    // MARK: - Helpers & Actions

    private func syncFormulaBarWithSelectedCell() {
        formulaBarText = document.spreadsheetData.cellValue(row: selectedRow, col: selectedCol)
    }

    private func commitFormula() {
        document.spreadsheetData.setCell(row: selectedRow, col: selectedCol, value: formulaBarText)
        formulaFocused = false
        onSave()
    }

    private func insertFormulaSnippet(_ snippet: String) {
        formulaBarText = snippet
        formulaFocused = true
    }

    private func performAutoSum() {
        let colLetter = SpreadsheetFormulaEngine.columnName(for: selectedCol)
        let startAddress = "\(colLetter)1"
        let endRow = max(1, selectedRow)
        let endAddress = "\(colLetter)\(endRow)"
        let autoSumFormula = "=SUM(\(startAddress):\(endAddress))"

        document.spreadsheetData.setCell(row: selectedRow, col: selectedCol, value: autoSumFormula)
        formulaBarText = autoSumFormula
        onSave()
    }

    private func setColumnFormat(_ format: CellNumberFormat) {
        if selectedCol < document.spreadsheetData.columnFormats.count {
            document.spreadsheetData.columnFormats[selectedCol] = format
            onSave()
        }
    }
}
