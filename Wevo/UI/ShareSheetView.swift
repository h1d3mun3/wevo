//
//  ShareSheetView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI
import os

#if os(iOS)
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        Logger.ui.debug("ShareSheetView: Creating UIActivityViewController")
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif os(macOS)
struct ShareSheetView: NSViewRepresentable {
    let items: [Any]

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        Logger.ui.debug("ShareSheetView: Creating NSView")
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else {
            Logger.ui.warning("ShareSheetView: No window available")
            return
        }

        Logger.ui.debug("ShareSheetView: Showing NSSharingServicePicker")
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: .zero, of: nsView, preferredEdge: .minY)
    }
}
#endif

#Preview("Share Sheet") {
    ShareSheetView(items: ["Preview Item"])
}
