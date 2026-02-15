import Foundation

struct MindMapNode: Identifiable, Equatable, Codable {
    let id: UUID
    var text: String
    var position: CGPoint
    var parentIDs: Set<UUID>
    var colorHex: String?

    init(id: UUID = UUID(), text: String = "", position: CGPoint, parentIDs: Set<UUID> = [], colorHex: String? = nil) {
        self.id = id
        self.text = text
        self.position = position
        self.parentIDs = parentIDs
        self.colorHex = colorHex
    }
}
