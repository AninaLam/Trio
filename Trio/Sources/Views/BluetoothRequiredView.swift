//
//  BluetoothRequiredView.swift
//  Trio
//
//  Created by Cengiz Deniz on 27.04.25.
//
import LoopKit
import SwiftUI

public struct BluetoothRequiredView: View {
    let bluetoothManager: BluetoothStateManager
    let onAuthorizationChanged: ((BluetoothAuthorization) -> Void)?

    @State private var isRequestingAuthorization = false

    init(
        bluetoothManager: BluetoothStateManager,
        onAuthorizationChanged: ((BluetoothAuthorization) -> Void)? = nil
    ) {
        self.bluetoothManager = bluetoothManager
        self.onAuthorizationChanged = onAuthorizationChanged
    }

    private var subtitle: String {
        switch bluetoothManager.bluetoothAuthorization {
        case .notDetermined:
            "Tap to Allow Bluetooth for Trio"
        case .authorized:
            "Bluetooth access is enabled"
        case .denied,
             .restricted:
            "Tap to Enable Bluetooth in iOS Settings"
        }
    }

    public var body: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack {
                Image("logo.bluetooth.capsule.portrait.fill")
                    .foregroundStyle(Color.red)
                Text("Bluetooth Required")
            }
            .font(.headline.bold())
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .overlay(
                Capsule()
                    .stroke(Color.red.opacity(0.75), lineWidth: 2)
            )

            Text(subtitle)
                .font(.subheadline.bold())
                .foregroundStyle(Color.primary.opacity(0.8))
        }
        .onTapGesture {
            requestBluetoothAuthorization()
        }
    }

    private func requestBluetoothAuthorization() {
        let authorization = bluetoothManager.bluetoothAuthorization

        guard authorization != .authorized else {
            onAuthorizationChanged?(.authorized)
            return
        }

        if authorization == .notDetermined, !isRequestingAuthorization {
            isRequestingAuthorization = true
            bluetoothManager.authorizeBluetooth { updatedAuthorization in
                DispatchQueue.main.async {
                    isRequestingAuthorization = false
                    onAuthorizationChanged?(updatedAuthorization)
                    if updatedAuthorization != .authorized {
                        openSettings()
                    }
                }
            }
        } else {
            openSettings()
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(url)
    }
}
