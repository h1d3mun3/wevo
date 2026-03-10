//
//  ShareSheetView.swift
//  Wevo
//
//  Created by hidemune on 3/10/26.
//

import SwiftUI

#if os(iOS)
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        print("📤 ShareSheetView: Creating UIActivityViewController with items: \(items)")
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif os(macOS)
struct ShareSheetView: NSViewRepresentable {
    let items: [Any]

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        print("📤 ShareSheetView: Creating NSView with items: \(items)")
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let window = nsView.window else {
            print("⚠️ ShareSheetView: No window available")
            return
        }

        print("📤 ShareSheetView: Showing NSSharingServicePicker")
        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: .zero, of: nsView, preferredEdge: .minY)
    }
}
#endif

#Preview("Share Sheet") {
    ShareSheetView(items: ["Preview Item"])
}
