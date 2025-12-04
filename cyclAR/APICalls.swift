//
//  APICalls.swift
//  cyclAR
//
//  Created by Nandini Swami on 11/4/25.
//

import Foundation
import CoreLocation


enum APIError: Error { case invalidURL, noRoutes, network(String), parse }

final class APICalls {
    static let instance = APICalls()
        private init() {}

        private let apiKey = "-"
    
    // Addy to addy
    func getBikeDirections(origin: String, destination: String,
                                   completion: @escaping (Result<[DirectionStep], Error>) -> Void) {

                let url = URL(string: "https://routes.googleapis.com/directions/v2:computeRoutes")!
                
                // Request body for Routes API
                let body: [String: Any] = [
                    "origin": [
                        "address": origin
                    ],
                    "destination": [
                        "address": destination
                    ],
                    "travelMode": "BICYCLE",
                    // tells API what to return
                    "extraComputations": ["HTML_FORMATTED_NAVIGATION_INSTRUCTIONS"],
                    "languageCode": "en-US"
                ]

                // Encode body
                guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
                    completion(.failure(APIError.parse))
                    return
                }

                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = jsonData
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
                request.addValue(
                    "routes.legs.steps.navigationInstruction,routes.legs.steps.distanceMeters",
                    forHTTPHeaderField: "X-Goog-FieldMask"
                )


                let task = URLSession.shared.dataTask(with: request) { data, resp, err in
                    if let err = err { return completion(.failure(APIError.network(err.localizedDescription))) }
                    guard let data = data else { return completion(.failure(APIError.network("no data"))) }

                    do {
                        // Debug: print raw JSON
                        print(String(data: data, encoding: .utf8) ?? "no utf8")

                        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let routes = root["routes"] as? [[String: Any]],
                              let firstRoute = routes.first,
                              let legs = firstRoute["legs"] as? [[String: Any]],
                              let firstLeg = legs.first,
                              let steps = firstLeg["steps"] as? [[String: Any]] else {
                            return completion(.failure(APIError.noRoutes))
                        }

                        let mapped: [DirectionStep] = steps.compactMap { step in
                            let nav = step["navigationInstruction"] as? [String: Any]
                            let html = (nav?["instructions"] as? String) ?? ""
                            let plain = Self.stripHTML(html)

                            let maneuver = (nav?["maneuver"] as? String) ?? "STRAIGHT"
                            let simple = Self.reduceToLRS(from: maneuver, fallback: plain)

                            let meters = step["distanceMeters"] as? Double ?? 0
                            let distanceText = Self.formatDistance(meters)

                            return DirectionStep(
                                rawInstruction: plain,
                                maneuver: maneuver,
                                simple: simple,
                                distanceText: distanceText
                            )
                        }

                        completion(.success(mapped))
                    } catch {
                        completion(.failure(APIError.parse))
                    }
                }

                task.resume()
            }

    // LIVE
    func getBikeDirections(origin: CLLocationCoordinate2D,
                               destination: String,
                               completion: @escaping (Result<[DirectionStep], Error>) -> Void) {
            
            let url = URL(string: "https://routes.googleapis.com/directions/v2:computeRoutes")!

            let body: [String: Any] = [
                "origin": [
                    "location": [
                        "latLng": [
                            "latitude": origin.latitude,
                            "longitude": origin.longitude
                        ]
                    ]
                ],
                "destination": [
                    "address": destination
                ],
                "travelMode": "BICYCLE",
                "extraComputations": ["HTML_FORMATTED_NAVIGATION_INSTRUCTIONS"],
                "languageCode": "en-US"
            ]


            // Encode body
            guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
                completion(.failure(APIError.parse))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
            request.addValue(
                "routes.legs.steps.navigationInstruction,routes.legs.steps.distanceMeters",
                forHTTPHeaderField: "X-Goog-FieldMask"
            )


            let task = URLSession.shared.dataTask(with: request) { data, resp, err in
                if let err = err { return completion(.failure(APIError.network(err.localizedDescription))) }
                guard let data = data else { return completion(.failure(APIError.network("no data"))) }

                do {
                    // Debug: print raw JSON
                    print(String(data: data, encoding: .utf8) ?? "no utf8")

                    guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let routes = root["routes"] as? [[String: Any]],
                          let firstRoute = routes.first,
                          let legs = firstRoute["legs"] as? [[String: Any]],
                          let firstLeg = legs.first,
                          let steps = firstLeg["steps"] as? [[String: Any]] else {
                        return completion(.failure(APIError.noRoutes))
                    }

                    let mapped: [DirectionStep] = steps.compactMap { step in
                        let nav = step["navigationInstruction"] as? [String: Any]
                        let html = (nav?["instructions"] as? String) ?? ""
                        let plain = Self.stripHTML(html)

                        let maneuver = (nav?["maneuver"] as? String) ?? "STRAIGHT"
                        let simple = Self.reduceToLRS(from: maneuver, fallback: plain)

                        let meters = step["distanceMeters"] as? Double ?? 0
                        let distanceText = Self.formatDistance(meters)

                        return DirectionStep(
                            rawInstruction: plain,
                            maneuver: maneuver,
                            simple: simple,
                            distanceText: distanceText
                        )
                    }

                    completion(.success(mapped))
                } catch {
                    completion(.failure(APIError.parse))
                }
            }

            task.resume()
        }


    // Reduce Google maneuver to LEFT / RIGHT / STRAIGHT
    private static func reduceToLRS(from maneuver: String, fallback: String) -> String {
            let m = maneuver.lowercased()
            if m.contains("left") { return "LEFT" }
            if m.contains("right") { return "RIGHT" }
            let f = fallback.lowercased()
            if f.contains("left") { return "LEFT" }
            if f.contains("right") { return "RIGHT" }
            return "STRAIGHT"
        }

    // Very simple HTML stripper for html_instructions
    private static func stripHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
         .replacingOccurrences(of: "&nbsp;", with: " ")
         .replacingOccurrences(of: "&amp;", with: "&")
    }
    
    // formats distance from api call
    private static func formatDistance(_ meters: Double) -> String {
        let feet = meters * 3.28084
        if feet < 1000 {
            return "\(Int(feet)) ft"
        } else {
            let miles = feet / 5280
            return String(format: "%.1f mi", miles)
        }
    }
    
    func sendDataToESP32(message: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "http://10.103.207.13/command") else {
            return completion(.failure(APIError.invalidURL))
        }
        
        /// "http://10.0.0.121/command"
        // esp ip - 10.0.0.121

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // tells esp the data type
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = message.data(using: .utf8)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                        return completion(.failure(error))
                    }
                    
                    guard let data = data, let responseString = String(data: data, encoding: .utf8) else {
                        return completion(.failure(APIError.network("No data received")))
                    }
                    
                    completion(.success(responseString))
        }

        task.resume()
    }
}
