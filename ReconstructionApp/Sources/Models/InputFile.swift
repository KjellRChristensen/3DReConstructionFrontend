import Foundation

struct InputFile: Identifiable, Codable, Hashable {
    let name: String
    let path: String
    let size: Int
    let sizeHuman: String
    let modified: String
    let type: String
    let fileExtension: String

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case size
        case sizeHuman = "size_human"
        case modified
        case type
        case fileExtension = "extension"
    }

    var isImage: Bool {
        type == "image"
    }

    var isPDF: Bool {
        type == "document" && fileExtension == ".pdf"
    }

    var isCAD: Bool {
        type == "cad"
    }

    var iconName: String {
        switch type {
        case "image": return "photo"
        case "document": return "doc.text"
        case "cad": return "square.3.layers.3d"
        case "3d-model": return "cube"
        default: return "doc"
        }
    }

    var modifiedDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: modified) ?? ISO8601DateFormatter().date(from: modified)
    }
}

struct InputFilesResponse: Codable {
    let files: [InputFile]
    let total: Int
    let directory: String?
}
