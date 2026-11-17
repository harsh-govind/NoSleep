import Cocoa
import IOKit.pwr_mgt
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var assertionID: IOPMAssertionID = 0
    private var toggleItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    private var statusLine: NSMenuItem!

    private var menu: NSMenu!
    private var toggleSwitch: NSSwitch!

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Left-click toggles; right-click (or ctrl-click) opens the menu.
        statusItem.button?.target = self
        statusItem.button?.action = #selector(iconClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        menu = NSMenu()
        statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        menu.addItem(.separator())

        // A row with a label and an on/off switch.
        let row = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 32))
        let label = NSTextField(labelWithString: "Never Sleep (lid closed too)")
        label.font = NSFont.menuFont(ofSize: 0)
        label.frame = NSRect(x: 14, y: 8, width: 190, height: 18)
        toggleSwitch = NSSwitch(frame: NSRect(x: 205, y: 4, width: 42, height: 24))
        toggleSwitch.target = self
        toggleSwitch.action = #selector(toggle)
        row.addSubview(label); row.addSubview(toggleSwitch)
        toggleItem = NSMenuItem()
        toggleItem.view = row
        menu.addItem(toggleItem)

        loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        let hint = NSMenuItem(title: "Tip: left-click the icon to toggle", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(NSMenuItem(title: "Quit NoSleep (setting stays as is)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        refresh()
    }

    @objc private func iconClicked() {
        let e = NSApp.currentEvent
        if e?.type == .rightMouseUp || e?.modifierFlags.contains(.control) == true {
            refresh()
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggle()
        }
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
        toggleSwitch.state = on ? .on : .off
        statusItem.button?.toolTip = on ? "NoSleep: ON (click to turn off)" : "NoSleep: OFF (click to turn on)"
        statusLine.title = on ? "NoSleep is ON: Mac will not sleep" : "NoSleep is OFF: normal sleep"
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
