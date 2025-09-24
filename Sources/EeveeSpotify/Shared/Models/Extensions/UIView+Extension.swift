import UIKit

extension UIView {
    func getParent(matching regex: String) -> UIView? {
        guard let parent = self.superview else {
            return nil
        }

        let parentClassName = NSStringFromClass(type(of: parent))
        if parentClassName ~= regex {
            return parent
        } else {
            return parent.getParent(matching: regex)
        }
    }

    func hasParent(matching regex: String) -> Bool {
        return getParent(matching: regex) != nil
    }

    func subviews(matching regex: String) -> [UIView] {
        var matchingSubviews = [UIView]()
        var stack = [self]

        while !stack.isEmpty {
            let currentView = stack.removeLast()

            for subview in currentView.subviews {
                if NSStringFromClass(type(of: subview)) ~= regex {
                    matchingSubviews.append(subview)
                }
                stack.append(subview)
            }
        }

        return matchingSubviews
    }
}
