import SwiftUI

struct CanvasView: View {
    @ObservedObject var viewModel: DominoViewModel

    @State private var panOffset: CGSize = .zero
    @State private var dragStart: CGSize = .zero
    @State private var scale: CGFloat = 1.0
    @State private var gestureScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geo in
            let totalOffset = CGSize(
                width: panOffset.width + dragStart.width,
                height: panOffset.height + dragStart.height
            )
            let currentScale = scale * gestureScale

            ZStack {
                // Background - drag to pan, tap to deselect, double-click to create
                Color(nsColor: .windowBackgroundColor)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 3)
                            .onChanged { value in
                                dragStart = value.translation
                            }
                            .onEnded { value in
                                panOffset.width += value.translation.width
                                panOffset.height += value.translation.height
                                dragStart = .zero
                            }
                    )
                    .gesture(
                        MagnifyGesture()
                            .onChanged { value in
                                gestureScale = value.magnification
                            }
                            .onEnded { value in
                                scale = clampScale(scale * value.magnification)
                                gestureScale = 1.0
                            }
                    )
                    .onTapGesture(count: 2) { location in
                        // Convert screen location to canvas coordinates
                        let canvasPoint = CGPoint(
                            x: (location.x - totalOffset.width) / currentScale,
                            y: (location.y - totalOffset.height) / currentScale
                        )
                        viewModel.addNode(at: canvasPoint)
                    }
                    .simultaneousGesture(
                        TapGesture()
                            .onEnded {
                                viewModel.commitEditing()
                                viewModel.selectedNodeID = nil
                                viewModel.selectedEdgeID = nil
                            }
                    )

                // Empty state hint
                if viewModel.nodes.isEmpty {
                    VStack(spacing: 8) {
                        Text("Double-click to add a node")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.secondary.opacity(0.6))
                    }
                    .allowsHitTesting(false)
                }

                // Content layer, shifted by pan offset and scaled
                ZStack {
                    // Edges layer
                    ForEach(viewModel.edges) { edge in
                        EdgeShape(
                            from: viewModel.effectivePosition(edge.parent.id),
                            to: viewModel.effectivePosition(edge.child.id),
                            fromSize: viewModel.nodeSizes[edge.parent.id] ?? CGSize(width: 132, height: 44),
                            toSize: viewModel.nodeSizes[edge.child.id] ?? CGSize(width: 132, height: 44),
                            isSelected: viewModel.selectedEdgeID == edge.id,
                            onTap: {
                                viewModel.commitEditing()
                                viewModel.selectedNodeID = nil
                                viewModel.selectedEdgeID = viewModel.selectedEdgeID == edge.id ? nil : edge.id
                            }
                        )
                    }

                    // Preview edge while dragging
                    if let drag = viewModel.edgeDrag {
                        EdgeShape(
                            from: viewModel.effectivePosition(drag.sourceNodeID),
                            to: drag.currentPoint,
                            fromSize: viewModel.nodeSizes[drag.sourceNodeID] ?? CGSize(width: 132, height: 44),
                            color: .accentColor.opacity(0.5),
                            dash: [6, 4]
                        )
                    }

                    // Nodes layer
                    ForEach(viewModel.sortedNodes) { node in
                        NodeView(node: node, viewModel: viewModel)
                            .position(node.position)
                    }
                }
                .coordinateSpace(name: "canvas")
                .scaleEffect(currentScale)
                .offset(totalOffset)
            }
        }
        .clipped()
        .onChange(of: viewModel.fileLoadID) {
            centerOnNodes(viewportSize: NSApplication.shared.windows.first?.frame.size ?? CGSize(width: 1200, height: 800))
        }
    }

    private func centerOnNodes(viewportSize: CGSize) {
        scale = 1.0
        gestureScale = 1.0
        dragStart = .zero
        guard !viewModel.nodes.isEmpty else {
            panOffset = .zero
            return
        }
        let positions = viewModel.nodes.values.map(\.position)
        let avgX = positions.map(\.x).reduce(0, +) / CGFloat(positions.count)
        let avgY = positions.map(\.y).reduce(0, +) / CGFloat(positions.count)
        panOffset = CGSize(
            width: viewportSize.width / 2 - avgX,
            height: viewportSize.height / 2 - avgY
        )
    }

    private func clampScale(_ s: CGFloat) -> CGFloat {
        min(max(s, 0.2), 5.0)
    }
}
