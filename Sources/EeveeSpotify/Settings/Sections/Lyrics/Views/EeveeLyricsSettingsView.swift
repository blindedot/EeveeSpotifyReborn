import SwiftUI

struct EeveeLyricsSettingsView: View {
    @StateObject var viewModel = EeveeLyricsSettingsViewModel()

    var body: some View {
        List {
            lyricsSourceSection()

            if viewModel.lyricsSource != .notReplaced {
                if viewModel.lyricsSource != .genius {
                    geniusFallbackSection()
                }

                hideOnErrorSection()
                languageSettingsSection()

                if viewModel.lyricsSource == .musixmatch {
                    musixmatchLanguageSection()
                }
            }

            NonIPadSpacerView()
        }
        .onReceive(viewModel.musixmatchTokenInputAlertPublisher) { showAnonymousTokenOption in
            showMusixmatchTokenAlert(UserDefaults.lyricsSource, showAnonymousTokenOption)
        }
        .listStyle(GroupedListStyle())
        .disabled(viewModel.isRequestingMusixmatchToken)
        .animation(.default, value: viewModel.animationValues)
    }

    private func languageSettingsFooter() -> some View {
        var text = "romanized_lyrics_description".localized

        text.append("\n\n")
        text.append("include_romanization_with_meaning_description".localized)

        return Text(text)
    }

    @ViewBuilder private func geniusFallbackSection() -> some View {
        Section {
            Toggle(
                "genius_fallback".localized,
                isOn: $viewModel.lyricsOptions.geniusFallback
            )

            if viewModel.lyricsOptions.geniusFallback {
                Toggle(
                    "show_fallback_reasons".localized,
                    isOn: $viewModel.lyricsOptions.showFallbackReasons
                )
            }
        } footer: {
            Text("genius_fallback_description"
                .localizeWithFormat(viewModel.lyricsSource.description))
        }
    }

    @ViewBuilder private func languageSettingsSection() -> some View {
        Section {
            Toggle(
                "romanized_lyrics".localized,
                isOn: $viewModel.lyricsOptions.romanization
            )
            Toggle(
                "include_romanization_with_meaning".localized,
                isOn: $viewModel.lyricsOptions.includeRomanizationWithMeaning
            )
        } footer: {
            languageSettingsFooter()
        }
    }

    @ViewBuilder private func hideOnErrorSection() -> some View {
        Section {
            Toggle(
                "hide_lyrics_on_error".localized,
                isOn: $viewModel.lyricsOptions.hideOnError
            )
        } footer: {
            Text("hide_lyrics_on_error_description".localized)
        }
    }

    @ViewBuilder private func musixmatchLanguageSection() -> some View {
        Section {
            HStack {
                Text("musixmatch_language".localized)

                Spacer()

                TextField("en", text: $viewModel.lyricsOptions.musixmatchLanguage)
                    .frame(maxWidth: 20)
                    .foregroundColor(.gray)
            }
            .icon(
                "exclamationmark.triangle.fill",
                color: .yellow,
                when: $viewModel.showMusixmatchInvalidLanguageWarning
            )
        } footer: {
            Text("musixmatch_language_description".localized)
        }
    }
}
