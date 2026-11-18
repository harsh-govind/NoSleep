import Cocoa
import IOKit.pwr_mgt
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var assertionID: IOPMAssertionID = 0
    private var loginItem: NSMenuItem!
    private var toggleSwitch: NSSwitch!
    private var stateLabel: NSTextField!

    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self

        // Header: title + status on the left, on/off switch on the right.
        let header = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 52))
        let title = NSTextField(labelWithString: "NoSleep")
        title.font = .boldSystemFont(ofSize: 13)
        title.frame = NSRect(x: 14, y: 26, width: 180, height: 18)
        stateLabel = NSTextField(labelWithString: "")
        stateLabel.font = .systemFont(ofSize: 11)
        stateLabel.textColor = .secondaryLabelColor
        stateLabel.frame = NSRect(x: 14, y: 8, width: 190, height: 16)
        toggleSwitch = NSSwitch(frame: NSRect(x: 204, y: 14, width: 42, height: 24))
        toggleSwitch.target = self
        toggleSwitch.action = #selector(toggle)
        [title, stateLabel, toggleSwitch].forEach { header.addSubview($0) }
        let headerItem = NSMenuItem()
        headerItem.view = header
        menu.addItem(headerItem)
        menu.addItem(.separator())

        // Options below the switch.
        loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit NoSleep", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu

        // Keep the setting on while the user wants it on: re-check every few seconds and after every wake.
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.enforce() }
        let ws = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            ws.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.enforce() }
        }
        enforce()
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    /// What the user last chose with the switch (remembered across restarts).
    private var wantOn: Bool {
        get { UserDefaults.standard.bool(forKey: "wantOn") }
        set { UserDefaults.standard.set(newValue, forKey: "wantOn") }
    }

    /// If the user wants NoSleep on but something turned the system setting off, turn it back on.
    private func enforce() {
        if wantOn && !sleepDisabled() {
            let ok = runQuiet("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", "1"])
            log("SleepDisabled was reset to 0 by something else; re-applied: \(ok ? "ok" : "FAILED (passwordless rule missing?)")")
        }
        refresh()
    }

    @discardableResult
    private func runQuiet(_ path: String, _ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = Pipe(); p.standardError = Pipe()
        guard (try? p.run()) != nil else { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    /// Appends a line to ~/Library/Logs/NoSleep.log.
    private func log(_ msg: String) {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/NoSleep.log")
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(msg)\n"
        if let h = try? FileHandle(forWritingTo: url) {
            h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
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
        statusItem.button?.toolTip = on ? "NoSleep: ON" : "NoSleep: OFF"
        stateLabel.stringValue = on ? "On: Mac will not sleep" : "Off: normal sleep"
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
        // Close the menu first: while it's tracking, the password dialog can't take keyboard focus.
        statusItem.menu?.cancelTracking()
        // Run after the menu has fully closed, with the app frontmost so the dialog gets the keyboard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.applyToggle()
        }
    }

    private func applyToggle() {
        let target = sleepDisabled() ? 0 : 1
        // If the user installed the passwordless rule (see README), this succeeds with no prompt.
        if runQuiet("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", "\(target)"]) {
            wantOn = target == 1
            log("Switched \(target == 1 ? "ON" : "OFF")")
            refresh(); return
        }
        let script = "do shell script \"/usr/bin/pmset -a disablesleep \(target)\" with administrator privileges"
        // Run the admin prompt in a separate osascript process, off the main thread, so the
        // app's UI never blocks while macOS's password dialog is up.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", script]
            let errPipe = Pipe()
            p.standardError = errPipe
            p.standardOutput = Pipe()
            try? p.run()
            p.waitUntilExit()
            let errText = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                // -128 = user clicked "Don't Allow"; stay quiet in that case.
                if p.terminationStatus != 0 && !errText.contains("-128") {
                    let a = NSAlert()
                    a.messageText = "Couldn't change sleep setting"
                    a.informativeText = errText
                    a.runModal()
                }
                if let self = self {
                    self.wantOn = self.sleepDisabled()
                    self.log("Switched \(self.wantOn ? "ON" : "OFF") (password prompt)")
                    self.refresh()
                }
            }
        }
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
