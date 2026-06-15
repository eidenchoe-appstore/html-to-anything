import HTMLToAnythingCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = ConversionViewModel()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            mainContent
            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "curlybraces.square")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("HTML to Anything")
                    .font(.title3.weight(.semibold))
                Text("PDF, PNG, Markdown, JSP")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                viewModel.reset()
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .help("초기화")
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var mainContent: some View {
        HStack(alignment: .top, spacing: 18) {
            dropZone
            settingsPanel
        }
        .padding(24)
    }

    private var dropZone: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        viewModel.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1.5, dash: [7, 5])
                    )

                VStack(spacing: 12) {
                    Image(systemName: viewModel.inputURL == nil ? "doc.badge.plus" : "doc.text.fill")
                        .font(.system(size: 42, weight: .regular))
                        .foregroundStyle(viewModel.inputURL == nil ? Color.secondary : Color.accentColor)

                    VStack(spacing: 4) {
                        Text(viewModel.inputURL?.lastPathComponent ?? "HTML 파일 드롭")
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.75)

                        Text(viewModel.inputURL?.deletingLastPathComponent().path(percentEncoded: false) ?? "또는 파일 선택 버튼 사용")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .truncationMode(.middle)
                    }

                    Button {
                        viewModel.selectInputFile()
                    } label: {
                        Label("파일 선택", systemImage: "folder")
                    }
                    .controlSize(.large)
                }
                .padding(28)
            }
            .frame(minWidth: 350, minHeight: 280)
            .dropDestination(for: URL.self) { urls, _ in
                viewModel.handleDroppedURLs(urls)
            } isTargeted: { isTargeted in
                viewModel.isDropTargeted = isTargeted
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("저장 형식")
                    .font(.headline)

                Picker("저장 형식", selection: $viewModel.selectedFormat) {
                    ForEach(OutputFormat.allCases) { format in
                        Label(format.displayName, systemImage: format.systemImage)
                            .tag(format)
                    }
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("저장 위치")
                    .font(.headline)

                Text(viewModel.destinationLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    viewModel.selectDestinationDirectory()
                } label: {
                    Label("폴더 선택", systemImage: "folder.badge.gearshape")
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("출력")
                    .font(.headline)
                Label(viewModel.selectedFormat.summary, systemImage: viewModel.selectedFormat.systemImage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(18)
        .frame(width: 260)
        .frame(minHeight: 280)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var footer: some View {
        HStack(spacing: 12) {
            statusLabel

            Spacer()

            if case .success = viewModel.status {
                Button {
                    viewModel.revealOutput()
                } label: {
                    Label("Finder에서 보기", systemImage: "magnifyingglass")
                }
            }

            Button {
                viewModel.convert()
            } label: {
                if viewModel.isConverting {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("변환", systemImage: "arrowshape.turn.up.right.fill")
                }
            }
            .controlSize(.large)
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!viewModel.canConvert)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var statusLabel: some View {
        Label {
            Text(viewModel.status.message)
                .lineLimit(2)
                .truncationMode(.middle)
        } icon: {
            Image(systemName: viewModel.status.systemImage)
                .foregroundStyle(statusColor)
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    private var statusColor: Color {
        switch viewModel.status {
        case .idle:
            .secondary
        case .ready:
            .accentColor
        case .converting:
            .secondary
        case .success:
            .green
        case .failure:
            .red
        }
    }
}

#Preview {
    ContentView()
}
