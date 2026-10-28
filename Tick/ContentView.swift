import SwiftUI
import CloudKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("selectedSpaceID") private var selectedSpaceID = ""
    @State private var viewModel: TickViewModel
    @State private var selectedTab: ContentTab

    @MainActor
    init() {
        _viewModel = State(initialValue: TickViewModel())
        _selectedTab = State(initialValue: .today)
    }

    @MainActor
    init(viewModel: TickViewModel) {
        _viewModel = State(initialValue: viewModel)
        _selectedTab = State(initialValue: .today)
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

            selectedTab = .today
            viewModel.scheduleReload()
        }
        .onChange(of: viewModel.selectedProjectID) { _, selectedProjectID in
            selectedSpaceID = selectedProjectID?.uuidString ?? ""
            viewModel.scheduleWidgetSnapshotRefresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tickCloudSnapshotChanged)) { _ in
            viewModel.scheduleReload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in
            viewModel.scheduleReload()
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
    static let todayTimerOrderKey = "todayTimerOrder"

    static func resetForUITests(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: todayTimerOrderKey)
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
