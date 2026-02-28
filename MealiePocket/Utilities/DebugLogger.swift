import Foundation
import OSLog

enum DebugLogger {
#if DEBUG
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "MealiePocket", category: "Debug")

    static func apiRequest(_ request: URLRequest) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "<missing-url>"
        if let body = request.httpBody, let bodyString = truncatedString(from: body) {
            logger.debug("API Request [\(method)] \(url, privacy: .public) body=\(bodyString, privacy: .public)")
        } else {
            logger.debug("API Request [\(method)] \(url, privacy: .public)")
        }
    }

    static func apiResponse(_ response: HTTPURLResponse, data: Data, for request: URLRequest) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "<missing-url>"
        let statusCode = response.statusCode
        if let responseString = truncatedString(from: data) {
            logger.debug("API Response [\(statusCode)] [\(method)] \(url, privacy: .public) body=\(responseString, privacy: .public)")
        } else {
            logger.debug("API Response [\(statusCode)] [\(method)] \(url, privacy: .public)")
        }
    }

    static func apiError(_ error: Error, for request: URLRequest) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "<missing-url>"
        logger.error("API Error [\(method)] \(url, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
    }

    private static func truncatedString(from data: Data, maxLength: Int = 700) -> String? {
        guard !data.isEmpty else { return nil }
        guard let string = String(data: data, encoding: .utf8) else { return "<non-utf8-body>" }
        if string.count <= maxLength {
            return string
        }
        return String(string.prefix(maxLength)) + "..."
    }
#else
    static func apiRequest(_ request: URLRequest) {}
    static func apiResponse(_ response: HTTPURLResponse, data: Data, for request: URLRequest) {}
    static func apiError(_ error: Error, for request: URLRequest) {}
#endif
}
