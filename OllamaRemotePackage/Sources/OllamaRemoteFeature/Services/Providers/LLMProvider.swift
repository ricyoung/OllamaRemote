import Foundation

public protocol LLMProvider: Actor {
    var configuration: AnyProviderConfiguration { get }

    func testConnection() async throws -> Bool
    func fetchModels() async throws -> [LLMModel]
    func chat(request: ChatRequest) async throws -> ChatResponse
    func chatStream(request: ChatRequest) -> AsyncThrowingStream<StreamChunk, Error>
    func cancelCurrentRequest()
}
