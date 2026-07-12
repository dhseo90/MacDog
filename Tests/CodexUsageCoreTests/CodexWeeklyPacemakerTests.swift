import XCTest
@testable import CodexUsageCore

final class CodexWeeklyPacemakerTests: XCTestCase {
    private let resetStartAt = 1_800_000_000

    func testFirstDayUsesObservedResetBoundaryBaseline() throws {
        let pacemaker = try XCTUnwrap(makePacemaker(
            day: 1,
            currentUsedPercent: 12,
            history: CodexUsageWeeklyHistory(samples: [
                sample(recordedAt: resetStartAt, usedPercent: 0)
            ])
        ))

        XCTAssertEqual(pacemaker.dayIndex, 1)
        XCTAssertEqual(pacemaker.currentDayUsedPercent, 12)
        XCTAssertEqual(pacemaker.remainingDailyTargetPercent ?? -1, 100.0 / 7 - 12, accuracy: 0.001)
        XCTAssertTrue(pacemaker.isDailyTargetApproaching)
        XCTAssertFalse(pacemaker.isDailyTargetExceeded)
    }

    func testLaterDayUsesSampleAtDayBoundary() throws {
        let history = CodexUsageWeeklyHistory(samples: [
            sample(recordedAt: resetStartAt + 2 * 86_400 - 60, usedPercent: 24)
        ])
        let pacemaker = try XCTUnwrap(makePacemaker(
            day: 3,
            offset: 3_600,
            currentUsedPercent: 40,
            history: history
        ))

        XCTAssertEqual(pacemaker.dayIndex, 3)
        XCTAssertEqual(try XCTUnwrap(pacemaker.currentDayUsedPercent), 16, accuracy: 0.001)
        XCTAssertTrue(pacemaker.isDailyTargetExceeded)
        XCTAssertFalse(pacemaker.isCumulativeTargetExceeded)
    }

    func testExactDayBoundaryMovesToNextSlotAndExactTargetIsNotExceeded() throws {
        let target = CodexWeeklyPacemaker.dailyTargetUsedPercent
        let history = CodexUsageWeeklyHistory(samples: [
            sample(recordedAt: resetStartAt + 86_400, usedPercent: 10)
        ])
        let pacemaker = try XCTUnwrap(makePacemaker(
            day: 2,
            offset: 0,
            currentUsedPercent: 10 + target,
            history: history
        ))

        XCTAssertEqual(pacemaker.dayIndex, 2)
        XCTAssertEqual(try XCTUnwrap(pacemaker.currentDayUsedPercent), target, accuracy: 0.001)
        XCTAssertTrue(pacemaker.isDailyTargetApproaching)
        XCTAssertFalse(pacemaker.isDailyTargetExceeded)
    }

    func testMissingDayBoundarySampleKeepsDailyUsageUnknown() throws {
        let history = CodexUsageWeeklyHistory(samples: [
            sample(recordedAt: resetStartAt + 86_400, usedPercent: 10)
        ])
        let pacemaker = try XCTUnwrap(makePacemaker(
            day: 4,
            currentUsedPercent: 60,
            history: history
        ))

        XCTAssertNil(pacemaker.currentDayUsedPercent)
        XCTAssertNil(pacemaker.remainingDailyTargetPercent)
        XCTAssertFalse(pacemaker.isDailyTargetApproaching)
        XCTAssertFalse(pacemaker.isDailyTargetExceeded)
        XCTAssertTrue(pacemaker.isCumulativeTargetExceeded)
    }

    func testHistoryFromDifferentResetWindowIsIgnored() throws {
        let otherReset = resetStartAt + 7 * 86_400 + 600
        let history = CodexUsageWeeklyHistory(samples: [
            CodexUsageWeeklyHistorySample(
                recordedAt: resetStartAt + 2 * 86_400,
                usedPercent: 20,
                remainingPercent: 80,
                resetsAt: otherReset,
                windowDurationMins: 10_080
            )
        ])
        let pacemaker = try XCTUnwrap(makePacemaker(
            day: 3,
            currentUsedPercent: 45,
            history: history
        ))

        XCTAssertNil(pacemaker.currentDayUsedPercent)
    }

    func testRejectsExpiredOrNonWeeklyWindow() {
        let resetsAt = resetStartAt + 7 * 86_400
        XCTAssertNil(CodexWeeklyPacemakerBuilder().pacemaker(
            weeklyWindow: window(usedPercent: 20, resetsAt: resetsAt),
            history: .empty,
            recordedAt: resetsAt
        ))
        XCTAssertNil(CodexWeeklyPacemakerBuilder().pacemaker(
            weeklyWindow: UsageWindowReport(
                kind: .weekly,
                usedPercent: 20,
                remainingPercent: 80,
                windowDurationMins: 300,
                resetsAt: resetsAt
            ),
            history: .empty,
            recordedAt: resetStartAt + 60
        ))
    }

    private func makePacemaker(
        day: Int,
        offset: Int = 60,
        currentUsedPercent: Double,
        history: CodexUsageWeeklyHistory
    ) -> CodexWeeklyPacemaker? {
        let resetsAt = resetStartAt + 7 * 86_400
        return CodexWeeklyPacemakerBuilder().pacemaker(
            weeklyWindow: window(usedPercent: currentUsedPercent, resetsAt: resetsAt),
            history: history,
            recordedAt: resetStartAt + (day - 1) * 86_400 + offset
        )
    }

    private func window(usedPercent: Double, resetsAt: Int) -> UsageWindowReport {
        UsageWindowReport(
            kind: .weekly,
            usedPercent: usedPercent,
            remainingPercent: 100 - usedPercent,
            windowDurationMins: 10_080,
            resetsAt: resetsAt
        )
    }

    private func sample(recordedAt: Int, usedPercent: Double) -> CodexUsageWeeklyHistorySample {
        CodexUsageWeeklyHistorySample(
            recordedAt: recordedAt,
            usedPercent: usedPercent,
            remainingPercent: 100 - usedPercent,
            resetsAt: resetStartAt + 7 * 86_400,
            windowDurationMins: 10_080
        )
    }
}
