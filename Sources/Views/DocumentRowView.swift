import SwiftUI

/// Component representing an individual document row in the Dashboard list.
public struct DocumentRowView: View {
    public let document: DocumentItem
    public let onShare: () -> Void

    public init(document: DocumentItem, onShare: @escaping () -> Void) {
        self.document = document
        self.onShare = onShare
    }

    public var body: some View {
        HStack(spacing: 14) {
            // Document Format Icon Badge
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(document.format.themeColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: document.format.systemIcon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(document.format.themeColor)
            }

            // Title & Details
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(document.titleWithoutExtension)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Text(document.format.shortName)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(document.format.themeColor.opacity(0.12))
                        .foregroundColor(document.format.themeColor)
                        .clipShape(Capsule())
                }

                HStack(spacing: 8) {
                    Text(document.formattedFileSize)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Text(document.relativeDateString)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Quick Share Button
            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Circle())
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
