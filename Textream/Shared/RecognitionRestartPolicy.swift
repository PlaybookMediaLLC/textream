import Foundation

/// When to start a fresh speech-recognition task. A request stops after about a minute, so the
/// apps restart it; a restart mid-word drops the words in flight and the new task re-acquires
/// from scratch (the benchmark caught a re-read landing on a fixed 55 s restart and losing ~2 s).
/// From `earliest` on, restart at the first moment of quiet instead, with `deadline` as the cap.
///
/// Fed with the apps' audio level (`min(rms * 5, 1)`, ~20 updates/s).
struct RecognitionRestartPolicy {
    var earliest: TimeInterval = 45
    var deadline: TimeInterval = 57
    /// Below the voice-activity threshold (VoiceActivityDetector.activationLevel).
    var quietLevel: CGFloat = 0.012
    /// Consecutive quiet updates required (~200 ms at 20/s): a gap between words, not a breath in one.
    var quietUpdates = 4

    private var startedAt: TimeInterval = 0
    private var quietCount = 0

    mutating func sessionStarted(at time: TimeInterval) {
        startedAt = time
        quietCount = 0
    }

    mutating func shouldRestart(level: CGFloat, at time: TimeInterval) -> Bool {
        quietCount = level < quietLevel ? quietCount + 1 : 0
        let elapsed = time - startedAt
        return elapsed >= deadline || (elapsed >= earliest && quietCount >= quietUpdates)
    }
}
