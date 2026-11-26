// Command run drives the desktop benchmark suite (../PLAN.md). It builds a BENCHMARK copy of
// the app (bundle id dev.fka.textream.bench, never shipped), launches it with -bench-*
// arguments, reads its event log, and writes results/<host>/<bench>.{md,json}.
//
//	go run run.go build                         # app + harness + engine tool into .cache/
//	go run run.go micro                         # #4/#7 micro: per-redraw layout cost, broadcast encode
//	go run run.go launch [-cold]                # #8 launch, time-to-first-prompt
//	go run run.go idle [-minutes 5]             # #5 idle / paused cost
//	go run run.go render [-seconds 30]          # #4 frame pacing matrix
//	go run run.go broadcast                     # #7 WebSocket clients
//	go run run.go latency [-engine apple|local] # #2 word → screen, by stage
//	go run run.go soak [-minutes 90]            # #6 long session
//	go run run.go engine [-thermal 30]          # #3 local models: load, decode sweep, memory, thermals
//	go run run.go fetch-model <repo> [quant]    # download a catalog model into .cache/models
//	go run run.go record-local -model <file>    # #1: Layer B fixtures with a local model
//	go run run.go nightly                       # everything a bench Mac runs nightly
//	go run run.go compare <base.json> <new.json> [-check]
//
// Common flags: -runs N, -check (exit 1 on regression vs results/<host>/baseline/),
// -update-baseline, -host <name>, -skip-build.
//
// The app opens real windows: run on a Mac with a logged-in GUI session, outside any sandbox.
package main

import (
	"bufio"
	"bytes"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/binary"
	"encoding/hex"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"math"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
)

var (
	here, root, cacheDir string
	appBinary            string
	harnessBin           string
	engineBin            string
	hostName             string

	runs           = flag.Int("runs", 0, "repetitions per scenario (default depends on the benchmark)")
	check          = flag.Bool("check", false, "exit 1 if a metric regresses against results/<host>/baseline/")
	updateBaseline = flag.Bool("update-baseline", false, "copy this run's results over the baseline")
	hostFlag       = flag.String("host", "", "host class for results (default: chip and memory)")
	skipBuild      = flag.Bool("skip-build", false, "reuse the app already in .cache/")
	minutes        = flag.Float64("minutes", 0, "idle: minutes per scenario (5); soak: session length (90)")
	seconds        = flag.Float64("seconds", 30, "render/broadcast: seconds per scenario")
	cold           = flag.Bool("cold", false, "launch: purge the file cache before each launch (needs passwordless sudo purge)")
	engineFlag     = flag.String("engine", "local", "latency/soak: apple, apple-server or local")
	modelFlag      = flag.String("model", "", "local model file in .cache/models (default: the smallest one there)")
	casesFlag      = flag.String("cases", "baseline-us,accent-gb,noise-babble-10", "latency: rendered cases to run")
	thermal        = flag.Float64("thermal", 0, "engine: minutes of sustained load per model (0 = skip)")
	xctrace        = flag.Bool("xctrace", false, "render: also record an Instruments Animation Hitches trace per scenario")
	backendFlag    = flag.String("backend", "auto", "engine: transcribe.cpp backend (auto, cpu, metal)")
	only           = flag.String("only", "", "idle/render: run only scenarios whose name contains this text")
	appFlag        = flag.String("app", "", "use this BENCHMARK app binary instead of building one (A/B against another build)")
	autoplayFrom   = flag.Float64("from", 0, "render: start the highlight this far into the script (0–1)")
)

func main() {
	flag.Usage = func() {
		fmt.Fprintln(os.Stderr, "usage: go run run.go [flags] <build|micro|launch|idle|render|broadcast|latency|soak|engine|fetch-model|record-local|nightly|compare>")
		flag.PrintDefaults()
	}
	cmd, args := splitCommand(os.Args[1:])
	must(flag.CommandLine.Parse(args))
	positional := flag.Args()

	var err error
	here, err = os.Getwd()
	must(err)
	if _, err := os.Stat(filepath.Join(here, "engine", "main.swift")); err != nil {
		fail("run from benchmarks/desktop")
	}
	root = filepath.Clean(filepath.Join(here, "..", ".."))
	cacheDir = filepath.Join(here, ".cache")
	must(os.MkdirAll(cacheDir, 0o755))
	appBinary = filepath.Join(cacheDir, "dd", "Build", "Products", "Release", "Textream.app", "Contents", "MacOS", "Textream")
	if *appFlag != "" {
		appBinary = *appFlag
		*skipBuild = true
	}
	harnessBin = filepath.Join(cacheDir, "speech-tracking")
	engineBin = filepath.Join(cacheDir, "engine")
	hostName = *hostFlag
	if hostName == "" {
		hostName = detectHost()
	}

	switch cmd {
	case "build":
		buildAll()
	case "micro":
		ensureApp()
		finish("micro", benchMicro())
	case "launch":
		ensureApp()
		finish("launch", benchLaunch())
	case "idle":
		ensureApp()
		finish("idle", benchIdle())
	case "render":
		ensureApp()
		finish("render", benchRender())
	case "broadcast":
		ensureApp()
		finish("broadcast", benchBroadcast())
	case "latency":
		ensureApp()
		ensureHarness()
		finish("latency", benchLatency())
	case "soak":
		ensureApp()
		ensureHarness()
		finish("soak", benchSoak())
	case "engine":
		ensureEngine()
		ensureHarness()
		finish("engine", benchEngine())
	case "fetch-model":
		if len(positional) < 1 {
			fail("usage: fetch-model <repo id or substring> [quant]")
		}
		quant := ""
		if len(positional) > 1 {
			quant = positional[1]
		}
		fmt.Println(fetchModel(positional[0], quant))
	case "engine-tool":
		ensureEngine()
		fmt.Println(engineBin)
	case "record-local":
		ensureEngine()
		recordLocal()
	case "nightly":
		ensureApp()
		ensureHarness()
		ensureEngine()
		failed := false
		for _, b := range []struct {
			name string
			fn   func() Report
		}{{"micro", benchMicro}, {"launch", benchLaunch}, {"idle", benchIdle}, {"render", benchRender},
			{"broadcast", benchBroadcast}, {"latency", benchLatency}, {"engine", benchEngine}, {"soak", benchSoak}} {
			failed = save(b.name, b.fn()) || failed
		}
		if failed && *check {
			fail("regressions found; see results/" + hostName)
		}
	case "compare":
		if len(positional) != 2 {
			fail("usage: compare <base.json> <new.json>")
		}
		base, cur := loadReport(positional[0]), loadReport(positional[1])
		table, regressed := compare(base, cur)
		fmt.Print(table)
		if regressed && *check {
			os.Exit(1)
		}
	default:
		flag.Usage()
		os.Exit(2)
	}
}

// splitCommand lets the subcommand come before or after the flags.
func splitCommand(args []string) (string, []string) {
	for i, a := range args {
		if !strings.HasPrefix(a, "-") && (i == 0 || !flagTakesValue(args[i-1])) {
			return a, append(append([]string{}, args[:i]...), args[i+1:]...)
		}
	}
	return "", args
}

func flagTakesValue(a string) bool {
	if strings.Contains(a, "=") {
		return false
	}
	switch strings.TrimLeft(a, "-") {
	case "check", "update-baseline", "skip-build", "cold", "xctrace":
		return false
	}
	return true
}

// ---------------------------------------------------------------------------------------
// Results: every benchmark returns named metrics with one value per run.

type Metric struct {
	Unit   string    `json:"unit"`
	Lower  bool      `json:"lowerIsBetter"`
	Values []float64 `json:"values"`
	Median float64   `json:"median"`
	MAD    float64   `json:"mad"`
	Gate   bool      `json:"gate"` // compared by -check
}

type Report struct {
	Host     string             `json:"host"`
	Date     string             `json:"date"`
	Commit   string             `json:"commit"`
	Metrics  map[string]*Metric `json:"metrics"`
	Markdown string             `json:"-"`
}

func newReport() Report {
	commit, _ := exec.Command("git", "-C", root, "rev-parse", "--short", "HEAD").Output()
	return Report{Host: hostName, Date: time.Now().Format(time.RFC3339), Commit: strings.TrimSpace(string(commit)), Metrics: map[string]*Metric{}}
}

func (r *Report) add(name, unit string, lower, gate bool, v float64) {
	if math.IsNaN(v) || math.IsInf(v, 0) {
		return
	}
	m := r.Metrics[name]
	if m == nil {
		m = &Metric{Unit: unit, Lower: lower, Gate: gate}
		r.Metrics[name] = m
	}
	m.Values = append(m.Values, v)
	m.Median = median(m.Values)
	devs := make([]float64, len(m.Values))
	for i, x := range m.Values {
		devs[i] = math.Abs(x - m.Median)
	}
	m.MAD = median(devs)
}

func median(xs []float64) float64 {
	if len(xs) == 0 {
		return math.NaN()
	}
	s := append([]float64{}, xs...)
	sort.Float64s(s)
	if len(s)%2 == 1 {
		return s[len(s)/2]
	}
	return (s[len(s)/2-1] + s[len(s)/2]) / 2
}

func percentile(xs []float64, p float64) float64 {
	if len(xs) == 0 {
		return math.NaN()
	}
	s := append([]float64{}, xs...)
	sort.Float64s(s)
	return s[int(math.Min(float64(len(s)-1), float64(len(s)-1)*p))]
}

func finish(name string, r Report) {
	if save(name, r) && *check {
		os.Exit(1)
	}
}

// save writes the report, prints it, and returns true if -check found a regression.
func save(name string, r Report) bool {
	dir := filepath.Join(here, "results", hostName)
	must(os.MkdirAll(filepath.Join(dir, "baseline"), 0o755))
	data, err := json.MarshalIndent(r, "", "  ")
	must(err)
	jsonPath := filepath.Join(dir, name+".json")
	must(os.WriteFile(jsonPath, data, 0o644))

	md := fmt.Sprintf("# %s — %s\n\nHost `%s`, commit `%s`, %s.\n\n%s", name, title(name), r.Host, r.Commit, r.Date, r.Markdown)
	md += "\n## All metrics (median of runs, MAD)\n\n| Metric | Median | MAD | Unit | Runs |\n|---|---|---|---|---|\n"
	names := make([]string, 0, len(r.Metrics))
	for n := range r.Metrics {
		names = append(names, n)
	}
	sort.Strings(names)
	for _, n := range names {
		m := r.Metrics[n]
		md += fmt.Sprintf("| %s | %s | %s | %s | %d |\n", n, num(m.Median), num(m.MAD), m.Unit, len(m.Values))
	}

	regressed := false
	basePath := filepath.Join(dir, "baseline", name+".json")
	if _, err := os.Stat(basePath); err == nil {
		table, bad := compare(loadReport(basePath), r)
		md += "\n## Against baseline\n\n" + table
		regressed = bad
	} else {
		md += "\nNo baseline yet for this host. Commit one with -update-baseline once the numbers look right.\n"
	}
	must(os.WriteFile(filepath.Join(dir, name+".md"), []byte(md), 0o644))
	if *updateBaseline {
		must(os.WriteFile(basePath, data, 0o644))
	}
	fmt.Println(md)
	return regressed
}

func title(name string) string {
	return map[string]string{
		"micro": "per-redraw layout and broadcast encode cost (PLAN #4, #7)", "launch": "launch and time-to-first-prompt (PLAN #8)",
		"idle": "idle and open-but-paused cost (PLAN #5)", "render": "overlay frame pacing (PLAN #4)",
		"broadcast": "browser-mode WebSocket clients (PLAN #7)", "latency": "spoken word → highlight, by stage (PLAN #2)",
		"soak": "long session (PLAN #6)", "engine": "local model performance (PLAN #3)",
	}[name]
}

func loadReport(path string) Report {
	data, err := os.ReadFile(path)
	must(err)
	var r Report
	must(json.Unmarshal(data, &r))
	return r
}

// compare flags a gated metric when its median is >10% worse than baseline and both
// runs' spread (MAD) is less than half of the gap, so noisy runs don't fail CI.
func compare(base, cur Report) (string, bool) {
	out := "| Metric | Baseline | Now | Change | Verdict |\n|---|---|---|---|---|\n"
	names := make([]string, 0)
	for n := range cur.Metrics {
		if base.Metrics[n] != nil {
			names = append(names, n)
		}
	}
	sort.Strings(names)
	regressed := false
	for _, n := range names {
		b, c := base.Metrics[n], cur.Metrics[n]
		if b.Median == 0 {
			continue
		}
		change := (c.Median - b.Median) / math.Abs(b.Median)
		worse := change > 0.10
		if !c.Lower {
			worse = change < -0.10
		}
		gap := math.Abs(c.Median - b.Median)
		verdict := "ok"
		if worse {
			if math.Max(b.MAD, c.MAD) < gap/2 {
				if c.Gate {
					verdict = "❌ regression"
					regressed = true
				} else {
					verdict = "⚠️ worse (report-only)"
				}
			} else {
				verdict = "~ noisy"
			}
		}
		out += fmt.Sprintf("| %s | %s | %s | %+.1f%% | %s |\n", n, num(b.Median), num(c.Median), change*100, verdict)
	}
	return out, regressed
}

func num(x float64) string {
	switch {
	case math.IsNaN(x):
		return "–"
	case math.Abs(x) >= 100:
		return strconv.FormatFloat(x, 'f', 0, 64)
	case math.Abs(x) >= 1:
		return strconv.FormatFloat(x, 'f', 2, 64)
	default:
		return strconv.FormatFloat(x, 'g', 3, 64)
	}
}

// ---------------------------------------------------------------------------------------
// Building

func buildAll() {
	buildApp()
	buildHarness()
	buildEngine()
}

func ensureApp() {
	if !*skipBuild || !exists(appBinary) {
		buildApp()
	}
}

func ensureHarness() {
	if !*skipBuild || !exists(harnessBin) {
		buildHarness()
	}
}

func ensureEngine() {
	if !*skipBuild || !exists(engineBin) {
		buildEngine()
	}
}

func buildApp() {
	fmt.Fprintln(os.Stderr, "building BENCHMARK app…")
	cmd := exec.Command("xcodebuild", "-project", filepath.Join(root, "Textream", "Textream.xcodeproj"),
		"-scheme", "Textream", "-configuration", "Release", "-destination", "platform=macOS",
		"-derivedDataPath", filepath.Join(cacheDir, "dd"),
		"CODE_SIGNING_ALLOWED=NO", "SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) BENCHMARK",
		"PRODUCT_BUNDLE_IDENTIFIER=dev.fka.textream.bench", "build")
	var out bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &out
	if err := cmd.Run(); err != nil {
		for _, line := range strings.Split(out.String(), "\n") {
			if strings.Contains(line, "error:") {
				fmt.Fprintln(os.Stderr, line)
			}
		}
		fail("xcodebuild failed")
	}
	// Ad-hoc sign without the App Sandbox (so it can read bench files anywhere) and with
	// get-task-allow (so leaks and xctrace can attach).
	app := filepath.Dir(filepath.Dir(filepath.Dir(appBinary)))
	run("codesign", "--force", "--deep", "--sign", "-", "--entitlements", filepath.Join(here, "Bench.entitlements"), app)
}

func buildHarness() {
	cmd := exec.Command("go", "run", "run.go", "-build", harnessBin)
	cmd.Dir = filepath.Join(here, "..", "speech-tracking")
	cmd.Stdout, cmd.Stderr = os.Stderr, os.Stderr
	must(cmd.Run())
}

// buildEngine compiles the engine tool against the app's own LocalSpeechEngine.swift and
// the vendored TranscribeCpp bindings, linking the CTranscribe framework that the app build
// fetched (or downloading the pinned release itself when there is no app build yet).
func buildEngine() {
	framework := findFramework()
	work := filepath.Join(cacheDir, "engine-build")
	must(os.MkdirAll(work, 0o755))
	bindings, err := filepath.Glob(filepath.Join(root, "Textream", "Vendor", "TranscribeCpp", "Sources", "TranscribeCpp", "*.swift"))
	must(err)
	moduleCache := filepath.Join(work, "module-cache")
	lib := exec.Command("swiftc", append([]string{"-O", "-swift-version", "5", "-module-cache-path", moduleCache,
		"-parse-as-library", "-module-name", "TranscribeCpp", "-emit-module", "-emit-library", "-static", "-F", framework}, bindings...)...)
	lib.Dir = work
	lib.Stderr = os.Stderr
	must(lib.Run())
	tool := exec.Command("swiftc", "-O", "-swift-version", "5", "-module-cache-path", moduleCache, "-o", engineBin,
		"-I", work, "-L", work, "-lTranscribeCpp", "-F", framework, "-framework", "CTranscribe",
		"-Xlinker", "-rpath", "-Xlinker", framework, "-lc++", "-lz", "-framework", "Accelerate", "-framework", "Metal", "-framework", "MetalKit",
		filepath.Join(root, "Textream", "Textream", "LocalSpeechEngine.swift"), filepath.Join(here, "engine", "main.swift"))
	tool.Stderr = os.Stderr
	must(tool.Run())
}

func findFramework() string {
	matches, _ := filepath.Glob(filepath.Join(cacheDir, "dd", "SourcePackages", "artifacts", "*", "*", "TranscribeCpp.xcframework", "macos-*"))
	if len(matches) > 0 {
		return matches[0]
	}
	// No app build yet: fetch the release pinned in Vendor/TranscribeCpp/Package.swift.
	manifest, err := os.ReadFile(filepath.Join(root, "Textream", "Vendor", "TranscribeCpp", "Package.swift"))
	must(err)
	url := regexp.MustCompile(`url: "([^"]+)"`).FindSubmatch(manifest)
	sum := regexp.MustCompile(`checksum: "([0-9a-f]+)"`).FindSubmatch(manifest)
	if url == nil || sum == nil {
		fail("cannot find the CTranscribe binary target in Package.swift")
	}
	zip := filepath.Join(cacheDir, "TranscribeCpp.xcframework.zip")
	download(string(url[1]), zip, string(sum[1]))
	dest := filepath.Join(cacheDir, "xcframework")
	must(os.RemoveAll(dest))
	run("ditto", "-x", "-k", zip, dest)
	matches, _ = filepath.Glob(filepath.Join(dest, "*", "macos-*"))
	if len(matches) == 0 {
		matches, _ = filepath.Glob(filepath.Join(dest, "macos-*"))
	}
	if len(matches) == 0 {
		fail("no macOS slice in the downloaded xcframework")
	}
	return matches[0]
}

// ---------------------------------------------------------------------------------------
// Running the app

type Event map[string]any

func (e Event) str(k string) string { s, _ := e[k].(string); return s }
func (e Event) num(k string) float64 {
	if f, ok := e[k].(float64); ok {
		return f
	}
	return math.NaN()
}

type Events []Event

func (es Events) first(name string) Event {
	for _, e := range es {
		if e.str("e") == name {
			return e
		}
	}
	return nil
}

func (es Events) all(name string) Events {
	var out Events
	for _, e := range es {
		if e.str("e") == name {
			out = append(out, e)
		}
	}
	return out
}

type AppRun struct {
	Events Events
	Log    string
	PID    int
}

var runCounter int

// yes is a boolean launch argument. Launch arguments land in UserDefaults as strings
// unless written as a plist literal, and settings read with `object(forKey:) as? Bool`
// (browserServerEnabled, directorModeEnabled, …) ignore the string "YES".
const yes = "<true/>"

// launchApp runs the BENCHMARK app with bench arguments plus UserDefaults overrides
// (e.g. "-overlayMode", "floating"), waits for it to quit or for the timeout, and
// returns its event log. `during` runs alongside the app with its pid and log path.
func launchApp(args []string, timeout time.Duration, during func(pid int, logPath string)) AppRun {
	runCounter++
	logDir := filepath.Join(cacheDir, "logs")
	must(os.MkdirAll(logDir, 0o755))
	logPath := filepath.Join(logDir, fmt.Sprintf("%s-%03d.jsonl", time.Now().Format("150405"), runCounter))
	// Fresh preferences every run: the bench bundle id never shares the user's.
	_ = exec.Command("defaults", "delete", "dev.fka.textream.bench").Run()
	all := append([]string{"-bench-log", logPath, "-NSQuitAlwaysKeepsWindows", "NO", "-ApplePersistenceIgnoreState", yes}, args...)
	cmd := exec.Command(appBinary, all...)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	must(cmd.Start())
	// A sleeping display stops vsync, and with it every frame measurement: wake it (-u) and keep the
	// display (and system) awake for exactly as long as the app runs.
	_ = exec.Command("caffeinate", "-d", "-i", "-u", "-w", strconv.Itoa(cmd.Process.Pid)).Start()
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	if during != nil {
		go during(cmd.Process.Pid, logPath)
	}
	select {
	case <-done:
	case <-time.After(timeout):
		_ = cmd.Process.Kill()
		<-done
		fmt.Fprintf(os.Stderr, "app timed out after %s (args %v)\n", timeout, args)
	}
	return AppRun{Events: readEvents(logPath), Log: logPath, PID: cmd.Process.Pid}
}

func readEvents(path string) Events {
	f, err := os.Open(path)
	if err != nil {
		return nil
	}
	defer f.Close()
	var out Events
	sc := bufio.NewScanner(f)
	sc.Buffer(make([]byte, 1<<20), 1<<26)
	for sc.Scan() {
		var e Event
		if json.Unmarshal(sc.Bytes(), &e) == nil {
			out = append(out, e)
		}
	}
	return out
}

// Resources over [from, to] (wall seconds) from the app's own task_info samples.
type Resources struct{ CPUPercent, WakeupsPerSec, EnergyMW, MemoryMB, Seconds float64 }

func resources(es Events, from, to float64) Resources {
	var in Events
	for _, s := range es.all("sample") {
		if w := s.num("wall"); w >= from && w <= to {
			in = append(in, s)
		}
	}
	if len(in) < 2 {
		return Resources{CPUPercent: math.NaN(), WakeupsPerSec: math.NaN(), EnergyMW: math.NaN(), MemoryMB: math.NaN()}
	}
	a, b := in[0], in[len(in)-1]
	dt := b.num("wall") - a.num("wall")
	cpu := (b.num("cpuUserNs") + b.num("cpuSystemNs") - a.num("cpuUserNs") - a.num("cpuSystemNs")) / 1e9
	wake := b.num("idleWakeups") + b.num("interruptWakeups") - a.num("idleWakeups") - a.num("interruptWakeups")
	return Resources{
		CPUPercent:    cpu / dt * 100,
		WakeupsPerSec: wake / dt,
		EnergyMW:      (b.num("energyNj") - a.num("energyNj")) / dt / 1e6,
		MemoryMB:      b.num("physFootprint") / 1048576,
		Seconds:       dt,
	}
}

func probeSummary(es Events, probe string) Event {
	for _, e := range es.all("probe.summary") {
		if e.str("probe") == probe {
			return e
		}
	}
	return nil
}

func defaultRuns(n int) int {
	if *runs > 0 {
		return *runs
	}
	return n
}

// ---------------------------------------------------------------------------------------
// #4 / #7 micro

func benchMicro() Report {
	r := newReport()
	out := filepath.Join(cacheDir, "micro.json")
	for i := 0; i < defaultRuns(5); i++ {
		_ = os.Remove(out)
		launchApp([]string{"-bench-micro", out, "-bench-hide-main-window", yes}, 5*time.Minute, nil)
		data, err := os.ReadFile(out)
		if err != nil {
			fail("micro run produced no results (see the app log in .cache/logs)")
		}
		var rows []map[string]any
		must(json.Unmarshal(data, &rows))
		for _, row := range rows {
			name := fmt.Sprintf("%s.%dk", row["name"], int(row["words"].(float64))/1000)
			if at, ok := row["at"].(float64); ok {
				name += fmt.Sprintf("@%d%%", int(at*100))
			}
			r.add(name+".ms", "ms", true, true, row["ns"].(float64)/1e6)
			if b, ok := row["bytes"].(float64); ok {
				r.add(name+".bytes", "bytes", true, false, b)
			}
		}
	}
	r.Markdown = "Per-redraw work in `WordFlowLayout.body` before visible lines are laid out (cache check, next-word scan, RTL check), " +
		"and one broadcast tick's JSON encode. `layout.cold` is the first layout of a script (cache miss).\n\n" +
		"At 10 Hz, a broadcast's CPU share ≈ encode ms × 10 / 1000.\n"
	return r
}

// ---------------------------------------------------------------------------------------
// #8 launch and time-to-first-prompt

func benchLaunch() Report {
	r := newReport()
	n := defaultRuns(5)
	purge := func() {
		if *cold {
			if err := exec.Command("sudo", "-n", "purge").Run(); err != nil {
				fail("-cold needs passwordless `sudo purge` (see PLAN.md Phase 0, hardware)")
			}
		}
	}
	steps := map[string][]float64{}
	for i := 0; i < n; i++ {
		purge()
		run := launchApp([]string{"-bench-launch", yes}, 60*time.Second, nil)
		start, frame := run.Events.first("process.start"), run.Events.first("main.firstFrame")
		if start == nil || frame == nil {
			fmt.Fprintln(os.Stderr, "launch run missing events; log:", run.Log)
			continue
		}
		t0 := start.num("startWall")
		r.add("launch.mainWindowFirstFrame.ms", "ms", true, true, (frame.num("wall")-t0)*1000)
		if e := run.Events.first("launch.didFinishLaunching"); e != nil {
			r.add("launch.didFinishLaunching.ms", "ms", true, false, (e.num("wall")-t0)*1000)
		}
		prev := run.Events.first("launch.didFinishLaunching")
		for _, s := range run.Events.all("launch.step") {
			if prev != nil {
				steps[s.str("name")] = append(steps[s.str("name")], (s.num("wall")-prev.num("wall"))*1000)
			}
			prev = s
		}
	}
	for name, xs := range steps {
		for _, x := range xs {
			r.add("launch.step."+name+".ms", "ms", true, false, x)
		}
	}
	// Time to first prompt: app not running (launch with a script) and app running
	// (read 2 s after launch). Classic mode, so no recognizer is involved.
	for i := 0; i < n; i++ {
		purge()
		run := launchApp([]string{"-bench-launch", yes, "-bench-script", "words:2000", "-listeningMode", "classic"}, 60*time.Second, nil)
		if s, f := run.Events.first("process.start"), run.Events.first("overlay.firstFrame"); s != nil && f != nil {
			r.add("ttfp.notRunning.overlayFirstFrame.ms", "ms", true, true, (f.num("wall")-s.num("startWall"))*1000)
		}
		run = launchApp([]string{"-bench-launch", yes, "-bench-script", "words:2000", "-bench-read-after", "2", "-listeningMode", "classic"}, 60*time.Second, nil)
		if b, f := run.Events.first("read.begin"), run.Events.first("overlay.firstFrame"); b != nil && f != nil {
			r.add("ttfp.running.overlayFirstFrame.ms", "ms", true, true, (f.num("wall")-b.num("wall"))*1000)
		}
	}
	// First highlighted word with word tracking: includes recognizer start and, for a
	// local model, the model load.
	if c := ensureCase("baseline-us"); c != "" {
		for _, engine := range engines() {
			for i := 0; i < n; i++ {
				args := append([]string{"-bench-launch", yes, "-bench-until-highlight", yes, "-bench-read-after", "1",
					"-bench-script", filepath.Join(c, "script.txt"), "-bench-audio", filepath.Join(c, "audio.wav")}, engine.args...)
				run := launchApp(args, 120*time.Second, nil)
				b := run.Events.first("read.begin")
				var hit Event
				for _, f := range run.Events.all("frame") {
					if f.str("probe") == "overlay" && f.num("chars") > 0 {
						hit = f
						break
					}
				}
				if b != nil && hit != nil {
					r.add("ttfp.firstHighlight."+engine.name+".ms", "ms", true, true, (hit.num("wall")-b.num("wall"))*1000)
				}
			}
		}
	}
	r.Markdown = "Launch is measured from process start (kernel start time) to the first display refresh of the main window. " +
		"The app is exec'd directly, so LaunchServices time (Dock click, `open`) is not included.\n\n" +
		"- `ttfp.notRunning`: launched with a 2,000-word script → first overlay frame.\n" +
		"- `ttfp.running`: script read 2 s after launch → first overlay frame.\n" +
		"- `ttfp.firstHighlight.<engine>`: read → first frame with a highlighted word (file-fed audio; local includes model load).\n"
	if *cold {
		r.Markdown += "\nCold: the file cache was purged before every launch.\n"
	}
	return r
}

// ---------------------------------------------------------------------------------------
// #5 idle / open-but-paused

func benchIdle() Report {
	r := newReport()
	mins := *minutes
	if mins == 0 {
		mins = 5
	}
	settle := 60.0
	scenarios := []struct {
		name string
		args []string
		gate bool
	}{
		{"A.menubar", []string{"-bench-hide-main-window", yes}, true},
		{"B.mainWindow", nil, true},
		{"C.paused.pinned", []string{"-bench-script", "words:2000", "-bench-stop-listening", yes, "-overlayMode", "pinned"}, true},
		{"C.paused.floating", []string{"-bench-script", "words:2000", "-bench-stop-listening", yes, "-overlayMode", "floating"}, true},
		{"C.paused.fullscreen", []string{"-bench-script", "words:2000", "-bench-stop-listening", yes, "-overlayMode", "fullscreen"}, true},
		{"D.servers", []string{"-bench-hide-main-window", yes, "-directorModeEnabled", yes, "-browserServerEnabled", yes}, true},
		{"E.classic", []string{"-bench-script", "words:2000", "-listeningMode", "classic", "-scrollSpeed", "3"}, false},
		{"F.tracking-ui", []string{"-bench-script", "words:2000", "-bench-autoplay", "150"}, false},
	}
	md := "| Scenario | CPU % | Wakeups/s | Energy (mW) | Memory (MB) |\n|---|---|---|---|---|\n"
	for _, sc := range scenarios {
		if !strings.Contains(sc.name, *only) {
			continue
		}
		var cpu, wake, energy, mem []float64
		for i := 0; i < defaultRuns(3); i++ {
			args := append([]string{"-bench-sample-interval", "10", "-bench-quit-after", fmt.Sprint(settle + mins*60 + 1)}, sc.args...)
			run := launchApp(args, time.Duration(settle+mins*60+60)*time.Second, nil)
			start := run.Events.first("process.start")
			if start == nil {
				continue
			}
			t0 := start.num("wall")
			res := resources(run.Events, t0+settle, t0+settle+mins*60+5)
			r.add("idle."+sc.name+".cpuPercent", "%", true, sc.gate, res.CPUPercent)
			r.add("idle."+sc.name+".wakeupsPerSec", "/s", true, sc.gate, res.WakeupsPerSec)
			r.add("idle."+sc.name+".energyMW", "mW", true, false, res.EnergyMW)
			cpu, wake, energy, mem = append(cpu, res.CPUPercent), append(wake, res.WakeupsPerSec), append(energy, res.EnergyMW), append(mem, res.MemoryMB)
		}
		md += fmt.Sprintf("| %s | %s | %s | %s | %s |\n", sc.name, num(median(cpu)), num(median(wake)), num(median(energy)), num(median(mem)))
	}
	r.Markdown = md + fmt.Sprintf("\nEach scenario: %d-s settle, then %.0f min measured from the app's own task_info samples "+
		"(every 10 s, so the sampler adds ≈0.1 wakeups/s). Energy is the kernel's per-task estimate (Apple silicon only). "+
		"PLAN bars: A < 0.1%% CPU and < 2 wakeups/s; B < 0.5%%, < 5/s; C < 1%%, < 20/s; D adds < 1 wakeup/s over A. "+
		"C has recognition paused, so it measures what the open overlay costs on its own.\n", int(settle), mins)
	return r
}

// ---------------------------------------------------------------------------------------
// #4 rendering

func benchRender() Report {
	r := newReport()
	sizes := []int{1000, 10000, 50000}
	fonts := []string{"sans", "dyslexia"}
	modes := [][]string{{"pinned", "-overlayMode", "pinned"}, {"floating", "-overlayMode", "floating"}, {"fullscreen", "-overlayMode", "fullscreen"}}
	from := []string{}
	if *autoplayFrom > 0 {
		from = []string{"-bench-autoplay-from", fmt.Sprint(*autoplayFrom)}
	}
	if screens() > 1 {
		modes = append(modes, []string{"external", "-overlayMode", "floating", "-externalDisplayMode", "teleprompter"})
	}
	md := "| Words | Font | Mode | Hitch ms/s | Worst frame (ms) | CPU % | Refresh (Hz) |\n|---|---|---|---|---|---|---|\n"
	for _, n := range sizes {
		for _, font := range fonts {
			for _, mode := range modes {
				name := fmt.Sprintf("render.%dk.%s.%s", n/1000, font, mode[0])
				if !strings.Contains(name, *only) {
					continue
				}
				var hitch, worst, cpu, hz []float64
				for i := 0; i < defaultRuns(3); i++ {
					args := append(append([]string{"-bench-script", fmt.Sprintf("words:%d", n), "-bench-autoplay", "150", "-bench-probe", yes,
						"-bench-sample-interval", "5", "-bench-quit-after", fmt.Sprint(*seconds + 3), "-fontFamilyPreset", font}, mode[1:]...), from...)
					var run AppRun
					if *xctrace {
						run = launchUnderXctrace(args, name, i)
					} else {
						run = launchApp(args, time.Duration(*seconds+60)*time.Second, nil)
					}
					probe := "overlay"
					if mode[0] == "external" {
						probe = "external"
					}
					s := probeSummary(run.Events, probe)
					start := run.Events.first("autoplay.start")
					if s == nil || start == nil {
						fmt.Fprintln(os.Stderr, name, "missing probe summary; log:", run.Log)
						continue
					}
					res := resources(run.Events, start.num("wall"), start.num("wall")+*seconds+5)
					r.add(name+".hitchMsPerS", "ms/s", true, true, s.num("hitchMsPerS"))
					r.add(name+".maxFrameMs", "ms", true, false, s.num("maxFrameMs"))
					r.add(name+".cpuPercent", "%", true, true, res.CPUPercent)
					hitch, worst, cpu, hz = append(hitch, s.num("hitchMsPerS")), append(worst, s.num("maxFrameMs")), append(cpu, res.CPUPercent), append(hz, s.num("refreshHz"))
				}
				md += fmt.Sprintf("| %d | %s | %s | %s | %s | %s | %s |\n", n, font, mode[0], num(median(hitch)), num(median(worst)), num(median(cpu)), num(median(hz)))
			}
		}
	}
	r.Markdown = md + "\nThe highlight advances one word at a time at 150 wpm with no recognizer (`-bench-autoplay`), so only rendering is measured. " +
		"A hitch is a display-refresh callback that arrived more than 1.5 frames after the previous one: the main thread was busy. " +
		"CPU % is the whole app process. PLAN bars: hitches < 5 ms/s, CPU < 15% at 50k words. " +
		"Sidecar is a manual check each release.\n"
	if *xctrace {
		r.Markdown += "\nInstruments traces: `.cache/traces/`.\n"
	}
	return r
}

func launchUnderXctrace(args []string, name string, i int) AppRun {
	traces := filepath.Join(cacheDir, "traces")
	must(os.MkdirAll(traces, 0o755))
	logPath := filepath.Join(cacheDir, "logs", fmt.Sprintf("%s-%d.jsonl", name, i))
	_ = exec.Command("defaults", "delete", "dev.fka.textream.bench").Run()
	caffeinate := exec.Command("caffeinate", "-d", "-i", "-u")
	_ = caffeinate.Start()
	defer func() { _ = caffeinate.Process.Kill() }()
	all := append([]string{"xctrace", "record", "--template", "Animation Hitches", "--output", filepath.Join(traces, fmt.Sprintf("%s-%d.trace", name, i)),
		"--launch", "--", appBinary, "-bench-log", logPath}, args...)
	cmd := exec.Command("xcrun", all...)
	cmd.Stdout, cmd.Stderr = io.Discard, os.Stderr
	_ = cmd.Run()
	return AppRun{Events: readEvents(logPath), Log: logPath}
}

func screens() int {
	out, err := exec.Command("system_profiler", "SPDisplaysDataType").Output()
	if err != nil {
		return 1
	}
	return strings.Count(string(out), "Resolution:")
}

// ---------------------------------------------------------------------------------------
// #7 broadcast with real WebSocket clients

func benchBroadcast() Report {
	r := newReport()
	md := "| Words | Clients | App CPU % | KB/s per client | Highlight → client p50 / p95 (ms) |\n|---|---|---|---|---|\n"
	port := 47300
	for _, n := range []int{1000, 10000, 50000} {
		for _, clients := range []int{1, 5, 20} {
			name := fmt.Sprintf("broadcast.%dk.%dclients", n/1000, clients)
			var cpu, rate, p50, p95 []float64
			for i := 0; i < defaultRuns(3); i++ {
				port += 2
				var stats []*clientStats
				var mu sync.Mutex
				args := []string{"-bench-script", fmt.Sprintf("words:%d", n), "-bench-autoplay", "150", "-bench-hide-main-window", yes,
					"-browserServerEnabled", yes, "-browserServerPort", fmt.Sprint(port), "-listeningMode", "wordTracking",
					"-bench-sample-interval", "5", "-bench-quit-after", fmt.Sprint(*seconds + 5)}
				run := launchApp(args, time.Duration(*seconds+60)*time.Second, func(pid int, _ string) {
					var wg sync.WaitGroup
					for c := 0; c < clients; c++ {
						wg.Add(1)
						go func() {
							defer wg.Done()
							s := wsClient(fmt.Sprintf("127.0.0.1:%d", port+1), time.Duration(*seconds+3)*time.Second)
							mu.Lock()
							stats = append(stats, s)
							mu.Unlock()
						}()
					}
					wg.Wait()
				})
				start := run.Events.first("autoplay.start")
				if start == nil || len(stats) == 0 {
					fmt.Fprintln(os.Stderr, name, "no data; log:", run.Log)
					continue
				}
				changed := map[int]float64{}
				for _, a := range run.Events.all("autoplay") {
					changed[int(a.num("chars"))] = a.num("wall")
				}
				var delays []float64
				var bytesTotal, secs float64
				for _, s := range stats {
					bytesTotal += float64(s.bytes)
					secs = math.Max(secs, s.seconds)
					for chars, at := range s.firstSeen {
						if w, ok := changed[chars]; ok && at >= w {
							delays = append(delays, (at-w)*1000)
						}
					}
				}
				res := resources(run.Events, start.num("wall")+2, start.num("wall")+*seconds)
				r.add(name+".cpuPercent", "%", true, true, res.CPUPercent)
				kbps := bytesTotal / float64(len(stats)) / math.Max(secs, 1) / 1024
				r.add(name+".kbPerSecPerClient", "KB/s", true, false, kbps)
				r.add(name+".delayP95Ms", "ms", true, false, percentile(delays, 0.95))
				cpu, rate, p50, p95 = append(cpu, res.CPUPercent), append(rate, kbps), append(p50, percentile(delays, 0.5)), append(p95, percentile(delays, 0.95))
			}
			md += fmt.Sprintf("| %d | %d | %s | %s | %s / %s |\n", n, clients, num(median(cpu)), num(median(rate)), num(median(p50)), num(median(p95)))
		}
	}
	r.Markdown = md + "\nBrowser mode (no auth token) with the highlight advancing at 150 wpm. Clients run in this process, not the app, " +
		"so the app's CPU is the server's cost alone. Delay: app sets a new highlight → a client receives the first state containing it " +
		"(the 100 ms broadcast timer bounds it at ≈100 ms plus encode and send).\n"
	return r
}

type clientStats struct {
	bytes     int
	seconds   float64
	firstSeen map[int]float64 // highlightedCharCount → wall time first received
}

// wsClient is a minimal RFC 6455 client: handshake, then read (unmasked) server frames.
func wsClient(addr string, d time.Duration) *clientStats {
	s := &clientStats{firstSeen: map[int]float64{}}
	deadline := time.Now().Add(d)
	var conn net.Conn
	var err error
	for time.Now().Before(deadline) {
		if conn, err = net.DialTimeout("tcp", addr, time.Second); err == nil {
			break
		}
		time.Sleep(200 * time.Millisecond)
	}
	if conn == nil {
		return s
	}
	defer conn.Close()
	key := make([]byte, 16)
	_, _ = rand.Read(key)
	fmt.Fprintf(conn, "GET / HTTP/1.1\r\nHost: %s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n\r\n",
		addr, base64.StdEncoding.EncodeToString(key))
	br := bufio.NewReader(conn)
	status, err := br.ReadString('\n')
	if err != nil || !strings.Contains(status, "101") {
		return s
	}
	for {
		line, err := br.ReadString('\n')
		if err != nil || line == "\r\n" {
			break
		}
	}
	start := time.Now()
	_ = conn.SetReadDeadline(deadline)
	var message []byte
	for {
		header := make([]byte, 2)
		if _, err := io.ReadFull(br, header); err != nil {
			break
		}
		length := int64(header[1] & 0x7f)
		switch length {
		case 126:
			b := make([]byte, 2)
			if _, err := io.ReadFull(br, b); err != nil {
				return s
			}
			length = int64(binary.BigEndian.Uint16(b))
		case 127:
			b := make([]byte, 8)
			if _, err := io.ReadFull(br, b); err != nil {
				return s
			}
			length = int64(binary.BigEndian.Uint64(b))
		}
		var mask []byte
		if header[1]&0x80 != 0 {
			mask = make([]byte, 4)
			if _, err := io.ReadFull(br, mask); err != nil {
				return s
			}
		}
		payload := make([]byte, length)
		if _, err := io.ReadFull(br, payload); err != nil {
			break
		}
		if mask != nil {
			for i := range payload {
				payload[i] ^= mask[i%4]
			}
		}
		s.bytes += len(payload) + 2
		message = append(message, payload...)
		if header[0]&0x80 == 0 { // not the final fragment
			continue
		}
		var state struct {
			HighlightedCharCount int `json:"highlightedCharCount"`
		}
		if json.Unmarshal(message, &state) == nil {
			if _, seen := s.firstSeen[state.HighlightedCharCount]; !seen {
				s.firstSeen[state.HighlightedCharCount] = float64(time.Now().UnixNano()) / 1e9
			}
		}
		message = message[:0]
	}
	s.seconds = time.Since(start).Seconds()
	return s
}

// ---------------------------------------------------------------------------------------
// Rendered cases, engines and models

// ensureCase renders a harness case (TTS audio + ground truth) into .cache/cases/<id>.
func ensureCase(id string) string {
	dir := filepath.Join(cacheDir, "cases", id)
	if exists(filepath.Join(dir, "audio.wav")) {
		return dir
	}
	if !exists(harnessBin) {
		buildHarness()
	}
	cmd := exec.Command(harnessBin, "render-audio", filepath.Join(here, "..", "speech-tracking"), filepath.Join(cacheDir, "cases"))
	cmd.Env = append(os.Environ(), "CASE="+id)
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil || !exists(filepath.Join(dir, "audio.wav")) {
		fmt.Fprintln(os.Stderr, "could not render case", id, "(needs the macOS voices the case uses)")
		return ""
	}
	return dir
}

type engineChoice struct {
	name string
	args []string
}

// engines returns the app settings for the -engine flag ("apple", "apple-server" or "local").
func engines() []engineChoice {
	var out []engineChoice
	for _, e := range strings.Split(*engineFlag, ",") {
		switch e {
		case "apple":
			out = append(out, engineChoice{"apple", []string{"-speechEngine", "apple", "-listeningMode", "wordTracking"}})
		case "local":
			model := pickModel()
			if model == "" {
				fmt.Fprintln(os.Stderr, "no local model in .cache/models; run: go run run.go fetch-model whisper-base-gguf Q8_0")
				continue
			}
			out = append(out, engineChoice{"local-" + strings.TrimSuffix(filepath.Base(model), ".gguf"), []string{
				"-speechEngine", "local", "-listeningMode", "wordTracking",
				"-bench-models-dir", filepath.Dir(model), "-localModelFilename", filepath.Base(model)}})
		default:
			fail("unknown -engine " + e)
		}
	}
	return out
}

func models() []string {
	all, _ := filepath.Glob(filepath.Join(cacheDir, "models", "*.gguf"))
	sort.Slice(all, func(i, j int) bool { return fileSize(all[i]) < fileSize(all[j]) })
	return all
}

func pickModel() string {
	if *modelFlag != "" {
		if exists(*modelFlag) {
			return *modelFlag
		}
		return filepath.Join(cacheDir, "models", *modelFlag)
	}
	if ms := models(); len(ms) > 0 {
		return ms[0]
	}
	return ""
}

type catalog struct {
	Models []struct {
		RepoID       string `json:"repo_id"`
		Revision     string `json:"revision"`
		DefaultQuant string `json:"default_quant"`
		Files        []struct {
			Filename  string `json:"filename"`
			Quant     string `json:"quant"`
			SizeBytes int64  `json:"size_bytes"`
			SHA256    string `json:"sha256"`
		} `json:"files"`
	} `json:"models"`
}

func loadCatalog() catalog {
	data, err := os.ReadFile(filepath.Join(root, "Textream", "Textream", "Resources", "SpeechModelCatalog.json"))
	must(err)
	var c catalog
	must(json.Unmarshal(data, &c))
	return c
}

// fetchModel downloads a catalog model (pinned revision, sha256-verified) like the app does.
func fetchModel(repo, quant string) string {
	for _, m := range loadCatalog().Models {
		if !strings.Contains(m.RepoID, repo) {
			continue
		}
		if quant == "" {
			quant = m.DefaultQuant
		}
		for _, f := range m.Files {
			if f.Quant != quant {
				continue
			}
			dest := filepath.Join(cacheDir, "models", f.Filename)
			if exists(dest) {
				return dest
			}
			must(os.MkdirAll(filepath.Dir(dest), 0o755))
			download(fmt.Sprintf("https://huggingface.co/%s/resolve/%s/%s", m.RepoID, m.Revision, f.Filename), dest, f.SHA256)
			return dest
		}
		fail(fmt.Sprintf("%s has no %s file", m.RepoID, quant))
	}
	fail("no catalog model matches " + repo)
	return ""
}

func download(url, dest, sha string) {
	fmt.Fprintln(os.Stderr, "downloading", url)
	resp, err := http.Get(url)
	must(err)
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		fail(fmt.Sprintf("%s: HTTP %d", url, resp.StatusCode))
	}
	tmp := dest + ".part"
	f, err := os.Create(tmp)
	must(err)
	h := sha256.New()
	_, err = io.Copy(io.MultiWriter(f, h), resp.Body)
	must(err)
	must(f.Close())
	if got := hex.EncodeToString(h.Sum(nil)); sha != "" && got != sha {
		_ = os.Remove(tmp)
		fail(fmt.Sprintf("checksum mismatch for %s: got %s", url, got))
	}
	must(os.Rename(tmp, dest))
}

// ---------------------------------------------------------------------------------------
// #2 latency, #6 soak: the app reads a rendered case from file-fed audio

func scoreApp(caseDir, logPath string, loops int) (string, map[string]float64) {
	out, err := exec.Command(harnessBin, "score-app", filepath.Join(here, "..", "speech-tracking"), caseDir, logPath, strconv.Itoa(loops)).Output()
	if err != nil {
		return fmt.Sprintf("score-app failed for %s: %v\n", logPath, err), nil
	}
	text := string(out)
	metrics := map[string]float64{}
	if i := strings.LastIndex(text, "METRICS "); i >= 0 {
		_ = json.Unmarshal([]byte(strings.TrimSpace(text[i+8:])), &metrics)
		text = text[:i]
	}
	return text, metrics
}

func caseSeconds(caseDir string) float64 {
	var tl struct {
		End float64 `json:"end"`
	}
	data, err := os.ReadFile(filepath.Join(caseDir, "truth.json"))
	if err == nil {
		_ = json.Unmarshal(data, &tl)
	}
	return tl.End
}

func benchLatency() Report {
	r := newReport()
	md := ""
	for _, engine := range engines() {
		md += "## Engine `" + engine.name + "`\n\n"
		for _, id := range strings.Split(*casesFlag, ",") {
			c := ensureCase(id)
			if c == "" {
				continue
			}
			for i := 0; i < defaultRuns(1); i++ {
				args := append([]string{"-bench-script", filepath.Join(c, "script.txt"), "-bench-audio", filepath.Join(c, "audio.wav"),
					"-bench-probe", yes, "-bench-hide-main-window", yes, "-bench-quit-after-audio-start", fmt.Sprint(caseSeconds(c) + 6)}, engine.args...)
				run := launchApp(args, time.Duration(caseSeconds(c)+120)*time.Second, nil)
				text, m := scoreApp(c, run.Log, 1)
				if i == 0 {
					md += text
				}
				prefix := "latency." + engine.name + "." + id + "."
				for _, k := range []string{"e2eP50", "e2eP95", "asrP50", "hopP95", "matcherP95", "renderP95"} {
					if v, ok := m[k]; ok {
						r.add(prefix+k+".ms", "ms", true, k == "e2eP95" || k == "matcherP95" || k == "hopP95", v*1000)
					}
				}
				if v, ok := m["lostPer10Min"]; ok {
					r.add(prefix+"lostPer10Min", "events", true, true, v)
				}
			}
		}
	}
	r.Markdown = md + "PLAN bars (base M1, Apple on-device): matcher p95 < 5 ms, hop p95 < 16 ms, render p95 < 1 frame, " +
		"end to end p50 < 600 ms and p95 < 1200 ms.\n"
	if strings.Contains(*engineFlag, "apple") {
		r.Markdown += "\nApple engines need Speech Recognition permission for the bench app; macOS asks once per build.\n"
	}
	return r
}

func benchSoak() Report {
	r := newReport()
	mins := *minutes
	if mins == 0 {
		mins = 90
	}
	c := ensureCase("composite")
	if c == "" {
		fail("cannot render the soak case")
	}
	// The rendered audio is the timeline plus ~1.3 s of lead-in and tail silence.
	period := caseSeconds(c) + 2
	loops := int(math.Ceil(mins * 60 / period))
	// Reaching the last word closes the overlay (by design), which would end the session
	// after one loop. A closing sentence the audio never speaks keeps it open; it sits
	// after the scored text, so score-app's offsets are unchanged.
	original, err := os.ReadFile(filepath.Join(c, "script.txt"))
	must(err)
	script := filepath.Join(cacheDir, "soak-script.txt")
	must(os.WriteFile(script, append(bytes.TrimSpace(original), []byte("\n\nThat is the end of this rehearsal, so let us go back to the top and run it again.\n")...), 0o644))
	md := ""
	for _, engine := range engines() {
		total := float64(loops) * period
		leaks := "not measured"
		leakedBytes := math.NaN()
		leaksDone := make(chan struct{})
		args := append([]string{"-bench-script", script,
			"-bench-audio", filepath.Join(c, "audio.wav"), "-bench-loop-audio", yes, "-bench-probe", yes, "-bench-hide-main-window", yes,
			"-bench-sample-interval", "30", "-bench-quit-after-audio-start", fmt.Sprint(total + 5)}, engine.args...)
		run := launchApp(args, time.Duration(total+300)*time.Second, func(pid int, logPath string) {
			defer close(leaksDone)
			// Shortly before the session ends (audio starts after the model loads).
			var started float64
			for started == 0 {
				time.Sleep(time.Second)
				if e := readEvents(logPath).first("audio.start"); e != nil {
					started = e.num("wall")
				} else if p, _ := os.FindProcess(pid); p.Signal(syscall.Signal(0)) != nil {
					leaks = "app exited before audio started"
					return
				}
			}
			time.Sleep(time.Until(time.Unix(0, int64(started*1e9)).Add(time.Duration(math.Max(1, total-20)) * time.Second)))
			out, _ := exec.Command("leaks", strconv.Itoa(pid)).CombinedOutput()
			if m := regexp.MustCompile(`(\d+) leaks? for (\d+) total leaked bytes`).FindSubmatch(out); m != nil {
				leaks = string(m[1]) + " leaks, " + string(m[2]) + " bytes"
				leakedBytes, _ = strconv.ParseFloat(string(m[2]), 64)
			} else {
				leaks = "leaks did not report (needs get-task-allow; see .cache/logs)"
			}
		})
		<-leaksDone
		r.add("soak."+engine.name+".leakedBytes", "bytes", true, true, leakedBytes)
		text, m := scoreApp(c, run.Log, loops)
		md += "## Engine `" + engine.name + "`\n\n" + text + "Leaks at the end: " + leaks + "\n\n"
		for k, gate := range map[string]bool{"memSlopeMBPerHour": true, "peakMemoryMB": false, "cpuPercent": false, "lostPer10Min": true} {
			if v, ok := m[k]; ok {
				r.add("soak."+engine.name+"."+k, "", true, gate, v)
			}
		}
		restarts := 0.0
		for _, s := range run.Events.all("asr.session") {
			if s.str("reason") == "restartTask" {
				restarts++
			}
		}
		r.add("soak."+engine.name+".restartTasks", "count", true, false, restarts)
	}
	r.Markdown = md + fmt.Sprintf("Session: the `composite` case (%.0f s) read %d× in one session, jumping back to the top of the script at each loop (%d jumps). "+
		"Pass: memory slope < 5 MB/h after 10 min, last loop tracks like the first, Apple restarts ≈ one per 55 s, 0 leaked bytes from app code.\n\n"+
		"Manual release checklist (not automated): sleep/wake mid-session; mic switch built-in → AirPods → built-in; "+
		"unplug/replug the external display in fullscreen-on-external; default input changing while backgrounded.\n", period-1, loops, loops-1)
	return r
}

// ---------------------------------------------------------------------------------------
// #3 local engines, #1 local fixtures

func benchEngine() Report {
	r := newReport()
	c := ensureCase("baseline-us")
	if c == "" {
		fail("cannot render the engine audio case")
	}
	ms := models()
	if *modelFlag != "" {
		ms = []string{pickModel()}
	}
	if len(ms) == 0 {
		fail("no models in .cache/models; e.g. go run run.go fetch-model whisper-base-gguf Q8_0")
	}
	md := "| Model | Backend | Load (s) | Reload (s) | First partial (s) | Partial interval p95 (s) | Decode @26 s p50 (s) | Stream RTF p95 | Peak MB | Thermal ratio | Recommended |\n" +
		"|---|---|---|---|---|---|---|---|---|---|---|\n"
	var recommended []map[string]any
	for _, model := range ms {
		name := strings.TrimSuffix(filepath.Base(model), ".gguf")
		var last map[string]any
		for i := 0; i < defaultRuns(3); i++ {
			out := filepath.Join(cacheDir, "engine-"+name+".json")
			thermalMin := 0.0
			if i == 0 {
				thermalMin = *thermal
			}
			cmd := exec.Command(engineBin, "perf", "--audio", filepath.Join(c, "audio.wav"), "--model", model, "--out", out,
				"--backend", *backendFlag, "--thermal-minutes", fmt.Sprint(thermalMin))
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				fmt.Fprintln(os.Stderr, "engine perf failed for", name, err)
				break
			}
			data, _ := os.ReadFile(out)
			var m map[string]any
			if json.Unmarshal(data, &m) != nil {
				break
			}
			if i == 0 {
				last = m
			} else {
				for k, v := range m {
					if _, ok := last[k]; !ok {
						last[k] = v
					}
				}
			}
			for _, k := range []struct {
				key, unit string
				gate      bool
			}{{"loadSeconds", "s", true}, {"reloadSeconds", "s", false}, {"firstPartialSeconds", "s", true},
				{"partialIntervalP95", "s", true}, {"decodeAt26sP50", "s", true}, {"streamRtfP95", "x", true}, {"peakMemoryMB", "MB", true},
				{"streamAudioSecondsIn2Min", "s", false}} {
				if v, ok := m[k.key].(float64); ok && v >= 0 {
					r.add("engine."+name+"."+k.key, k.unit, true, k.gate, v)
				}
			}
			if v, ok := m["thermalRatio"].(float64); ok {
				r.add("engine."+name+".thermalRatio", "x", true, false, v)
			}
		}
		if last == nil {
			continue
		}
		get := func(k string) float64 {
			if m := r.Metrics["engine."+name+"."+k]; m != nil {
				return m.Median
			}
			return math.NaN()
		}
		streaming, _ := last["streaming"].(bool)
		fast := get("decodeAt26sP50") < 1.0
		if streaming {
			fast = get("streamRtfP95") < 0.7
		}
		thermalOK := math.IsNaN(get("thermalRatio")) || get("thermalRatio") < 1.3
		rec := fast && thermalOK
		verdict := map[bool]string{true: "✅", false: "—"}[rec]
		if math.IsNaN(get("thermalRatio")) && rec {
			verdict = "✅ (thermals not run)"
		}
		md += fmt.Sprintf("| %s | %v | %s | %s | %s | %s | %s | %s | %s | %s | %s |\n", name, last["backend"], num(get("loadSeconds")),
			num(get("reloadSeconds")), num(get("firstPartialSeconds")), num(get("partialIntervalP95")), num(get("decodeAt26sP50")),
			num(get("streamRtfP95")), num(get("peakMemoryMB")), num(get("thermalRatio")), verdict)
		recommended = append(recommended, map[string]any{"model": filepath.Base(model), "recommended": rec, "thermalsMeasured": !math.IsNaN(get("thermalRatio")),
			"decodeAt26sP50": orNull(get("decodeAt26sP50")), "streamRtfP95": orNull(get("streamRtfP95")), "peakMemoryMB": orNull(get("peakMemoryMB"))})
	}
	data, err := json.MarshalIndent(map[string]any{"host": hostName, "date": time.Now().Format("2006-01-02"), "models": recommended}, "", "  ")
	must(err)
	dir := filepath.Join(here, "results", hostName)
	must(os.MkdirAll(dir, 0o755))
	must(os.WriteFile(filepath.Join(dir, "recommended-models.json"), data, 0o644))
	r.Markdown = md + "\nAudio: the `baseline-us` case. The app's rolling window re-decodes up to 26 s of audio every 1.5 s, so " +
		"**recommended** = 26-s decode p50 under 1.0 s (≈33% headroom) — or, for streaming models, chunk RTF p95 under 0.7 — " +
		"and a thermal ratio (minutes 25–30 vs 0–5 of sustained load) under 1.3. " +
		"`recommended-models.json` holds the verdicts for this host class.\n"
	return r
}

func recordLocal() {
	model := pickModel()
	if model == "" {
		fail("no model; pass -model <file> or fetch one")
	}
	cmd := exec.Command("go", "run", "run.go", "-record")
	cmd.Dir = filepath.Join(here, "..", "speech-tracking")
	cmd.Env = append(os.Environ(), "ENGINE=local:"+model, "ENGINE_TOOL="+engineBin)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	must(cmd.Run())
}

// ---------------------------------------------------------------------------------------
// Utilities

func detectHost() string {
	brand, _ := exec.Command("sysctl", "-n", "machdep.cpu.brand_string").Output()
	mem, _ := exec.Command("sysctl", "-n", "hw.memsize").Output()
	b := strings.ToLower(strings.TrimSpace(string(brand)))
	b = strings.NewReplacer("apple ", "", "(r)", "", "(tm)", "", "intel core ", "intel-", "cpu", "").Replace(b)
	b = regexp.MustCompile(`[^a-z0-9]+`).ReplaceAllString(b, "-")
	b = strings.Trim(b, "-")
	if i := strings.Index(b, "-@"); i > 0 {
		b = b[:i]
	}
	gb := 0
	if m, err := strconv.ParseFloat(strings.TrimSpace(string(mem)), 64); err == nil {
		gb = int(m / (1 << 30))
	}
	if b == "" {
		b = "unknown"
	}
	return fmt.Sprintf("%s-%dgb", b, gb)
}

// orNull keeps NaN (not measured for this model) out of JSON, which can't encode it.
func orNull(x float64) any {
	if math.IsNaN(x) {
		return nil
	}
	return x
}

func exists(p string) bool { _, err := os.Stat(p); return err == nil }

func fileSize(p string) int64 {
	if st, err := os.Stat(p); err == nil {
		return st.Size()
	}
	return 0
}

func run(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stderr = os.Stderr
	must(cmd.Run())
}

func must(err error) {
	if err != nil {
		var ee *exec.ExitError
		if errors.As(err, &ee) && len(ee.Stderr) > 0 {
			fail(string(ee.Stderr))
		}
		fail(err.Error())
	}
}

func fail(msg string) {
	fmt.Fprintln(os.Stderr, msg)
	os.Exit(1)
}
