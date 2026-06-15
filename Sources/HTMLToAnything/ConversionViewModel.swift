import AppKit
import Foundation
import HTMLToAnythingCore
import UniformTypeIdentifiers

@MainActor
final class ConversionViewModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case ready(String)
        case converting
        case success(URL)
        case failure(String)

        var message: String {
            switch self {
            case .idle:
                "HTML 파일을 선택하거나 드롭해 주세요."
            case let .ready(message):
                message
            case .converting:
                "변환 중입니다."
            case let .success(url):
                "저장 완료: \(url.lastPathComponent)"
            case let .failure(message):
                message
            }
        }

        var systemImage: String {
            switch self {
            case .idle:
                "tray.and.arrow.down"
            case .ready:
                "checkmark.circle"
            case .converting:
                "arrow.triangle.2.circlepath"
            case .success:
                "checkmark.circle.fill"
            case .failure:
                "exclamationmark.triangle.fill"
            }
        }
    }

    @Published var inputURL: URL?
    @Published var selectedFormat: OutputFormat = .pdf
    @Published var destinationDirectory: URL?
    @Published var status: Status = .idle
    @Published var isConverting = false
    @Published var isDropTargeted = false

    private let service = HTMLConversionService()

    var canConvert: Bool {
        inputURL != nil && destinationDirectory != nil && !isConverting
    }

    var destinationLabel: String {
        destinationDirectory?.path(percentEncoded: false) ?? "입력 파일과 같은 폴더"
    }

    func selectInputFile() {
        let panel = NSOpenPanel()
        panel.title = "HTML 파일 선택"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.html, UTType(filenameExtension: "htm")].compactMap { $0 }

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        setInputFile(url)
    }

    func selectDestinationDirectory() {
        let panel = NSOpenPanel()
        panel.title = "저장 폴더 선택"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        destinationDirectory = url
        status = .ready("저장 폴더가 설정되었습니다.")
    }

    func handleDroppedURLs(_ urls: [URL]) -> Bool {
        guard let url = urls.first else {
            status = .failure("HTML 파일을 드롭해 주세요.")
            return false
        }

        setInputFile(url)
        return true
    }

    func convert() {
        guard let inputURL else {
            status = .failure("먼저 HTML 파일을 선택해 주세요.")
            return
        }

        let outputDirectory = destinationDirectory ?? inputURL.deletingLastPathComponent()

        isConverting = true
        status = .converting

        Task {
            do {
                let outputURL = try await service.convert(
                    inputURL: inputURL,
                    format: selectedFormat,
                    destinationDirectory: outputDirectory
                )
                status = .success(outputURL)
            } catch {
                status = .failure(error.localizedDescription)
            }

            isConverting = false
        }
    }

    func revealOutput() {
        guard case let .success(url) = status else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func reset() {
        inputURL = nil
        destinationDirectory = nil
        status = .idle
    }

    private func setInputFile(_ url: URL) {
        let fileExtension = url.pathExtension.lowercased()
        guard ["html", "htm"].contains(fileExtension) else {
            status = .failure("HTML 또는 HTM 파일만 선택할 수 있습니다.")
            return
        }

        inputURL = url
        destinationDirectory = url.deletingLastPathComponent()
        status = .ready("\(url.lastPathComponent)을 변환할 준비가 되었습니다.")
    }
}
