//
//  ShareViewController.swift
//  WevoShareExtension
//

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit

final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        loadSharedText { [weak self] text in
            guard let self else { return }
            DispatchQueue.main.async { self.embedShareUI(text: text) }
        }
    }

    private func embedShareUI(text: String) {
        let content = ShareMainView(sharedText: text) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
        let host = UIHostingController(rootView: content)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        host.didMove(toParent: self)
    }

    private func loadSharedText(completion: @escaping (String) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first
        else { completion(""); return }

        let identifiers = [UTType.plainText.identifier, "public.utf8-plain-text"]
        guard let identifier = identifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
            completion(""); return
        }
        provider.loadItem(forTypeIdentifier: identifier, options: nil) { data, _ in
            completion(data as? String ?? "")
        }
    }
}

#elseif os(macOS)
import AppKit

final class ShareViewController: NSViewController {
    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 560))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        loadSharedText { [weak self] text in
            guard let self else { return }
            DispatchQueue.main.async { self.embedShareUI(text: text) }
        }
    }

    private func embedShareUI(text: String) {
        let content = ShareMainView(sharedText: text) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
        let host = NSHostingController(rootView: content)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func loadSharedText(completion: @escaping (String) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first
        else { completion(""); return }

        let identifiers = [UTType.plainText.identifier, "public.utf8-plain-text"]
        guard let identifier = identifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) else {
            completion(""); return
        }
        provider.loadItem(forTypeIdentifier: identifier, options: nil) { data, _ in
            completion(data as? String ?? "")
        }
    }
}
#endif
