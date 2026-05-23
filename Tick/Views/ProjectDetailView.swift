import SwiftUI

struct ProjectDetailView: View {
    let viewModel: TickViewModel
    let project: TickProject
    @State private var deletionMessage: String?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            List {
                Section {
                    ProjectSummaryCard(
                        project: project,
                        duration: viewModel.totalDuration(for: project.id, at: timeline.date)
                    )
                }
                .listRowBackground(Color.clear)

                Section("Sessions") {
                    let projectSessions = viewModel.sessions(for: project.id)
                    if projectSessions.isEmpty {
                        ContentUnavailableView(
                            "No Ticks yet",
                            systemImage: "clock",
                            description: Text("Sessions for this project will appear here.")
                        )
                    } else {
                        ForEach(projectSessions) { session in
                            NavigationLink {
                                SessionDetailView(viewModel: viewModel, session: session)
                            } label: {
                                SessionRowView(
                                    session: session,
                                    projectID: project.id,
                                    projectName: project.name,
                                    displayDate: timeline.date,
                                    defaultTitle: defaultTitle(for: session, in: projectSessions)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens session details.")
                        }
                        .onDelete { indexSet in
                            deleteSessions(at: indexSet, from: projectSessions)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(TickPalette.appBackground)
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Could Not Delete", isPresented: deletionAlertIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deletionMessage ?? "Tick could not delete that session.")
        }
    }

    private var deletionAlertIsPresented: Binding<Bool> {
        Binding {
            deletionMessage != nil
        } set: { isPresented in
            if !isPresented {
                deletionMessage = nil
            }
        }
    }

    private func defaultTitle(for session: TimeSession, in sessions: [TimeSession]) -> String {
        guard let offset = sessions
            .filter({ $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            .firstIndex(where: { $0.id == session.id }) else {
            return "Tick"
        }

        return "\(offset + 1) Tick"
    }

    private func deleteSessions(at indexSet: IndexSet, from sessions: [TimeSession]) {
        Task {
            for index in indexSet {
                let didDelete = await viewModel.deleteSession(id: sessions[index].id)
                if !didDelete {
                    deletionMessage = viewModel.errorMessage ?? "Tick could not delete that session."
                    return
                }
            }
        }
    }
}

private struct ProjectSummaryCard: View {
    let project: TickProject
    let duration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                TickProjectBadge(color: TickProjectAccent.color(for: project.id), systemImage: "folder.fill")

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)

                    Text("Created \(project.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text(TickDurationFormatter.shortString(from: duration))
                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.75)
                .lineLimit(1)

            Text("Total tracked")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .tickCard(tint: TickProjectAccent.color(for: project.id))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.name), \(TickDurationFormatter.shortString(from: duration)) total tracked, created \(project.createdAt.formatted(date: .abbreviated, time: .omitted))")
    }
}
