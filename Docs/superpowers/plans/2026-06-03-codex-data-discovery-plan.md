# Codex 데이터 탐색 관문 구현 계획

> **에이전트 작업자:** REQUIRED SUB-SKILL: 이 계획을 작업 단위로 실행할 때는 `superpowers:subagent-driven-development`를 권장하며, 같은 세션에서 순차 실행할 때는 `superpowers:executing-plans`를 사용한다. 단계 추적은 체크박스(`- [ ]`) 문법을 유지한다.

**목표:** Codex app-server 응답에서 MacDog가 아직 보여주지 않는 안전한 사용량 묶음/필드 정보를 확인하고, 기본 JSON/cache 계약을 깨지 않는 `doctor` 고급 진단 표면을 추가한다.

**아키텍처:** raw app-server payload를 저장하거나 출력하지 않고, 메모리 안에서 JSON-RPC 응답의 `result` 구조를 읽어 필드 이름만 추출한다. `CodexUsageCore`가 필드 목록과 `doctor` 출력 포맷을 소유하고, CLI는 기존 `doctor` 흐름에서 진단 report를 받아 출력만 담당한다. 이 계획은 Codex 데이터 탐색 관문만 구현하며, 유틸리티 코어 정리는 탐색 결과를 보고 별도 계획으로 작성한다.

**기술 스택:** Swift 6, SwiftPM, Foundation `JSONSerialization`, XCTest, 기존 `CodexUsageCore`/`CodexUsageCLI` 구조.

---

## 범위와 경계

- Apple Developer Program, Developer ID, notarization, App Group provisioning, App Store Connect가 필요한 작업은 하지 않는다.
- `~/.codex/auth.json`을 읽거나 출력하지 않는다.
- raw app-server payload를 파일, 로그, cache, UI에 남기지 않는다.
- `codex-usage status --json` 출력 schema와 app-owned cache schema는 바꾸지 않는다.
- WidgetKit 기본 제외 정책은 건드리지 않는다.
- GUI 앱 실행, 설치 스크립트, LaunchAgent 변경, helper 설치/삭제, DMG 설치 검수, 장시간 테스트, push는 실행하지 않는다.
- 커밋은 사용자가 단계별 커밋을 명시 요청한 경우에만 수행한다.

## 파일 구조

- 생성: `Sources/CodexUsageCore/Usage/CodexUsageFieldInventory.swift`
  - JSON-RPC rate limit 응답에서 필드 이름만 추출하고, 민감해 보이는 필드 이름은 `<redacted-sensitive-field>`로 대체한다.
- 생성: `Sources/CodexUsageCore/Usage/CodexUsageDoctorFormatter.swift`
  - `doctor`가 출력할 bucket inventory 문장을 만든다.
- 수정: `Sources/CodexUsageCore/AppServer/CodexAppServerClient.swift`
  - 기존 `readRateLimits()` 동작은 보존하고, 같은 요청에서 decoded response와 field inventory를 함께 얻는 진단 메서드를 추가한다.
- 수정: `Sources/CodexUsageCore/Usage/CodexUsageService.swift`
  - `CodexUsageDiagnosticReport`와 `readDiagnosticReport()`를 추가한다.
- 수정: `Sources/CodexUsageCLI/main.swift`
  - `doctor` 명령에 bucket inventory 섹션을 추가한다.
- 생성: `Tests/CodexUsageCoreTests/CodexUsageFieldInventoryTests.swift`
  - 고정 예제 기반 field inventory, 추가 안전 field, 민감 field redaction을 검증한다.
- 생성: `Tests/CodexUsageCoreTests/CodexUsageDoctorFormatterTests.swift`
  - `doctor` bucket inventory 출력 포맷을 검증한다.
- 수정: `README.md`
  - `codex-usage doctor`가 고급 bucket inventory를 보여줄 수 있음을 짧게 기록한다.

## 작업 1: Codex field inventory 모델 추가

**Files:**

- Create: `Sources/CodexUsageCore/Usage/CodexUsageFieldInventory.swift`
- Create: `Tests/CodexUsageCoreTests/CodexUsageFieldInventoryTests.swift`

- [ ] **Step 1: 실패하는 field inventory 테스트 작성**

`Tests/CodexUsageCoreTests/CodexUsageFieldInventoryTests.swift`를 추가한다.

```swift
import XCTest
@testable import CodexUsageCore

final class CodexUsageFieldInventoryTests: XCTestCase {
    func testBuildsInventoryFromJSONRPCFixtureEnvelope() throws {
        let fixture = try JSONSerialization.jsonObject(with: loadFixtureData())
        let envelope: [String: Any] = [
            "id": CodexAppServerRequestFactory.rateLimitReadRequestID,
            "result": fixture
        ]
        let data = try JSONSerialization.data(withJSONObject: envelope)

        let inventory = try CodexUsageFieldInventory.make(fromJSONRPCResponseData: data)

        XCTAssertEqual(inventory.topLevelFields, ["rateLimits", "rateLimitsByLimitId"])
        XCTAssertEqual(inventory.buckets.map(\.key), ["codex", "codex_bengalfox"])
        XCTAssertEqual(
            inventory.buckets.first?.fields,
            ["credits", "limitId", "limitName", "planType", "primary", "rateLimitReachedType", "secondary"]
        )
        XCTAssertEqual(inventory.buckets.first?.primaryFields, ["resetsAt", "usedPercent", "windowDurationMins"])
        XCTAssertEqual(inventory.buckets.first?.secondaryFields, ["resetsAt", "usedPercent", "windowDurationMins"])
        XCTAssertEqual(inventory.buckets.first?.creditsFields, ["balance", "hasCredits", "unlimited"])
    }

    func testKeepsAdditiveSafeFieldsAsFieldNamesOnly() throws {
        let json = """
        {
          "id": 2,
          "result": {
            "rateLimits": {
              "limitId": "codex",
              "limitName": "Codex",
              "primary": { "usedPercent": 12, "windowDurationMins": 300, "resetsAt": 1780000000, "safeFutureWindowField": "ignored-value" },
              "secondary": { "usedPercent": 34, "windowDurationMins": 10080, "resetsAt": 1780500000 },
              "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
              "planType": "pro",
              "rateLimitReachedType": null,
              "safeFutureBucketField": { "nested": true }
            },
            "safeFutureTopLevelField": "ignored-value"
          }
        }
        """

        let inventory = try CodexUsageFieldInventory.make(fromJSONRPCResponseData: Data(json.utf8))

        XCTAssertTrue(inventory.topLevelFields.contains("safeFutureTopLevelField"))
        XCTAssertTrue(inventory.buckets[0].fields.contains("safeFutureBucketField"))
        XCTAssertTrue(inventory.buckets[0].primaryFields.contains("safeFutureWindowField"))
    }

    func testRedactsSensitiveLookingFieldNamesAndNeverIncludesValues() throws {
        let json = """
        {
          "id": 2,
          "result": {
            "rateLimits": {
              "limitId": "codex",
              "limitName": "Codex",
              "primary": { "usedPercent": 12, "windowDurationMins": 300, "resetsAt": 1780000000 },
              "secondary": { "usedPercent": 34, "windowDurationMins": 10080, "resetsAt": 1780500000 },
              "credits": { "hasCredits": false, "unlimited": false, "balance": "0" },
              "planType": "pro",
              "rateLimitReachedType": null,
              "access_token": "secret-token-value",
              "cookie": "secret-cookie-value"
            }
          }
        }
        """

        let inventory = try CodexUsageFieldInventory.make(fromJSONRPCResponseData: Data(json.utf8))
        let summary = inventory.redactedSummaryLines.joined(separator: "\\n")

        XCTAssertTrue(inventory.buckets[0].fields.contains("<redacted-sensitive-field>"))
        XCTAssertFalse(summary.contains("access_token"))
        XCTAssertFalse(summary.contains("cookie"))
        XCTAssertFalse(summary.contains("secret-token-value"))
        XCTAssertFalse(summary.contains("secret-cookie-value"))
    }

    func testMissingResultThrowsInventoryError() {
        let json = #"{"id":2,"error":{"message":"unauthorized"}}"#

        XCTAssertThrowsError(
            try CodexUsageFieldInventory.make(fromJSONRPCResponseData: Data(json.utf8))
        ) { error in
            XCTAssertEqual(error as? CodexUsageFieldInventoryError, .missingResult)
        }
    }

    private func loadFixtureData() throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(
            forResource: "rate_limits_response",
            withExtension: "json"
        ))
        return try Data(contentsOf: url)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run:

```bash
swift test --filter CodexUsageFieldInventoryTests
```

Expected:

```text
error: cannot find 'CodexUsageFieldInventory' in scope
```

- [ ] **Step 3: field inventory 구현 추가**

`Sources/CodexUsageCore/Usage/CodexUsageFieldInventory.swift`를 추가한다.

```swift
import Foundation

public enum CodexUsageFieldInventoryError: Error, Equatable {
    case invalidEnvelope
    case missingResult
}

public struct CodexUsageFieldInventory: Equatable, Sendable {
    public let topLevelFields: [String]
    public let buckets: [CodexUsageBucketFieldInventory]

    public init(topLevelFields: [String], buckets: [CodexUsageBucketFieldInventory]) {
        self.topLevelFields = topLevelFields
        self.buckets = buckets
    }

    public static func make(fromJSONRPCResponseData data: Data) throws -> CodexUsageFieldInventory {
        guard
            let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw CodexUsageFieldInventoryError.invalidEnvelope
        }

        guard let result = envelope["result"] as? [String: Any] else {
            throw CodexUsageFieldInventoryError.missingResult
        }

        return make(fromRateLimitsObject: result)
    }

    public static func make(fromRateLimitsObject object: [String: Any]) -> CodexUsageFieldInventory {
        let bucketObjects = bucketObjects(from: object)
        return CodexUsageFieldInventory(
            topLevelFields: redactedSortedKeys(of: object),
            buckets: bucketObjects
                .map { key, bucket in
                    CodexUsageBucketFieldInventory(
                        key: sanitizedFieldName(key),
                        limitId: sanitizedFieldName(bucket["limitId"] as? String ?? key),
                        fields: redactedSortedKeys(of: bucket),
                        primaryFields: redactedSortedKeys(of: bucket["primary"] as? [String: Any]),
                        secondaryFields: redactedSortedKeys(of: bucket["secondary"] as? [String: Any]),
                        creditsFields: redactedSortedKeys(of: bucket["credits"] as? [String: Any])
                    )
                }
                .sorted { $0.key < $1.key }
        )
    }

    public var redactedSummaryLines: [String] {
        buckets.flatMap { bucket in
            [
                "bucket: \\(bucket.key)",
                "fields: \\(bucket.fields.joined(separator: \", \"))",
                "primary fields: \\(bucket.primaryFields.joined(separator: \", \"))",
                "secondary fields: \\(bucket.secondaryFields.joined(separator: \", \"))",
                "credits fields: \\(bucket.creditsFields.joined(separator: \", \"))"
            ]
        }
    }

    private static func bucketObjects(from object: [String: Any]) -> [(String, [String: Any])] {
        if let byID = object["rateLimitsByLimitId"] as? [String: Any] {
            return byID.compactMap { key, value in
                guard let bucket = value as? [String: Any] else { return nil }
                return (key, bucket)
            }
        }

        guard let legacy = object["rateLimits"] as? [String: Any] else {
            return []
        }

        return [(legacy["limitId"] as? String ?? "codex", legacy)]
    }

    private static func redactedSortedKeys(of object: [String: Any]?) -> [String] {
        guard let object else { return [] }
        return Array(Set(object.keys.map(sanitizedFieldName))).sorted()
    }

    private static func sanitizedFieldName(_ name: String) -> String {
        isSensitiveLookingFieldName(name) ? "<redacted-sensitive-field>" : name
    }

    private static func isSensitiveLookingFieldName(_ name: String) -> Bool {
        let normalized = name
            .replacingOccurrences(of: "-", with: "_")
            .lowercased()
        let sensitiveFragments = [
            "access_token",
            "refresh_token",
            "id_token",
            "auth_token",
            "authorization",
            "cookie",
            "session",
            "client_secret",
            "api_key"
        ]
        return sensitiveFragments.contains { normalized.contains($0) }
    }
}

public struct CodexUsageBucketFieldInventory: Equatable, Sendable {
    public let key: String
    public let limitId: String
    public let fields: [String]
    public let primaryFields: [String]
    public let secondaryFields: [String]
    public let creditsFields: [String]

    public init(
        key: String,
        limitId: String,
        fields: [String],
        primaryFields: [String],
        secondaryFields: [String],
        creditsFields: [String]
    ) {
        self.key = key
        self.limitId = limitId
        self.fields = fields
        self.primaryFields = primaryFields
        self.secondaryFields = secondaryFields
        self.creditsFields = creditsFields
    }
}
```

- [ ] **Step 4: field inventory 테스트 통과 확인**

Run:

```bash
swift test --filter CodexUsageFieldInventoryTests
```

Expected:

```text
Test Suite 'CodexUsageFieldInventoryTests' passed
```

- [ ] **Step 5: 조건부 커밋**

사용자가 단계별 커밋을 요청한 경우에만 실행한다.

```bash
git add Sources/CodexUsageCore/Usage/CodexUsageFieldInventory.swift Tests/CodexUsageCoreTests/CodexUsageFieldInventoryTests.swift
git commit -m "feat: add codex usage field inventory"
```

사용자가 커밋을 요청하지 않았다면 이 단계는 실행하지 않고 `커밋: 수행하지 않음 - 이유: 사용자 요청 없음`으로 보고한다.

## 작업 2: app-server 진단 report 경로 추가

**Files:**

- Modify: `Sources/CodexUsageCore/AppServer/CodexAppServerClient.swift`
- Modify: `Sources/CodexUsageCore/Usage/CodexUsageService.swift`
- Modify: `Tests/CodexUsageCoreTests/CodexUsageReportTests.swift`

- [ ] **Step 1: diagnostic report builder 테스트 작성**

`Tests/CodexUsageCoreTests/CodexUsageReportTests.swift`에 아래 테스트를 추가한다.

```swift
func testBuildsDiagnosticReportWithoutChangingUsageReport() throws {
    let response = try loadFixture()
    let fixtureObject = try XCTUnwrap(JSONSerialization.jsonObject(with: loadFixtureData()) as? [String: Any])
    let inventory = CodexUsageFieldInventory.make(fromRateLimitsObject: fixtureObject)
    let builder = CodexUsageReportBuilder(dateProvider: {
        Date(timeIntervalSince1970: 1_779_700_000)
    })

    let diagnostic = builder.buildDiagnosticReport(from: response, fieldInventory: inventory)

    XCTAssertEqual(diagnostic.report.generatedAt, 1_779_700_000)
    XCTAssertEqual(diagnostic.report.codexLimit?.fiveHour?.remainingPercent, 85)
    XCTAssertEqual(diagnostic.fieldInventory.buckets.map(\.key), ["codex", "codex_bengalfox"])
}
```

같은 test file의 helper 영역에 `loadFixtureData()`를 추가하고 기존 `loadFixture()`가 이를 재사용하게 바꾼다.

```swift
private func loadFixture() throws -> RateLimitsResponse {
    try JSONDecoder().decode(RateLimitsResponse.self, from: loadFixtureData())
}

private func loadFixtureData() throws -> Data {
    let url = try XCTUnwrap(Bundle.module.url(
        forResource: "rate_limits_response",
        withExtension: "json"
    ))
    return try Data(contentsOf: url)
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run:

```bash
swift test --filter CodexUsageReportTests/testBuildsDiagnosticReportWithoutChangingUsageReport
```

Expected:

```text
error: value of type 'CodexUsageReportBuilder' has no member 'buildDiagnosticReport'
```

- [ ] **Step 3: diagnostic report 모델과 builder 추가**

`Sources/CodexUsageCore/Usage/CodexUsageReport.swift`에 아래 타입과 메서드를 추가한다.

```swift
public struct CodexUsageDiagnosticReport: Equatable, Sendable {
    public let report: CodexUsageReport
    public let fieldInventory: CodexUsageFieldInventory

    public init(report: CodexUsageReport, fieldInventory: CodexUsageFieldInventory) {
        self.report = report
        self.fieldInventory = fieldInventory
    }
}
```

`CodexUsageReportBuilder` 안에 아래 메서드를 추가한다.

```swift
public func buildDiagnosticReport(
    from response: RateLimitsResponse,
    fieldInventory: CodexUsageFieldInventory
) -> CodexUsageDiagnosticReport {
    CodexUsageDiagnosticReport(
        report: build(from: response),
        fieldInventory: fieldInventory
    )
}
```

- [ ] **Step 4: client raw response 재사용 경로 추가**

`Sources/CodexUsageCore/AppServer/CodexAppServerClient.swift`에서 `readRateLimits(arguments:)`를 raw response data helper를 쓰도록 분리한다.

```swift
public struct CodexAppServerRateLimitDiagnostic: Equatable, Sendable {
    public let response: RateLimitsResponse
    public let fieldInventory: CodexUsageFieldInventory

    public init(response: RateLimitsResponse, fieldInventory: CodexUsageFieldInventory) {
        self.response = response
        self.fieldInventory = fieldInventory
    }
}
```

`CodexAppServerClient`에 public 메서드를 추가한다.

```swift
public func readRateLimitDiagnostic() throws -> CodexAppServerRateLimitDiagnostic {
    var lastError: Error?
    for arguments in appServerArgumentCandidates() {
        do {
            let data = try readRateLimitResponseData(arguments: arguments)
            return CodexAppServerRateLimitDiagnostic(
                response: try decodeResponse(
                    RateLimitsResponse.self,
                    from: data,
                    id: CodexAppServerRequestFactory.rateLimitReadRequestID
                ),
                fieldInventory: try CodexUsageFieldInventory.make(fromJSONRPCResponseData: data)
            )
        } catch {
            lastError = error
            guard Self.canRetryWithNextInvocation(after: error) else {
                throw error
            }
        }
    }

    throw lastError ?? CodexAppServerError.processLaunchFailed("No Codex app-server invocation was available.")
}
```

기존 private `readRateLimits(arguments:)`를 아래처럼 바꾼다.

```swift
private func readRateLimits(arguments: [String]) throws -> RateLimitsResponse {
    try decodeResponse(
        RateLimitsResponse.self,
        from: readRateLimitResponseData(arguments: arguments),
        id: CodexAppServerRequestFactory.rateLimitReadRequestID
    )
}
```

기존 `readRateLimits(arguments:)` 안의 process 실행 본문을 `readRateLimitResponseData(arguments:)`로 옮긴다. 마지막 줄은 decode가 아니라 raw data 반환이어야 한다.

```swift
private func readRateLimitResponseData(arguments: [String]) throws -> Data {
    let process = Process()
    process.executableURL = codexURL
    process.arguments = arguments
    process.currentDirectoryURL = workingDirectoryURL

    let stdin = Pipe()
    let stdout = Pipe()
    process.standardInput = stdin
    process.standardOutput = stdout
    process.standardError = FileHandle.nullDevice

    let reader = JSONRPCLineReader()
    reader.start(reading: stdout.fileHandleForReading)

    do {
        try process.run()
    } catch {
        throw CodexAppServerError.processLaunchFailed(error.localizedDescription)
    }

    defer {
        stdout.fileHandleForReading.readabilityHandler = nil
        stdin.fileHandleForWriting.closeFile()
        if process.isRunning {
            process.terminate()
        }
    }

    try sendInitialize(to: stdin.fileHandleForWriting)
    let initializeData = try reader.waitForResponse(
        id: CodexAppServerRequestFactory.initializeRequestID,
        timeout: timeout
    )
    _ = try decodeResponse(
        InitializeResponse.self,
        from: initializeData,
        id: CodexAppServerRequestFactory.initializeRequestID
    )

    try sendRateLimitRead(to: stdin.fileHandleForWriting)
    return try reader.waitForResponse(
        id: CodexAppServerRequestFactory.rateLimitReadRequestID,
        timeout: timeout
    )
}
```

- [ ] **Step 5: service 진단 메서드 추가**

`Sources/CodexUsageCore/Usage/CodexUsageService.swift`에 아래 메서드를 추가한다.

```swift
public func readDiagnosticReport() throws -> CodexUsageDiagnosticReport {
    let diagnostic = try client.readRateLimitDiagnostic()
    return reportBuilder.buildDiagnosticReport(
        from: diagnostic.response,
        fieldInventory: diagnostic.fieldInventory
    )
}
```

- [ ] **Step 6: focused 테스트 통과 확인**

Run:

```bash
swift test --filter CodexUsageReportTests --filter CodexAppServerClientTests
```

Expected:

```text
Test Suite 'CodexUsageReportTests' passed
Test Suite 'CodexAppServerClientTests' passed
```

- [ ] **Step 7: 조건부 커밋**

사용자가 단계별 커밋을 요청한 경우에만 실행한다.

```bash
git add Sources/CodexUsageCore/AppServer/CodexAppServerClient.swift Sources/CodexUsageCore/Usage/CodexUsageService.swift Sources/CodexUsageCore/Usage/CodexUsageReport.swift Tests/CodexUsageCoreTests/CodexUsageReportTests.swift
git commit -m "feat: add codex usage diagnostic report"
```

사용자가 커밋을 요청하지 않았다면 이 단계는 실행하지 않고 `커밋: 수행하지 않음 - 이유: 사용자 요청 없음`으로 보고한다.

## 작업 3: doctor bucket inventory 출력 추가

**Files:**

- Create: `Sources/CodexUsageCore/Usage/CodexUsageDoctorFormatter.swift`
- Create: `Tests/CodexUsageCoreTests/CodexUsageDoctorFormatterTests.swift`
- Modify: `Sources/CodexUsageCLI/main.swift`

- [ ] **Step 1: doctor formatter 테스트 작성**

`Tests/CodexUsageCoreTests/CodexUsageDoctorFormatterTests.swift`를 추가한다.

```swift
import XCTest
@testable import CodexUsageCore

final class CodexUsageDoctorFormatterTests: XCTestCase {
    func testFormatsBucketInventoryWithoutRawValues() {
        let inventory = CodexUsageFieldInventory(
            topLevelFields: ["rateLimits", "rateLimitsByLimitId"],
            buckets: [
                CodexUsageBucketFieldInventory(
                    key: "codex",
                    limitId: "codex",
                    fields: ["credits", "limitId", "primary", "secondary"],
                    primaryFields: ["resetsAt", "usedPercent", "windowDurationMins"],
                    secondaryFields: ["resetsAt", "usedPercent", "windowDurationMins"],
                    creditsFields: ["balance", "hasCredits", "unlimited"]
                ),
                CodexUsageBucketFieldInventory(
                    key: "codex_bengalfox",
                    limitId: "codex_bengalfox",
                    fields: ["credits", "limitId", "primary", "secondary"],
                    primaryFields: ["resetsAt", "usedPercent", "windowDurationMins"],
                    secondaryFields: ["resetsAt", "usedPercent", "windowDurationMins"],
                    creditsFields: ["balance", "hasCredits", "unlimited"]
                )
            ]
        )

        let lines = CodexUsageDoctorFormatter().bucketInventoryLines(from: inventory)

        XCTAssertEqual(lines[0], "Buckets: codex, codex_bengalfox")
        XCTAssertTrue(lines.contains("Bucket codex: fields credits, limitId, primary, secondary"))
        XCTAssertTrue(lines.contains("Bucket codex primary fields: resetsAt, usedPercent, windowDurationMins"))
        XCTAssertFalse(lines.joined(separator: "\\n").contains("secret"))
    }

    func testFormatsEmptyBucketInventory() {
        let lines = CodexUsageDoctorFormatter().bucketInventoryLines(
            from: CodexUsageFieldInventory(topLevelFields: [], buckets: [])
        )

        XCTAssertEqual(lines, ["Buckets: unavailable"])
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run:

```bash
swift test --filter CodexUsageDoctorFormatterTests
```

Expected:

```text
error: cannot find 'CodexUsageDoctorFormatter' in scope
```

- [ ] **Step 3: doctor formatter 구현**

`Sources/CodexUsageCore/Usage/CodexUsageDoctorFormatter.swift`를 추가한다.

```swift
public struct CodexUsageDoctorFormatter: Sendable {
    public init() {}

    public func bucketInventoryLines(from inventory: CodexUsageFieldInventory) -> [String] {
        guard !inventory.buckets.isEmpty else {
            return ["Buckets: unavailable"]
        }

        var lines = [
            "Buckets: \\(inventory.buckets.map(\\.key).joined(separator: \", \"))"
        ]

        for bucket in inventory.buckets {
            lines.append("Bucket \\(bucket.key): fields \\(bucket.fields.joined(separator: \", \"))")
            if !bucket.primaryFields.isEmpty {
                lines.append("Bucket \\(bucket.key) primary fields: \\(bucket.primaryFields.joined(separator: \", \"))")
            }
            if !bucket.secondaryFields.isEmpty {
                lines.append("Bucket \\(bucket.key) secondary fields: \\(bucket.secondaryFields.joined(separator: \", \"))")
            }
            if !bucket.creditsFields.isEmpty {
                lines.append("Bucket \\(bucket.key) credits fields: \\(bucket.creditsFields.joined(separator: \", \"))")
            }
        }

        return lines
    }
}
```

- [ ] **Step 4: CLI doctor에서 diagnostic report 사용**

`Sources/CodexUsageCLI/main.swift`의 `runDoctor()`에서 기존 `readReport()` 호출을 `readDiagnosticReport()`로 바꾸고 bucket inventory 출력을 추가한다.

```swift
private func runDoctor() -> ExitCode {
    output("Codex Usage Doctor")

    do {
        let resolver = CodexCLIResolver()
        let codexURL = try resolver.resolve()
        output("Codex CLI: \\(codexURL.path)")

        let service = CodexUsageService(client: CodexAppServerClient(codexURL: codexURL))
        let diagnostic = try service.readDiagnosticReport()
        let report = diagnostic.report
        let codex = report.codexLimit
        output("App-server: ok")
        output("Plan: \\(codex?.planType ?? report.planType ?? \"unknown\")")
        output("5h window: \\(codex?.fiveHour == nil ? \"missing\" : \"ok\")")
        output("Weekly window: \\(codex?.weekly == nil ? \"missing\" : \"ok\")")
        CodexUsageDoctorFormatter()
            .bucketInventoryLines(from: diagnostic.fieldInventory)
            .forEach(output)
        return .success
    } catch {
        errorOutput(CodexUsageFailureGuide().message(for: error, context: .doctor))
        return .failure
    }
}
```

- [ ] **Step 5: doctor formatter 테스트 통과 확인**

Run:

```bash
swift test --filter CodexUsageDoctorFormatterTests
```

Expected:

```text
Test Suite 'CodexUsageDoctorFormatterTests' passed
```

- [ ] **Step 6: CLI build 확인**

Run:

```bash
swift build --product codex-usage
```

Expected:

```text
Build complete!
```

- [ ] **Step 7: 조건부 커밋**

사용자가 단계별 커밋을 요청한 경우에만 실행한다.

```bash
git add Sources/CodexUsageCore/Usage/CodexUsageDoctorFormatter.swift Tests/CodexUsageCoreTests/CodexUsageDoctorFormatterTests.swift Sources/CodexUsageCLI/main.swift
git commit -m "feat: show codex bucket inventory in doctor"
```

사용자가 커밋을 요청하지 않았다면 이 단계는 실행하지 않고 `커밋: 수행하지 않음 - 이유: 사용자 요청 없음`으로 보고한다.

## 작업 4: 문서 갱신

**Files:**

- Modify: `README.md`
- Modify: `Docs/superpowers/specs/2026-06-03-codex-data-discovery-macdog-utility-core-design.md`

- [ ] **Step 1: README CLI 설명 갱신**

`README.md`의 `## CLI` 섹션에서 `doctor` 설명 뒤에 아래 문장을 추가한다.

```markdown
`doctor`는 Codex CLI/app-server 접근 상태와 함께 현재 응답에 포함된 사용량 묶음 이름과 필드 목록을 구조 요약으로 보여줍니다. raw app-server 응답이나 auth/session material은 출력하지 않습니다.
```

- [ ] **Step 2: 설계 spec에 구현 결정 기록**

`Docs/superpowers/specs/2026-06-03-codex-data-discovery-macdog-utility-core-design.md`의 `## 현재 범위 안의 후속 후보` 위에 아래 섹션을 추가한다.

```markdown
## 구현 계획 결정

2026-06-03 구현 계획은 Codex 데이터 탐색 관문만 대상으로 합니다. 첫 구현은 `codex-usage doctor`에 안전한 사용량 묶음/필드 목록을 추가하고, 기본 `status` 텍스트/JSON 출력과 cache schema는 변경하지 않습니다.

유틸리티 코어 정리는 Codex 데이터 탐색 결과를 확인한 뒤 별도 계획으로 작성합니다.
```

- [ ] **Step 3: 문서 공백 검사**

Run:

```bash
git diff --check
```

Expected: 출력 없음.

- [ ] **Step 4: markdownlint 시도**

Run:

```bash
npx --yes markdownlint-cli2@0.22.1 README.md Docs/superpowers/specs/2026-06-03-codex-data-discovery-macdog-utility-core-design.md Docs/superpowers/plans/2026-06-03-codex-data-discovery-plan.md
```

Expected:

```text
Finding: README.md Docs/superpowers/specs/2026-06-03-codex-data-discovery-macdog-utility-core-design.md Docs/superpowers/plans/2026-06-03-codex-data-discovery-plan.md
Linting: 3 file(s)
Summary: 0 error(s)
```

npm registry 접근이 막혀 실패하면 실패 원인을 보고하고 통과로 처리하지 않는다.

- [ ] **Step 5: 조건부 커밋**

사용자가 단계별 커밋을 요청한 경우에만 실행한다.

```bash
git add README.md Docs/superpowers/specs/2026-06-03-codex-data-discovery-macdog-utility-core-design.md
git commit -m "docs: document codex data discovery gate"
```

사용자가 커밋을 요청하지 않았다면 이 단계는 실행하지 않고 `커밋: 수행하지 않음 - 이유: 사용자 요청 없음`으로 보고한다.

## 작업 5: 최종 검증과 관문 판정

**Files:**

- No direct file changes.

- [ ] **Step 1: focused test 실행**

Run:

```bash
swift test --filter CodexUsageFieldInventoryTests --filter CodexUsageDoctorFormatterTests --filter CodexUsageReportTests --filter RateLimitModelsTests
```

Expected:

```text
Test Suite 'CodexUsageFieldInventoryTests' passed
Test Suite 'CodexUsageDoctorFormatterTests' passed
Test Suite 'CodexUsageReportTests' passed
Test Suite 'RateLimitModelsTests' passed
```

- [ ] **Step 2: privacy/cache guard 실행**

Run:

```bash
./script/verify_app_privacy_boundaries.sh
./script/verify_cache_contract.sh
```

Expected: 두 명령 모두 exit code 0.

- [ ] **Step 3: 전체 Swift test 실행**

Run:

```bash
swift test --no-parallel
```

Expected:

```text
Build complete!
Test Suite 'All tests' passed
```

- [ ] **Step 4: 최종 diff 공백 검사**

Run:

```bash
git diff --check
```

Expected: 출력 없음.

- [ ] **Step 5: live doctor smoke는 사용자 승인 후에만 실행**

사용자가 live Codex app-server 진단을 명시 승인한 경우에만 실행한다.

```bash
.build/debug/codex-usage doctor
```

Expected 예시:

```text
Codex Usage Doctor
Codex CLI: /path/to/codex
App-server: ok
Plan: pro
5h window: ok
Weekly window: ok
Buckets: codex, codex_bengalfox
Bucket codex: fields credits, limitId, limitName, planType, primary, rateLimitReachedType, secondary
```

실행하지 않았다면 `live doctor smoke: 실행하지 않음 - 이유: 사용자 명시 승인 없음`으로 보고한다.

- [ ] **Step 6: 관문 판정 기록**

최종 보고에 아래 중 하나를 명확히 적는다.

```text
Codex 데이터 탐색 관문:
- 확인됨: doctor가 안전한 사용량 묶음/필드 목록을 출력함
- 기본 status JSON/cache schema: 변경 없음
- 다음 단계: 유틸리티 코어 정리 계획 작성 가능
```

또는 live smoke까지 승인되어 실행한 경우:

```text
Codex 데이터 탐색 관문:
- 확인됨: live doctor에서 codex 계열 사용량 묶음 목록 확인
- 새로 유용한 field: 있음/없음
- 다음 단계: advanced bucket UI 추가 / 유틸리티 코어 정리 계획 작성
```

- [ ] **Step 7: 조건부 커밋**

사용자가 단계별 커밋을 요청한 경우라도 이 단계에서 새로 커밋할 파일은 없다. 앞선 작업 1~4의 조건부 커밋이 모두 수행됐다면 아래 명령으로 작업 트리만 확인한다.

```bash
git status --short
```

Expected: 출력 없음.

사용자가 커밋을 요청하지 않았다면 `커밋: 수행하지 않음 - 이유: 사용자 요청 없음`으로 보고한다.

## 중단 조건

- `CodexUsageFieldInventory`가 raw value를 출력하거나 테스트에서 secret 문자열이 summary에 포함되면 즉시 중단한다.
- `codex-usage status --json` schema가 변경되면 즉시 중단한다.
- cache schema가 변경되면 즉시 중단한다.
- `~/.codex/auth.json` 접근이 필요해지면 즉시 중단한다.
- app-server 응답 원문을 로그/문서/cache에 남기는 구현이 필요해지면 즉시 중단한다.
- Apple Developer Program이 필요한 항목이 완료 조건에 들어가면 즉시 중단한다.
- `git diff --check`가 실패하면 뒤 단계는 건너뛴다.

## 실행 후 보고 형식

```text
Codex 데이터 탐색 관문 완료/실패

작업:
- field inventory 모델 추가
- app-server diagnostic report 경로 추가
- doctor bucket inventory 출력 추가

변경 파일:
- Sources/CodexUsageCore/Usage/CodexUsageFieldInventory.swift
- Sources/CodexUsageCore/Usage/CodexUsageDoctorFormatter.swift
- Sources/CodexUsageCore/AppServer/CodexAppServerClient.swift
- Sources/CodexUsageCore/Usage/CodexUsageService.swift
- Sources/CodexUsageCore/Usage/CodexUsageReport.swift
- Sources/CodexUsageCLI/main.swift
- Tests/CodexUsageCoreTests/CodexUsageFieldInventoryTests.swift
- Tests/CodexUsageCoreTests/CodexUsageDoctorFormatterTests.swift
- Tests/CodexUsageCoreTests/CodexUsageReportTests.swift
- README.md
- Docs/superpowers/specs/2026-06-03-codex-data-discovery-macdog-utility-core-design.md

검증:
- swift test --filter CodexUsageFieldInventoryTests --filter CodexUsageDoctorFormatterTests --filter CodexUsageReportTests --filter RateLimitModelsTests: 통과/실패
- ./script/verify_app_privacy_boundaries.sh: 통과/실패
- ./script/verify_cache_contract.sh: 통과/실패
- git diff --check: 통과/실패

미실행:
- live doctor smoke: 실행하지 않음/실행함
- GUI 실행: 실행하지 않음
- 장시간 테스트: 실행하지 않음

커밋:
- 수행하지 않음 / 메시지와 해시

푸시 가능: 예/아니오
푸시 수행 여부: 수행하지 않음
```
