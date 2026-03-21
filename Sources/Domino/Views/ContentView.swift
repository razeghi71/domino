import SwiftUI

private enum CanvasWorkspace: String, CaseIterable, Identifiable {
    case graph
    case table

    var id: String { rawValue }

    var title: String {
        switch self {
        case .graph: "Graph"
        case .table: "Table"
        }
    }
}

private struct CanvasWorkspaceTabs: View {
    @Binding var selection: CanvasWorkspace

    var body: some View {
        HStack(spacing: 12) {
            Text("View")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(CanvasWorkspace.allCases) { mode in
                    Button {
                        selection = mode
                    } label: {
                        Text(mode.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(selection == mode ? .white : .primary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 6)
                            .background {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(selection == mode ? Color.accentColor : Color.clear)
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: DominoViewModel
    @State private var workspace: CanvasWorkspace = .graph

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer(minLength: 0)
                CanvasWorkspaceTabs(selection: $workspace)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Group {
                switch workspace {
                case .graph:
                    CanvasView(viewModel: viewModel)
                case .table:
                    NodesTableView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
