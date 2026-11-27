//
//  HardwareControlBridge.swift
//  Dante for Creators
//
//  Cross-platform (macOS + iOS/iPadOS) GameController bridge for Bluetooth
//  foot pedals, studio remote clickers, and controllers.
//

import Foundation
#if canImport(GameController)
import GameController
#endif

@MainActor
final class HardwareControlBridge {
    var onAction: ((StudioKeyAction) -> Void)?
    private(set) var connectedControllerNames: [String] = []
    private var isStarted = false
    private var observers: [NSObjectProtocol] = []

    nonisolated init() {}

    func start() {
        guard !isStarted else { return }
        isStarted = true

        #if canImport(GameController)
        let center = NotificationCenter.default
        let connectObs = center.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshControllers()
            }
        }
        let disconnectObs = center.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshControllers()
            }
        }
        observers = [connectObs, disconnectObs]
        refreshControllers()
        #endif
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false

        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()

        #if canImport(GameController)
        for controller in GCController.controllers() {
            clearHandlers(on: controller)
        }
        #endif
        connectedControllerNames.removeAll()
    }

    #if canImport(GameController)
    private func refreshControllers() {
        let controllers = GCController.controllers()
        connectedControllerNames = controllers.map { $0.vendorName ?? "Studio Controller" }
        for controller in controllers {
            attachHandlers(to: controller)
        }
    }

    private func attachHandlers(to controller: GCController) {
        if let pad = controller.extendedGamepad {
            pad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor [weak self] in self?.emit(.togglePause) }
            }
            pad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor [weak self] in self?.emit(.rewindSentence) }
            }
            pad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor [weak self] in self?.emit(.dropMarker) }
            }
            pad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor [weak self] in self?.emit(.previousPage) }
            }
            pad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor [weak self] in self?.emit(.nextPage) }
            }
            pad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor [weak self] in self?.emit(.rewindSentence) }
            }
            pad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor [weak self] in self?.emit(.nextPage) }
            }
            pad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor [weak self] in self?.emit(.speedUp) }
            }
            pad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor [weak self] in self?.emit(.speedDown) }
            }
        } else if let micro = controller.microGamepad {
            micro.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor [weak self] in self?.emit(.togglePause) }
            }
            micro.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
                guard pressed else { return }
                Task { @MainActor [weak self] in self?.emit(.rewindSentence) }
            }
        }
    }

    private func clearHandlers(on controller: GCController) {
        if let pad = controller.extendedGamepad {
            pad.buttonA.pressedChangedHandler = nil
            pad.buttonB.pressedChangedHandler = nil
            pad.buttonX.pressedChangedHandler = nil
            pad.leftShoulder.pressedChangedHandler = nil
            pad.rightShoulder.pressedChangedHandler = nil
            pad.dpad.left.pressedChangedHandler = nil
            pad.dpad.right.pressedChangedHandler = nil
            pad.dpad.up.pressedChangedHandler = nil
            pad.dpad.down.pressedChangedHandler = nil
        }
        if let micro = controller.microGamepad {
            micro.buttonA.pressedChangedHandler = nil
            micro.buttonX.pressedChangedHandler = nil
        }
    }
    #endif

    private func emit(_ action: StudioKeyAction) {
        onAction?(action)
    }
}
