//
//  CloudModelsSummary.swift
//  itsWritten
//

import Foundation
import VoltaSDK

/// The short status shown next to "Cloud Models" in Settings.
enum CloudModelsSummary {
    /// "Off" with no keys, the vendor's name with one, a count with several.
    static func text(for vendors: Set<CloudVendor>) -> String {
        switch vendors.count {
        case 0:
            String(localized: "Off")
        case 1:
            vendors.first.map { ConsentDestination.vendor($0).displayName } ?? ""
        default:
            String(localized: "\(vendors.count) models")
        }
    }
}
