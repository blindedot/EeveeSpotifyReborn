import Orion
import UIKit

import ObjectiveC.runtime

// Mark text views we've already touched so we don't keep redoing work.
private var kMadeSelectableKey: UInt8 = 0

@inline(__always)
private func makeSelectable(_ tv: UITextView) {
    // Avoid re-entry
    if objc_getAssociatedObject(tv, &kMadeSelectableKey) as? Bool == true { return }
    objc_setAssociatedObject(tv, &kMadeSelectableKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

    // Core: enable selection, keep it non-editable (safer for most apps).
    tv.isEditable = false
    tv.isSelectable = true
    tv.isUserInteractionEnabled = true

    // Optional: ensure long-press selection works nicely.
    tv.delaysContentTouches = false
}

class SelectableUITextViewHook: ClassHook<UITextView> {
    func didMoveToWindow() {
        // override
        orig.didMoveToWindow()

        target.textColor = .green

        if !target.isSelectable {
            makeSelectable(target)
        }
    }

    func setIsSelectable(_ selectable: Bool) {
        orig.setIsSelectable(selectable)

        if !target.isSelectable {
            makeSelectable(target)
        }
    }

    func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        // override
        let plecoAction = UIAction(title: "Pleco") { (action) in
            self.openInPleco()
        }

        return UIMenu(children: [plecoAction])
    }

    // orion:new
    func openInPleco() {
        if let range = target.selectedTextRange, let selectedText = target.text(in: range) {
            let url = URL(string: "plecoapi://x-callback-url/df?hw=\(selectedText)")
            UIApplication.shared.open(url!)
        }
    }
}
