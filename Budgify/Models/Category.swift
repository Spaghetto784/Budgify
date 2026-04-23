import SwiftData
import Foundation

@Model
final class Category {
    var name: String
    var colorHex: String
    var icon: String

    init(name: String, colorHex: String, icon: String) {
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
    }
}
