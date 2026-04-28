import Foundation

public enum EmulatorConfig {
    public static var isEnabled: Bool {
        isEnabled(from: ProcessInfo.processInfo.environment)
    }

    public static var host: String {
        host(from: ProcessInfo.processInfo.environment)
    }

    public static func isEnabled(from env: [String: String]) -> Bool {
        env["USE_EMULATOR"] == "1"
    }

    public static func host(from env: [String: String]) -> String {
        guard let value = env["EMULATOR_HOST"], !value.isEmpty else {
            return "127.0.0.1"
        }
        return value
    }
}
