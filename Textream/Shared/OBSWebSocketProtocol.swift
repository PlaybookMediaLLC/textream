//
//  OBSWebSocketProtocol.swift
//  Dante for Creators
//
//  Zero-dependency OBS WebSocket v5 protocol helpers (SHA-256 challenge/salt
//  authentication, Identify payload builder, and RecordStateChanged parser).
//

import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

enum OBSConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected(String)
    case error(String)

    var label: String {
        switch self {
        case .disconnected:     return "Disconnected"
        case .connecting:       return "Connecting…"
        case .connected(let h): return "Connected (\(h))"
        case .error(let msg):   return msg
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }
}

enum OBSRecordOutputState: String, Equatable, Sendable {
    case starting = "OBS_WEBSOCKET_OUTPUT_STARTING"
    case started  = "OBS_WEBSOCKET_OUTPUT_STARTED"
    case stopping = "OBS_WEBSOCKET_OUTPUT_STOPPING"
    case stopped  = "OBS_WEBSOCKET_OUTPUT_STOPPED"
    case paused   = "OBS_WEBSOCKET_OUTPUT_PAUSED"
    case resumed  = "OBS_WEBSOCKET_OUTPUT_RESUMED"
}

struct OBSHelloInfo: Equatable, Sendable {
    let rpcVersion: Int
    let challenge: String?
    let salt: String?
}

enum OBSWebSocketProtocol {
    /// OBS WebSocket v5 EventSubscription bitmask for `Outputs` (`1 << 6 = 64`),
    /// which delivers `RecordStateChanged` events with minimal noise.
    static let outputsEventSubscription = 64

    /// Computes the OBS WebSocket v5 authentication string:
    /// 1. secret = Base64(SHA256(password + salt))
    /// 2. auth   = Base64(SHA256(secret + challenge))
    static func computeAuthenticationString(
        password: String,
        salt: String,
        challenge: String
    ) -> String {
        #if canImport(CryptoKit)
        let firstInput = Data((password + salt).utf8)
        let secretDigest = SHA256.hash(data: firstInput)
        let secretBase64 = Data(secretDigest).base64EncodedString()

        let secondInput = Data((secretBase64 + challenge).utf8)
        let authDigest = SHA256.hash(data: secondInput)
        return Data(authDigest).base64EncodedString()
        #else
        return ""
        #endif
    }

    static func parseOpcode(from data: Data) -> Int? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object["op"] as? Int
    }

    static func parseHello(from data: Data) -> OBSHelloInfo? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (object["op"] as? Int) == 0,
              let d = object["d"] as? [String: Any] else {
            return nil
        }
        let rpcVersion = d["rpcVersion"] as? Int ?? 1
        let auth = d["authentication"] as? [String: Any]
        let challenge = auth?["challenge"] as? String
        let salt = auth?["salt"] as? String
        return OBSHelloInfo(rpcVersion: rpcVersion, challenge: challenge, salt: salt)
    }

    static func makeIdentifyPayload(
        rpcVersion: Int = 1,
        authentication: String? = nil,
        eventSubscriptions: Int = outputsEventSubscription
    ) -> Data? {
        var d: [String: Any] = [
            "rpcVersion": rpcVersion,
            "eventSubscriptions": eventSubscriptions
        ]
        if let authentication, !authentication.isEmpty {
            d["authentication"] = authentication
        }
        let message: [String: Any] = [
            "op": 1,
            "d": d
        ]
        return try? JSONSerialization.data(withJSONObject: message, options: [.sortedKeys])
    }

    static func parseRecordStateEvent(from data: Data) -> OBSRecordOutputState? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (object["op"] as? Int) == 5,
              let d = object["d"] as? [String: Any],
              (d["eventType"] as? String) == "RecordStateChanged",
              let eventData = d["eventData"] as? [String: Any],
              let stateString = eventData["outputState"] as? String else {
            return nil
        }
        return OBSRecordOutputState(rawValue: stateString)
    }
}
