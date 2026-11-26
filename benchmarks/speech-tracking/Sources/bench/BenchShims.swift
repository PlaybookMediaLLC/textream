// The app's LocalSpeechEngine.swift (symlinked here) logs through Benchmark.swift's benchLog, which is
// app code. The harness doesn't record app events, so it gets the same no-op as shipping builds.
func benchLog(_ event: String, _ fields: @autoclosure () -> [String: Any] = [:]) {}
