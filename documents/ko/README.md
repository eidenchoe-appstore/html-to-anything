# HTML to Anything

HTML to Anything는 로컬 `.html` 또는 `.htm` 파일을 PDF, PNG, Markdown, JSP로 변환하는 작은 macOS 앱입니다.

[최신 DMG 다운로드](https://github.com/eidenchoe-appstore/html-to-anything/releases/latest/download/HTMLToAnything.dmg)

![HTML to Anything 앱 미리보기](../../assets/app-preview.png)

## 주요 기능

| 형식 | 결과물 | 에셋 처리 |
| --- | --- | --- |
| PDF | 렌더링된 문서 | HTML과 같은 폴더의 상대 경로 에셋을 반영 |
| PNG | 렌더링된 이미지 | HTML과 같은 폴더의 상대 경로 에셋을 반영 |
| Markdown | `.md` 텍스트 파일 | 로컬 에셋을 `<파일명>_assets/`로 복사하고 참조 경로 재작성 |
| JSP | `.jsp` 파일 | 로컬 에셋을 `<파일명>_assets/`로 복사하고 HTML 참조 경로 재작성 |

## 사용 방법

1. **HTML to Anything** 앱을 엽니다.
2. `.html` 또는 `.htm` 파일을 드롭 영역에 끌어다 놓거나 **파일 선택**을 눌러 직접 선택합니다.
3. 오른쪽 패널에서 저장 형식을 선택합니다.
4. 기본 저장 위치를 그대로 쓰거나 **폴더 선택**으로 다른 폴더를 지정합니다.
5. **변환**을 누릅니다.
6. 변환 완료 후 **Finder에서 보기**로 결과 파일을 바로 확인합니다.

## 출력 방식

앱은 기존 결과 파일을 덮어쓰지 않습니다. 같은 이름의 파일이 이미 있으면 다음처럼 번호를 붙여 저장합니다.

```text
report.pdf
report-1.pdf
report-2.pdf
```

Markdown과 JSP는 HTML에서 참조한 로컬 에셋을 결과 파일 옆의 에셋 폴더로 복사합니다. 따라서 이미지, CSS, 폰트 파일을 따로 직접 복사하지 않아도 변환 결과와 함께 보관할 수 있습니다.

## 에셋 포함 HTML 처리

HTML 파일은 보통 다음과 같은 로컬 에셋 폴더와 함께 사용됩니다.

```text
report.html
assets/style.css
assets/logo.png
images/chart.png
```

PDF와 PNG는 WebKit 렌더링 단계에서 HTML 파일의 부모 폴더를 읽어 CSS, 이미지, 폰트 등을 반영합니다.

Markdown과 JSP는 결과 파일 옆에 에셋 폴더를 만들고, 참조 경로를 새 위치에 맞게 바꿉니다.

```text
report.md
report_assets/assets/logo.png
report_assets/images/chart.png
```

외부 URL, `data:` URL, `mailto:`, `tel:`, 페이지 내부 앵커 링크는 그대로 둡니다.

## 요구 사항

- macOS 14 이상
- 별도 CLI 변환 도구 필요 없음

## 개발 및 검증

```bash
swift test
./script/build_and_run.sh --verify
./script/package_dmg.sh
```

DMG 결과물:

```text
dist/HTMLToAnything.dmg
```

## 릴리스

현재 버전: `1.0.1`

앱 아이콘은 `icon.icon/Assets/icon.png`를 기반으로 빌드 시 `.icns`로 생성되어 앱 번들에 등록됩니다.

## 라이선스

Apache License 2.0
