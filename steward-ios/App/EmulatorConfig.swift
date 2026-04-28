import Foundation

enum EmulatorConfig {
    static var isEnabled: Bool {
        isEnabled(from: ProcessInfo.processInfo.environment)
    }

    static var host: String {
        host(from: ProcessInfo.processInfo.environment)
    }

    static func isEnabled(from env: [String: String]) -> Bool {
        env["USE_EMULATOR"] == "1"
    }

    static func host(from env: [String: String]) -> String {
        guard let value = env["EMULATOR_HOST"], !value.isEmpty else {
            return "127.0.0.1"
        }
        return value
    }
}
