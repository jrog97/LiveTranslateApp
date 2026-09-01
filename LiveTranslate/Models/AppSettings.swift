import Foundation

@Observable
final class AppSettings {
    var myLanguageID: String {
        didSet { defaults.set(myLanguageID, forKey: Keys.myLanguage) }
    }

    var theirLanguageID: String {
        didSet { defaults.set(theirLanguageID, forKey: Keys.theirLanguage) }
    }

    var requireOnDeviceSpeech: Bool {
        didSet { defaults.set(requireOnDeviceSpeech, forKey: Keys.onDevice) }
    }

    var speakTranslations: Bool {
        didSet { defaults.set(speakTranslations, forKey: Keys.speak) }
    }

    var myLanguage: AppLanguage { AppLanguage.named(myLanguageID) }
    var theirLanguage: AppLanguage { AppLanguage.named(theirLanguageID) }

    private let defaults: UserDefaults

    private enum Keys {
        static let myLanguage = "myLanguageID"
        static let theirLanguage = "theirLanguageID"
        static let onDevice = "requireOnDeviceSpeech"
        static let speak = "speakTranslations"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        myLanguageID = defaults.string(forKey: Keys.myLanguage) ?? AppLanguage.english.id
        theirLanguageID = defaults.string(forKey: Keys.theirLanguage) ?? AppLanguage.spanish.id
        requireOnDeviceSpeech = defaults.object(forKey: Keys.onDevice) as? Bool ?? true
        speakTranslations = defaults.object(forKey: Keys.speak) as? Bool ?? true
    }

    func swapLanguages() {
        let mine = myLanguageID
        myLanguageID = theirLanguageID
        theirLanguageID = mine
    }
}
