//
//  StudioIntegrationsTests.swift
//  TextreamTests
//
//  Unit tests for Phase 5: StudioRemoteProtocol wire encoding/decoding & legacy
//  compatibility, StudioControlBindings key/clicker/foot-pedal mappings, and
//  OBS WebSocket v5 SHA-256 authentication + RecordStateChanged event parsing.
//

import XCTest
@testable import Textream

final class StudioIntegrationsTests: XCTestCase {

    func testStudioRemoteCommandAndStateRoundTripAndLegacyCompatibility() throws {
        let command = StudioRemoteCommand(
            action: .adjustSpeed,
            delta: 0.5,
            label: "Boost"
        )
        let cmdData = try JSONEncoder().encode(command)
        let decodedCmd = try JSONDecoder().decode(StudioRemoteCommand.self, from: cmdData)
        XCTAssertEqual(decodedCmd, command)
        XCTAssertEqual(decodedCmd.action, .adjustSpeed)
        XCTAssertEqual(decodedCmd.delta, 0.5)

        let state = StudioRemoteState(
            highlightedCharCount: 120,
            totalCharCount: 240,
            isActive: true,
            isDone: false,
            isListening: true,
            fontColor: "#ffffff",
            cueColor: "#38bdf8",
            lastSpokenText: "hello world",
            audioLevels: [0.2, 0.5],
            pageIndex: 1,
            pageCount: 4,
            currentWPM: 152,
            paceDeltaSeconds: -2,
            elapsedSeconds: 45,
            retakeCount: 1,
            scriptTitle: "Product Launch",
            scrollSpeed: 3.5
        )
        let stateData = try JSONEncoder().encode(state)
        let decodedState = try JSONDecoder().decode(StudioRemoteState.self, from: stateData)
        XCTAssertEqual(decodedState, state)
        XCTAssertEqual(decodedState.progress, 0.5, accuracy: 0.001)

        // Legacy DirectorState JSON (without extended Pro Studio fields) decodes cleanly
        let legacyJSON = """
        {
          "highlightedCharCount": 50,
          "totalCharCount": 100,
          "isActive": true,
          "isDone": false,
          "isListening": true,
          "fontColor": "#ffffff",
          "cueColor": "#ffffff",
          "lastSpokenText": "hello",
          "audioLevels": [0.1]
        }
        """
        let decodedLegacy = try JSONDecoder().decode(StudioRemoteState.self, from: Data(legacyJSON.utf8))
        XCTAssertEqual(decodedLegacy.highlightedCharCount, 50)
        XCTAssertEqual(decodedLegacy.progress, 0.5, accuracy: 0.001)
        XCTAssertNil(decodedLegacy.currentWPM)
        XCTAssertNil(decodedLegacy.scriptTitle)
    }

    func testStudioControlBindingsDefaultClickerAndFootPedalMappingsAndPersistence() {
        let bindings = StudioControlBindings()
        XCTAssertEqual(bindings.action(forKeyCode: 49), .togglePause)    // Space
        XCTAssertEqual(bindings.action(forKeyCode: 123), .rewindSentence) // Left arrow
        XCTAssertEqual(bindings.action(forKeyCode: 121), .nextPage)       // Page Down (clicker)
        XCTAssertEqual(bindings.action(forKeyCode: 116), .previousPage)   // Page Up (clicker)
        XCTAssertEqual(bindings.action(forKeyCode: 105), .togglePause)    // F13 (foot pedal 1)
        XCTAssertEqual(bindings.action(forKeyCode: 107), .rewindSentence) // F14 (foot pedal 2)
        XCTAssertEqual(bindings.action(forKeyCode: 113), .dropMarker)     // F15 (foot pedal 3)
        XCTAssertEqual(bindings.action(forKeyCode: 46), .dropMarker)      // M key
        XCTAssertEqual(bindings.action(forKeyCode: 53), .stop)            // Esc

        // Custom override persists cleanly to UserDefaults
        let suiteName = "StudioIntegrationsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var custom = StudioControlBindings()
        custom.bind(keyCode: 99, to: .dropMarker)
        custom.bind(keyCode: 49, to: nil)
        custom.save(to: defaults)

        let reloaded = StudioControlBindings.load(from: defaults)
        XCTAssertEqual(reloaded.action(forKeyCode: 99), .dropMarker)
        XCTAssertNil(reloaded.action(forKeyCode: 49))
    }

    func testOBSWebSocketV5AuthenticationVectorAndEventParsing() throws {
        // Official OBS WebSocket v5 specification test vector
        let auth = OBSWebSocketProtocol.computeAuthenticationString(
            password: "supersecretpassword",
            salt: "lM1GncleQOaCu9lT1yeUZhFYnqhsLLP1G5lAGo3ixaI=",
            challenge: "+IxH4CnCiqpX1rM9scsNynZzbOe4KhDeYcTNS3PDaeY="
        )
        XCTAssertEqual(auth, "1Ct943GAT+6YQUUX47Ia/ncufilbe6+oD6lY+5kaCu4=")

        // Hello payload parsing (op 0)
        let helloJSON = """
        {
          "op": 0,
          "d": {
            "obsWebSocketVersion": "5.3.0",
            "rpcVersion": 1,
            "authentication": {
              "challenge": "+IxH4CnCiqpX1rM9scsNynZzbOe4KhDeYcTNS3PDaeY=",
              "salt": "lM1GncleQOaCu9lT1yeUZhFYnqhsLLP1G5lAGo3ixaI="
            }
          }
        }
        """
        let hello = OBSWebSocketProtocol.parseHello(from: Data(helloJSON.utf8))
        XCTAssertEqual(hello?.rpcVersion, 1)
        XCTAssertEqual(hello?.challenge, "+IxH4CnCiqpX1rM9scsNynZzbOe4KhDeYcTNS3PDaeY=")
        XCTAssertEqual(hello?.salt, "lM1GncleQOaCu9lT1yeUZhFYnqhsLLP1G5lAGo3ixaI=")

        // Identify payload builder (op 1)
        let identifyData = try XCTUnwrap(
            OBSWebSocketProtocol.makeIdentifyPayload(rpcVersion: 1, authentication: auth)
        )
        let identifyObj = try XCTUnwrap(
            JSONSerialization.jsonObject(with: identifyData) as? [String: Any]
        )
        XCTAssertEqual(identifyObj["op"] as? Int, 1)
        let identifyD = try XCTUnwrap(identifyObj["d"] as? [String: Any])
        XCTAssertEqual(identifyD["authentication"] as? String, auth)
        XCTAssertEqual(identifyD["eventSubscriptions"] as? Int, 64)

        // RecordStateChanged events (op 5)
        let startedEvent = """
        {
          "op": 5,
          "d": {
            "eventType": "RecordStateChanged",
            "eventData": {
              "outputActive": true,
              "outputState": "OBS_WEBSOCKET_OUTPUT_STARTED"
            }
          }
        }
        """
        XCTAssertEqual(
            OBSWebSocketProtocol.parseRecordStateEvent(from: Data(startedEvent.utf8)),
            .started
        )

        let stoppedEvent = """
        {
          "op": 5,
          "d": {
            "eventType": "RecordStateChanged",
            "eventData": {
              "outputActive": false,
              "outputState": "OBS_WEBSOCKET_OUTPUT_STOPPED"
            }
          }
        }
        """
        XCTAssertEqual(
            OBSWebSocketProtocol.parseRecordStateEvent(from: Data(stoppedEvent.utf8)),
            .stopped
        )

        let unrelatedEvent = """
        {
          "op": 5,
          "d": {
            "eventType": "CurrentProgramSceneChanged",
            "eventData": { "sceneName": "Camera A" }
          }
        }
        """
        XCTAssertNil(OBSWebSocketProtocol.parseRecordStateEvent(from: Data(unrelatedEvent.utf8)))
    }
}
