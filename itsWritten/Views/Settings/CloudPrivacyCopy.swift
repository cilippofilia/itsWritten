//
//  CloudPrivacyCopy.swift
//  itsWritten
//

import Foundation
import NaturalLanguage

/// Copy for the cloud privacy explanation in Settings.
enum CloudPrivacyCopy {
    /// Which languages names are checked in, read from the detector so the copy
    /// can't drift from what the app does, e.g. "Names are checked automatically
    /// in English, Italian, and Spanish. In other languages, they're sent as written."
    static func nameLanguagesText(locale: Locale) -> String {
        let names = SensitiveTextDetector.reliableNameLanguages
            .compactMap { locale.localizedString(forLanguageCode: $0.rawValue) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            .formatted(.list(type: .and).locale(locale))
        return String(localized: "Names are checked automatically in \(names). In other languages, they're sent as written.")
    }
}
