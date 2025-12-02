import Foundation

enum ExportFormat: String, CaseIterable, Codable, Identifiable {
    case obj = "obj"
    case gltf = "gltf"
    case glb = "glb"
    case usdz = "usdz"
    case ifc = "ifc"
    case step = "step"
    case stl = "stl"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .obj: return "OBJ"
        case .gltf: return "glTF"
        case .glb: return "GLB (Binary glTF)"
        case .usdz: return "USDZ (iOS AR)"
        case .ifc: return "IFC (BIM)"
        case .step: return "STEP (CAD)"
        case .stl: return "STL (3D Print)"
        }
    }

    var fileExtension: String {
        rawValue
    }

    var mimeType: String {
        switch self {
        case .obj: return "model/obj"
        case .gltf: return "model/gltf+json"
        case .glb: return "model/gltf-binary"
        case .usdz: return "model/vnd.usdz+zip"
        case .ifc: return "application/x-step"
        case .step: return "application/step"
        case .stl: return "model/stl"
        }
    }

    var supportsARQuickLook: Bool {
        self == .usdz
    }
}
