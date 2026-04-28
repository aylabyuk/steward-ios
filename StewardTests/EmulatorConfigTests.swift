import Testing
import StewardCore

@Suite("EmulatorConfig environment parsing")
struct EmulatorConfigTests {

    @Test("isEnabled returns true when USE_EMULATOR env var is exactly \"1\"")
    func isEnabledTrueWhenOne() {
        #expect(EmulatorConfig.isEnabled(from: ["USE_EMULATOR": "1"]) == true)
    }

    @Test("isEnabled returns false when USE_EMULATOR is unset")
    func isEnabledFalseWhenUnset() {
        #expect(EmulatorConfig.isEnabled(from: [:]) == false)
    }

    @Test(
        "isEnabled returns false for any value other than \"1\"",
        arguments: ["0", "true", "yes", "on", "", " "]
    )
    func isEnabledFalseForOtherValues(value: String) {
        #expect(EmulatorConfig.isEnabled(from: ["USE_EMULATOR": value]) == false)
    }

    @Test("host returns EMULATOR_HOST when set")
    func hostFromEnv() {
        #expect(
            EmulatorConfig.host(from: ["EMULATOR_HOST": "192.168.2.24"])
                == "192.168.2.24"
        )
    }

    @Test("host falls back to 127.0.0.1 when EMULATOR_HOST is unset")
    func hostFallback() {
        #expect(EmulatorConfig.host(from: [:]) == "127.0.0.1")
    }

    @Test("host treats an empty EMULATOR_HOST as unset")
    func hostEmptyStringFallback() {
        #expect(EmulatorConfig.host(from: ["EMULATOR_HOST": ""]) == "127.0.0.1")
    }
}
