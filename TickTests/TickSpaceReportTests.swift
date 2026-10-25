import XCTest
@testable import Tick

final class TickSpaceReportTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 12, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func manual(_ projectID: UUID, at date: Date, title: String = "Development", notes: String = "Tested changes", duration: TimeInterval = 1_800) -> TimeSession {
        TimeSession(projectID: projectID, title: title, notes: notes, startedAt: nil, endedAt: nil,
                    manualDuration: duration, entrySource: .manual, createdAt: date)
    }

    func testReportMatchesSpaceSummaryForEveryPresetAndIncludesArchivedWork() {
        let project = TickProject(name: "Client", isArchived: true)
        let other = TickProject(name: "Private")
        let now = date(15)
        let sessions = [manual(project.id, at: now), manual(project.id, at: date(1)),
                        manual(project.id, at: date(1, month: 1)), manual(other.id, at: now)]
        for period in SummaryPeriod.allCases {
            let range = TickReportDateRange.initial(period: period, projectID: project.id, sessions: sessions, referenceDate: now, calendar: calendar)
            let report = TickSpaceReport(projectID: project.id, projectName: project.name, range: range, sessions: sessions, generatedAt: now, calendar: calendar)
            let summary = TickSummaryCalculator.summary(for: period, projects: [project, other], sessions: sessions, referenceDate: now, calendar: calendar)
            XCTAssertEqual(report.totalDuration, summary.durationByProject.first { $0.projectID == project.id }?.duration, period.rawValue)
            XCTAssertFalse(report.entries.contains { $0.id == sessions.last?.id })
        }
    }

    func testCustomRangeIncludesBothDaysAndExcludesNextMidnightAndOtherSpaces() {
        let projectID = UUID()
        let start = date(14, hour: 0)
        let nextMidnight = date(16, hour: 0)
        let sessions = [manual(projectID, at: start), manual(projectID, at: nextMidnight.addingTimeInterval(-1)),
                        manual(projectID, at: start.addingTimeInterval(-1)), manual(projectID, at: nextMidnight),
                        manual(UUID(), at: start, title: "Other client secret")]
        let report = TickSpaceReport(projectID: projectID, projectName: "Client", range: TickReportDateRange(start: start, end: date(15), calendar: calendar), sessions: sessions, calendar: calendar)
        XCTAssertEqual(report.sessionCount, 2)
        XCTAssertEqual(report.totalDuration, 3_600)
        XCTAssertEqual(report.days.count, 2)
        XCTAssertFalse(report.sharedText.contains("Other client secret"))
    }

    func testSummaryChartsAndReportExcludeTheFollowingPeriodBoundary() {
        let project = TickProject(name: "Client")
        let now = date(15)
        for period in [SummaryPeriod.day, .week, .month, .year] {
            let interval = period.interval(containing: now, calendar: calendar)
            let sessions = [manual(project.id, at: interval.start), manual(project.id, at: interval.end)]
            let range = TickReportDateRange.initial(period: period, projectID: project.id, sessions: sessions, referenceDate: now, calendar: calendar)
            let report = TickSpaceReport(projectID: project.id, projectName: project.name, range: range, sessions: sessions, generatedAt: now, calendar: calendar)
            let summary = TickSummaryCalculator.summary(for: period, projects: [project], sessions: sessions, referenceDate: now, calendar: calendar)
            let chart = TickChartDataBuilder.projectEntries(for: period, projects: [project], sessions: sessions, referenceDate: now, calendar: calendar)
            let timeline = TickChartDataBuilder.periodProjectEntries(for: period, projects: [project], sessions: sessions, referenceDate: now, calendar: calendar)
            XCTAssertEqual(summary.totalDuration, 1_800, period.rawValue)
            XCTAssertEqual(report.totalDuration, summary.totalDuration, period.rawValue)
            XCTAssertEqual(chart.first?.duration, summary.totalDuration, period.rawValue)
            if period != .day {
                XCTAssertEqual(timeline.reduce(0) { $0 + $1.duration }, summary.totalDuration, period.rawValue)
            }
        }
    }

    func testCalendarDayAcrossDaylightSavingUsesNextLocalMidnight() {
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let range = TickReportDateRange(start: start, end: start, calendar: calendar)
        XCTAssertEqual(range.endExclusive.timeIntervalSince(range.start), 25 * 3_600)
        XCTAssertTrue(range.contains(range.endExclusive.addingTimeInterval(-1)))
        XCTAssertFalse(range.contains(range.endExclusive))
    }

    func testDescriptionsGroupExactlyAndNotesCanBeOmittedFromEntireReport() {
        let projectID = UUID()
        let now = date(15)
        let range = TickReportDateRange(start: now, end: now, calendar: calendar)
        let sessions = [manual(projectID, at: now), manual(projectID, at: now, title: " Development "),
                        manual(projectID, at: now, notes: "Private note"), manual(projectID, at: now, title: "  ", notes: " ")]
        let report = TickSpaceReport(projectID: projectID, projectName: "Client", range: range, sessions: sessions, generatedAt: now, calendar: calendar)
        XCTAssertEqual(report.work.count, 3)
        XCTAssertEqual(report.work.first?.sessionCount, 2)
        XCTAssertEqual(report.work.first?.duration, 3_600)
        XCTAssertTrue(report.sharedText.contains("Untitled work"))
        XCTAssertTrue(report.sharedText.contains("Private note"))
        let withoutNotes = TickSpaceReport(projectID: projectID, projectName: "Client", range: range, sessions: sessions, generatedAt: now, includeNotes: false, calendar: calendar)
        XCTAssertEqual(withoutNotes.work.count, 2)
        XCTAssertTrue(withoutNotes.entries.allSatisfy { $0.description.notes.isEmpty })
        XCTAssertFalse(withoutNotes.sharedText.contains("Private note"))
        XCTAssertFalse(withoutNotes.sharedText.contains("Tested changes"))
        XCTAssertEqual(withoutNotes.totalDuration, report.totalDuration)
    }

    func testReportPreservesFullOvernightDurationAndSnapshotsPausedAndRunningTime() {
        let projectID = UUID()
        let now = date(15)
        let overnight = TimeSession(projectID: projectID, title: "Overnight", notes: "", startedAt: date(14, hour: 23), endedAt: date(15, hour: 1), manualDuration: nil, entrySource: .timer)
        let paused = TimeSession(projectID: projectID, title: "Paused work", notes: "", startedAt: now.addingTimeInterval(-3_600), endedAt: nil, manualDuration: nil, pausedAt: now.addingTimeInterval(-600), accumulatedPausedDuration: 300, entrySource: .timer)
        let running = TimeSession(projectID: projectID, title: "Running work", notes: "", startedAt: now.addingTimeInterval(-61), endedAt: nil, manualDuration: nil, entrySource: .autoLocation)
        let report = TickSpaceReport(projectID: projectID, projectName: "Client", range: TickReportDateRange(start: date(14), end: now, calendar: calendar), sessions: [running, overnight, paused], generatedAt: now, calendar: calendar)
        XCTAssertEqual(report.totalDuration, 7_200 + 2_700 + 61)
        XCTAssertEqual(report.activeSessionCount, 2)
        XCTAssertEqual(report.entries.map(\.status), ["Timer", "Paused", "Running"])
        XCTAssertTrue(report.sharedText.contains("1m 1s"))
        XCTAssertTrue(report.sharedText.contains("running or paused"))
        XCTAssertFalse(report.sharedText.contains("Sessions are included by their recorded date"))
        XCTAssertFalse(report.sharedText.contains("Generated with Ticks"))
        XCTAssertEqual(report.days.reduce(0) { $0 + $1.duration }, report.totalDuration)
        XCTAssertEqual(report.work.reduce(0) { $0 + $1.duration }, report.totalDuration)
    }

    func testSharedReportSeparatesHeadingsTasksTimingAndNotesIntoReadableBlocks() {
        let projectID = UUID()
        let start = date(20, hour: 9)
        let finish = date(21, hour: 14)
        let title = "Migration of proof of concept to business AWS account"
        let note = "Updated support functions.\nChecked the remaining UI issues."
        let sessions = [
            manual(projectID, at: finish, title: "Add versioning", notes: "", duration: 1_800),
            TimeSession(projectID: projectID, title: title, notes: note, startedAt: start,
                        endedAt: start.addingTimeInterval(3_615), manualDuration: nil, entrySource: .timer)
        ]
        let report = TickSpaceReport(projectID: projectID, projectName: "3Puzzles",
                                     range: TickReportDateRange(start: start, end: finish, calendar: calendar),
                                     sessions: sessions, generatedAt: finish, calendar: calendar)
        let expected = """
        3Puzzles
        Work report

        \(report.range.title)


        Overview

        Total time: 1h 30m 15s
        2 sessions across 2 days


        Work summary

        1. \(title)
        Time: 1h 15s
        Notes: \(note)

        2. Add versioning
        Time: 30m


        Daily detail

        \(report.days[0].id.formatted(date: .complete, time: .omitted))
        Daily total: 1h 15s

        • \(title)
        Time: 1h 15s
        Started: \(start.formatted(date: .omitted, time: .shortened)) · Timer
        Notes: \(note)


        \(report.days[1].id.formatted(date: .complete, time: .omitted))
        Daily total: 30m

        • Add versioning
        Time: 30m
        Recorded manually
        """
        XCTAssertEqual(report.sharedText, expected)
        XCTAssertFalse(report.sharedText.contains("As of"))
        let preview = XCTAttachment(string: report.sharedText)
        preview.name = "Shared report formatting"
        preview.lifetime = .keepAlways
        add(preview)
    }

    func testEmptyReportAndLifetimeFallbackHaveFiniteDates() {
        let projectID = UUID()
        let now = date(15)
        let range = TickReportDateRange.initial(period: .lifetime, projectID: projectID, sessions: [], referenceDate: now, calendar: calendar)
        XCTAssertEqual(range.start, calendar.startOfDay(for: now))
        XCTAssertEqual(range.start, range.end)
        let report = TickSpaceReport(projectID: projectID, projectName: "Unknown Space", range: range, sessions: [], calendar: calendar)
        XCTAssertEqual(report.totalDuration, 0)
        XCTAssertTrue(report.sharedText.contains("No time recorded"))
        XCTAssertFalse(report.sharedText.contains("Daily detail"))
        XCTAssertEqual(TickSpaceReport.durationText(0), "0s")
    }
}
