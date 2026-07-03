import SwiftUI

struct HistoryView: View {
    private let store: ClipboardStore
    @State private var query = ""
    @State private var refreshToken = UUID()

    init(store: ClipboardStore) {
        self.store = store
    }

    private var results: [ClipboardItem] {
        _ = refreshToken
        return store.search(query)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("ClipboardX")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Clear") {
                    store.clear()
                    refreshToken = UUID()
                }
            }

            TextField("Search clipboard history...", text: $query)
                .textFieldStyle(.roundedBorder)

            if results.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 36))
                    Text("No clipboard history yet")
                        .font(.headline)
                    Text("Copy some text and it will appear here.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List(results) { item in
                    Button {
                        ClipboardWriter.writeText(item.content)
                        refreshToken = UUID()
                    } label: {
                        ClipboardRowView(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 480)
    }
}
