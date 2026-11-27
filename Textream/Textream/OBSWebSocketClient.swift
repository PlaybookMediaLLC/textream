//
//  OBSWebSocketClient.swift
//  Dante for Creators
//
//  Zero-dependency OBS Studio WebSocket v5 client using URLSessionWebSocketTask.
//  Subscribes to RecordStateChanged events to auto-start/stop the teleprompter
//  in sync with OBS Studio recordings.
//

import Foundation
import Observation

@Observable
@MainActor
final class OBSWebSocketClient {
    private(set) var state: OBSConnectionState = .disconnected
    private(set) var isOBSRecording: Bool = false

    var onRecordingStarted: (() -> Void)?
    var onRecordingStopped: (() -> Void)?

    @ObservationIgnored private var webSocketTask: URLSessionWebSocketTask?
    @ObservationIgnored private var receiveLoopTask: Task<Void, Never>?
    @ObservationIgnored private var activeHost: String = "127.0.0.1"
    @ObservationIgnored private var activePassword: String = ""

    func connect(host: String, port: UInt16, password: String) {
        disconnect()

        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedHost = trimmedHost.isEmpty ? "127.0.0.1" : trimmedHost
        guard let url = URL(string: "ws://\(resolvedHost):\(port)") else {
            state = .error("Invalid OBS URL")
            return
        }

        activeHost = resolvedHost
        activePassword = password
        state = .connecting

        let task = URLSession.shared.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        receiveLoopTask = Task { @MainActor [weak self] in
            await self?.runReceiveLoop(task: task)
        }
    }

    func disconnect() {
        receiveLoopTask?.cancel()
        receiveLoopTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isOBSRecording = false
        state = .disconnected
    }

    private func runReceiveLoop(task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                let data: Data
                switch message {
                case .string(let text):
                    data = Data(text.utf8)
                case .data(let raw):
                    data = raw
                @unknown default:
                    continue
                }
                await handleMessage(data, on: task)
            } catch {
                if !Task.isCancelled && webSocketTask === task {
                    isOBSRecording = false
                    state = .error("Connection closed")
                    webSocketTask = nil
                }
                break
            }
        }
    }

    private func handleMessage(_ data: Data, on task: URLSessionWebSocketTask) async {
        guard let op = OBSWebSocketProtocol.parseOpcode(from: data) else { return }

        switch op {
        case 0: // Hello
            guard let hello = OBSWebSocketProtocol.parseHello(from: data) else { return }
            let authString: String?
            if let challenge = hello.challenge, let salt = hello.salt {
                authString = OBSWebSocketProtocol.computeAuthenticationString(
                    password: activePassword,
                    salt: salt,
                    challenge: challenge
                )
            } else {
                authString = nil
            }
            if let identifyData = OBSWebSocketProtocol.makeIdentifyPayload(
                rpcVersion: hello.rpcVersion,
                authentication: authString
            ), let text = String(data: identifyData, encoding: .utf8) {
                try? await task.send(.string(text))
            }

        case 2: // Identified
            state = .connected(activeHost)

        case 5: // Event
            guard let recordState = OBSWebSocketProtocol.parseRecordStateEvent(from: data) else {
                return
            }
            switch recordState {
            case .started:
                isOBSRecording = true
                onRecordingStarted?()
            case .stopped:
                isOBSRecording = false
                onRecordingStopped?()
            case .starting, .stopping, .paused, .resumed:
                break
            }

        default:
            break
        }
    }
}
