import AVFoundation
import Foundation

struct AudioRouteSnapshot: Equatable {
    var outputName: String
    var isBluetooth: Bool
    var isAirPods: Bool

    static let unknown = AudioRouteSnapshot(
        outputName: "iPhone",
        isBluetooth: false,
        isAirPods: false
    )

    var displayName: String {
        if isAirPods {
            return "AirPods"
        }

        if isBluetooth {
            return outputName
        }

        return "iPhone"
    }
}

enum AudioPlaybackTarget {
    /// Translation plays through the connected personal audio device.
    case personal

    /// Translation plays through the iPhone speaker.
    case speaker
}

final class AudioSessionManager {

    func configure(playback: AudioPlaybackTarget) throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [
                .allowBluetoothHFP,
                .allowBluetoothA2DP,
                .duckOthers,
                .defaultToSpeaker
            ]
        )

        try session.setActive(
            true,
            options: .notifyOthersOnDeactivation
        )

        switch playback {
        case .speaker:
            try session.overrideOutputAudioPort(.speaker)

        case .personal:
            try session.overrideOutputAudioPort(.none)
        }
    }

    func currentRoute() -> AudioRouteSnapshot {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs

        let preferred = outputs.first {
            Self.isWireless($0)
        } ?? outputs.first

        let name = preferred?.portName ?? "iPhone"
        let bluetooth = preferred.map(Self.isWireless) ?? false
        let airPods = name.localizedCaseInsensitiveContains("airpod")

        return AudioRouteSnapshot(
            outputName: name,
            isBluetooth: bluetooth,
            isAirPods: airPods
        )
    }

    private static func isWireless(
        _ port: AVAudioSessionPortDescription
    ) -> Bool {
        switch port.portType {
        case .bluetoothA2DP,
             .bluetoothHFP,
             .bluetoothLE:
            return true

        default:
            return false
        }
    }
}
