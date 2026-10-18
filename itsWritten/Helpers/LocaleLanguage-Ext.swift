//
//  LocaleLanguage-Ext.swift
//  itsWritten
//
//  Created by Filippo Cilia on 24/05/2026.
//

import Foundation

extension Locale.Language {
    /// A human-readable name for this language, localized for `locale`.
    ///
    /// Only Simplified and Traditional Chinese keep their script, since that's the one
    /// case where the script distinguishes otherwise identically named languages.
    func displayName(in locale: Locale) -> String {
        let scriptsToShow: Set<Locale.Script> = [.hanSimplified, .hanTraditional]
        let scriptToUse = script.flatMap { scriptsToShow.contains($0) ? $0 : nil }

        let components = Locale.Components(
            languageCode: languageCode,
            script: scriptToUse,
            languageRegion: region
        )
        let identifier = Locale(components: components).identifier

        if let name = locale.localizedString(forIdentifier: identifier) {
            return name
        }

        if let code = languageCode?.identifier {
            return locale.localizedString(forLanguageCode: code) ?? code
        }

        return String(localized: "Unknown")
    }
}
