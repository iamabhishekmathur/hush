import Foundation

/// Expands a raw surface token into the sequence of words a speaker actually
/// says, so the script lines up with on-device ASR output. Handles currency,
/// percentages, bare numbers (incl. decimals), and short acronyms.
///
///   "$29"   → ["twenty","nine","dollars"]
///   "99.9%" → ["ninety","nine","point","nine","percent"]
///   "API"   → ["a","p","i"]
///   "iOS"   → ["i","o","s"]
///   "Hush"  → ["hush"]
public enum Normalizer {
    private static let edgePunctuation = CharacterSet(charactersIn: ".,!?;:\"'()[]{}…—–")

    public static func expand(_ raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: edgePunctuation)
        guard !trimmed.isEmpty else { return [] }

        // currency: $29 / $1,200
        if trimmed.hasPrefix("$") {
            let numStr = String(trimmed.dropFirst()).replacingOccurrences(of: ",", with: "")
            if let words = numberWords(numStr) {
                let unit = (Double(numStr) == 1) ? "dollar" : "dollars"
                return words + [unit]
            }
        }
        // percentage: 99.9%
        if trimmed.hasSuffix("%") {
            let numStr = String(trimmed.dropLast()).replacingOccurrences(of: ",", with: "")
            if let words = numberWords(numStr) { return words + ["percent"] }
        }
        // bare number: 10 / 99.9
        if let words = numberWords(trimmed.replacingOccurrences(of: ",", with: "")) { return words }

        // acronym: ≥2 uppercase letters, short, all-letters → spell out
        let upper = trimmed.filter { $0.isUppercase }.count
        let letters = trimmed.filter { $0.isLetter }
        if upper >= 2 && letters.count <= 5 && letters.count == trimmed.count {
            return letters.map { String($0).lowercased() }
        }

        // default: lowercase, keep letters/digits/apostrophe
        let cleaned = trimmed.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "'" }
        return cleaned.isEmpty ? [] : [cleaned]
    }

    // MARK: numbers

    static func numberWords(_ s: String) -> [String]? {
        if let dot = s.firstIndex(of: ".") {
            let intPart = String(s[s.startIndex..<dot])
            let fracPart = String(s[s.index(after: dot)...])
            guard let intW = intWords(intPart) else { return nil }
            var out = intW + ["point"]
            for ch in fracPart {
                guard let d = ch.wholeNumberValue else { return nil }
                out.append(ones[d])
            }
            return out
        }
        return intWords(s)
    }

    private static func intWords(_ s: String) -> [String]? {
        guard let n = Int(s) else { return nil }
        return words(forInt: n)
    }

    private static let ones = ["zero","one","two","three","four","five","six","seven","eight","nine","ten","eleven","twelve","thirteen","fourteen","fifteen","sixteen","seventeen","eighteen","nineteen"]
    private static let tens = ["","","twenty","thirty","forty","fifty","sixty","seventy","eighty","ninety"]

    private static func words(forInt n: Int) -> [String]? {
        if n < 0 { return nil }
        if n < 20 { return [ones[n]] }
        if n < 100 {
            let t = tens[n / 10]; let r = n % 10
            return r == 0 ? [t] : [t, ones[r]]
        }
        if n < 1000 {
            let h = [ones[n / 100], "hundred"]; let r = n % 100
            return r == 0 ? h : h + (words(forInt: r) ?? [])
        }
        if n < 1_000_000 {
            let th = (words(forInt: n / 1000) ?? []) + ["thousand"]; let r = n % 1000
            return r == 0 ? th : th + (words(forInt: r) ?? [])
        }
        return nil
    }
}
