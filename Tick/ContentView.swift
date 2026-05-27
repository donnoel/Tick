import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
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
                    Label("Spaces", systemImage: "folder.fill")
                }

            AutoTicksView(viewModel: viewModel)
                .tabItem {
                    Label("Auto Ticks", systemImage: "location.fill")
                }

            SummariesView(viewModel: viewModel)
                .tabItem {
                    Label("Summaries", systemImage: "calendar")
                }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await viewModel.reload()
            }
        }
        .onChange(of: viewModel.selectedProjectID) { _, _ in
            Task {
                await viewModel.refreshWidgetSnapshot()
            }
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
