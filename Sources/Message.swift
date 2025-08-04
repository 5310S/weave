import Foundation

struct Message: Codable, Equatable {
    let type: String
    let payload: Data
    let metadata: [String: String]?
}
