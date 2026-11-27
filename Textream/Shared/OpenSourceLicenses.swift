//
//  OpenSourceLicenses.swift
//  Dante for Creators
//

import Foundation

struct OpenSourceLicenseEntry: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let licenseType: String
    let copyright: String
    let summary: String
    let fullText: String
    let urlString: String?
}

enum OpenSourceLicenseCatalog {
    static func entries(
        includeLocalSpeechModels: Bool,
        bundle: Bundle = .main
    ) -> [OpenSourceLicenseEntry] {
        var result: [OpenSourceLicenseEntry] = [
            OpenSourceLicenseEntry(
                id: "textream",
                name: "Textream",
                licenseType: "MIT License",
                copyright: "Copyright (c) 2026 Fatih Kadir Akin",
                summary: "Dante for Creators incorporates open-source teleprompter foundations from Textream (original concept by Semih Kışlar).",
                fullText: textreamMITLicense,
                urlString: "https://github.com/f/textream"
            ),
            OpenSourceLicenseEntry(
                id: "opendyslexic",
                name: "OpenDyslexic 3 Font",
                licenseType: "SIL Open Font License 1.1",
                copyright: "Copyright (c) 2011-2026 Abbie Gonzalez (OpenDyslexic)",
                summary: "Open-source typeface designed to increase readability for readers with dyslexia.",
                fullText: loadBundledText(resource: "OpenDyslexic-OFL", ext: "txt", bundle: bundle)
                    ?? openDyslexicFallbackLicense,
                urlString: "https://opendyslexic.org"
            )
        ]

        if includeLocalSpeechModels {
            result.append(
                OpenSourceLicenseEntry(
                    id: "transcribecpp",
                    name: "TranscribeCpp, ggml & miniz",
                    licenseType: "MIT License",
                    copyright: "Copyright (c) 2023-2026 The transcribe.cpp, ggml, and miniz authors",
                    summary: "On-device speech inference runtime, tensor compute backend, and compression utilities.",
                    fullText: loadBundledText(resource: "TranscribeCpp-Licenses", ext: "txt", bundle: bundle)
                        ?? transcribeCppFallbackLicense,
                    urlString: "https://github.com/handy-computer/transcribe.cpp"
                )
            )
            result.append(
                OpenSourceLicenseEntry(
                    id: "speech-models",
                    name: "Optional On-Device Speech Models",
                    licenseType: "Apache 2.0 · CC-BY-4.0 · MIT · OpenMDW-1.1",
                    copyright: "Respective upstream model authors (NVIDIA, Qwen, OpenAI, Mistral AI, Cohere, Useful Sensors, Handy)",
                    summary: "User-selected GGUF speech recognition models downloaded on demand from Hugging Face are governed by their respective open licenses.",
                    fullText: speechModelAttributionsText,
                    urlString: "https://huggingface.co/handy-computer"
                )
            )
        }

        return result
    }

    private static func loadBundledText(resource: String, ext: String, bundle: Bundle) -> String? {
        guard let url = bundle.url(forResource: resource, withExtension: ext),
              let text = try? String(contentsOf: url, encoding: .utf8),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return text
    }

    static let textreamMITLicense = """
    MIT License

    Copyright (c) 2026 Fatih Kadir Akin

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    """

    private static let openDyslexicFallbackLicense = """
    The OpenDyslexic font is distributed under the SIL Open Font License 1.1.
    Reserved Font Name: OpenDyslexic.
    """

    private static let transcribeCppFallbackLicense = """
    transcribe.cpp, ggml, and miniz are distributed under the MIT License.
    Copyright (c) 2026 The transcribe.cpp authors.
    Copyright (c) 2023-2026 The ggml authors.
    Copyright 2010-2014 Rich Geldreich, Tenacious Software LLC, RAD Game Tools, and Valve Software.
    """

    private static let speechModelAttributionsText = """
    Optional On-Device Speech Models (Downloaded on Demand)

    Dante for Creators does not bundle speech model weights inside the application binary. When you choose to download an optional local model on macOS, weights are fetched directly from public Hugging Face repositories and remain governed by their upstream licenses:

    • NVIDIA Nemotron 3.5 ASR Streaming 0.6B (nvidia/nemotron-3.5-asr-streaming-0.6b)
      License: OpenMDW-1.1 · GGUF conversion by handy-computer

    • NVIDIA Parakeet Unified EN 0.6B, Parakeet TDT 0.6B v3, Canary 180M Flash
      License: Creative Commons Attribution 4.0 International (CC-BY-4.0) · GGUF conversion by handy-computer

    • Qwen3-ASR 1.7B & Qwen3-ASR 0.6B (Qwen/Qwen3-ASR)
      License: Apache License 2.0 · GGUF conversion by handy-computer

    • OpenAI Whisper Family (Tiny, Base, Small, Medium, Large v3, Large v3 Turbo)
      License: Apache License 2.0 / MIT · GGUF conversion by handy-computer

    • Mistral Voxtral Mini 4B Realtime (mistralai/Voxtral-Mini-4B-Realtime-2602)
      License: Apache License 2.0 · GGUF conversion by handy-computer

    • Cohere Transcribe (CohereLabs/cohere-transcribe-03-2026)
      License: Apache License 2.0 · GGUF conversion by handy-computer

    • Useful Sensors Moonshine Streaming Small (UsefulSensors/moonshine-streaming-small)
      License: MIT License · GGUF conversion by handy-computer
    """
}
