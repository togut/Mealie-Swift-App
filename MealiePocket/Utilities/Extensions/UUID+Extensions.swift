import Foundation

extension UUID {
    var rfc4122String: String {
        return self.uuidString.lowercased()
    }
}
