import Orion
import UIKit

struct AllSimplifiedChinese: HookGroup { }

// This fails to set OS level song information since we do not override the actual data.

func simplifyAttributedString(_ originalAttributedString: NSAttributedString) -> NSAttributedString
{
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

class UILabelHook: ClassHook<UILabel> {
    typealias Group = AllSimplifiedChinese

    func setText(_ text: String) {
        orig.setText(text.simplify())
    }

    func setAttributedText(_ text: NSAttributedString) {
        orig.setAttributedText(simplifyAttributedString(text))
    }
}
