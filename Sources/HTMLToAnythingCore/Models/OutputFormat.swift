import Foundation

public enum OutputFormat: String, CaseIterable, Hashable, Identifiable, Sendable {
    case pdf
    case png
    case markdown
    case jsp

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .pdf:
            "PDF"
        case .png:
            "PNG"
        case .markdown:
            "Markdown"
        case .jsp:
            "JSP"
        }
    }

    public var fileExtension: String {
        switch self {
        case .pdf:
            "pdf"
        case .png:
            "png"
        case .markdown:
            "md"
        case .jsp:
            "jsp"
        }
    }

    public var systemImage: String {
        switch self {
        case .pdf:
            "doc.richtext"
        case .png:
            "photo"
        case .markdown:
            "text.alignleft"
        case .jsp:
            "curlybraces.square"
        }
    }

    public var summary: String {
        switch self {
        case .pdf:
            "페이지 레이아웃을 PDF 문서로 저장"
        case .png:
            "렌더링된 화면을 PNG 이미지로 저장"
        case .markdown:
            "HTML 문서를 Markdown 텍스트로 저장"
        case .jsp:
            "원본 HTML을 JSP 파일로 저장"
        }
    }
}
