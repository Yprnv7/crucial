import Foundation

public final class GeminiExplainerService: Sendable {
    public static let shared = GeminiExplainerService()

    private init() {}

    public var apiKey: String? {
        if let key = UserDefaults.standard.string(forKey: "crucial_gemini_api_key"), !key.isEmpty {
            return key
        }
        return ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
    }

    public func setApiKey(_ key: String) {
        UserDefaults.standard.set(key.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "crucial_gemini_api_key")
    }

    public func testConnection() async -> (success: Bool, message: String) {
        guard let key = apiKey, !key.isEmpty else {
            return (false, "No API key configured")
        }

        guard let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent?key=\(key)") else {
            return (false, "Invalid endpoint URL")
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "ping"]
                    ]
                ]
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return (false, "Invalid server response")
            }

            if httpResponse.statusCode == 200 {
                return (true, "Connected successfully! (Gemini 3.5 Flash Lite)")
            } else {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorObj = json["error"] as? [String: Any],
                   let msg = errorObj["message"] as? String {
                    return (false, "API Error (\(httpResponse.statusCode)): \(msg)")
                }
                return (false, "HTTP \(httpResponse.statusCode) response")
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }

    public func explain(item: FileItem) async -> VitalityAssessment {
        guard let key = apiKey, !key.isEmpty else {
            return item.assessment
        }

        let prompt = """
        You are Crucial, a macOS system utility AI analyzer. Analyze this file/directory and determine if it is Safe to Delete, Needs Review (Caution), or Vital/Protected.
        Path: \(item.path)
        Filename: \(item.name)
        Size: \(item.formattedSize)
        Is Directory: \(item.isDirectory)
        Days Since Last Access: \(item.daysSinceLastAccess)

        Respond in valid JSON with these exact keys:
        {
          "level": "Safe to Delete" | "Needs Review" | "Protected / Vital",
          "riskScore": (integer 0 to 100, where 0 is disposable junk and 100 is critical OS file),
          "summary": (brief 1-sentence description of what this is and what app created it),
          "impact": (clear explanation of what happens if the user deletes it),
          "canBeRebuilt": (boolean),
          "rebuildCommand": (string or null if can't be rebuilt)
        }
        """

        // Try gemini-flash-lite-latest (fastest & most reliable)
        let modelCandidates = ["gemini-flash-lite-latest", "gemini-flash-latest"]

        for model in modelCandidates {
            guard let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
                continue
            }

            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 12

            let requestBody: [String: Any] = [
                "contents": [
                    [
                        "parts": [
                            ["text": prompt]
                        ]
                    ]
                ],
                "generationConfig": [
                    "responseMimeType": "application/json"
                ]
            ]

            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    continue
                }

                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let firstCandidate = candidates.first,
                      let content = firstCandidate["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]],
                      let text = parts.first?["text"] as? String else {
                    continue
                }

                let cleanJsonString = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```", with: "")

                if let parsedData = cleanJsonString.data(using: .utf8),
                   let parsed = try? JSONSerialization.jsonObject(with: parsedData) as? [String: Any] {
                    let levelStr = parsed["level"] as? String ?? item.assessment.level.rawValue
                    let level: VitalityLevel
                    if levelStr.contains("Safe") {
                        level = .safeToDelete
                    } else if levelStr.contains("Vital") || levelStr.contains("Protected") {
                        level = .vital
                    } else {
                        level = .caution
                    }

                    let riskScore = parsed["riskScore"] as? Int ?? item.assessment.riskScore
                    let summary = parsed["summary"] as? String ?? item.assessment.summary
                    let impact = parsed["impact"] as? String ?? item.assessment.impact
                    let canRebuild = parsed["canBeRebuilt"] as? Bool ?? item.assessment.canBeRebuilt
                    let rebuildCmd = parsed["rebuildCommand"] as? String

                    return VitalityAssessment(
                        level: level,
                        riskScore: riskScore,
                        category: item.category,
                        summary: summary,
                        impact: impact,
                        canBeRebuilt: canRebuild,
                        rebuildCommand: rebuildCmd,
                        aiGenerated: true
                    )
                }
            } catch {
                continue
            }
        }

        return item.assessment
    }
}
