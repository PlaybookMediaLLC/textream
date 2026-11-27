//
//  StudioRemoteClient.swift
//  Dante for Creators (iOS / iPadOS)
//
//  Discovers nearby macOS Dante instances via Bonjour (_dante-director._tcp)
//  and connects over native Network.framework WebSocket for live telemetry
//  and hands-on studio remote control.
//

import Foundation
import Network
import Observation

struct DiscoveredStudioHost: Identifiable, Hashable, @unchecked Sendable {
    let id: String
    let name: String
    let endpoint: NWEndpoint
}

enum StudioRemoteConnectionState: Equatable, Sendable {
    case idle
    case connecting(String)
    case connected(String)
    case failed(String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var label: String {
        switch self {
        case .idle:              return "Not Connected"
        case .connecting(let n): return "Connecting to \(n)…"
        case .connected(let n):  return "Connected to \(n)"
        case .failed(let msg):   return msg
        }
    }
}

@Observable
@MainActor
final class StudioRemoteClient {
    private(set) var discoveredHosts: [DiscoveredStudioHost] = []
    private(set) var connectionState: StudioRemoteConnectionState = .idle
    private(set) var remoteState: StudioRemoteState?
    private(set) var isSearching = false

    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private var connection: NWConnection?
    @ObservationIgnored private var connectionGeneration: Int = 0
    @ObservationIgnored private var activeHostName: String = ""
    @ObservationIgnored private var activePairingPIN: String = ""

    func startDiscovery() {
        stopDiscovery()
        let descriptor = NWBrowser.Descriptor.bonjour(type: StudioBonjour.serviceType, domain: nil)
        let params = NWParameters()
        params.includePeerToPeer = true
        let newBrowser = NWBrowser(for: descriptor, using: params)
        browser = newBrowser
        isSearching = true

        newBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            let hosts: [DiscoveredStudioHost] = results.compactMap { result in
                guard case let .service(name, _, _, _) = result.endpoint else { return nil }
                return DiscoveredStudioHost(id: name, name: name, endpoint: result.endpoint)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            Task { @MainActor [weak self] in
                self?.discoveredHosts = hosts
            }
        }
        newBrowser.stateUpdateHandler = { [weak self] state in
            let failed: Bool
            if case .failed = state { failed = true } else { failed = false }
            Task { @MainActor [weak self] in
                if failed {
                    self?.isSearching = false
                }
            }
        }
        newBrowser.start(queue: .main)
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    func connect(to host: DiscoveredStudioHost, pairingPIN: String) {
        connect(endpoint: host.endpoint, displayName: host.name, pairingPIN: pairingPIN)
    }

    func connectManual(host: String, port: UInt16, pairingPIN: String) {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let nwPort = NWEndpoint.Port(rawValue: port) else {
            connectionState = .failed("Invalid host or port")
            return
        }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(trimmed), port: nwPort)
        connect(endpoint: endpoint, displayName: "\(trimmed):\(port)", pairingPIN: pairingPIN)
    }

    func disconnect() {
        connectionGeneration &+= 1
        connection?.cancel()
        connection = nil
        remoteState = nil
        connectionState = .idle
    }

    private func connect(endpoint: NWEndpoint, displayName: String, pairingPIN: String) {
        disconnect()
        let generation = connectionGeneration
        activeHostName = displayName
        activePairingPIN = pairingPIN.trimmingCharacters(in: .whitespacesAndNewlines)
        connectionState = .connecting(displayName)

        let params = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        let conn = NWConnection(to: endpoint, using: params)
        connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            let failureText: String?
            let isReady: Bool
            let isCancelled: Bool
            switch state {
            case .ready:
                isReady = true
                isCancelled = false
                failureText = nil
            case .failed(let error):
                isReady = false
                isCancelled = false
                failureText = error.localizedDescription
            case .cancelled:
                isReady = false
                isCancelled = true
                failureText = nil
            default:
                isReady = false
                isCancelled = false
                failureText = nil
            }
            Task { @MainActor [weak self] in
                guard let self, self.connectionGeneration == generation else { return }
                if isReady {
                    self.connectionState = .connected(displayName)
                    self.sendCommand(StudioRemoteCommand(action: .auth, text: self.activePairingPIN))
                    self.receiveNextMessage(generation: generation)
                } else if let failureText {
                    self.connectionState = .failed("Connection failed: \(failureText)")
                    self.connection = nil
                } else if isCancelled {
                    if case .connected = self.connectionState {
                        self.connectionState = .idle
                    }
                    self.connection = nil
                }
            }
        }
        conn.start(queue: .main)
    }

    private func receiveNextMessage(generation: Int) {
        guard let conn = connection, connectionGeneration == generation else { return }
        conn.receiveMessage { [weak self] data, _, _, error in
            let errorMessage = error?.localizedDescription
            Task { @MainActor [weak self] in
                guard let self, self.connectionGeneration == generation else { return }
                if let errorMessage {
                    self.connectionState = .failed("Disconnected: \(errorMessage)")
                    self.connection?.cancel()
                    self.connection = nil
                    return
                }
                if let data, let decoded = try? JSONDecoder().decode(StudioRemoteState.self, from: data) {
                    self.remoteState = decoded
                }
                self.receiveNextMessage(generation: generation)
            }
        }
    }

    func sendCommand(_ command: StudioRemoteCommand) {
        guard let conn = connection,
              let data = try? JSONEncoder().encode(command) else { return }
        let meta = NWProtocolWebSocket.Metadata(opcode: .text)
        let ctx = NWConnection.ContentContext(identifier: "ws", metadata: [meta])
        conn.send(content: data, contentContext: ctx, completion: .idempotent)
    }

    // MARK: - Studio Transport Actions

    func toggleListening() {
        sendCommand(StudioRemoteCommand(action: .toggleListening))
    }

    func rewindSentence() {
        sendCommand(StudioRemoteCommand(action: .rewindSentence))
    }

    func nextPage() {
        sendCommand(StudioRemoteCommand(action: .nextPage))
    }

    func previousPage() {
        sendCommand(StudioRemoteCommand(action: .previousPage))
    }

    func adjustSpeed(delta: Double) {
        sendCommand(StudioRemoteCommand(action: .adjustSpeed, delta: delta))
    }

    func dropMarker(label: String = "Remote Marker") {
        sendCommand(StudioRemoteCommand(action: .dropMarker, label: label))
    }

    func stopSession() {
        sendCommand(StudioRemoteCommand(action: .stop))
    }
}
