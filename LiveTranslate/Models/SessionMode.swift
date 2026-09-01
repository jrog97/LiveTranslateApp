import Foundation

enum SessionMode: String, CaseIterable, Identifiable {
    case listen
    case speak
    case conversation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .listen: "Listen"
        case .speak: "Speak"
        case .conversation: "Talk"
        }
    }

    var subtitle: String {
        switch self {
        case .listen: "Hear them, get your language"
        case .speak: "You talk, the phone speaks for you"
        case .conversation: "Take turns in both languages"
        }
    }

    var systemImage: String {
        switch self {
        case .listen: "ear"
        case .speak: "mouth"
        case .conversation: "bubble.left.and.bubble.right"
        }
    }
}

enum ConversationTurn: String {
    case them
    case me

    var label: String {
        switch self {
        case .them: "They speak"
        case .me: "I speak"
        }
    }
}
