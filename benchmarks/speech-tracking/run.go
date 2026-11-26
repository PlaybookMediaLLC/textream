// Command run builds the speech-tracking benchmark against the shipping matcher (and the
// pre-rewrite matcher from git, for comparison), runs it, and writes results/.
//
//	go run run.go [-seeds 30] [-legacy f9c6c94] [-check]   # Layer A + replay Layer B fixtures
//	go run run.go -build <path>                            # just build the harness (render-audio, score-app) for ../desktop
//	go run run.go -record apple-on-device                  # Layer B: (re-)record fixtures in real time (~75 min, macOS)
//	go run run.go -record /path/to/nemotron.gguf           #   …core cases with a local transcribe.cpp model (the app's LocalSpeechEngine)
//
// -check exits non-zero if any gating case fails, for use as a CI regression gate.
// CASE=<text> limits the run to cases whose name (or fixture id) contains <text>.
package main

import (
	"bytes"
	"flag"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

func main() {
	seeds := flag.Int("seeds", 30, "Layer A seeds per case")
	legacyRef := flag.String("legacy", "f9c6c94", "git ref holding the pre-rewrite matcher")
	check := flag.Bool("check", false, "exit 1 if any gating case fails")
	buildOnly := flag.String("build", "", "only build the harness binary and copy it to this path (used by ../desktop/run.go)")
	record := flag.String("record", "", "re-record Layer B fixtures with this engine: apple-on-device or a .gguf model path")
	flag.Parse()

	here, err := os.Getwd()
	must(err)
	if _, err := os.Stat(filepath.Join(here, "Sources", "bench", "main.swift")); err != nil {
		fail("run from benchmarks/speech-tracking")
	}
	// The legacy matcher and its alignment helpers, renamed so they compile beside the current ones.
	var legacy []byte
	for _, file := range []string{"Speech/PromptMatcher.swift", "Speech/SpeechTextAlignment.swift"} {
		src, err := exec.Command("git", "-C", here, "show", *legacyRef+":Textream/TextreamiOS/"+file).Output()
		must(err)
		legacy = append(legacy, src...)
	}
	for _, name := range []string{"PromptMatcher", "SpeechTextAlignment"} {
		legacy = bytes.ReplaceAll(legacy, []byte(name), []byte("Legacy"+name))
	}
	generated := filepath.Join(here, "Sources", "bench", "Generated") // gitignored
	must(os.MkdirAll(generated, 0o755))
	must(os.WriteFile(filepath.Join(generated, "Legacy.swift"), legacy, 0o644))

	// SwiftPM package: the shipping matcher and LocalSpeechEngine are symlinked into Sources/bench.
	build := exec.Command("swift", "build", "-c", "release", "--package-path", here)
	build.Stdout, build.Stderr = os.Stderr, os.Stderr
	must(build.Run())
	bin := filepath.Join(here, ".build", "release", "bench")
	if *buildOnly != "" {
		must(os.MkdirAll(filepath.Dir(*buildOnly), 0o755))
		must(exec.Command("cp", bin, *buildOnly).Run())
		// The binary loads CTranscribe.framework from next to itself (@loader_path).
		framework := filepath.Join(filepath.Dir(bin), "CTranscribe.framework")
		dest := filepath.Join(filepath.Dir(*buildOnly), "CTranscribe.framework")
		must(os.RemoveAll(dest))
		must(exec.Command("cp", "-R", framework, dest).Run())
		return
	}

	if *record != "" {
		cmd := exec.Command(bin, "record-audio", here, *record)
		cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
		must(cmd.Run())
	}

	failed := false
	for _, layer := range []struct{ name, mode string }{{"", ""}, {"audio-", "score-audio"}} {
		for _, matcher := range []string{"legacy", "current"} {
			args := []string{here, strconv.Itoa(*seeds)}
			if layer.mode != "" {
				args = []string{layer.mode, here}
			}
			cmd := exec.Command(bin, args...)
			cmd.Env = append(os.Environ(), "MATCHER="+matcher)
			cmd.Stderr = os.Stderr
			out, err := cmd.Output()
			must(err)
			must(os.WriteFile(filepath.Join(here, "results", layer.name+matcher+".md"), out, 0o644))
			if matcher == "current" {
				os.Stdout.Write(out)
				failed = failed || strings.Contains(string(out), "❌")
			}
		}
	}

	if *check && failed {
		fail("gating cases failed; see results/current.md and results/audio-current.md")
	}
}

func must(err error) {
	if err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			fail(string(ee.Stderr))
		}
		fail(err.Error())
	}
}

func fail(msg string) {
	fmt.Fprintln(os.Stderr, msg)
	os.Exit(1)
}
