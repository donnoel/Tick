import SwiftUI

struct ContentView: View {
    @State private var viewModel: TickViewModel

    @MainActor
    init() {
        _viewModel = State(initialValue: TickViewModel())
    }

    @MainActor
    init(viewModel: TickViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        TabView {
            TodayView(viewModel: viewModel)
                .tabItem {
                    Label("Today", systemImage: "clock.fill")
                }

            ProjectsView(viewModel: viewModel)
                .tabItem {
                    Label("Projects", systemImage: "folder.fill")
                }

            SummariesView(viewModel: viewModel)
                .tabItem {
                    Label("Summaries", systemImage: "calendar")
                }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .alert("Tick needs attention", isPresented: errorIsPresented) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding {
            viewModel.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                viewModel.clearError()
            }
        }
    }
}

#Preview {
    ContentView()
}
