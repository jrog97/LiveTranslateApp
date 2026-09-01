import Foundation

struct AppLanguage: Identifiable, Hashable {
    let id: String
    let name: String
    let nativeName: String
    let speechLocaleIdentifier: String
    let translationIdentifier: String

    var speechLocale: Locale { Locale(identifier: speechLocaleIdentifier) }
    var translationLanguage: Locale.Language { Locale.Language(identifier: translationIdentifier) }

    static let english = AppLanguage(
        id: "en",
        name: "English",
        nativeName: "English",
        speechLocaleIdentifier: "en-US",
        translationIdentifier: "en"
    )

    static let spanish = AppLanguage(
        id: "es",
        name: "Spanish",
        nativeName: "Español",
        speechLocaleIdentifier: "es-ES",
        translationIdentifier: "es"
    )

    static let french = AppLanguage(
        id: "fr",
        name: "French",
        nativeName: "Français",
        speechLocaleIdentifier: "fr-FR",
        translationIdentifier: "fr"
    )

    static let japanese = AppLanguage(
        id: "ja",
        name: "Japanese",
        nativeName: "日本語",
        speechLocaleIdentifier: "ja-JP",
        translationIdentifier: "ja"
    )

    static let korean = AppLanguage(
        id: "ko",
        name: "Korean",
        nativeName: "한국어",
        speechLocaleIdentifier: "ko-KR",
        translationIdentifier: "ko"
    )

    static let mandarin = AppLanguage(
        id: "zh",
        name: "Mandarin",
        nativeName: "中文",
        speechLocaleIdentifier: "zh-CN",
        translationIdentifier: "zh-Hans"
    )

    static let russian = AppLanguage(
        id: "ru",
        name: "Russian",
        nativeName: "Русский",
        speechLocaleIdentifier: "ru-RU",
        translationIdentifier: "ru"
    )

    static let supported: [AppLanguage] = [
        .english, .spanish, .french, .japanese, .korean, .mandarin, .russian
    ]

    static func named(_ id: String) -> AppLanguage {
        supported.first { $0.id == id } ?? .english
    }
}
