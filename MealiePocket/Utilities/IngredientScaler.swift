import Foundation

enum IngredientScaler {

    static func scaleFactor(originalServings: Double?, targetServings: Double?) -> Double {
        guard let original = originalServings, original > 0,
              let target = targetServings, target > 0 else {
            return 1.0
        }
        return target / original
    }
    
    private static let quantityFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter
    }()
    
    static func formatQuantity(_ value: Double) -> String {
        if value == floor(value) && value < 100000 {
            return String(Int(value))
        }
        
        let whole = Int(value)
        let fractional = value - Double(whole)
        
        if let vulgar = vulgarFraction(for: fractional) {
            return whole > 0 ? "\(whole) \(vulgar)" : vulgar
        }
        
        return quantityFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2g", value)
    }
    
    static func vulgarFraction(for fractional: Double, tolerance: Double = 0.05) -> String? {
        let fractions: [(threshold: Double, symbol: String)] = [
            (1.0 / 8.0, "\u{215B}"),
            (1.0 / 6.0, "\u{2159}"),
            (1.0 / 5.0, "\u{2155}"),
            (1.0 / 4.0, "\u{00BC}"),
            (1.0 / 3.0, "\u{2153}"),
            (3.0 / 8.0, "\u{215C}"),
            (2.0 / 5.0, "\u{2156}"),
            (1.0 / 2.0, "\u{00BD}"),
            (3.0 / 5.0, "\u{2157}"),
            (5.0 / 8.0, "\u{215D}"),
            (2.0 / 3.0, "\u{2154}"),
            (3.0 / 4.0, "\u{00BE}"),
            (4.0 / 5.0, "\u{2158}"),
            (5.0 / 6.0, "\u{215A}"),
            (7.0 / 8.0, "\u{215E}"),
        ]
        
        for fraction in fractions {
            if abs(fractional - fraction.threshold) < tolerance {
                return fraction.symbol
            }
        }
        return nil
    }

    static func displayText(for ingredient: RecipeIngredient, scaleFactor: Double) -> String {
        guard scaleFactor != 1.0, let qty = ingredient.quantity, qty > 0 else {
            return ingredient.display
        }
        let scaledQty = qty * scaleFactor
        let formatted = formatQuantity(scaledQty)
        var parts: [String] = [formatted]
        if let unit = ingredient.unit { parts.append(unit.name) }
        if let food = ingredient.food { parts.append(food.name) }
        if !ingredient.note.isEmpty { parts.append(ingredient.note) }
        return parts.joined(separator: " ")
    }
}
