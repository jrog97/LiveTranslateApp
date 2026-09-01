import Foundation
import Translation

struct LanguagePackState: Identifiable {
    var id: String { "\(source.id)-\(target.id)" }
    let source: AppLanguage
    let target: AppLanguage
    var status: LanguageAvailability.Status
}

@MainActor
final class LanguagePackService {
    private let availability = LanguageAvailability()

    func refresh(myLanguage: AppLanguage, theirLanguage: AppLanguage) async -> [LanguagePackState] {
        let pairs = [
            (myLanguage, theirLanguage),
            (theirLanguage, myLanguage)
        ]
        var states: [LanguagePackState] = []
        for (source, target) in pairs {
            let status = await availability.status(from: source.translationLanguage, to: target.translationLanguage)
            states.append(LanguagePackState(source: source, target: target, status: status))
        }
        return states
    }

    func label(for status: LanguageAvailability.Status) -> String {
        switch status {
        case .installed: "On this iPhone"
        case .supported: "Download needed"
        case .unsupported: "Not supported"
        @unknown default: "Unknown"
        }
    }
}
