import Foundation

extension UserDefaults {
    @UserDefault(
        key: "lyricsOptions",
        defaultValue: LyricsOptions(
            romanization: false,
            simplifiedChinese: false,
            includeRomanizationWithMeaning: false,
            musixmatchLanguage: Locale.current.languageCode ?? "",
            lrclibUrl: LrclibLyricsRepository.originalApiUrl,
            geniusFallback: true,
            showFallbackReasons: true,
            hideOnError: false
        )
    )
    static var lyricsOptions
}
