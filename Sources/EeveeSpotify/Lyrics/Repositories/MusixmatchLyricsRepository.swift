import Foundation
import UIKit

class MusixmatchLyricsRepository: LyricsRepository {
    private let apiUrl = "https://apic.musixmatch.com"

    var selectedLanguage: String

    static let shared = MusixmatchLyricsRepository(
        language: UserDefaults.lyricsOptions.musixmatchLanguage
    )

    private init(language: String) {
        // acts as the translation language; lyrics still show the original language
        selectedLanguage = language
    }

    private func perform(
        _ path: String,
        query: [String: Any] = [:]
    ) throws -> Data {
        var stringUrl = "\(apiUrl)\(path)"
        var finalQuery = query

        finalQuery["usertoken"] = UserDefaults.musixmatchToken
        finalQuery["app_id"] = UIDevice.current.musixmatchAppId

        let queryString = finalQuery.queryString
        stringUrl += "?\(queryString)"

        let request = URLRequest(url: URL(string: stringUrl)!)

        let semaphore = DispatchSemaphore(value: 0)
        var data: Data?
        var error: Error?

        let task = URLSession.shared.dataTask(with: request) { response, _, err in
            error = err
            data = response
            semaphore.signal()
        }

        task.resume()
        semaphore.wait()

        if let error = error {
            throw error
        }

        return data!
    }

    //

    private func getMacroCalls(_ data: Data) throws -> [String: Any] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let message = json["message"] as? [String: Any],
            let body = message["body"] as? [String: Any],
            let macroCalls = body["macro_calls"] as? [String: Any]
        else {
            throw LyricsError.decodingError
        }

        if let header = message["header"] as? [String: Any],
            header["status_code"] as? Int == 401 {
            throw LyricsError.invalidMusixmatchToken
        }

        return macroCalls
    }

    private func getFirstSubtitle(_ subtitlesMessage: [String: Any]) throws -> [String: Any] {
        guard
            let subtitlesBody = subtitlesMessage["body"] as? [String: Any],
            let subtitleList = subtitlesBody["subtitle_list"] as? [[String: Any]],
            let firstSubtitle = subtitleList.first,
            let subtitle = firstSubtitle["subtitle"] as? [String: Any]
        else {
            throw LyricsError.decodingError
        }

        if let restricted = subtitle["restricted"] as? Bool, restricted {
            throw LyricsError.musixmatchRestricted
        }

        return subtitle
    }

    func removeBracketedText(_ text: String) -> String {
        let pattern = "【.*?】"
        return text.replacingOccurrences(of: pattern,
                                        with: "",
                                        options: .regularExpression)
    }

    //

    private func getTranslations(_ spotifyTrackId: String, selectedLanguage: String) throws -> [String: String] {
        let data = try perform(
            "/ws/1.1/crowd.track.translations.get",
            query: [
                "track_spotify_id": spotifyTrackId,
                "selected_language": selectedLanguage
            ]
        )

        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
            let message = json["message"] as? [String: Any],
            let body = message["body"] as? [String: Any],
            let translationsList = body["translations_list"] as? [[String: Any]]
        else {
            throw LyricsError.decodingError
        }

        let translations = translationsList.compactMap {
            $0["translation"] as? [String: Any]
        }

        return translations.reduce(into: [:]) { dictionary, translation in
            dictionary[translation["subtitle_matched_line"] as! String] = translation["description"] as? String
        }
    }

    //

    func getLyrics(_ query: LyricsSearchQuery, options: LyricsOptions) throws -> LyricsDto {
        var musixmatchQuery = [
            "track_spotify_id": query.spotifyTrackId,
            "subtitle_format": "mxm",
            "q_track": query.title,
            "q_artist": query.primaryArtist
        ]

        if !selectedLanguage.isEmpty {
            musixmatchQuery["selected_language"] = selectedLanguage
            musixmatchQuery["part"] = "subtitle_translated"
        }

        let data = try perform(
            "/ws/1.1/macro.subtitles.get",
            query: musixmatchQuery
        )

        // 😭😭😭

        var romanized = false
        var simplified = false
        var translation: LyricsTranslationDto? = nil

        let macroCalls = try getMacroCalls(data)

        if let trackSubtitlesGet = macroCalls["track.subtitles.get"] as? [String: Any],
            let subtitlesMessage = trackSubtitlesGet["message"] as? [String: Any],
            let subtitle = try? getFirstSubtitle(subtitlesMessage),
            let subtitleLanguage = subtitle["subtitle_language"] as? String,
            let subtitleBody = subtitle["subtitle_body"] as? String,
            let subtitles = try? JSONDecoder().decode(
                [MusixmatchSubtitle].self, from: subtitleBody.data(using: .utf8)!
            ) {

            let romanizationLanguage = "r\(subtitleLanguage.prefix(1))"
            let simplifiedLanguage = "zh"

            var lyricsLines = subtitles.dropLast().map { subtitle in
                LyricsLineDto(
                    content: subtitle.text.lyricsNoteIfEmpty,
                    offsetMs: Int(subtitle.time.total * 1000)
                )
            }

            lyricsLines.append(
                LyricsLineDto(
                    content: "",
                    offsetMs: Int(subtitles.last!.time.total * 1000)
                )
            )

            // if selected language doesn't match song source, try to get translations
            if selectedLanguage != subtitleLanguage,
               let subtitleTranslated = subtitle["subtitle_translated"] as? [String: Any],
               let subtitleTranslatedBody = subtitleTranslated["subtitle_body"] as? String,
               let subtitlesTranslated = try? JSONDecoder().decode(
                    [MusixmatchSubtitle].self, from: subtitleTranslatedBody.data(using: .utf8)!
               )
            {
                // if selected language is romanization language, replace source
                // assumes subtitleLanguage can be romanized (isCanBeRomanizedLanguage)
                if selectedLanguage == romanizationLanguage {
                    romanized = true

                    for (index, subtitleTranslated) in subtitlesTranslated.enumerated() {
                        if !subtitleTranslated.text.isEmpty {
                            lyricsLines[index].content = subtitleTranslated.text
                        }
                    }
                }
                // if selected language is simplified chinese, replace source
                else if subtitleLanguage.isCanBeRomanizedLanguage
                    && selectedLanguage == simplifiedLanguage
                {
                    simplified = true

                    for (index, subtitleTranslated) in subtitlesTranslated.enumerated() {
                        if !subtitleTranslated.text.isEmpty {
                            lyricsLines[index].content = subtitleTranslated.text
                        }
                    }
                }
                // otherwise add as translation
                else {
                    translation = LyricsTranslationDto(
                        languageCode: selectedLanguage,
                        lines: subtitlesTranslated.map { $0.text }
                    )
                }
            }

            // if the user wants simplified regardless of the selected language
            if options.simplifiedChinese && selectedLanguage != simplifiedLanguage {
                // Musixmatch tags the language incorrectly. Just don't bother getting their translation.
                /*
                if let translations = try? getTranslations(
                    query.spotifyTrackId,
                    selectedLanguage: simplifiedLanguage
                ) {
                    if (translations.count > 0) {
                        simplified = true

                        for (original, translation) in translations {
                            for i in 0..<lyricsLines.count {
                                if lyricsLines[i].content == original {
                                    lyricsLines[i].content = translation
                                }
                            }
                        }
                    }
                }
                */
            }

            if options.includeRomanizationWithMeaning && subtitleLanguage.isCanBeRomanizedLanguage
                && selectedLanguage != romanizationLanguage
            {
                if var t = translation {
                    for i in 0..<lyricsLines.count {
                        let romanizedLine = lyricsLines[i].content.romanize()
                        let meaningLine = removeBracketedText(t.lines[i])
                        t.lines[i] = "[\(romanizedLine)]\n\(meaningLine)"
                    }
                    translation = t
                } else {
                    translation = LyricsTranslationDto(
                        languageCode: romanizationLanguage,
                        lines: lyricsLines.map { $0.content.romanize() }
                    )
                }
                if let translations = try? getTranslations(
                    query.spotifyTrackId,
                    selectedLanguage: romanizationLanguage
                ) {
                }
            }

            // if the user wants romanization to replace original lyrics
            if options.romanization && selectedLanguage != romanizationLanguage {
                if let translations = try? getTranslations(
                    query.spotifyTrackId,
                    selectedLanguage: romanizationLanguage
                ) {
                    if !options.includeRomanizationWithMeaning && options.simplifiedChinese
                        && selectedLanguage != simplifiedLanguage
                    {
                        let romanizedLines = lyricsLines.map { line in
                            translations[line.content] ?? line.content
                        }

                        translation = LyricsTranslationDto(
                            languageCode: romanizationLanguage,
                            lines: romanizedLines
                        )
                    } else {
                        romanized = true

                        for (original, translation) in translations {
                            for i in 0..<lyricsLines.count {
                                if lyricsLines[i].content == original {
                                    lyricsLines[i].content = translation
                                }
                            }
                        }
                    }
                }
            }

            var romanization = LyricsRomanizationStatus.original

            if romanized {
                romanization = .romanized
            }
            else if subtitleLanguage.isCanBeRomanizedLanguage {
                romanization = .canBeRomanized
            }

            var chineseSimplified = LyricsChineseSimplificationStatus.original

            if simplified {
                chineseSimplified = .chineseSimplified
            }
            else if subtitleLanguage.isCanBeSimplifiedLanguage {
                chineseSimplified = .canBeChineseSimplified
            }

            return LyricsDto(
                lines: lyricsLines,
                timeSynced: true,
                romanization: romanization,
                chineseSimplified: chineseSimplified,
                translation: translation
            )
        }

        // does not bother directly substituting romanized, simplified chinese, or with translations
        if let trackLyricsGet = macroCalls["track.lyrics.get"] as? [String: Any],
           let lyricsMessage = trackLyricsGet["message"] as? [String: Any],
           let lyricsHeader = lyricsMessage["header"] as? [String: Any],
           let lyricsStatusCode = lyricsHeader["status_code"] as? Int {

            if lyricsStatusCode == 404 {
                throw LyricsError.noSuchSong
            }

            if let lyricsBody = lyricsMessage["body"] as? [String: Any],
               let lyrics = lyricsBody["lyrics"] as? [String: Any],
               let lyricsLanguage = lyrics["lyrics_language"] as? String,
               let plainLyrics = lyrics["lyrics_body"] as? String {

                if let restricted = lyrics["restricted"] as? Bool, restricted {
                    throw LyricsError.musixmatchRestricted
                }

                return LyricsDto(
                    lines: plainLyrics
                        .components(separatedBy: "\n")
                        .dropLast()
                        .map { LyricsLineDto(content: $0.lyricsNoteIfEmpty) },
                    timeSynced: false,
                    romanization: lyricsLanguage.isCanBeRomanizedLanguage ? .canBeRomanized : .original,
                    chineseSimplified: lyricsLanguage.isCanBeSimplifiedLanguage ? .canBeChineseSimplified : .original
                )
            }
        }

        throw LyricsError.decodingError
    }
}
