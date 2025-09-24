import Foundation
import UIKit

extension NSAttributedString {
    func simplify() -> NSAttributedString {
        let originalAttributedString = self
        let originalString = originalAttributedString.string

        let transformed = originalString.simplify()
        let attributedString = NSMutableAttributedString(string: transformed)
        var indexOffset = 0

        originalAttributedString.enumerateAttributes(
            in: NSRange(location: 0, length: originalAttributedString.length),
            options: []
        ) { attributes, range, _ in

            let originalSubstring = originalAttributedString.attributedSubstring(from: range).string

            let transformedSubstring = originalSubstring.simplify()

            let lengthDifference = transformedSubstring.count - originalSubstring.count

            let adjustedRange = NSRange(
                location: range.location + indexOffset, length: transformedSubstring.count)

            attributedString.addAttributes(attributes, range: adjustedRange)

            indexOffset += lengthDifference
        }

        return attributedString
    }

    /// Underline all ranges that match `【.*?】` in the given attributed string.
    func underlineMatchingSpans(matching pattern: String, dotMatchesNewlines: Bool = false)
        -> NSAttributedString
    {
        let output = NSMutableAttributedString(attributedString: self)
        let text = self.string
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        let options: NSRegularExpression.Options =
            dotMatchesNewlines ? [.dotMatchesLineSeparators] : []
        let regex = try? NSRegularExpression(pattern: pattern, options: options)

        regex?.enumerateMatches(in: text, options: [], range: fullRange) { match, _, _ in
            guard let r = match?.range else { return }
            output.addAttribute(
                .underlineStyle,
                value: NSUnderlineStyle.single.rawValue,
                range: r)
        }

        return output
    }

    func styleDelimitedSpans(
        start: String,
        end: String,
        attributeStyle: NSAttributedString.Key? = nil,
        attributeValue: Any? = nil,
        removeDelimiters: Bool = true,
        dotMatchesNewlines: Bool = false
    ) -> NSAttributedString {
        guard !start.isEmpty, !end.isEmpty, self.length > 0 else { return self }

        let mutable = NSMutableAttributedString(attributedString: self)
        let s = self.string as NSString
        let full = NSRange(location: 0, length: s.length)

        // Build a safe non-greedy regex: <start> .*? <end>
        let escStart = NSRegularExpression.escapedPattern(for: start)
        let escEnd   = NSRegularExpression.escapedPattern(for: end)
        let pattern  = "\(escStart).*?\(escEnd)"
        let opts: NSRegularExpression.Options = dotMatchesNewlines ? [.dotMatchesLineSeparators] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: opts) else {
            return self
        }

        // Collect matches first; if removing, process in reverse to keep ranges valid.
        let matches = regex.matches(in: self.string, options: [], range: full)
        let sequence: AnySequence<NSTextCheckingResult> = removeDelimiters
            ? AnySequence(matches.reversed())
            : AnySequence(matches)

        for m in sequence {
            let outer = m.range
            // Validate lengths
            guard outer.length >= start.utf16.count + end.utf16.count else { continue }

            // Compute inner range (exclude delimiters)
            let innerLoc = outer.location + start.utf16.count
            let innerLen = outer.length   - start.utf16.count - end.utf16.count
            guard innerLen > 0 else { continue }
            let inner = NSRange(location: innerLoc, length: innerLen)

            if let attributeKey = attributeStyle {
                // Apply style
                mutable.addAttribute(attributeKey, value: attributeValue, range: inner)
            }

            // Optionally remove the delimiters, end then start
            if removeDelimiters {
                // Remove closing delimiter after inner
                let endRange = NSRange(location: inner.location + inner.length, length: end.utf16.count)
                mutable.deleteCharacters(in: endRange)
                // Remove opening delimiter before inner (note: inner.location shifts left by end removal? No, we removed after.)
                let startRange = NSRange(location: outer.location, length: start.utf16.count)
                mutable.deleteCharacters(in: startRange)
            }
        }

        return mutable
    }
}
