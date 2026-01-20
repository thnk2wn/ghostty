import SwiftUI
import AppKit

/// Renders markdown content with rich formatting, code blocks, and copy functionality
struct RichMarkdownView: View {
    let content: String
    let showLineNumbers: Bool

    init(content: String, showLineNumbers: Bool = true) {
        self.content = content
        self.showLineNumbers = showLineNumbers
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(parseMarkdown().enumerated()), id: \.offset) { _, element in
                switch element {
                case .header(let level, let text):
                    HeaderView(level: level, text: text)
                case .paragraph(let text):
                    ParagraphView(text: text)
                case .codeBlock(let language, let code):
                    CodeBlockView(language: language, code: code, showLineNumbers: showLineNumbers)
                case .list(let items, let ordered):
                    ListView(items: items, ordered: ordered)
                case .blockQuote(let text):
                    BlockQuoteView(text: text)
                }
            }
        }
    }

    private func parseMarkdown() -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        var lines = content.components(separatedBy: "\n")
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Code block
            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                index += 1

                while index < lines.count && !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }

                elements.append(.codeBlock(language: language, code: codeLines.joined(separator: "\n")))
                index += 1
                continue
            }

            // Headers
            if trimmed.hasPrefix("#### ") {
                elements.append(.header(level: 4, text: String(trimmed.dropFirst(5))))
                index += 1
                continue
            }
            if trimmed.hasPrefix("### ") {
                elements.append(.header(level: 3, text: String(trimmed.dropFirst(4))))
                index += 1
                continue
            }
            if trimmed.hasPrefix("## ") {
                elements.append(.header(level: 2, text: String(trimmed.dropFirst(3))))
                index += 1
                continue
            }
            if trimmed.hasPrefix("# ") {
                elements.append(.header(level: 1, text: String(trimmed.dropFirst(2))))
                index += 1
                continue
            }

            // Block quote
            if trimmed.hasPrefix("> ") {
                var quoteLines: [String] = []
                while index < lines.count {
                    let qLine = lines[index].trimmingCharacters(in: .whitespaces)
                    if qLine.hasPrefix("> ") {
                        quoteLines.append(String(qLine.dropFirst(2)))
                        index += 1
                    } else if qLine == ">" {
                        quoteLines.append("")
                        index += 1
                    } else {
                        break
                    }
                }
                elements.append(.blockQuote(text: quoteLines.joined(separator: "\n")))
                continue
            }

            // Unordered list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                var listItems: [(number: Int, text: String)] = []
                while index < lines.count {
                    let lLine = lines[index].trimmingCharacters(in: .whitespaces)
                    if lLine.hasPrefix("- ") {
                        listItems.append((number: listItems.count + 1, text: String(lLine.dropFirst(2))))
                        index += 1
                    } else if lLine.hasPrefix("* ") {
                        listItems.append((number: listItems.count + 1, text: String(lLine.dropFirst(2))))
                        index += 1
                    } else if lLine.isEmpty {
                        index += 1
                        break
                    } else {
                        break
                    }
                }
                elements.append(.list(items: listItems, ordered: false))
                continue
            }

            // Ordered list - extract actual number from markdown
            if let _ = trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                var listItems: [(number: Int, text: String)] = []
                while index < lines.count {
                    let lLine = lines[index].trimmingCharacters(in: .whitespaces)
                    if let match = lLine.range(of: #"^(\d+)\.\s+"#, options: .regularExpression),
                       let numMatch = lLine.range(of: #"^\d+"#, options: .regularExpression) {
                        let numStr = String(lLine[numMatch])
                        let num = Int(numStr) ?? (listItems.count + 1)
                        listItems.append((number: num, text: String(lLine[match.upperBound...])))
                        index += 1
                    } else if lLine.isEmpty {
                        index += 1
                        break
                    } else {
                        break
                    }
                }
                elements.append(.list(items: listItems, ordered: true))
                continue
            }

            // Empty line - skip
            if trimmed.isEmpty {
                index += 1
                continue
            }

            // Paragraph - collect consecutive non-special lines
            var paragraphLines: [String] = []
            while index < lines.count {
                let pLine = lines[index]
                let pTrimmed = pLine.trimmingCharacters(in: .whitespaces)

                if pTrimmed.isEmpty ||
                   pTrimmed.hasPrefix("#") ||
                   pTrimmed.hasPrefix("```") ||
                   pTrimmed.hasPrefix("> ") ||
                   pTrimmed.hasPrefix("- ") ||
                   pTrimmed.hasPrefix("* ") ||
                   pTrimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                    break
                }

                paragraphLines.append(pLine)
                index += 1
            }

            if !paragraphLines.isEmpty {
                elements.append(.paragraph(text: paragraphLines.joined(separator: " ")))
            }
        }

        return elements
    }
}

// MARK: - Markdown Elements

enum MarkdownElement {
    case header(level: Int, text: String)
    case paragraph(text: String)
    case codeBlock(language: String, code: String)
    case list(items: [(number: Int, text: String)], ordered: Bool)
    case blockQuote(text: String)
}

// MARK: - Header View

struct HeaderView: View {
    let level: Int
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            headerIcon
                .foregroundColor(headerColor)
            Text(parseInlineFormatting(text))
                .font(headerFont)
                .fontWeight(.semibold)
                .foregroundColor(headerColor)
        }
    }

    private var headerIcon: some View {
        Group {
            switch level {
            case 1: Text("▌")
            case 2: Text("▸")
            case 3: Text("▹")
            default: Text("›")
            }
        }
    }

    private var headerFont: Font {
        switch level {
        case 1: return .title2
        case 2: return .title3
        case 3: return .headline
        default: return .subheadline
        }
    }

    private var headerColor: Color {
        switch level {
        case 1: return Color(red: 0.4, green: 0.6, blue: 1.0)
        case 2: return Color(red: 0.5, green: 0.7, blue: 1.0)
        case 3: return Color(red: 0.6, green: 0.75, blue: 1.0)
        default: return Color(red: 0.65, green: 0.8, blue: 1.0)
        }
    }
}

// MARK: - Paragraph View

struct ParagraphView: View {
    let text: String

    var body: some View {
        Text(parseInlineFormatting(text))
            .font(.body)
            .textSelection(.enabled)
    }
}

// MARK: - Code Block View

struct CodeBlockView: View {
    let language: String
    let code: String
    let showLineNumbers: Bool
    @State private var isHovering = false
    @State private var copied = false

    private var lines: [String] {
        code.components(separatedBy: "\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header bar
            HStack {
                Text(language.isEmpty ? "code" : language)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)

                Spacer()

                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Copied" : "Copy")
                    }
                    .font(.caption)
                    .foregroundColor(copied ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .opacity(isHovering || copied ? 1 : 0.6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    if showLineNumbers {
                        // Line numbers column
                        VStack(alignment: .trailing, spacing: 0) {
                            ForEach(1...max(lines.count, 1), id: \.self) { num in
                                Text("\(num)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .frame(height: 18)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))

                        Divider()
                    }

                    // Code content with syntax highlighting
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                            Text(SyntaxHighlighter.highlight(line: line, language: language))
                                .font(.system(size: 13, design: .monospaced))
                                .frame(height: 18, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .textSelection(.enabled)
                }
            }
            .background(Color(NSColor.textBackgroundColor).opacity(0.3))
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }
}

// MARK: - Syntax Highlighter

struct SyntaxHighlighter {
    // Colors for syntax highlighting
    static let keywordColor = Color(red: 0.8, green: 0.4, blue: 0.8)      // Purple for keywords
    static let stringColor = Color(red: 0.8, green: 0.6, blue: 0.4)       // Orange for strings
    static let commentColor = Color(red: 0.5, green: 0.6, blue: 0.5)      // Gray-green for comments
    static let numberColor = Color(red: 0.7, green: 0.8, blue: 0.5)       // Yellow-green for numbers
    static let typeColor = Color(red: 0.4, green: 0.7, blue: 0.8)         // Cyan for types
    static let functionColor = Color(red: 0.6, green: 0.7, blue: 1.0)     // Light blue for functions
    static let variableColor = Color(red: 0.9, green: 0.9, blue: 0.9)     // White for variables

    // Keywords by language family
    static let shellKeywords = Set(["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "in", "function", "return", "exit", "export", "local", "readonly", "shift", "source", "alias", "unalias", "set", "unset", "trap", "eval", "exec", "true", "false"])

    static let cLikeKeywords = Set(["if", "else", "for", "while", "do", "switch", "case", "break", "continue", "return", "void", "int", "char", "float", "double", "long", "short", "unsigned", "signed", "const", "static", "extern", "struct", "enum", "typedef", "union", "sizeof", "goto", "default", "volatile", "register", "auto", "inline", "restrict", "bool", "true", "false", "null", "nil", "NULL"])

    static let pythonKeywords = Set(["if", "elif", "else", "for", "while", "try", "except", "finally", "with", "as", "def", "class", "return", "yield", "import", "from", "pass", "break", "continue", "raise", "assert", "del", "in", "is", "not", "and", "or", "lambda", "global", "nonlocal", "True", "False", "None", "async", "await"])

    static let jsKeywords = Set(["if", "else", "for", "while", "do", "switch", "case", "break", "continue", "return", "function", "var", "let", "const", "class", "extends", "new", "this", "super", "import", "export", "from", "default", "try", "catch", "finally", "throw", "async", "await", "yield", "typeof", "instanceof", "in", "of", "true", "false", "null", "undefined"])

    static let swiftKeywords = Set(["if", "else", "for", "while", "repeat", "switch", "case", "break", "continue", "return", "func", "var", "let", "class", "struct", "enum", "protocol", "extension", "import", "public", "private", "internal", "fileprivate", "open", "static", "final", "override", "init", "deinit", "self", "Self", "super", "true", "false", "nil", "guard", "defer", "do", "try", "catch", "throw", "throws", "rethrows", "async", "await", "actor", "some", "any", "where", "associatedtype", "typealias", "inout", "mutating", "nonmutating", "lazy", "weak", "unowned", "willSet", "didSet", "get", "set"])

    static let rustKeywords = Set(["if", "else", "for", "while", "loop", "match", "break", "continue", "return", "fn", "let", "mut", "const", "static", "struct", "enum", "impl", "trait", "type", "use", "mod", "pub", "crate", "self", "Self", "super", "true", "false", "as", "ref", "move", "async", "await", "dyn", "where", "unsafe", "extern"])

    static let goKeywords = Set(["if", "else", "for", "switch", "case", "break", "continue", "return", "func", "var", "const", "type", "struct", "interface", "map", "chan", "go", "select", "defer", "package", "import", "range", "default", "fallthrough", "goto", "true", "false", "nil", "iota"])

    static func highlight(line: String, language: String) -> AttributedString {
        if line.isEmpty { return AttributedString(" ") }

        var result = AttributedString(line)

        let lang = language.lowercased()

        // Determine keyword set based on language
        let keywords: Set<String>
        switch lang {
        case "bash", "sh", "shell", "zsh":
            keywords = shellKeywords
        case "python", "py":
            keywords = pythonKeywords
        case "javascript", "js", "typescript", "ts":
            keywords = jsKeywords
        case "swift":
            keywords = swiftKeywords
        case "rust", "rs":
            keywords = rustKeywords
        case "go", "golang":
            keywords = goKeywords
        case "c", "cpp", "c++", "h", "hpp", "java", "cs", "csharp":
            keywords = cLikeKeywords
        default:
            keywords = cLikeKeywords.union(shellKeywords)
        }

        // Highlight comments (do this first so they override other highlighting)
        highlightComments(in: &result, line: line, language: lang)

        // Highlight strings
        highlightStrings(in: &result, line: line)

        // Highlight numbers
        highlightNumbers(in: &result, line: line)

        // Highlight keywords
        highlightKeywords(in: &result, line: line, keywords: keywords)

        return result
    }

    private static func highlightComments(in result: inout AttributedString, line: String, language: String) {
        // Single line comments
        let commentPatterns: [String]
        switch language {
        case "python", "py", "bash", "sh", "shell", "zsh":
            commentPatterns = ["#"]
        default:
            commentPatterns = ["//", "#"]
        }

        for pattern in commentPatterns {
            if let range = line.range(of: pattern) {
                let commentStart = line.distance(from: line.startIndex, to: range.lowerBound)
                if let attrRange = result.range(of: String(line[range.lowerBound...])) {
                    result[attrRange].foregroundColor = commentColor
                }
            }
        }
    }

    private static func highlightStrings(in result: inout AttributedString, line: String) {
        // Double-quoted strings
        if let regex = try? NSRegularExpression(pattern: "\"[^\"]*\"", options: []) {
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            for match in matches {
                if let range = Range(match.range, in: line),
                   let attrRange = result.range(of: String(line[range])) {
                    result[attrRange].foregroundColor = stringColor
                }
            }
        }

        // Single-quoted strings
        if let regex = try? NSRegularExpression(pattern: "'[^']*'", options: []) {
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            for match in matches {
                if let range = Range(match.range, in: line),
                   let attrRange = result.range(of: String(line[range])) {
                    result[attrRange].foregroundColor = stringColor
                }
            }
        }
    }

    private static func highlightNumbers(in result: inout AttributedString, line: String) {
        if let regex = try? NSRegularExpression(pattern: "\\b\\d+(\\.\\d+)?\\b", options: []) {
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            for match in matches {
                if let range = Range(match.range, in: line),
                   let attrRange = result.range(of: String(line[range])) {
                    result[attrRange].foregroundColor = numberColor
                }
            }
        }
    }

    private static func highlightKeywords(in result: inout AttributedString, line: String, keywords: Set<String>) {
        // Match word boundaries
        if let regex = try? NSRegularExpression(pattern: "\\b([a-zA-Z_][a-zA-Z0-9_]*)\\b", options: []) {
            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
            for match in matches {
                if let range = Range(match.range, in: line) {
                    let word = String(line[range])
                    if keywords.contains(word) {
                        if let attrRange = result.range(of: word) {
                            result[attrRange].foregroundColor = keywordColor
                        }
                    }
                }
            }
        }
    }
}

// MARK: - List View

struct ListView: View {
    let items: [(number: Int, text: String)]
    let ordered: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    if ordered {
                        Text("\(item.number).")
                            .font(.body)
                            .foregroundColor(Color.orange)
                            .frame(minWidth: 24, alignment: .trailing)
                    } else {
                        Text("•")
                            .font(.body)
                            .foregroundColor(Color.orange)
                            .frame(minWidth: 24, alignment: .center)
                    }
                    Text(parseInlineFormatting(item.text))
                        .font(.body)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.leading, 8)
    }
}

// MARK: - Block Quote View

struct BlockQuoteView: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: 3)

            Text(parseInlineFormatting(text))
                .font(.body)
                .italic()
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Inline Formatting

private func parseInlineFormatting(_ text: String) -> AttributedString {
    var result = AttributedString(text)

    // Process inline code: `code`
    if let codeRegex = try? NSRegularExpression(pattern: "`([^`]+)`", options: []) {
        let nsText = text as NSString
        let matches = codeRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        for match in matches.reversed() {
            if match.numberOfRanges > 1 {
                let fullRange = Range(match.range, in: text)!
                let codeContent = String(text[Range(match.range(at: 1), in: text)!])

                var codeAttr = AttributedString(codeContent)
                codeAttr.font = .system(.body, design: .monospaced)
                codeAttr.backgroundColor = Color(NSColor.controlBackgroundColor)

                if let attrRange = result.range(of: String(text[fullRange])) {
                    result.replaceSubrange(attrRange, with: codeAttr)
                }
            }
        }
    }

    // Process bold: **text**
    if let boldRegex = try? NSRegularExpression(pattern: "\\*\\*([^*]+)\\*\\*", options: []) {
        let nsText = text as NSString
        let matches = boldRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        for match in matches.reversed() {
            if match.numberOfRanges > 1 {
                let fullRange = Range(match.range, in: text)!
                let boldContent = String(text[Range(match.range(at: 1), in: text)!])

                var boldAttr = AttributedString(boldContent)
                boldAttr.font = .body.bold()

                if let attrRange = result.range(of: String(text[fullRange])) {
                    result.replaceSubrange(attrRange, with: boldAttr)
                }
            }
        }
    }

    // Process italic: *text* (single asterisks, not double)
    if let italicRegex = try? NSRegularExpression(pattern: "(?<!\\*)\\*([^*]+)\\*(?!\\*)", options: []) {
        let nsText = text as NSString
        let matches = italicRegex.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length))

        for match in matches.reversed() {
            if match.numberOfRanges > 1 {
                let fullRange = Range(match.range, in: text)!
                let italicContent = String(text[Range(match.range(at: 1), in: text)!])

                var italicAttr = AttributedString(italicContent)
                italicAttr.font = .body.italic()

                if let attrRange = result.range(of: String(text[fullRange])) {
                    result.replaceSubrange(attrRange, with: italicAttr)
                }
            }
        }
    }

    return result
}

// MARK: - Preview

#Preview {
    ScrollView {
        RichMarkdownView(content: """
            # Main Header

            This is a paragraph with **bold** and *italic* text, plus `inline code`.

            ## Secondary Header

            Here's a code block:

            ```swift
            func hello() {
                print("Hello, world!")
            }
            ```

            ### List Example

            - First item
            - Second item
            - Third item

            > This is a block quote
            > spanning multiple lines

            1. Numbered item one
            2. Numbered item two
            """)
        .padding()
    }
    .frame(width: 600, height: 800)
}
