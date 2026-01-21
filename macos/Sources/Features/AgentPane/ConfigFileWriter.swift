import Foundation

/// Helper for reading and writing to the Ghostty config file.
/// Performs smart updates that preserve existing content and comments.
struct ConfigFileWriter {
    /// Get the path to the Ghostty config file
    static var configPath: String {
        let xdgConfig = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"]
            ?? NSString("~/.config").expandingTildeInPath
        return "\(xdgConfig)/ghostty/config"
    }

    /// Update a single key-value pair in the config file.
    /// If the key exists, updates it in place. Otherwise appends to the end.
    static func updateValue(key: String, value: String) {
        updateValues([key: value])
    }

    /// Update multiple key-value pairs in the config file.
    /// For each key: if it exists, updates it in place. Otherwise appends to the end.
    static func updateValues(_ updates: [String: String]) {
        let path = configPath
        let fileManager = FileManager.default

        // Ensure directory exists
        let directory = (path as NSString).deletingLastPathComponent
        if !fileManager.fileExists(atPath: directory) {
            do {
                try fileManager.createDirectory(atPath: directory, withIntermediateDirectories: true)
            } catch {
                print("ConfigFileWriter: Failed to create config directory: \(error)")
                return
            }
        }

        // Read existing content or start fresh
        var lines: [String]
        if fileManager.fileExists(atPath: path),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            lines = content.components(separatedBy: "\n")
        } else {
            lines = []
        }

        // Track which keys we've updated
        var updatedKeys = Set<String>()

        // Update existing lines
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Parse key from line (format: key = value or key=value)
            if let equalsIndex = line.firstIndex(of: "=") {
                let lineKey = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespaces)

                if let newValue = updates[lineKey] {
                    // Preserve any leading whitespace from original line
                    let leadingWhitespace = String(line.prefix(while: { $0.isWhitespace }))
                    lines[index] = "\(leadingWhitespace)\(lineKey) = \(newValue)"
                    updatedKeys.insert(lineKey)
                }
            }
        }

        // Append any keys that weren't found
        let keysToAppend = updates.keys.filter { !updatedKeys.contains($0) }
        if !keysToAppend.isEmpty {
            // Add a blank line before new entries if file doesn't end with one
            if let lastLine = lines.last, !lastLine.isEmpty {
                lines.append("")
            }

            for key in keysToAppend.sorted() {
                if let value = updates[key] {
                    lines.append("\(key) = \(value)")
                }
            }
        }

        // Write back to file
        let content = lines.joined(separator: "\n")
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("ConfigFileWriter: Failed to write config file: \(error)")
        }
    }

    /// Read a value from the config file.
    /// Returns nil if the key doesn't exist or the file can't be read.
    static func readValue(key: String) -> String? {
        let path = configPath

        guard FileManager.default.fileExists(atPath: path),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return nil
        }

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            // Parse key-value pair
            if let equalsIndex = line.firstIndex(of: "=") {
                let lineKey = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
                if lineKey == key {
                    let valueStart = line.index(after: equalsIndex)
                    return String(line[valueStart...]).trimmingCharacters(in: .whitespaces)
                }
            }
        }

        return nil
    }

    /// Remove a key from the config file.
    static func removeValue(key: String) {
        let path = configPath

        guard FileManager.default.fileExists(atPath: path),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return
        }

        var lines = content.components(separatedBy: "\n")
        var modified = false

        lines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Keep comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                return true
            }

            // Check if this is the key to remove
            if let equalsIndex = line.firstIndex(of: "=") {
                let lineKey = String(line[..<equalsIndex]).trimmingCharacters(in: .whitespaces)
                if lineKey == key {
                    modified = true
                    return false
                }
            }

            return true
        }

        if modified {
            let newContent = lines.joined(separator: "\n")
            try? newContent.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}
