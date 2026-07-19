//
//  HardenedURLSession.swift
//  Wevo
//

import Foundation

/// URLSession delegate that refuses redirects which would weaken transport security: a downgrade
/// from https to a non-https scheme, or a redirect to a different host.
///
/// Wevo's API and `/info` traffic has no legitimate reason to be silently bounced to another origin.
/// With ATS disabled by product decision, an unchecked redirect is an easy lever for a hostile
/// server or on-path attacker to move traffic to a plaintext or attacker-controlled endpoint.
/// Same-origin redirects (and an http→https upgrade on the same host) are still followed; anything
/// else is refused, and the task completes with the redirect response instead.
final class RedirectHardeningDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // Compare against the task's *original* request so a chain can never walk off the first
        // host one same-host hop at a time.
        completionHandler(Self.allowsRedirect(from: task.originalRequest?.url, to: request.url) ? request : nil)
    }

    /// Pure redirect policy: follow a redirect only when it stays on the same host and does not
    /// downgrade https to a weaker scheme. A same-host http→https upgrade is allowed.
    static func allowsRedirect(from origin: URL?, to target: URL?) -> Bool {
        guard let origin, let target else { return false }
        let downgrade = origin.scheme?.lowercased() == "https" && target.scheme?.lowercased() != "https"
        let hostChanged = origin.host?.lowercased() != target.host?.lowercased()
        return !(downgrade || hostChanged)
    }
}

extension URLSession {
    /// Shared session that applies `RedirectHardeningDelegate`. Use this instead of `.shared` for
    /// all server/API traffic so a redirect cannot silently downgrade the scheme or cross origins.
    static let wevoHardened: URLSession = {
        URLSession(configuration: .default, delegate: RedirectHardeningDelegate(), delegateQueue: nil)
    }()
}
