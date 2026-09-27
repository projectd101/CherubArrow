import AVFoundation
import Combine

/// Synthesizes speech from arbitrary text — custom lines, facts, future news headlines.
///
/// Shells out to the "piper-classic" Python package (`pip install piper-tts`),
/// invoked as `python3 -m piper`, using the en_US-lessac-medium voice — confirmed
/// working from a manual terminal test at ~/piper-classic. Uses that venv's own
/// python3 directly, so it doesn't depend on system PATH or python3 having
/// piper-tts installed globally.
final class TTSManager: ObservableObject {

    // MARK: - Speech tuning (persisted so the Voice tab's sliders survive relaunch)

    /// Piper speed. 1.0 = normal, HIGHER = SLOWER. Try 1.15 to 1.4.
    @Published var lengthScale: Double {
        didSet { UserDefaults.standard.set(lengthScale, forKey: Self.lengthScaleKey) }
    }

    /// Seconds of silence between sentences. Makes summaries feel less rushed.
    @Published var sentenceSilence: Double {
        didSet { UserDefaults.standard.set(sentenceSilence, forKey: Self.sentenceSilenceKey) }
    }

    private static let lengthScaleKey = "tts.lengthScale"
    private static let sentenceSilenceKey = "tts.sentenceSilence"

    // MARK: - Setup

    private let pythonURL: URL?
    private let voiceModelURL: URL?
    private let fallbackSynthesizer = FallbackSynthesizer()

    /// True once the piper-classic venv's python3 + voice model are actually found.
    private(set) var isPiperAvailable: Bool

    init() {
        let defaults = UserDefaults.standard
        self.lengthScale = defaults.object(forKey: Self.lengthScaleKey) as? Double ?? 1.25
        self.sentenceSilence = defaults.object(forKey: Self.sentenceSilenceKey) as? Double ?? 0.4

        // Points directly at the confirmed-working piper-classic venv:
        //   ~/piper-classic/venv/bin/python3   (has piper-tts installed)
        //   ~/piper-classic/en_US-lessac-medium.onnx  (already downloaded)
        let home = FileManager.default.homeDirectoryForCurrentUser
        let venvPython = home.appendingPathComponent("piper-classic/venv/bin/python3")
        let modelPath = home.appendingPathComponent("piper-classic/en_US-lessac-medium.onnx")

        pythonURL = FileManager.default.fileExists(atPath: venvPython.path) ? venvPython : nil
        voiceModelURL = FileManager.default.fileExists(atPath: modelPath.path) ? modelPath : nil

        isPiperAvailable = pythonURL != nil && voiceModelURL != nil

        if !isPiperAvailable {
            print("⚠️ piper-classic venv/model not found at ~/piper-classic — using the built-in system voice instead.")
        }
    }

    // MARK: - Speaking

    /// Synthesizes `text` and plays it. `completion` fires on the main queue;
    /// `true` means piper spoke it, `false` means the fallback voice did.
    func speak(_ text: String, completion: ((Bool) -> Void)? = nil) {
        guard isPiperAvailable,
              let python = pythonURL,
              let model = voiceModelURL else {
            fallbackSynthesizer.speak(text)
            completion?(false)
            return
        }

        // Capture current settings so a change mid-synthesis can't cause a mismatch.
        let lengthScale = self.lengthScale
        let sentenceSilence = self.sentenceSilence

        DispatchQueue.global(qos: .userInitiated).async {
            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("cherub_tts_\(UUID().uuidString).wav")

            let process = Process()
            process.executableURL = python
            process.arguments = [
                "-m", "piper",
                "-m", model.path,
                "-f", outputURL.path,
                "--length-scale", String(lengthScale),
                "--sentence-silence", String(sentenceSilence),
                "--", text
            ]
            // Options must come BEFORE the "--" separator; everything after it is the text.

            let pipe = Pipe() // swallow piper's own stdout/stderr chatter
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                guard process.terminationStatus == 0,
                      let data = try? Data(contentsOf: outputURL) else {
                    DispatchQueue.main.async {
                        self.fallbackSynthesizer.speak(text)
                        completion?(false)
                    }
                    return
                }

                DispatchQueue.main.async {
                    AudioPlaybackHelper.shared.play(data: data)
                    completion?(true)
                }

                try? FileManager.default.removeItem(at: outputURL)
            } catch {
                DispatchQueue.main.async {
                    self.fallbackSynthesizer.speak(text)
                    completion?(false)
                }
            }
        }
    }
}

/// Zero-setup fallback voice (Apple's built-in synthesizer) so TTSManager works
/// immediately, before you've bundled piper-plus — matches the "free tier uses the
/// system voice, paid tier uses a better open-weight voice" plan.
private final class FallbackSynthesizer {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.42 // default is ~0.5; slowed to match Piper's pace
        utterance.postUtteranceDelay = 0.3
        synthesizer.speak(utterance)
    }
}

/// Shared player so overlapping clips (rapid clicks) don't stack into jumbled speech —
/// mirrors the same behavior SoundManager already has for affirmation clips.
final class AudioPlaybackHelper {
    static let shared = AudioPlaybackHelper()
    private var currentPlayer: AVAudioPlayer?

    func play(data: Data) {
        currentPlayer?.stop()
        let player = try? AVAudioPlayer(data: data)
        player?.play()
        currentPlayer = player
    }
}
