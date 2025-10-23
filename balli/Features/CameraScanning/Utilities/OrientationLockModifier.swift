//
//  OrientationLockModifier.swift
//  balli
//
//  View modifier to lock orientation for specific views
//

import SwiftUI

struct OrientationLockModifier: ViewModifier {
    let orientation: UIInterfaceOrientationMask
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                AppDelegate.orientationLock = orientation
                // Force orientation update
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
                }
            }
            .onDisappear {
                AppDelegate.orientationLock = .all
            }
    }
}

extension View {
    func lockOrientation(_ orientation: UIInterfaceOrientationMask) -> some View {
        modifier(OrientationLockModifier(orientation: orientation))
    }
}