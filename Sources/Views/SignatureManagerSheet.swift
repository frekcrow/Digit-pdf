import SwiftUI

/// Sheet for browsing, creating, and selecting saved signatures.
struct SignatureManagerSheet: View {
    var onSelectSignature: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    @StateObject private var store = SignatureStore.shared
    @State private var showingPad: Bool = false

    var body: some View {
        NavigationView {
            ZStack {
                Theme.paper.ignoresSafeArea()

                VStack(spacing: 0) {
                    if store.signatures.isEmpty {
                        emptyState
                    } else {
                        signatureList
                    }
                }
            }
            .navigationTitle("Signatures")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(Theme.inkSecondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showingPad = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("New")
                        }
                        .font(Theme.sans(13, weight: .semibold))
                        .foregroundColor(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showingPad) {
                SignaturePadView { image in
                    onSelectSignature(image)
                    dismiss()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "signature")
                .font(.system(size: 44, weight: .light))
                .foregroundColor(Theme.accent)

            Text("No Saved Signatures")
                .font(Theme.serif(20))
                .foregroundColor(Theme.ink)

            Text("Create a signature or initials once and stamp them onto any PDF document.")
                .font(Theme.sans(12.5))
                .foregroundColor(Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Button {
                showingPad = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.tip")
                    Text("Create Signature")
                }
                .font(Theme.sans(12, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Theme.accent)
                .clipShape(Capsule())
            }
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var signatureList: some View {
        List {
            Section {
                ForEach(store.signatures) { sig in
                    Button {
                        if let img = sig.image {
                            onSelectSignature(img)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 16) {
                            if let img = sig.image {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 50)
                                    .padding(4)
                                    .background(Theme.sheet)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Theme.rule, lineWidth: Theme.hairline)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(sig.name)
                                    .font(Theme.sans(14, weight: .semibold))
                                    .foregroundColor(Theme.ink)

                                Text(formattedDate(sig.createdAt))
                                    .font(Theme.mono(10))
                                    .foregroundColor(Theme.inkTertiary)
                            }

                            Spacer()

                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 16))
                                .foregroundColor(Theme.accent.opacity(0.8))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let sig = store.signatures[index]
                        store.delete(sig)
                    }
                }
            } header: {
                Text("TAP A SIGNATURE TO INSERT ON ACTIVE PAGE")
                    .font(Theme.mono(9, weight: .bold))
                    .foregroundColor(Theme.inkTertiary)
            }
        }
        .listStyle(.insetGrouped)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
