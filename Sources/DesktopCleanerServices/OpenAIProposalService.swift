import DesktopCleanerCore
import Foundation

public protocol AIProposalServicing: Sendable {
    func hasAPIKey() async throws -> Bool
    func saveAPIKey(_ key: String) async throws
    func deleteAPIKey() async throws
    func testConnection() async throws
    func proposeMetadata(
        for items: [ScannedItem],
        quality: AIQualityPreference,
        responseLanguage: String
    ) async throws -> [AIProposal]
}

public enum OpenAIServiceError: Error, Equatable {
    case missingAPIKey
    case invalidResponse
    case refusal(String)
    case requestFailed(statusCode: Int, message: String)
}

extension OpenAIServiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: "No OpenAI API key is stored."
        case .invalidResponse: "OpenAI returned an unreadable response. The local plan was preserved."
        case .refusal(let message): "OpenAI declined the request: \(message)"
        case .requestFailed(let statusCode, let message): "OpenAI request failed (\(statusCode)): \(message)"
        }
    }
}

public struct AIMetadataItem: Codable, Equatable, Sendable {
    public let id: UUID
    public let filename: String
    public let pathExtension: String
    public let typeIdentifier: String?
    public let sizeRange: String
    public let createdAt: Date?
    public let modifiedAt: Date?

    public init(item: ScannedItem) {
        id = item.id
        filename = item.filename
        pathExtension = item.pathExtension
        typeIdentifier = item.typeIdentifier
        sizeRange = Self.range(for: item.size)
        createdAt = item.creationDate
        modifiedAt = item.modificationDate
    }

    private static func range(for size: Int64) -> String {
        switch size {
        case ..<10_000: "under_10_kb"
        case ..<1_000_000: "10_kb_to_1_mb"
        case ..<100_000_000: "1_mb_to_100_mb"
        default: "over_100_mb"
        }
    }
}

public struct OpenAIRequestBuilder: Sendable {
    public let model: String

    public init(model: String = "gpt-5.6-luna") {
        self.model = model
    }

    public func makeMetadataRequest(
        items: [ScannedItem],
        quality: AIQualityPreference = .fast,
        responseLanguage: String = "English"
    ) throws -> URLRequest {
        let metadata = items.map(AIMetadataItem.init)
        let payload: [String: Any] = [
            "model": model,
            "store": false,
            "reasoning": ["effort": quality.reasoningEffort],
            "instructions": "Classify file metadata and suggest concise basenames. suggestedBasename must exclude the file extension. Never invent extensions, paths, commands, deletion actions, or approval decisions. Return one item for every supplied id. Write each reason in \(responseLanguage).",
            "input": try metadataJSONObject(metadata),
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "desktop_cleaner_proposals",
                    "strict": true,
                    "schema": Self.responseSchema
                ]
            ]
        ]
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 45
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return request
    }

    private func metadataJSONObject(_ metadata: [AIMetadataItem]) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(["items": metadata])
        return String(decoding: data, as: UTF8.self)
    }

    private static var responseSchema: [String: Any] { [
        "type": "object",
        "additionalProperties": false,
        "properties": [
            "items": [
                "type": "array",
                "items": [
                    "type": "object",
                    "additionalProperties": false,
                    "properties": [
                        "id": ["type": "string"],
                        "category": ["type": "string", "enum": ItemCategory.allCases.map(\.rawValue)],
                        "suggestedBasename": ["type": "string"],
                        "confidence": ["type": "string", "enum": ["high", "medium", "low"]],
                        "reason": ["type": "string"],
                        "warnings": ["type": "array", "items": ["type": "string"]]
                    ],
                    "required": ["id", "category", "suggestedBasename", "confidence", "reason", "warnings"]
                ]
            ]
        ],
        "required": ["items"]
    ] }
}

public actor OpenAIProposalService: AIProposalServicing {
    private let keyStore: any APIKeyStoring
    private let session: URLSession
    private let requestBuilder: OpenAIRequestBuilder
    private let validator: AIProposalValidator

    public init(
        keyStore: any APIKeyStoring = KeychainStore(),
        session: URLSession = .shared,
        requestBuilder: OpenAIRequestBuilder = OpenAIRequestBuilder(),
        validator: AIProposalValidator = AIProposalValidator()
    ) {
        self.keyStore = keyStore
        self.session = session
        self.requestBuilder = requestBuilder
        self.validator = validator
    }

    public func hasAPIKey() async throws -> Bool {
        try await keyStore.loadAPIKey() != nil
    }

    public func saveAPIKey(_ key: String) async throws {
        try await keyStore.saveAPIKey(key)
    }

    public func deleteAPIKey() async throws {
        try await keyStore.deleteAPIKey()
    }

    public func testConnection() async throws {
        guard let key = try await keyStore.loadAPIKey() else { throw OpenAIServiceError.missingAPIKey }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models/\(requestBuilder.model)")!)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 20
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OpenAIServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw OpenAIServiceError.requestFailed(statusCode: http.statusCode, message: "Connection test failed")
        }
    }

    public func proposeMetadata(
        for items: [ScannedItem],
        quality: AIQualityPreference = .fast,
        responseLanguage: String = "English"
    ) async throws -> [AIProposal] {
        guard let key = try await keyStore.loadAPIKey() else { throw OpenAIServiceError.missingAPIKey }
        var request = try requestBuilder.makeMetadataRequest(
            items: items,
            quality: quality,
            responseLanguage: responseLanguage
        )
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")

        var lastError: Error?
        for attempt in 0..<3 {
            try Task.checkCancellation()
            do {
                let (data, response) = try await session.data(for: request)
                try Task.checkCancellation()
                guard let http = response as? HTTPURLResponse else { throw OpenAIServiceError.invalidResponse }
                guard (200..<300).contains(http.statusCode) else {
                    let message = Self.apiErrorMessage(from: data) ?? "Request failed"
                    let error = OpenAIServiceError.requestFailed(statusCode: http.statusCode, message: message)
                    if http.statusCode == 429 || http.statusCode >= 500 { throw RetriableError(wrapped: error) }
                    throw error
                }
                let raw = try Self.decodeProposals(from: data)
                return try validator.validate(raw, expectedItems: Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) }))
            } catch let error as RetriableError {
                lastError = error.wrapped
                if attempt < 2 {
                    try await Task.sleep(for: .seconds(1 << attempt))
                    continue
                }
            } catch let error as URLError where error.code == .cancelled && Task.isCancelled {
                throw CancellationError()
            }
        }
        throw lastError ?? OpenAIServiceError.invalidResponse
    }

    private static func decodeProposals(from data: Data) throws -> [AIRawProposal] {
        let response = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        for output in response.output {
            for content in output.content ?? [] {
                if let refusal = content.refusal { throw OpenAIServiceError.refusal(refusal) }
                if content.type == "output_text", let text = content.text {
                    return try JSONDecoder().decode(ProposalEnvelope.self, from: Data(text.utf8)).items
                }
            }
        }
        throw OpenAIServiceError.invalidResponse
    }

    private static func apiErrorMessage(from data: Data) -> String? {
        (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data))?.error.message
    }

    private struct ResponseEnvelope: Decodable {
        let output: [Output]
    }

    private struct Output: Decodable {
        let content: [Content]?
    }

    private struct Content: Decodable {
        let type: String
        let text: String?
        let refusal: String?
    }

    private struct ProposalEnvelope: Decodable {
        let items: [AIRawProposal]
    }

    private struct APIErrorEnvelope: Decodable {
        let error: APIError
    }

    private struct APIError: Decodable {
        let message: String
    }

    private struct RetriableError: Error {
        let wrapped: Error
    }
}
