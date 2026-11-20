import SwiftUI
import CloudKit

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedSpaceID") private var selectedSpaceID = ""
    @AppStorage(TickUIStateStorage.selectedTabKey) private var selectedTabRawValue = ContentTab.today.rawValue
    @State private var viewModel: TickViewModel
    @State private var lastActiveColorScheme: ColorScheme?

    @MainActor
    init() {
        _viewModel = State(initialValue: TickViewModel())
    }

    @MainActor
    init(viewModel: TickViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        TabView(selection: selectedTab) {
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
        .preferredColorScheme(scenePhase == .active ? nil : lastActiveColorScheme)
        .task {
            restoreSelectedSpaceIfNeeded()
            await viewModel.loadIfNeeded()
        }
        .onChange(of: colorScheme, initial: true) { _, newScheme in
            guard scenePhase == .active else { return }
            lastActiveColorScheme = newScheme
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            lastActiveColorScheme = colorScheme
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

    private var selectedTab: Binding<ContentTab> {
        Binding(
            get: { ContentTab(rawValue: selectedTabRawValue) ?? .today },
            set: { selectedTabRawValue = $0.rawValue }
        )
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
    static let selectedTabKey = "selectedTab"

    static func resetForUITests(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: todayTimerOrderKey)
        defaults.removeObject(forKey: selectedTabKey)
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
