import SwiftUI

struct DirectionStep: Identifiable {
    let id = UUID()
    let rawInstruction: String
    let maneuver: String
    let simple: String
    let distanceText: String
}

struct ContentView: View {
    @State private var origin = "Houston Hall, Philadelphia"
    @State private var destination = "Penn Museum, Philadelphia"
    @State private var steps: [DirectionStep] = []
    @State private var errorMsg: String?
    @StateObject private var loc = LocationManager()
    @State private var liveMode = false
    @State private var navTimer: Timer?
    
    @State private var connectionStatus = "Not Connected"
    
    // --- VARIABLES FOR SIMULATION ---
        @State private var demoTimer: Timer?
        @State private var currentStepIndex = 0
        @State private var isSimulating = false
        // ------------------------------------

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // --- NEW TEST SECTION ---
                VStack {
                    Text("ESP32 IP: 10.103.207.13") // Reminding you of the IP
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                        
                Text("Status: \(connectionStatus)")
                    .font(.caption)
                    .foregroundColor(connectionStatus.contains("Success") ? .green : .gray)
                    .padding(.bottom, 5)
                    
                    Button("Turn left") {
                        sendLeft()
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
            
                    Button("Turn right") {
                        sendRight()
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                
                    Button("Go Straight") {
                        sendUp()
                    }
                    .buttonStyle(.bordered)
                    .tint(.green)
                }
                .padding(.bottom, 20)
                

                // Toggle Mode
                Toggle("Live Navigation", isOn: $liveMode)
                    .padding(.horizontal)
                    .onChange(of: liveMode) { isOn in
                            if !isOn {
                                navTimer?.invalidate()
                                navTimer = nil
                                errorMsg = nil
                            } else {
                                // Stop sim if live nav starts
                                stopSimulation()
                            }
                        }

                VStack(spacing: 12) {

                    // Show fields depending on mode
                    if liveMode == false {
                        TextField("Start", text: $origin)
                            .textFieldStyle(.roundedBorder)
                    }

                    TextField("Destination", text: $destination)
                        .textFieldStyle(.roundedBorder)

//                    Button(liveMode ? "Start Live Navigation" : "Get Route Preview") {
//                        if liveMode {
//                            startLiveNavigation()
//                        } else {
//                            previewRoute()
//                        }
//                    }
//                    .buttonStyle(.borderedProminent)
                    
                    // --- ACTION BUTTONS ---
                    HStack {
                        Button(liveMode ? "Start Live Navigation" : "Get Route Preview") {
                            if liveMode {
                                startLiveNavigation()
                            } else {
                                previewRoute()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSimulating) // Disable main button while simulating
                        
                        // --- SIMULATE BUTTON (Only in Preview Mode & has steps) ---
                        if !liveMode && !steps.isEmpty {
                            Button(isSimulating ? "Stop Sim" : "Send to Display") {
                                if isSimulating {
                                    stopSimulation()
                                } else {
                                    startSimulation()
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.purple)
                        }
                    }
                    
                    if let errorMsg {
                        Text(errorMsg)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
                .padding()

                // Steps List
                List(steps.indices, id: \.self) { idx in
                    let s = steps[idx]
                    HStack(alignment: .top) {
                        Text(icon(for: s.simple))
                            .font(.title2)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(s.simple).font(.headline)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.rawInstruction)
                                    .foregroundColor(.secondary)
                                    .font(.subheadline)

                                Text("→ in \(s.distanceText)")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                        Spacer()
                        
                        // Highlight the currently sending step during simulation
                        if isSimulating && idx == currentStepIndex {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .foregroundColor(.green)
                                .animateForever()
                        }
                    }
                    .listRowBackground(isSimulating && idx == currentStepIndex ? Color.green.opacity(0.1) : Color.clear)
                }
                .listStyle(.plain)
            }
            .navigationTitle("CyclAR")
        }
        .onDisappear {
            stopSimulation()
            navTimer?.invalidate()
        }
    }

    private func icon(for simple: String) -> String {
        switch simple {
        case "LEFT": return "⬅️"
        case "RIGHT": return "➡️"
        default: return "⬆️"
        }
    }

    // MARK: - Preview Route (Text Origin + Destination)
    func previewRoute() {
        APICalls.instance.getBikeDirections(origin: origin,
                                            destination: destination) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let newSteps):
                    errorMsg = nil
                    steps = newSteps
                case .failure(let e):
                    errorMsg = e.localizedDescription

                }
            }
        }
    }

    // MARK: - Live Navigation (GPS → Destination)
    func startLiveNavigation() {
        navTimer?.invalidate()
        
        navTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            guard let current = loc.current else {
                errorMsg = "Waiting for GPS..."
                return
            }

            APICalls.instance.getBikeDirections(origin: current,
                                                destination: destination) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let newSteps):
                        errorMsg = nil
                        steps = Array(newSteps.prefix(2))
                    case .failure(let e):
                        errorMsg = e.localizedDescription
                    }
                }
            }
        }
    }
    
    // MARK: - Manual Send Functions
        func sendLeft() {
            print("Button Pressed: Left")
            connectionStatus = "Sending Left..."
            APICalls.instance.sendDataToESP32(message: "left") { handleResult($0) }
        }
        
        func sendRight() {
            print("Button Pressed: Right")
            connectionStatus = "Sending Right..."
            APICalls.instance.sendDataToESP32(message: "right") { handleResult($0) }
        }
        
        func sendUp() {
            print("Button Pressed: Up")
            connectionStatus = "Sending Up..."
            APICalls.instance.sendDataToESP32(message: "up") { handleResult($0) }
        }
    
    // MARK: - Simulation Logic
        func startSimulation() {
            guard !steps.isEmpty else { return }
            
            print("Starting Simulation...")
            isSimulating = true
            currentStepIndex = 0 // Start from the beginning
            
            // 1. Send the very first step immediately
            sendCurrentStep()
            
            // 2. Schedule timer for subsequent steps (every 3 seconds)
            demoTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                // Move to next step
                currentStepIndex += 1
                
                if currentStepIndex < steps.count {
                    sendCurrentStep()
                } else {
                    // We reached the end
                    stopSimulation()
                    connectionStatus = "Simulation Complete"
                }
            }
        }
    
    func sendCurrentStep() {
            let step = steps[currentStepIndex]
            
            // --- ROBUST MAPPING LOGIC ---
            // The API returns "STRAIGHT", "DEPART", "NAME_CHANGE", "TURN_RIGHT", etc.
            // We need to map these to exactly what the ESP32 expects: "up", "left", "right"
            
            let direction = step.simple.lowercased()
            var commandToSend = "up" // Default to up (handles DEPART, STRAIGHT, NAME_CHANGE)
            
            if direction.contains("left") {
                commandToSend = "left"
            } else if direction.contains("right") {
                commandToSend = "right"
            }
            
            print("Simulating Step \(currentStepIndex) (\(step.simple)) -> Sending: \(commandToSend)")
            connectionStatus = "Simulating: \(commandToSend)..."
            
            APICalls.instance.sendDataToESP32(message: commandToSend) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let response):
                        connectionStatus = "Sent: \(commandToSend) (\(response))"
                    case .failure(let error):
                        connectionStatus = "Err: \(error.localizedDescription)"
                    }
                }
            }
        }
        
    
    func stopSimulation() {
            demoTimer?.invalidate()
            demoTimer = nil
            isSimulating = false
            print("Simulation Stopped")
        }
    
    
    func handleResult(_ result: Result<String, Error>) {
        DispatchQueue.main.async {
            switch result {
            case .success(let response):
                connectionStatus = "Success: \(response)"
            case .failure(let error):
                connectionStatus = "Error: \(error.localizedDescription)"
            }
        }
    }
}

// Simple animation helper for the radio icon
extension View {
    func animateForever() -> some View {
        self.modifier(PulsatingEffect())
    }
}

struct PulsatingEffect: ViewModifier {
    @State private var isOn = false
    func body(content: Content) -> some View {
        content
            .opacity(isOn ? 1 : 0.2)
            .animation(.easeInOut(duration: 0.8).repeatForever(), value: isOn)
            .onAppear { isOn = true }
    }
}


#Preview { ContentView() }
