import XCTest
@testable import CodexUsageCore

final class CodexPlanTransitionScenarioTests: XCTestCase {
    private let transitionAt = 2_000_000_000

    func testConfigurationRejectsInvalidUserInputs() {
        XCTAssertThrowsError(try configuration(currentPlanLabel: " "))
        XCTAssertThrowsError(try configuration(targetPlanLabel: ""))
        XCTAssertThrowsError(try configuration(targetRelativeCapacity: 0))
        XCTAssertThrowsError(try configuration(targetRelativeCapacity: -0.25))
        XCTAssertThrowsError(try configuration(reservePercent: -1))
        XCTAssertThrowsError(try configuration(reservePercent: 101))
        XCTAssertThrowsError(try configuration(plannedTransitionAt: 0))
        XCTAssertThrowsError(try configuration(confirmedTransitionAt: -1))
        XCTAssertThrowsError(try configuration(currentPlanEpochID: ""))
        XCTAssertThrowsError(try configuration(targetPlanEpochID: " "))
    }

    func testConfigurationStoresOnlyExplicitUserPlanLabelsAndDoesNotInferPriceTier() throws {
        let configuration = try self.configuration(
            currentPlanLabel: "직접 입력한 현재 플랜",
            targetPlanLabel: "직접 입력한 목표 플랜"
        )
        let data = try JSONEncoder().encode(configuration)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["currentPlanLabel"] as? String, "직접 입력한 현재 플랜")
        XCTAssertEqual(object["targetPlanLabel"] as? String, "직접 입력한 목표 플랜")
        XCTAssertNil(object["planType"])
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("$100"))
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("$200"))
    }

    func testConfigurationStoreWritesAtomicallyToSeparateStableJSONFile() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cacheURL = directory.appendingPathComponent("usage.json")
        let fileURL = CodexPlanTransitionConfigurationStore.defaultFileURL(
            adjacentToCacheFileURL: cacheURL
        )
        let store = CodexPlanTransitionConfigurationStore(fileURL: fileURL)
        let configuration = try self.configuration()

        try store.write(configuration)

        XCTAssertEqual(fileURL.lastPathComponent, "usage-plan-transition.json")
        XCTAssertNotEqual(fileURL, cacheURL)
        XCTAssertEqual(try store.read(), configuration)
        XCTAssertEqual(
            Set(try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(contentsOf: fileURL)) as? [String: Any]
            ).keys),
            [
                "schemaVersion",
                "currentPlanLabel",
                "targetPlanLabel",
                "targetRelativeCapacity",
                "reservePercent",
                "plannedTransitionAt",
                "confirmedTransitionAt",
                "currentPlanEpochID",
                "targetPlanEpochID"
            ]
        )
    }

    func testStoreRejectsInvalidDecodedConfiguration() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("usage-plan-transition.json")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let invalid = """
        {
          "schemaVersion": 1,
          "currentPlanLabel": "Current",
          "targetPlanLabel": "Target",
          "targetRelativeCapacity": 0,
          "reservePercent": 20,
          "currentPlanEpochID": "current",
          "targetPlanEpochID": "target"
        }
        """
        try invalid.write(to: fileURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try CodexPlanTransitionConfigurationStore(fileURL: fileURL).read())
    }

    func testPlannedDateDoesNotActivateTargetEpochUntilUserConfirmsTransition() throws {
        let configuration = try self.configuration(
            plannedTransitionAt: transitionAt,
            confirmedTransitionAt: nil
        )
        let epochs = CodexPlanTransitionEpochs(configuration: configuration)

        XCTAssertTrue(epochs.current.contains(transitionAt + 86_400))
        XCTAssertFalse(epochs.target.contains(transitionAt + 86_400))
        XCTAssertNil(epochs.current.endsAt)
        XCTAssertNil(epochs.target.startsAt)
    }

    func testConfirmedTransitionCreatesExclusiveEpochBoundary() throws {
        let configuration = try self.configuration(
            plannedTransitionAt: transitionAt - 3_600,
            confirmedTransitionAt: transitionAt
        )
        let epochs = CodexPlanTransitionEpochs(configuration: configuration)

        XCTAssertTrue(epochs.current.contains(transitionAt - 1))
        XCTAssertFalse(epochs.current.contains(transitionAt))
        XCTAssertFalse(epochs.target.contains(transitionAt - 1))
        XCTAssertTrue(epochs.target.contains(transitionAt))
    }

    func testObservationCrossingConfirmedEpochBoundaryIsExcluded() throws {
        let epochs = CodexPlanTransitionEpochs(configuration: try configuration(
            confirmedTransitionAt: transitionAt
        ))
        let crossing = try observation(
            window: .weekly,
            startedAt: transitionAt - 3 * 86_400,
            endedAt: transitionAt + 4 * 86_400,
            epochID: "current",
            usedPercent: 40
        )

        XCTAssertFalse(crossing.isFullyContained(in: epochs.current))
        XCTAssertFalse(crossing.isFullyContained(in: epochs.target))
    }

    func testScenarioUsesObservedPercentDividedByRelativeCapacityAndComputesStatistics() throws {
        let configuration = try self.configuration(
            targetRelativeCapacity: 0.5,
            reservePercent: 20
        )
        let observations = try [10.0, 20, 30, 40, 55].enumerated().flatMap { index, used in
            let timestamp = transitionAt - (5 - index) * 3_600
            return [
                try observation(
                    window: .fiveHour,
                    startedAt: timestamp - 300,
                    endedAt: timestamp,
                    epochID: "current",
                    usedPercent: used
                ),
                try observation(
                    window: .weekly,
                    startedAt: timestamp - 300,
                    endedAt: timestamp,
                    epochID: "current",
                    usedPercent: used / 2
                )
            ]
        }
        let scenario = CodexPlanTransitionScenarioBuilder(
            minimumObservationCount: 3,
            minimumObservationDurationSeconds: 2 * 3_600
        ).scenario(configuration: configuration, observations: observations, now: transitionAt - 1)

        XCTAssertEqual(scenario.basisLabel, "사용자 설정 기반 예상")
        XCTAssertEqual(scenario.observationStatus, .sufficient)
        XCTAssertEqual(scenario.fiveHour.observedP50Percent, 30)
        XCTAssertEqual(scenario.fiveHour.observedP90Percent, 55)
        XCTAssertEqual(scenario.fiveHour.observedMaximumPercent, 55)
        XCTAssertEqual(scenario.fiveHour.projectedP50Percent, 60)
        XCTAssertEqual(scenario.fiveHour.projectedP90Percent, 110)
        XCTAssertEqual(scenario.fiveHour.projectedMaximumPercent, 110)
        XCTAssertEqual(scenario.fiveHour.reserveShortfallWindowCount, 1)
        XCTAssertEqual(scenario.fiveHour.limitExceededWindowCount, 1)
        XCTAssertEqual(scenario.weekly.projectedMaximumPercent, 55)
    }

    func testScenarioFiltersDifferentEpochAndBoundaryCrossingObservations() throws {
        let configuration = try self.configuration(confirmedTransitionAt: transitionAt)
        let validTimes = [transitionAt - 10_800, transitionAt - 7_200, transitionAt - 3_600]
        var observations = try validTimes.map {
            try observation(
                window: .fiveHour,
                startedAt: $0 - 300,
                endedAt: $0,
                epochID: "current",
                usedPercent: 30
            )
        }
        observations.append(try observation(
            window: .fiveHour,
            startedAt: transitionAt + 3_000,
            endedAt: transitionAt + 3_600,
            epochID: "target",
            usedPercent: 99
        ))
        observations.append(try observation(
            window: .fiveHour,
            startedAt: transitionAt - 300,
            endedAt: transitionAt + 300,
            epochID: "current",
            usedPercent: 90
        ))

        let scenario = CodexPlanTransitionScenarioBuilder(
            minimumObservationCount: 3,
            minimumObservationDurationSeconds: 3_600
        ).scenario(configuration: configuration, observations: observations, now: transitionAt)

        XCTAssertEqual(scenario.fiveHour.observationCount, 3)
        XCTAssertEqual(scenario.fiveHour.observedMaximumPercent, 30)
    }

    func testScenarioUsesPeakOnceWhenFiveHourResetTimestampJitters() throws {
        let configuration = try self.configuration()
        let observations = try [
            observation(
                window: .fiveHour,
                startedAt: transitionAt - 18_000,
                endedAt: transitionAt,
                epochID: "current",
                usedPercent: 20
            ),
            observation(
                window: .fiveHour,
                startedAt: transitionAt - 17_940,
                endedAt: transitionAt + 60,
                epochID: "current",
                usedPercent: 30
            )
        ]
        let scenario = CodexPlanTransitionScenarioBuilder(
            minimumObservationCount: 1,
            minimumObservationDurationSeconds: 0
        ).scenario(
            configuration: configuration,
            observations: observations,
            now: transitionAt + 120
        )

        XCTAssertEqual(scenario.fiveHour.observationCount, 1)
        XCTAssertEqual(scenario.fiveHour.observedMaximumPercent, 30)
    }

    func testScenarioReportsInsufficientObservationsForSampleCountOrDuration() throws {
        let configuration = try self.configuration()
        let observations = try [0, 60].map {
            try observation(
                window: .fiveHour,
                startedAt: transitionAt - 3_600 + $0,
                endedAt: transitionAt - 3_300 + $0,
                epochID: "current",
                usedPercent: 20
            )
        }
        let builder = CodexPlanTransitionScenarioBuilder(
            minimumObservationCount: 3,
            minimumObservationDurationSeconds: 3_600
        )

        let scenario = builder.scenario(
            configuration: configuration,
            observations: observations,
            now: transitionAt - 1
        )

        XCTAssertEqual(scenario.observationStatus, .insufficient)
        XCTAssertEqual(scenario.fiveHour.observationStatus, .insufficient)
        XCTAssertNil(scenario.fiveHour.observedP90Percent)
        XCTAssertNil(scenario.fiveHour.projectedP50Percent)
    }

    func testTransitionStatusSeparatesPlannedFromConfirmedSevenDayObservation() throws {
        let builder = CodexPlanTransitionScenarioBuilder()
        let planned = try configuration(
            plannedTransitionAt: transitionAt,
            confirmedTransitionAt: nil
        )
        XCTAssertEqual(
            builder.scenario(configuration: planned, observations: [], now: transitionAt + 1).transitionStatus,
            .planned(at: transitionAt)
        )

        let confirmed = try configuration(
            plannedTransitionAt: transitionAt - 86_400,
            confirmedTransitionAt: transitionAt
        )
        XCTAssertEqual(
            builder.scenario(configuration: confirmed, observations: [], now: transitionAt).transitionStatus,
            .observing(until: transitionAt + 7 * 86_400)
        )
        XCTAssertEqual(
            builder.scenario(
                configuration: confirmed,
                observations: [],
                now: transitionAt + 7 * 86_400
            ).transitionStatus,
            .awaitingObservations(since: transitionAt)
        )
    }

    func testFutureConfirmedDateRemainsPlannedUntilBoundary() throws {
        let configuration = try self.configuration(
            confirmedTransitionAt: transitionAt
        )
        let scenario = CodexPlanTransitionScenarioBuilder().scenario(
            configuration: configuration,
            observations: [],
            now: transitionAt - 1
        )

        XCTAssertEqual(scenario.transitionStatus, .planned(at: transitionAt))
    }

    func testPostTransitionComparisonUsesOnlyFirstSevenDaysAndExposesDelta() throws {
        let configuration = try self.configuration(
            targetRelativeCapacity: 0.5,
            confirmedTransitionAt: transitionAt
        )
        var observations: [CodexPlanTransitionObservation] = []
        for index in 0..<6 {
            let currentEnd = transitionAt - (6 - index) * 5 * 3_600
            observations.append(try observation(
                window: .fiveHour,
                startedAt: currentEnd - 5 * 3_600,
                endedAt: currentEnd,
                epochID: "current",
                usedPercent: 30 + Double(index * 2)
            ))
            let targetEnd = transitionAt + (index + 1) * 5 * 3_600
            observations.append(try observation(
                window: .fiveHour,
                startedAt: targetEnd - 5 * 3_600,
                endedAt: targetEnd,
                epochID: "target",
                usedPercent: 70 + Double(index * 2)
            ))
        }
        observations.append(try observation(
            window: .fiveHour,
            startedAt: transitionAt + 8 * 86_400 - 5 * 3_600,
            endedAt: transitionAt + 8 * 86_400,
            epochID: "target",
            usedPercent: 100
        ))
        let scenario = CodexPlanTransitionScenarioBuilder().scenario(
            configuration: configuration,
            observations: observations,
            now: transitionAt + 9 * 86_400
        )

        XCTAssertEqual(scenario.transitionStatus, .completed(
            observedThrough: transitionAt + 7 * 86_400
        ))
        XCTAssertEqual(scenario.targetFiveHour.observedP90Percent, 80)
        XCTAssertEqual(scenario.fiveHour.projectedP90Percent, 80)
        XCTAssertEqual(scenario.fiveHourP90DeltaPercent, 0)
    }

    func testReserveShortfallRequiresProjectedUsageAboveBoundary() throws {
        let configuration = try self.configuration(
            targetRelativeCapacity: 1,
            reservePercent: 20
        )
        let observations = try [79.9, 80, 80.1].enumerated().map { index, used in
            try observation(
                window: .fiveHour,
                startedAt: transitionAt - (index + 2) * 3_600,
                endedAt: transitionAt - (index + 1) * 3_600,
                epochID: "current",
                usedPercent: used
            )
        }
        let scenario = CodexPlanTransitionScenarioBuilder(
            minimumObservationCount: 3,
            minimumObservationDurationSeconds: 0
        ).scenario(
            configuration: configuration,
            observations: observations,
            now: transitionAt
        )

        XCTAssertEqual(scenario.fiveHour.reserveShortfallWindowCount, 1)
    }

    private func configuration(
        currentPlanLabel: String = "Current user label",
        targetPlanLabel: String = "Target user label",
        targetRelativeCapacity: Double = 0.5,
        reservePercent: Double = 20,
        plannedTransitionAt: Int? = nil,
        confirmedTransitionAt: Int? = nil,
        currentPlanEpochID: String = "current",
        targetPlanEpochID: String = "target"
    ) throws -> CodexPlanTransitionConfiguration {
        try CodexPlanTransitionConfiguration(
            currentPlanLabel: currentPlanLabel,
            targetPlanLabel: targetPlanLabel,
            targetRelativeCapacity: targetRelativeCapacity,
            reservePercent: reservePercent,
            plannedTransitionAt: plannedTransitionAt,
            confirmedTransitionAt: confirmedTransitionAt,
            currentPlanEpochID: currentPlanEpochID,
            targetPlanEpochID: targetPlanEpochID
        )
    }

    private func observation(
        window: CodexPlanTransitionWindow,
        startedAt: Int,
        endedAt: Int,
        epochID: String,
        usedPercent: Double
    ) throws -> CodexPlanTransitionObservation {
        try CodexPlanTransitionObservation(
            window: window,
            windowStartedAt: startedAt,
            windowEndedAt: endedAt,
            recordedAt: endedAt,
            planEpochID: epochID,
            usedPercent: usedPercent
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
