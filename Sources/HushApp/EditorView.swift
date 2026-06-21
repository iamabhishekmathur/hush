import SwiftUI

/// Script library + editor window: list on the left, edit on the right.
struct EditorView: View {
    @ObservedObject var store: ScriptStore
    @State private var selection: Script.ID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(store.scripts) { script in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(script.title.isEmpty ? "Untitled" : script.title)
                            .font(.headline)
                        Text("\(script.wordCount) words · ~\(script.estReadSeconds)s")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(script.id)
                }
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240)
            .toolbar {
                Button { selection = store.add().id } label: { Image(systemName: "plus") }
                    .help("New script")
            }
        } detail: {
            if let id = selection, let index = store.scripts.firstIndex(where: { $0.id == id }) {
                ScriptEditor(
                    script: $store.scripts[index],
                    onChange: { store.update(store.scripts[index]) },
                    onDelete: {
                        let s = store.scripts[index]
                        selection = nil
                        store.delete(s)
                    }
                )
            } else {
                ContentUnavailableView("No script selected",
                                       systemImage: "doc.text",
                                       description: Text("Pick a script on the left, or create one."))
            }
        }
    }
}

private struct ScriptEditor: View {
    @Binding var script: Script
    var onChange: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Title", text: $script.title)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.plain)
                .padding([.horizontal, .top])
            Text("\(script.wordCount) words · ~\(script.estReadSeconds)s read")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Divider().padding(.vertical, 8)
            TextEditor(text: $script.body)
                .font(.system(size: 16))
                .scrollContentBackground(.hidden)
                .padding(.horizontal)
        }
        .toolbar {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .help("Delete script")
        }
        .onChange(of: script) { _, _ in onChange() }
    }
}
