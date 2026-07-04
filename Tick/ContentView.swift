import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("selectedSpaceID") private var selectedSpaceID = ""
    @AppStorage(TickUIStateStorage.selectedContentTabKey) private var selectedTab = ContentTab.today
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
        TabView(selection: $selectedTab) {
            TodayView(viewModel: viewModel)
                .tabItem {
                    Label("Today", systemImage: "clock.fill")
                }
                .tag(ContentTab.today)

            ProjectsView(viewModel: viewModel)
                .tabItem {
                    Label("Spaces", systemImage: "folder.fill")
                }
                .tag(ContentTab.spaces)

            AutoTicksView(viewModel: viewModel)
                .tabItem {
                    Label("Auto Ticks", systemImage: "location.fill")
                }
                .tag(ContentTab.autoTicks)

            SummariesView(viewModel: viewModel)
                .tabItem {
                    Label("Summaries", systemImage: "calendar")
                }
                .tag(ContentTab.summaries)
        }
        .task {
            restoreSelectedSpaceIfNeeded()
            await viewModel.loadIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            viewModel.scheduleReload()
        }
        .onChange(of: viewModel.selectedProjectID) { _, selectedProjectID in
            selectedSpaceID = selectedProjectID?.uuidString ?? ""
            viewModel.scheduleWidgetSnapshotRefresh()
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

    private func restoreSelectedSpaceIfNeeded() {
        guard viewModel.selectedProjectID == nil else {
            return
        }

        viewModel.selectedProjectID = UUID(uuidString: selectedSpaceID)
    }
}

nonisolated enum TickUIStateStorage {
    static let selectedContentTabKey = "selectedContentTab"

    static func resetForNewAppLaunch(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: selectedContentTabKey)
    }

    static func resetForUITests(defaults: UserDefaults = .standard) {
        resetForNewAppLaunch(defaults: defaults)
    }
}

private enum ContentTab: String, Hashable {
    case today
    case spaces
    case autoTicks
    case summaries
}

#Preview {
    ContentView()
}
