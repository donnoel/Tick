import SwiftUI

struct SessionRowView: View {
    enum DetailStyle {
        case time
        case date
    }

    let session: TimeSession
    let projectID: TickProject.ID
    let projectName: String
    let displayDate: Date
    let defaultTitle: String
    var detailStyle: DetailStyle = .time

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TickProjectBadge(
                color: accentColor,
                systemImage: session.entrySource == .autoLocation ? "location.fill" : "circle.fill"
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)

                        Text(projectName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let sourceBadgeTitle {
                        Text(sourceBadgeTitle)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(accentColor.opacity(0.14), in: Capsule())
                            .foregroundStyle(accentColor)
                            .accessibilityLabel(sourceBadgeAccessibilityLabel)
                    }
                }

                HStack {
                    Text(timeDescription)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(TickDurationFormatter.shortString(from: session.duration(at: displayDate)))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(session.isActive ? TickPalette.running : Color.primary)
                }
                .font(.subheadline)
            }
        }
        .padding(12)
        .tickCard(tint: accentColor, isHighlighted: session.isActive)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accentColor: Color {
        TickProjectAccent.color(for: projectID)
    }

    private var title: String {
        let trimmedTitle = session.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? defaultTitle : trimmedTitle
    }

    private var timeDescription: String {
        if detailStyle == .date && !session.isActive {
            return formattedDate(session.referenceDate)
        }

        if session.isActive {
            return "Running since \(formattedTime(session.startedAt))"
        }

        if session.entrySource == .manual {
            return formattedDate(session.referenceDate)
        }

        guard let endedAt = session.endedAt else {
            return formattedTime(session.referenceDate)
        }

        return "\(formattedTime(session.referenceDate)) - \(formattedTime(endedAt))"
    }

    private var accessibilityDescription: String {
        var parts = [
            title,
            projectName,
            TickDurationFormatter.shortString(from: session.duration(at: displayDate)),
            timeDescription
        ]

        if let sourceBadgeTitle {
            parts.append(sourceBadgeTitle)
        }

        return parts.joined(separator: ", ")
    }

    private var sourceBadgeTitle: String? {
        switch session.entrySource {
        case .timer:
            nil
        case .manual:
            "Manual"
        case .autoLocation:
            "Auto"
        }
    }

    private var sourceBadgeAccessibilityLabel: String {
        switch session.entrySource {
        case .timer:
            "Timer session"
        case .manual:
            "Manual time entry"
        case .autoLocation:
            "Auto Tick session"
        }
    }

    private func formattedTime(_ date: Date?) -> String {
        guard let date else {
            return "unknown time"
        }

        return date.formatted(date: .omitted, time: .shortened)
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}
