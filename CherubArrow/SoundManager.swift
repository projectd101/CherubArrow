import AVFoundation

/// Plays a random short affirmation clip on every click.
/// Drop as many audio files as you like into the Xcode project (see README),
/// each one named starting with "affirmation" — e.g. affirmation_01.mp3,
/// affirmation_confidence.wav, affirmation_bestever.m4a. No code changes
/// needed to add more: they're all discovered automatically at launch.
final class SoundManager {

    var isMuted = false

    private var clipsData: [Data] = []
    private var currentPlayer: AVAudioPlayer?

    init() {
        clipsData = Self.loadAffirmationClips()
        if clipsData.isEmpty {
            print("⚠️ No affirmation audio files found. Add files named 'affirmation...' (mp3/wav/caf/m4a) to the app bundle — see README.")
        }
    }

    func playRandomAffirmation() {
        guard !isMuted, let data = clipsData.randomElement() else { return }
        currentPlayer?.stop() // avoid overlapping, jumbled speech on rapid clicks
        let player = try? AVAudioPlayer(data: data)
        player?.play()
        currentPlayer = player
    }

    private static func loadAffirmationClips() -> [Data] {
        guard let resourceURL = Bundle.main.resourceURL else { return [] }
        let validExtensions: Set<String> = ["mp3", "wav", "caf", "m4a"]

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: resourceURL, includingPropertiesForKeys: nil
        ) else { return [] }

        let clipURLs = contents.filter {
            $0.lastPathComponent.lowercased().hasPrefix("affirmation")
                && validExtensions.contains($0.pathExtension.lowercased())
        }

        return clipURLs.compactMap { try? Data(contentsOf: $0) }
    }
}
