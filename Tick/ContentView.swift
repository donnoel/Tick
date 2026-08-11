import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("selectedSpaceID") private var selectedSpaceID = ""
    @State private var viewModel: TickViewModel
    @State private var selectedTab: ContentTab

    @MainActor
    init() {
        _viewModel = State(initialValue: TickViewModel())
        _selectedTab = State(initialValue: TickUIStateStorage.selectedContentTab())
    }

    @MainActor
    init(viewModel: TickViewModel) {
        _viewModel = State(initialValue: viewModel)
        _selectedTab = State(initialValue: TickUIStateStorage.selectedContentTab())
    }

    var body: some View {
        TabView(selection: selectedTabBinding) {
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

            selectedTab = TickUIStateStorage.selectedContentTab()
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

    private var selectedTabBinding: Binding<ContentTab> {
        Binding {
            selectedTab
        } set: { newTab in
            guard scenePhase == .active else {
                return
            }

            selectedTab = newTab
            TickUIStateStorage.saveSelectedContentTab(newTab)
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

    static func selectedContentTab(defaults: UserDefaults = .standard) -> ContentTab {
        guard let rawValue = defaults.string(forKey: selectedContentTabKey),
              let selectedTab = ContentTab(rawValue: rawValue) else {
            return .today
        }

        return selectedTab
    }

    static func saveSelectedContentTab(
        _ selectedTab: ContentTab,
        defaults: UserDefaults = .standard
    ) {
        defaults.set(selectedTab.rawValue, forKey: selectedContentTabKey)
    }

    static func resetForUITests(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: selectedContentTabKey)
    }
}

nonisolated enum ContentTab: String, Hashable {
    case today
    case spaces
    case autoTicks
    case summaries
}

#Preview {
    ContentView()
}
