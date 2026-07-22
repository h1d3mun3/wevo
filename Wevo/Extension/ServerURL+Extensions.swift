//
//  ServerURL+Extensions.swift
//  Wevo
//

import Foundation

extension Collection where Element == String {
    /// True when at least one entry is a usable http/https server endpoint.
    ///
    /// Single source of truth for "does this Space talk to a server, or is it local-only?".
    /// Mirrors the scheme filter `ResilientProposeAPIClient` applies, so the UI's local-only
    /// decision can never drift from what the transition use cases actually do.
    var hasUsableServerURL: Bool {
        contains { URL(string: $0)?.scheme == "https" || URL(string: $0)?.scheme == "http" }
    }
}

extension String {
    /// Normalizes a user-entered server URL for storage: trims whitespace, prepends `https://`
    /// when no scheme is present, and returns nil when the result is still not a usable
    /// http/https URL (so a non-empty-but-unusable URL is never persisted — leaving the URL
    /// blank is the documented way to get a local-only Space).
    var normalizedServerURL: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let candidate = (URL(string: trimmed)?.scheme?.isEmpty == false) ? trimmed : "https://" + trimmed
        guard let url = URL(string: candidate),
              url.scheme == "https" || url.scheme == "http",
              let host = url.host, !host.isEmpty else { return nil }
        return candidate
    }
}
