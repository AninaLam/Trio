import Foundation
import LoopKit
import SwiftUI
import Swinject

extension PumpConfig {
    struct RootView: BaseView {
        let resolver: Resolver
        let displayClose: Bool
        let bluetoothManager: BluetoothStateManager
        @StateObject var state = StateModel()
        @State private var shouldDisplayHint: Bool = false
        @State var hintDetent = PresentationDetent.large
        @State var selectedVerboseHint: AnyView?
        @State var hintLabel: String?
        @State private var decimalPlaceholder: Decimal = 0.0
        @State private var booleanPlaceholder: Bool = false
        @State var showPumpSelection: Bool = false
        @State private var bluetoothAuthorization: BluetoothAuthorization

        @Environment(\.colorScheme) var colorScheme
        @Environment(AppState.self) var appState

        init(resolver: Resolver, displayClose: Bool, bluetoothManager: BluetoothStateManager) {
            self.resolver = resolver
            self.displayClose = displayClose
            self.bluetoothManager = bluetoothManager
            _bluetoothAuthorization = State(initialValue: bluetoothManager.bluetoothAuthorization)
        }

        var body: some View {
            NavigationView {
                Form {
                    Section(
                        header: Text("Pump Integration to Trio"),
                        content: {
                            if bluetoothAuthorization != .authorized {
                                HStack {
                                    Spacer()
                                    BluetoothRequiredView(bluetoothManager: bluetoothManager) { authorization in
                                        bluetoothAuthorization = authorization
                                    }
                                    Spacer()
                                }
                            } else if let pumpState = state.pumpState {
                                Button {
                                    state.setupPump = true
                                } label: {
                                    HStack {
                                        Image(uiImage: pumpState.image ?? UIImage())
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: 100)
                                        Text(pumpState.name)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 50, alignment: .center)
                                    .font(.title2)
                                }.padding()
                                if state.hasUnacknowledgedAlert {
                                    Spacer()
                                    Button("Acknowledge all alerts") { state.ack() }
                                }
                            } else {
                                VStack {
                                    Button {
                                        showPumpSelection.toggle()
                                    } label: {
                                        Text("Add Pump")
                                            .font(.title3) }
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .buttonStyle(.bordered)

                                    HStack(alignment: .center) {
                                        Text(
                                            "Pair your insulin pump with Trio. See hint for compatible devices."
                                        )
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .lineLimit(nil)
                                        Spacer()
                                        Button(
                                            action: {
                                                shouldDisplayHint.toggle()
                                            },
                                            label: {
                                                HStack {
                                                    Image(systemName: "questionmark.circle")
                                                }
                                            }
                                        ).buttonStyle(BorderlessButtonStyle())
                                    }.padding(.top)
                                }.padding(.vertical)
                            }
                        }
                    )
                    .listRowBackground(Color.chart)
                }
                .scrollContentBackground(.hidden).background(appState.trioBackgroundColor(for: colorScheme))
                .onAppear {
                    bluetoothAuthorization = bluetoothManager.bluetoothAuthorization
                    configureView()
                }
                .onReceive(
                    Foundation.NotificationCenter.default
                        .publisher(for: UIApplication.willEnterForegroundNotification)
                ) { _ in
                    bluetoothAuthorization = bluetoothManager.bluetoothAuthorization
                }
                .navigationTitle("Insulin Pump")
                .navigationBarTitleDisplayMode(.automatic)
                .navigationBarItems(leading: displayClose ? Button("Close", action: state.hideModal) : nil)
                .sheet(isPresented: $state.setupPump) {
                    if let pumpManager = state.provider.apsManager.pumpManager {
                        PumpSettingsView(
                            pumpManager: pumpManager,
                            bluetoothManager: state.provider.apsManager.bluetoothManager!,
                            completionDelegate: state,
                            setupDelegate: state
                        )
                    } else {
                        PumpSetupView(
                            pumpType: state.setupPumpType,
                            pumpInitialSettings: state.initialSettings,
                            bluetoothManager: state.provider.apsManager.bluetoothManager!,
                            completionDelegate: state,
                            setupDelegate: state
                        )
                    }
                }
                .sheet(isPresented: $shouldDisplayHint) {
                    SettingInputHintView(
                        hintDetent: $hintDetent,
                        shouldDisplayHint: $shouldDisplayHint,
                        hintLabel: "Pump Pairing to Trio",
                        hintText: AnyView(
                            VStack(alignment: .leading, spacing: 10) {
                                Text(
                                    "Current Pump Models Supported:"
                                )
                                VStack(alignment: .leading) {
                                    Text("• Medtronic")
                                    Text("• Omnipod Eros")
                                    Text("• Omnipod DASH")
                                    Text("• Dana (RS/-i)")
                                    Text("• Medtrum Nano (200u/300u)")
                                    Text("• Pump Simulator")
                                }
                                Text(
                                    "Note: If using a pump simulator, you will not have continuous readings from the CGM in Trio. Using a pump simulator is only advisable for becoming familiar with the app user interface. It will not give you insight on how the algorithm will respond."
                                )
                            }
                        ),
                        sheetTitle: String(localized: "Help", comment: "Help sheet title")
                    )
                }
                .confirmationDialog("Pump Model", isPresented: $showPumpSelection) {
                    Button("Medtronic") { state.addPump(.minimed) }
                    Button("Omnipod Eros") { state.addPump(.omnipod) }
                    Button("Omnipod DASH") { state.addPump(.omnipodBLE) }
                    Button("Dana(RS/-i)") { state.addPump(.dana) }
                    Button("Medtrum Nano") { state.addPump(.medtrum) }
                    Button("Pump Simulator") { state.addPump(.simulator) }
                } message: { Text("Select Pump Model") }
            }
        }
    }
}
