import AppKit
import Foundation
import WebKit

@MainActor
final class HTMLRenderer: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let window: NSWindow
    private var loadContinuation: CheckedContinuation<Void, Error>?

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false

        webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: 1024, height: 768),
            configuration: configuration
        )

        window = NSWindow(
            contentRect: webView.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        super.init()

        webView.navigationDelegate = self
        window.contentView = webView
        window.orderOut(nil)
    }

    func load(fileURL: URL) async throws {
        let readAccessURL = fileURL.deletingLastPathComponent()

        try await withCheckedThrowingContinuation { continuation in
            loadContinuation = continuation
            webView.loadFileURL(fileURL, allowingReadAccessTo: readAccessURL)
        }

        try await waitForRenderSettled()
        let size = try await documentSize()
        webView.setFrameSize(size)
        window.setContentSize(size)
        try await waitForRenderSettled()
    }

    func makePDFData() async throws -> Data {
        let configuration = WKPDFConfiguration()
        configuration.rect = CGRect(origin: .zero, size: webView.bounds.size)

        return try await withCheckedThrowingContinuation { continuation in
            webView.createPDF(configuration: configuration) { result in
                continuation.resume(with: result.mapError { error in
                    HTMLConversionError.renderingFailed(error.localizedDescription)
                })
            }
        }
    }

    func makePNGData() async throws -> Data {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(origin: .zero, size: webView.bounds.size)

        let image: NSImage = try await withCheckedThrowingContinuation { continuation in
            webView.takeSnapshot(with: configuration) { image, error in
                if let error {
                    continuation.resume(throwing: HTMLConversionError.renderingFailed(error.localizedDescription))
                    return
                }

                guard let image else {
                    continuation.resume(throwing: HTMLConversionError.renderingFailed("snapshot image is empty"))
                    return
                }

                continuation.resume(returning: image)
            }
        }

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            throw HTMLConversionError.pngEncodingFailed
        }

        return pngData
    }

    func makeMarkdown() async throws -> String {
        guard let markdown = try await evaluate(Self.markdownJavaScript) as? String else {
            throw HTMLConversionError.markdownExtractionFailed
        }

        return markdown
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            self?.finishLoading(with: .success(()))
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor [weak self] in
            self?.finishLoading(with: .failure(HTMLConversionError.renderingFailed(error.localizedDescription)))
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.finishLoading(with: .failure(HTMLConversionError.renderingFailed(error.localizedDescription)))
        }
    }

    private func finishLoading(with result: Result<Void, Error>) {
        guard let continuation = loadContinuation else {
            return
        }

        loadContinuation = nil
        continuation.resume(with: result)
    }

    private func waitForRenderSettled() async throws {
        try await Task.sleep(nanoseconds: 450_000_000)
    }

    private func documentSize() async throws -> CGSize {
        let width = try await numericJavaScriptResult("""
            Math.max(
              document.body ? document.body.scrollWidth : 0,
              document.documentElement ? document.documentElement.scrollWidth : 0,
              document.documentElement ? document.documentElement.clientWidth : 0,
              1024
            )
            """)

        let height = try await numericJavaScriptResult("""
            Math.max(
              document.body ? document.body.scrollHeight : 0,
              document.documentElement ? document.documentElement.scrollHeight : 0,
              document.documentElement ? document.documentElement.clientHeight : 0,
              768
            )
            """)

        return CGSize(
            width: min(max(width, 612), 2400),
            height: min(max(height, 792), 20000)
        )
    }

    private func numericJavaScriptResult(_ javaScript: String) async throws -> CGFloat {
        let value = try await evaluate(javaScript)

        if let number = value as? NSNumber {
            return CGFloat(truncating: number)
        }

        if let double = value as? Double {
            return CGFloat(double)
        }

        if let string = value as? String, let double = Double(string) {
            return CGFloat(double)
        }

        return 0
    }

    private func evaluate(_ javaScript: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            webView.evaluateJavaScript(javaScript) { value, error in
                if let error {
                    continuation.resume(throwing: HTMLConversionError.renderingFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: value)
                }
            }
        }
    }

    private static let markdownJavaScript = #"""
    (() => {
      const ignoredTags = new Set(["script", "style", "noscript", "template", "meta", "link"]);

      function clean(text) {
        return (text || "")
          .replace(/\u00a0/g, " ")
          .replace(/[ \t\r\n]+/g, " ")
          .trim();
      }

      function inline(node) {
        if (node.nodeType === Node.TEXT_NODE) {
          return clean(node.nodeValue);
        }

        if (node.nodeType !== Node.ELEMENT_NODE) {
          return "";
        }

        const tag = node.tagName.toLowerCase();
        if (ignoredTags.has(tag)) {
          return "";
        }

        if (tag === "br") {
          return "\n";
        }

        if (tag === "img") {
          const alt = clean(node.getAttribute("alt") || "");
          const src = clean(node.getAttribute("src") || "");
          return src ? `![${alt}](${src})` : alt;
        }

        const content = Array.from(node.childNodes)
          .map(inline)
          .filter(Boolean)
          .join(" ")
          .replace(/\s+([,.;:!?])/g, "$1")
          .trim();

        if (!content) {
          return "";
        }

        if (tag === "strong" || tag === "b") {
          return `**${content}**`;
        }

        if (tag === "em" || tag === "i") {
          return `_${content}_`;
        }

        if (tag === "code") {
          return `\`${content.replace(/`/g, "\\`")}\``;
        }

        if (tag === "a") {
          const href = clean(node.getAttribute("href") || "");
          return href ? `[${content}](${href})` : content;
        }

        return content;
      }

      function table(node) {
        const rows = Array.from(node.querySelectorAll("tr"))
          .map(row => Array.from(row.children).map(cell => inline(cell).replace(/\|/g, "\\|")));

        if (rows.length === 0) {
          return "";
        }

        const columnCount = Math.max(...rows.map(row => row.length));
        const normalized = rows.map(row => {
          const copy = row.slice();
          while (copy.length < columnCount) {
            copy.push("");
          }
          return copy;
        });

        const header = normalized[0];
        const separator = Array.from({ length: columnCount }, () => "---");
        const body = normalized.slice(1);

        return [
          `| ${header.join(" | ")} |`,
          `| ${separator.join(" | ")} |`,
          ...body.map(row => `| ${row.join(" | ")} |`)
        ].join("\n") + "\n\n";
      }

      function listItem(node, depth, index) {
        const marker = `${"  ".repeat(depth)}${index ? `${index}.` : "-"} `;
        const ownText = Array.from(node.childNodes)
          .filter(child => !(child.nodeType === Node.ELEMENT_NODE && ["ul", "ol"].includes(child.tagName.toLowerCase())))
          .map(inline)
          .filter(Boolean)
          .join(" ")
          .trim();

        const nested = Array.from(node.children)
          .filter(child => ["ul", "ol"].includes(child.tagName.toLowerCase()))
          .map(child => block(child, depth + 1))
          .join("");

        return `${marker}${ownText}\n${nested}`;
      }

      function block(node, depth = 0) {
        if (node.nodeType === Node.TEXT_NODE) {
          const text = clean(node.nodeValue);
          return text ? `${text}\n\n` : "";
        }

        if (node.nodeType !== Node.ELEMENT_NODE) {
          return "";
        }

        const tag = node.tagName.toLowerCase();
        if (ignoredTags.has(tag)) {
          return "";
        }

        if (/^h[1-6]$/.test(tag)) {
          return `${"#".repeat(Number(tag[1]))} ${inline(node)}\n\n`;
        }

        if (tag === "p") {
          const text = inline(node);
          return text ? `${text}\n\n` : "";
        }

        if (tag === "pre") {
          return `\`\`\`\n${node.innerText.trim()}\n\`\`\`\n\n`;
        }

        if (tag === "blockquote") {
          const quoted = Array.from(node.childNodes).map(child => block(child, depth)).join("").trim();
          return quoted ? quoted.split("\n").map(line => `> ${line}`).join("\n") + "\n\n" : "";
        }

        if (tag === "ul" || tag === "ol") {
          const items = Array.from(node.children)
            .filter(child => child.tagName && child.tagName.toLowerCase() === "li")
            .map((child, offset) => listItem(child, depth, tag === "ol" ? offset + 1 : null))
            .join("");
          return `${items}\n`;
        }

        if (tag === "table") {
          return table(node);
        }

        if (tag === "hr") {
          return "---\n\n";
        }

        if (["body", "main", "article", "section", "header", "footer", "nav", "div"].includes(tag)) {
          return Array.from(node.childNodes).map(child => block(child, depth)).join("");
        }

        const text = inline(node);
        return text ? `${text}\n\n` : "";
      }

      const root = document.body || document.documentElement;
      const markdown = Array.from(root.childNodes)
        .map(node => block(node))
        .join("")
        .replace(/\n{3,}/g, "\n\n")
        .trim();

      return markdown ? `${markdown}\n` : "";
    })()
    """#
}
