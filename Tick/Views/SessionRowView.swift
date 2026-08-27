import SwiftUI

struct SessionRowView: View {
    enum DetailStyle {
        case time
        case date
    }

    enum Presentation {
        case card
        case plain
    }

    let session: TimeSession
    let projectID: TickProject.ID
    let projectName: String
    let displayDate: Date
    let defaultTitle: String
    var detailStyle: DetailStyle = .time
    var accentColor: Color?
    var presentation: Presentation = .card

    @ViewBuilder
    var body: some View {
        switch presentation {
        case .card:
            cardRow
        case .plain:
            plainRow
        }
    }

    private var cardRow: some View {
        HStack(alignment: .top, spacing: 12) {
            TickProjectBadge(
                color: rowAccentColor,
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
                            .background(rowAccentColor.opacity(0.14), in: Capsule())
                            .foregroundStyle(rowAccentColor)
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
        .tickCard(tint: rowAccentColor, isHighlighted: session.isActive)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var plainRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(rowAccentColor)
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(title)
                        .font(.body.weight(.semibold))
                        .lineLimit(2)

                    Spacer(minLength: 8)

                    Text(TickDurationFormatter.shortString(from: session.duration(at: displayDate)))
                        .font(.body.weight(.medium).monospacedDigit())
                        .foregroundStyle(session.isActive ? TickPalette.running : Color.primary)
                }

                Text(compactMetadata)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var rowAccentColor: Color {
        accentColor ?? TickProjectAccent.color(for: projectID)
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
            if session.isPaused {
                return "Paused at \(formattedTime(session.pausedAt))"
            }

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

    private var compactMetadata: String {
        switch session.entrySource {
        case .timer:
            return "\(projectName) - \(timeDescription)"
        case .manual:
            return "\(projectName) - Manual"
        case .autoLocation:
            return "\(projectName) - Auto - \(timeDescription)"
        }
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
