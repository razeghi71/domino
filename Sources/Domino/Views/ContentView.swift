import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: DominoViewModel

    var body: some View {
        CanvasView(viewModel: viewModel)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
