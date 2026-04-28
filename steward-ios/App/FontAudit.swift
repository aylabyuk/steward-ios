#if DEBUG
import Foundation
import UIKit

/// Debug helper: logs every font family + its concrete PostScript names so we
/// can verify the bundled `.ttf` files registered correctly and pin the right
/// strings in `StewardCore.Font` extensions. Variable fonts often expose a
/// PostScript name that doesn't match the file name (e.g. `Newsreader.ttf`
/// might register as `Newsreader-Regular`).
///
/// Call once from `steward_iosApp.init()` after `FirebaseSetup.configure()`.
enum FontAudit {
    static func dumpLoadedFonts(filter: [String] = ["Newsreader", "Inter", "Plex"]) {
        let families = UIFont.familyNames.sorted()
        for family in families {
            guard filter.isEmpty || filter.contains(where: { family.localizedCaseInsensitiveContains($0) }) else {
                continue
            }
            let names = UIFont.fontNames(forFamilyName: family)
            print("[FontAudit] family=\(family)")
            for name in names {
                print("[FontAudit]   - \(name)")
            }
        }
    }
}
#endif
