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

    var body: some View {
        // If you’re on iOS 16+, you can use NavigationStack instead of NavigationView
        NavigationView {
            VStack(spacing: 0) {                           // <- no Spacer at bottom
                // Header / controls
                VStack(spacing: 12) {
                    TextField("Start", text: $origin)
                        .textFieldStyle(.roundedBorder)
                    TextField("End", text: $destination)
                        .textFieldStyle(.roundedBorder)

                    Button("Get Directions (bike)") {
                        errorMsg = nil
                        APICalls.instance.getBikeDirections(origin: origin, destination: destination) { result in
                            DispatchQueue.main.async {
                                switch result {
                                case .success(let s): steps = s
                                case .failure(let e): errorMsg = e.localizedDescription
                                }
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    if let errorMsg {
                        Text(errorMsg)
                            .foregroundColor(.red)
                            .font(.footnote)
                    }
                }
                .padding()

                // List fills the rest, scrolls as needed
                List(steps) { s in
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
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("CyclAR")
        }
    }

    private func icon(for simple: String) -> String {
        switch simple {
        case "LEFT": return "⬅️"
        case "RIGHT": return "➡️"
        default: return "⬆️"
        }
    }
}

#Preview { ContentView() }
