import Orion
import UIKit

struct AllSimplifiedChineseGroup: HookGroup {}

// This fails to set OS level song information since we do not override the actual data.
class UILabelHook: ClassHook<UILabel> {
    typealias Group = AllSimplifiedChineseGroup

    func setText(_ text: String) {
        orig.setText(text.simplify())
    }

    func setAttributedText(_ text: NSAttributedString) {
        // Lyrics_TextComponentImpl.LyricsCell is a UITableViewCell
        // not found :[

        // Lyrics_TextElementImpl.LyricsCell is a UITableViewCell
        if let cell = target.getParent(matching: "Lyrics_TextElementImpl.LyricsCell") {
            // underline romanization
            var t = text.simplify()
                .styleDelimitedSpans(
                    start: "【", end: "】",
                    attributeStyle: .underlineStyle,
                    attributeValue: NSUnderlineStyle.thick.rawValue,
                    dotMatchesNewlines: true
                )

            // cannot tell translating state
            // let translating = Ivars<Bool>(cell).isTranslationEnabled
            // print("[MYLD]! translating: \(translating)")
            let translating = false
            if translating {
                t = t.styleDelimitedSpans(
                    start: "〖", end: "〗",
                    attributeStyle: .kern,
                    attributeValue: NSNumber(2))
            } else {
                t = t.styleDelimitedSpans(start: "〖", end: "〗")
            }
            return orig.setAttributedText(t)
        }
        return orig.setAttributedText(text.simplify())
    }
}

// class LyricsCellHook: ClassHook<UITableViewCell> {
//     typealias Group = LyricsGroup
//     static let targetName = "Lyrics_TextElementImpl.LyricsCell"

//     // var calledOnce = false

//     // func setSelected(_ selected: Bool, animated: Bool) {
//     //     // disable selection
//     //     // orig.setSelected(false, animated: animated)
//     // }

//     // func setHighlighted(_ highlighted: Bool, animated: Bool) {
//     //     // disable highlight
//     //     // orig.setHighlighted(false, animated: animated)
//     // }
// }

class UIUnderlineLyricsHook: ClassHook<UILabel> {
    typealias Group = LyricsGroup

    // func setAttributedText(_ text: NSAttributedString) {
    //     if let cell = target.getParent(matching: "Lyrics_TextElementImpl.LyricsCell") {
    //         orig.setAttributedText(text.underlineMatchingSpans(matching: "【.*?】", dotMatchesNewlines: true))
    //     }
    // }

    // func intrinsicContentSize() -> CGSize {

    //     return orig.intrinsicContentSize()
    // }

    //         if !calledOnce {
    //             let names = [
    //                 "isShareModeEnabled", "isSingleCellViewEnabled", "isTranslationEnabled",
    //                 "lyricsLabel", "detailLabel",
    //             ]
    //             for name in names {
    //                 print("[MYLD]! \(cell.getTypeOfProperty(name: name))")
    //             }

    //             if let tableViewCell = cell as? UITableViewCell {
    //                 // print("[Orion] LyricsCell: \(tableViewCell.allowsSelection)")
    //                 // tableViewCell.allowsSelection = false
    //                 // print("[Orion] LyricsCell: \(tableViewCell.allowsSelection)")
    //             } else {
    //                 print("[Orion] ERROR no cell matched")
    //             }
}

extension UITextView {
    func plecoAction() {
        if let range = self.selectedTextRange, let selectedText = self.text(in: range) {
            let url = URL(string: "plecoapi://x-callback-url/df?hw=\(selectedText)")
            UIApplication.shared.open(url!)
        }
    }

    // override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
    //     let plecoAction = UIAction(title: "Pleco") { (action) in
    //         print("Translate tapped, sender: \(action.sender)")
    //         self.plecoAction()
    //     }
    //     return UIMenu(children: [plecoAction])
    // }
}

class UITextViewHook: ClassHook<UITextView> {
    typealias Group = AllSimplifiedChineseGroup

    func setText(_ text: String) {
        orig.setText(text.simplify())
    }

    func setAttributedText(_ text: NSAttributedString) {
        orig.setAttributedText(text.simplify())
    }

    //     // orion:new
    //     override func editMenu(for textRange: UITextRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
    //         let plecoAction = UIAction(title: "Pleco") { (action) in
    //             print("Translate tapped, sender: \(action.sender)")
    //             if let sender = action.sender as? UITextView {
    //                 sender.plecoAction()
    //             }
    //         }
    //         return UIMenu(children: [plecoAction])
    //     //     let menu = orig.editMenu(for: textRange, suggestedActions: suggestedActions)

    //     //     if menu == nil {
    //     //         return UIMenu(children: [plecoAction])
    //     //     }

    //     //     let updatedChildren = [plecoAction] + menu.children ?? []

    //     //     return UIMenu(title: menu.title, options: menu.options, children: updatedChildren)
    //     }
}

// var printed = false

// We override the actual data here so OS level song information is also changed.
// This only affects track data
class SPTPlayerTrackLanguageHook: ClassHook<NSObject> {
    typealias Group = AllSimplifiedChineseGroup
    static let targetName =
        EeveeSpotify.hookTarget == .latest
        ? "SPTPlayerTrackImplementation"
        : "SPTPlayerTrack"

    func metadata() -> [String: String] {
        if let dict = Ivars<NSDictionary>(target)._metadata as? [String: Any] {
            // if !printed {
            //     // printed = true
            //     print("---- metadata ----")
            //     for (key, value) in dict {
            //         print("key: \(key), value: \(value)")
            //     }
            //     print("---- end metadata ----")
            // }

            let was_simplified = dict["was_simplified"] as? String ?? ""
            if was_simplified != "true" {
                var transformed = dict.mapValues { value -> Any in
                    if let s = value as? String {
                        if UserDefaults.allIncludeRomanized {
                            return s.simplify().attachRomanized()
                        } else {
                            return s.simplify()
                        }
                    }
                    return value
                }
                transformed["was_simplified"] = "true"
                // we don't hide the lyrics container since we might get lyrics separately
                transformed["has_lyrics"] = "true"

                Ivars<NSDictionary>(target)._metadata = transformed as NSDictionary
            }
        }

        return orig.metadata()
    }
}
