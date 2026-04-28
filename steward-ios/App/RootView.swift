import SwiftUI
import StewardCore

struct RootView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "building.columns")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Steward")
                .font(.title2.weight(.semibold))
            if EmulatorConfig.isEnabled {
                Text("Emulator: \(EmulatorConfig.host)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    RootView()
}
