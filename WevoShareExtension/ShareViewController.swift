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
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    private func loadSharedText(completion: @escaping (String) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first
        else { completion(""); return }

        let identifier = UTType.plainText.identifier
        guard provider.hasItemConformingToTypeIdentifier(identifier) else {
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
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.width, .height]
        view.addSubview(host.view)
    }

    private func loadSharedText(completion: @escaping (String) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first
        else { completion(""); return }

        let identifier = UTType.plainText.identifier
        guard provider.hasItemConformingToTypeIdentifier(identifier) else {
            completion(""); return
        }
        provider.loadItem(forTypeIdentifier: identifier, options: nil) { data, _ in
            completion(data as? String ?? "")
        }
    }
}
#endif
