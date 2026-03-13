//
//  CloudKitReloadModifier.swift
//  Wevo
//

import CoreData
import SwiftUI

private struct CloudKitReloadModifier: ViewModifier {
    let action: () -> Void

    func body(content: Content) -> some View {
        content.onReceive(
            NotificationCenter.default.publisher(
                for: NSPersistentCloudKitContainer.eventChangedNotification
            )
        ) { notification in
            guard
                let event = notification.userInfo?[
                    NSPersistentCloudKitContainer.eventNotificationUserInfoKey
                ] as? NSPersistentCloudKitContainer.Event,
                event.type == .import,
                event.succeeded
            else { return }
            action()
        }
    }
}

extension View {
    func onCloudKitImport(perform action: @escaping () -> Void) -> some View {
        modifier(CloudKitReloadModifier(action: action))
    }
}
