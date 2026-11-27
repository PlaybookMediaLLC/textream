import SwiftUI

@main
struct TextreamiOSApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            debugRootView
            #else
            RootView(model: model)
                .preferredColorScheme(model.appAppearance.colorScheme)
            #endif
        }
    }

    #if DEBUG
    @ViewBuilder
    private var debugRootView: some View {
        let args = ProcessInfo.processInfo.arguments
        let schemeOverride: ColorScheme? = {
            if args.contains("-DanteThemeDark") { return .dark }
            if args.contains("-DanteThemeLight") { return .light }
            return model.appAppearance.colorScheme
        }()

        Group {
            if args.contains("-TextreamGalleryPreview") {
                SavedRecordingsGallery(store: Self.galleryPreviewStore())
            } else if args.contains("-TextreamSettingsPreview") {
                SettingsView(model: model)
            } else if args.contains("-TextreamPromptPreview") {
                PromptSessionView(configuration: Self.promptPreviewConfiguration())
                    .preferredColorScheme(.dark)
            } else if args.contains("-TextreamOuterDisplayPreview") {
                OuterDisplayPromptPreview(configuration: Self.promptPreviewConfiguration())
            } else if args.contains("-DanteLibraryPreview") {
                ScriptLibrarySheet(model: model)
            } else if args.contains("-DanteQuickComposerPreview") {
                QuickComposerSheet(model: model)
            } else if args.contains("-DanteStudioRemotePreview") {
                StudioRemoteView(
                    previewHostName: "Studio MacBook Pro",
                    previewState: StudioRemoteState(
                        highlightedCharCount: 186,
                        totalCharCount: 310,
                        isActive: true,
                        isDone: false,
                        isListening: true,
                        fontColor: "#ffffff",
                        cueColor: "#38bdf8",
                        lastSpokenText: "studio videos in a single take",
                        audioLevels: [0.3, 0.7, 0.5, 0.8],
                        pageIndex: 0,
                        pageCount: 3,
                        currentWPM: 152,
                        paceDeltaSeconds: 0,
                        elapsedSeconds: 74,
                        retakeCount: 1,
                        scriptTitle: "How I Shoot 4K Studio Videos",
                        scrollSpeed: 3.0
                    )
                )
            } else {
                RootView(model: model)
            }
        }
        .preferredColorScheme(schemeOverride)
        .onAppear {
            if args.contains("-DanteThemeDark") {
                model.appAppearance = .dark
                model.markOnboardingCompleted()
            } else if args.contains("-DanteThemeLight") {
                model.appAppearance = .light
                model.markOnboardingCompleted()
            }
            if args.contains("-DanteSeedDemoScripts") && model.scripts.count < 3 {
                let yt = model.createScriptFromTemplate(CreatorPreset.preset(for: .youtubeStudio))
                model.togglePin(scriptID: yt.id)
                let shorts = model.createScriptFromTemplate(CreatorPreset.preset(for: .shortsReels))
                model.togglePin(scriptID: shorts.id)
                _ = model.createScriptFromTemplate(CreatorPreset.preset(for: .podcastInterview))
                _ = model.createScriptFromTemplate(CreatorPreset.preset(for: .keynoteLive))
                model.selectScript(shorts)
            }
        }
    }
    #endif

    #if DEBUG
    @MainActor
    private static func galleryPreviewStore() -> SavedRecordingsStore {
        SavedRecordingsStore(
            previewRecordings: [
                previewRecording(id: "landscape", size: CGSize(width: 640, height: 360), color: .systemIndigo, subjectOffset: -0.16),
                previewRecording(id: "portrait", size: CGSize(width: 360, height: 640), color: .systemOrange, subjectOffset: 0.08),
                previewRecording(id: "square", size: CGSize(width: 480, height: 480), color: .systemTeal, subjectOffset: -0.08),
                previewRecording(id: "landscape-2", size: CGSize(width: 640, height: 360), color: .systemPink, subjectOffset: 0.18),
                previewRecording(id: "portrait-2", size: CGSize(width: 360, height: 640), color: .systemBlue, subjectOffset: -0.12),
                previewRecording(id: "square-2", size: CGSize(width: 480, height: 480), color: .systemPurple, subjectOffset: 0.14),
                previewRecording(id: "landscape-3", size: CGSize(width: 640, height: 360), color: .systemMint, subjectOffset: -0.20),
                previewRecording(id: "portrait-3", size: CGSize(width: 360, height: 640), color: .systemRed, subjectOffset: 0.04)
            ]
        )
    }

    @MainActor
    private static func previewRecording(
        id: String,
        size: CGSize,
        color: UIColor,
        subjectOffset: CGFloat
    ) -> SavedRecording {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cg = context.cgContext
            let bounds = CGRect(origin: .zero, size: size)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                color.withAlphaComponent(0.86).cgColor,
                color.withAlphaComponent(0.30).cgColor,
                UIColor.black.cgColor
            ] as CFArray
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 0.55, 1])!
            cg.drawLinearGradient(
                gradient,
                start: CGPoint(x: size.width * 0.15, y: 0),
                end: CGPoint(x: size.width * 0.85, y: size.height),
                options: []
            )

            // A softly lit studio backdrop gives the gallery a real-world feel
            // without tying App Store captures to a private camera recording.
            UIColor.white.withAlphaComponent(0.12).setFill()
            let window = CGRect(
                x: size.width * 0.08,
                y: size.height * 0.10,
                width: size.width * 0.34,
                height: size.height * 0.45
            )
            UIBezierPath(roundedRect: window, cornerRadius: min(size.width, size.height) * 0.025).fill()

            UIColor.white.withAlphaComponent(0.05).setFill()
            UIBezierPath(
                roundedRect: CGRect(
                    x: size.width * 0.64,
                    y: size.height * 0.14,
                    width: size.width * 0.25,
                    height: size.height * 0.25
                ),
                cornerRadius: min(size.width, size.height) * 0.04
            ).fill()

            let subjectX = size.width * (0.53 + subjectOffset)
            UIColor.black.withAlphaComponent(0.72).setFill()
            let headDiameter = min(size.width, size.height) * 0.24
            UIBezierPath(
                ovalIn: CGRect(
                    x: subjectX - headDiameter / 2,
                    y: size.height * 0.31,
                    width: headDiameter,
                    height: headDiameter
                )
            ).fill()
            UIBezierPath(
                ovalIn: CGRect(
                    x: subjectX - size.width * 0.27,
                    y: size.height * 0.52,
                    width: size.width * 0.54,
                    height: size.height * 0.62
                )
            ).fill()

            UIColor.white.withAlphaComponent(0.10).setStroke()
            cg.setLineWidth(min(size.width, size.height) * 0.012)
            cg.strokeEllipse(in: CGRect(
                x: subjectX - headDiameter / 2,
                y: size.height * 0.31,
                width: headDiameter,
                height: headDiameter
            ))

            UIColor.black.withAlphaComponent(0.18).setFill()
            cg.fill(CGRect(x: 0, y: size.height * 0.72, width: size.width, height: size.height * 0.28))
            cg.stroke(bounds.insetBy(dx: 0.5, dy: 0.5))
        }
        return SavedRecording(
            assetIdentifier: id,
            thumbnail: image,
            createdAt: .now.addingTimeInterval(TimeInterval(-3_600 * id.count)),
            duration: TimeInterval(5 + id.count * 9)
        )
    }

    private static func promptPreviewConfiguration() -> PromptSessionConfiguration {
        PromptSessionConfiguration(
            script: """
            Stay on script. Keep eye contact. [smile]

            Dante follows every word you say and keeps the last spoken line close to the camera.

            Read naturally, speak confidently, and never lose your place.
            """,
            sessionMode: .read,
            cameraEnabled: false,
            followMode: .classic,
            mirrorEnabled: true,
            mirrorAxis: .horizontal,
            readingPosition: .nearCamera,
            scrollSpeed: 0.5,
            fontFamily: .sans,
            fontSize: .lg,
            textColor: .white,
            cueColor: .blue,
            cueBrightness: .medium,
            overlayOpacity: 0.52,
            speechLocaleIdentifier: "en-US"
        )
    }
    #endif
}
