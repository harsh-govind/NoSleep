import Cocoa
import IOKit.pwr_mgt
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var assertionID: IOPMAssertionID = 0
    private var toggleItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var statusLine: NSMenuItem!

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())
        toggleItem = NSMenuItem(title: "Never Sleep (even with lid closed)", action: #selector(toggle), keyEquivalent: "s")
        toggleItem.target = self
        menu.addItem(toggleItem)
        loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit NoSleep (setting stays as is)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        statusItem.menu = menu
        refresh()
    }

    /// Reads the system-wide `SleepDisabled` flag from pmset.
    private func sleepDisabled() -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        p.arguments = ["-g"]
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return out.split(separator: "\n").contains { line in
            let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            return parts.count >= 2 && parts[0] == "SleepDisabled" && parts[1] == "1"
        }
    }

    private func refresh() {
        let on = sleepDisabled()
        toggleItem.state = on ? .on : .off
        statusLine.title = on ? "Status: Mac will NOT sleep" : "Status: normal sleep"
        let symbol = on ? "cup.and.saucer.fill" : "moon.zzz"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "NoSleep")
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        if on { holdAssertion() } else { releaseAssertion() }
    }

    private func holdAssertion() {
        guard assertionID == 0 else { return }
        IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
                                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                    "NoSleep keeping Mac awake" as CFString, &assertionID)
    }

    private func releaseAssertion() {
        if assertionID != 0 { IOPMAssertionRelease(assertionID); assertionID = 0 }
    }

    @objc private func toggle() {
        let target = sleepDisabled() ? 0 : 1
        let script = "do shell script \"/usr/bin/pmset -a disablesleep \(target)\" with administrator privileges"
        var err: NSDictionary?
        NSAppleScript(source: script)?.executeAndReturnError(&err)
        if let err = err, (err[NSAppleScript.errorNumber] as? Int) != -128 {
            let a = NSAlert()
            a.messageText = "Couldn't change sleep setting"
            a.informativeText = "\(err[NSAppleScript.errorMessage] ?? err)"
            a.runModal()
        }
        refresh()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let a = NSAlert()
            a.messageText = "Couldn't change login item"
            a.informativeText = error.localizedDescription
            a.runModal()
        }
        refresh()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
