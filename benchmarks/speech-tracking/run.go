// Command run builds the speech-tracking benchmark against the shipping matcher (and the
// pre-rewrite matcher from git, for comparison), runs it, and writes results/.
//
//	go run run.go [-seeds 30] [-legacy f9c6c94] [-check]   # Layer A + replay Layer B fixtures
//	go run run.go -record                                  # Layer B: re-record fixtures (real time, ~50 min, macOS only)
//	ENGINE=local:<model.gguf> ENGINE_TOOL=<path> go run run.go -record   # Layer B with a local model
//	go run run.go -build <path>                            # just build the harness (render-audio, score-app)
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
	record := flag.Bool("record", false, "re-record Layer B fixtures (ENGINE=apple-on-device|apple-server|local:<model.gguf>; local needs ENGINE_TOOL)")
	buildOnly := flag.String("build", "", "only build the harness binary to this path (used by ../desktop/run.go)")
	flag.Parse()

	here, err := os.Getwd()
	must(err)
	if _, err := os.Stat(filepath.Join(here, "Sources", "main.swift")); err != nil {
		fail("run from benchmarks/speech-tracking")
	}
	shared := filepath.Join(here, "..", "..", "Textream", "Shared")
	work, err := os.MkdirTemp("", "speech-tracking-bench")
	must(err)
	defer os.RemoveAll(work)

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
	legacyPath := filepath.Join(work, "Legacy.swift")
	must(os.WriteFile(legacyPath, legacy, 0o644))

	bin := filepath.Join(work, "bench")
	sources, err := filepath.Glob(filepath.Join(here, "Sources", "*.swift"))
	must(err)
	build := exec.Command("swiftc", append([]string{"-O", "-o", bin,
		"-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", filepath.Join(here, "Info.plist"),
		filepath.Join(shared, "PromptTextProcessor.swift"),
		filepath.Join(shared, "SpeechTextAlignment.swift"),
		filepath.Join(shared, "PromptMatcher.swift"),
		legacyPath}, sources...)...)
	build.Env = append(os.Environ(), "TMPDIR="+work) // swiftc needs a writable cache dir
	build.Stderr = os.Stderr
	must(build.Run())

	if *buildOnly != "" {
		must(copyFile(bin, *buildOnly))
		return
	}

	if *record {
		cmd := exec.Command(bin, "record-audio", here)
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

func copyFile(from, to string) error {
	data, err := os.ReadFile(from)
	if err != nil {
		return err
	}
	return os.WriteFile(to, data, 0o755)
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
