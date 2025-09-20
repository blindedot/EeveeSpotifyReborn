import Foundation

enum LyricsChineseSimplificationStatus {
    case chineseSimplified // lyrics are already simplified
    case canBeChineseSimplified // lyrics can be simplified, but there were no simplified lyrics available
    case original
}

// z1: chinese (traditional) <-> zh: chinese (simplified)
