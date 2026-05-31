import Foundation
import MacDogPrivilegedHelperSupport

enum HelperCLI {
    static func run(arguments: [String] = CommandLine.arguments) -> Int32 {
        let args = Array(arguments.dropFirst())

        switch args.first {
        case "--version":
            print(MacDogPrivilegedHelperContract.helperVersion)
            return 0
        case "--install-plan":
            for line in PrivilegedHelperInstallPlan.current.dryRunLines(appBundlePath: "/Applications/MacDog.app") {
                print(line)
            }
            return 0
        case "--handle-json-stdin":
            return handleJSONStdin()
        case "--run-xpc-service":
            return runXPCService()
        case "--help", "-h", nil:
            print("""
            usage: MacDogPrivilegedHelper [--version|--install-plan|--handle-json-stdin|--run-xpc-service]

            This helper is intended to run as a privileged LaunchDaemon after explicit installation.
            Allowed commands are limited to reading SleepDisabled, setting SleepDisabled to 0 or 1,
            reading screenLock, and setting screenLock to off, immediate, or seconds.
            """)
            return 0
        default:
            fputs("unsupported argument\n", stderr)
            return 2
        }
    }

    private static func runXPCService() -> Int32 {
        let service = MacDogPrivilegedHelperXPCService(
            handler: PrivilegedHelperCommandHandler(runner: PrivilegedHelperProcessRunner())
        )
        let delegate = HelperXPCDelegate(
            service: service,
            authorizer: SecCodePrivilegedHelperConnectionAuthorizer()
        )
        let listener = NSXPCListener(machServiceName: MacDogPrivilegedHelperContract.machServiceName)
        listener.delegate = delegate
        listener.resume()
        RunLoop.current.run()
        return 0
    }

    private static func handleJSONStdin() -> Int32 {
        let input = FileHandle.standardInput.readDataToEndOfFile()

        do {
            let request = try JSONDecoder().decode(PrivilegedHelperRequest.self, from: input)
            let handler = PrivilegedHelperCommandHandler(runner: PrivilegedHelperProcessRunner())
            let response = handler.handle(request)
            let output = try JSONEncoder().encode(response)
            FileHandle.standardOutput.write(output)
            FileHandle.standardOutput.write(Data("\n".utf8))
            return response.status == .success ? 0 : 1
        } catch {
            let response = PrivilegedHelperResponse(status: .failed, errorMessage: error.localizedDescription)
            if let output = try? JSONEncoder().encode(response) {
                FileHandle.standardOutput.write(output)
                FileHandle.standardOutput.write(Data("\n".utf8))
            }
            return 1
        }
    }
}

exit(HelperCLI.run())

private final class HelperXPCDelegate: NSObject, NSXPCListenerDelegate {
    private let service: MacDogPrivilegedHelperXPCProtocol
    private let authorizer: PrivilegedHelperConnectionAuthorizing

    init(
        service: MacDogPrivilegedHelperXPCProtocol,
        authorizer: PrivilegedHelperConnectionAuthorizing
    ) {
        self.service = service
        self.authorizer = authorizer
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard authorizer.shouldAccept(processIdentifier: connection.processIdentifier) else {
            return false
        }

        connection.exportedInterface = NSXPCInterface(with: MacDogPrivilegedHelperXPCProtocol.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }
}
