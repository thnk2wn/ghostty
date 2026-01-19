import Foundation

/// Converts markdown to ANSI-styled terminal output for rich rendering
class MarkdownTerminalRenderer {
    private var buffer: String = ""
    private var inCodeBlock: Bool = false
    private var codeBlockLanguage: String = ""
    private var lastLineType: LineType = .empty

    private enum LineType {
        case empty
        case header
        case codeBlockStart
        case codeBlockContent
        case codeBlockEnd
        case list
        case blockQuote
        case paragraph
    }

    // ANSI escape codes
    private struct ANSI {
        static let esc = "\u{001B}"
        static let reset = "\(esc)[0m"
        static let bold = "\(esc)[1m"
        static let dim = "\(esc)[2m"
        static let italic = "\(esc)[3m"

        // 256-color foreground
        static func fg(_ color: Int) -> String { "\(esc)[38;5;\(color)m" }
        // 256-color background
        static func bg(_ color: Int) -> String { "\(esc)[48;5;\(color)m" }

        // Colors
        static let headerColor = 75      // Light blue
        static let header2Color = 117    // Lighter blue
        static let header3Color = 153    // Even lighter
        static let codeBlockBg = 236     // Dark gray
        static let codeBlockFg = 252     // Light text
        static let codeBorder = 240      // Medium gray
        static let inlineCodeBg = 238    // Dark gray
        static let inlineCodeFg = 252    // Light gray text
        static let quoteBar = 243        // Gray for quote bar
        static let quoteFg = 250         // Light text for quotes
        static let listBullet = 214      // Orange for bullets
    }

    // Box drawing
    private struct Box {
        static let topLeft = "╭"
        static let topRight = "╮"
        static let bottomLeft = "╰"
        static let bottomRight = "╯"
        static let horizontal = "─"
        static let vertical = "│"
    }

    /// Append a chunk and return the formatted output
    func append(_ chunk: String) -> String {
        buffer += chunk

        // Process all complete lines, keep incomplete line in buffer
        var output = ""

        while let newlineIndex = buffer.firstIndex(of: "\n") {
            let line = String(buffer[..<newlineIndex])
            buffer = String(buffer[buffer.index(after: newlineIndex)...])

            let formatted = processLine(line)
            output += formatted + "\r\n"
        }

        return output
    }

    /// Reset for a new block
    func reset() {
        buffer = ""
        inCodeBlock = false
        codeBlockLanguage = ""
        lastLineType = .empty
    }

    /// Flush any remaining content (call at end of stream)
    func flush() -> String {
        guard !buffer.isEmpty else { return "" }

        let remaining = buffer
        buffer = ""

        // If we're in a code block, close it
        if inCodeBlock {
            inCodeBlock = false
            let closeLine = "\(ANSI.fg(ANSI.codeBorder))\(Box.bottomLeft)\(Box.horizontal)\(Box.horizontal)\(ANSI.reset)"
            let codeLine = "\(ANSI.fg(ANSI.codeBorder))\(Box.vertical)\(ANSI.reset) \(ANSI.dim)\(remaining)\(ANSI.reset)"
            return codeLine + "\r\n" + closeLine + "\r\n"
        }

        return processLine(remaining) + "\r\n"
    }

    private func processLine(_ line: String) -> String {
        var prefix = ""

        // Handle code block state
        if line.hasPrefix("```") {
            if inCodeBlock {
                // End of code block - output closing border
                inCodeBlock = false
                lastLineType = .codeBlockEnd
                return "\(ANSI.fg(ANSI.codeBorder))\(Box.bottomLeft)\(Box.horizontal)\(Box.horizontal)\(ANSI.reset)"
            } else {
                // Start of code block - add spacing before
                if lastLineType != .empty {
                    prefix = "\r\n"
                }
                inCodeBlock = true
                codeBlockLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                let label = codeBlockLanguage.isEmpty ? "code" : codeBlockLanguage
                lastLineType = .codeBlockStart
                return prefix + "\(ANSI.fg(ANSI.codeBorder))\(Box.topLeft)\(Box.horizontal)\(Box.horizontal) \(label) \(Box.horizontal)\(Box.horizontal)\(ANSI.reset)"
            }
        }

        if inCodeBlock {
            // Output code line with left border
            lastLineType = .codeBlockContent
            return "\(ANSI.fg(ANSI.codeBorder))\(Box.vertical)\(ANSI.reset) \(ANSI.dim)\(line)\(ANSI.reset)"
        }

        // Empty line
        if line.trimmingCharacters(in: .whitespaces).isEmpty {
            lastLineType = .empty
            return ""
        }

        // Headers - add spacing before (check longer prefixes first)
        if line.hasPrefix("#### ") {
            if lastLineType != .empty {
                prefix = "\r\n"
            }
            lastLineType = .header
            return prefix + renderHeader(String(line.dropFirst(5)), level: 4)
        }
        if line.hasPrefix("### ") {
            if lastLineType != .empty {
                prefix = "\r\n"
            }
            lastLineType = .header
            return prefix + renderHeader(String(line.dropFirst(4)), level: 3)
        }
        if line.hasPrefix("## ") {
            if lastLineType != .empty {
                prefix = "\r\n"
            }
            lastLineType = .header
            return prefix + renderHeader(String(line.dropFirst(3)), level: 2)
        }
        if line.hasPrefix("# ") {
            if lastLineType != .empty {
                prefix = "\r\n"
            }
            lastLineType = .header
            return prefix + renderHeader(String(line.dropFirst(2)), level: 1)
        }

        // Block quotes
        if line.hasPrefix("> ") {
            if lastLineType != .empty && lastLineType != .blockQuote {
                prefix = "\r\n"
            }
            lastLineType = .blockQuote
            return prefix + renderBlockQuote(String(line.dropFirst(2)))
        }
        if line == ">" {
            lastLineType = .blockQuote
            return renderBlockQuote("")
        }

        // Unordered lists
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            if lastLineType != .empty && lastLineType != .list {
                prefix = "\r\n"
            }
            lastLineType = .list
            return prefix + renderListItem(String(line.dropFirst(2)), ordered: false)
        }

        // Ordered lists
        if let match = line.range(of: #"^(\d+)\.\s+"#, options: .regularExpression) {
            if lastLineType != .empty && lastLineType != .list {
                prefix = "\r\n"
            }
            let content = String(line[match.upperBound...])
            let numStr = line[line.startIndex..<match.upperBound]
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: ".", with: "")
            lastLineType = .list
            return prefix + renderListItem(content, ordered: true, number: Int(numStr) ?? 1)
        }

        // Regular paragraph text - add spacing after code blocks or headers
        if lastLineType == .codeBlockEnd || lastLineType == .header {
            prefix = "\r\n"
        }
        lastLineType = .paragraph
        return prefix + renderInlineFormatting(line)
    }

    private func renderHeader(_ text: String, level: Int) -> String {
        let color: Int
        let prefix: String

        switch level {
        case 1:
            color = ANSI.headerColor
            prefix = "▌"
        case 2:
            color = ANSI.header2Color
            prefix = "▸"
        case 3:
            color = ANSI.header3Color
            prefix = "▹"
        default:
            color = ANSI.header3Color
            prefix = "›"
        }

        let formattedText = renderInlineFormatting(text)
        return "\(ANSI.fg(color))\(ANSI.bold)\(prefix) \(formattedText)\(ANSI.reset)"
    }

    private func renderBlockQuote(_ text: String) -> String {
        let formattedText = renderInlineFormatting(text)
        return "\(ANSI.fg(ANSI.quoteBar))│\(ANSI.reset) \(ANSI.fg(ANSI.quoteFg))\(ANSI.italic)\(formattedText)\(ANSI.reset)"
    }

    private func renderListItem(_ text: String, ordered: Bool, number: Int = 1) -> String {
        let formattedText = renderInlineFormatting(text)
        if ordered {
            return "  \(ANSI.fg(ANSI.listBullet))\(number).\(ANSI.reset) \(formattedText)"
        } else {
            return "  \(ANSI.fg(ANSI.listBullet))•\(ANSI.reset) \(formattedText)"
        }
    }

    private func renderInlineFormatting(_ text: String) -> String {
        var result = text

        // Process inline code first (to avoid conflicts)
        result = processInlineCode(result)

        // Bold: **text**
        result = processInlineStyle(result, marker: "**", style: ANSI.bold)

        // Italic: *text* (single asterisk, but not inside words)
        result = processItalic(result)

        return result
    }

    private func processInlineCode(_ text: String) -> String {
        var result = ""
        var remaining = text[...]

        while let start = remaining.firstIndex(of: "`") {
            result += remaining[..<start]
            remaining = remaining[remaining.index(after: start)...]

            if let end = remaining.firstIndex(of: "`") {
                let code = String(remaining[..<end])
                result += "\(ANSI.bg(ANSI.inlineCodeBg))\(ANSI.fg(ANSI.inlineCodeFg)) \(code) \(ANSI.reset)"
                remaining = remaining[remaining.index(after: end)...]
            } else {
                result += "`"
            }
        }
        result += remaining

        return result
    }

    private func processInlineStyle(_ text: String, marker: String, style: String) -> String {
        var result = ""
        var remaining = text[...]

        while let start = remaining.range(of: marker) {
            result += remaining[..<start.lowerBound]
            remaining = remaining[start.upperBound...]

            if let end = remaining.range(of: marker) {
                let content = String(remaining[..<end.lowerBound])
                result += "\(style)\(content)\(ANSI.reset)"
                remaining = remaining[end.upperBound...]
            } else {
                result += marker
            }
        }
        result += remaining

        return result
    }

    private func processItalic(_ text: String) -> String {
        var result = ""
        var i = text.startIndex

        while i < text.endIndex {
            let c = text[i]

            if c == "*" {
                // Check it's not ** (bold)
                let next = text.index(after: i)
                if next < text.endIndex && text[next] == "*" {
                    result += "**"
                    i = text.index(after: next)
                    continue
                }

                // Look for closing *
                if let endRange = text[next...].firstIndex(of: "*") {
                    // Make sure it's not **
                    let afterEnd = text.index(after: endRange)
                    if afterEnd < text.endIndex && text[afterEnd] == "*" {
                        result += String(c)
                        i = next
                        continue
                    }

                    let content = String(text[next..<endRange])
                    result += "\(ANSI.italic)\(content)\(ANSI.reset)"
                    i = text.index(after: endRange)
                    continue
                }
            }

            result += String(c)
            i = text.index(after: i)
        }

        return result
    }
}
