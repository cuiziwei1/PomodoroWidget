//
//  PomodoroWidgetApp.swift
//  PomodoroWidget
//
//  Created by 崔紫微 on 2026/2/26.
//

import SwiftUI

extension Notification.Name {
    static let saveTasksNotification = Notification.Name("saveTasksNotification")
}

@main
struct PomodoroWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 300, height: 420)
                .onAppear {
                    guard let window = NSApplication.shared.windows.first else { return }
                    window.isOpaque = false
                    window.backgroundColor = .clear
                    window.titlebarAppearsTransparent = true
                    window.titleVisibility = .hidden
                    window.styleMask.insert(.fullSizeContentView)
                    window.isMovableByWindowBackground = true
                    window.level = .normal
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.post(name: .saveTasksNotification, object: nil)
    }
}
