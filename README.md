# HTML to Anything

HTML to Anything is a small macOS app for converting a local `.html` or `.htm` file into PDF, PNG, Markdown, or JSP.

[Download latest DMG](https://github.com/eidenchoe-appstore/html-to-anything/releases/latest/download/HTMLToAnything.dmg)

## Features

| Input | Output |
| --- | --- |
| Local HTML or HTM file | PDF document |
| Local HTML or HTM file | PNG image |
| Local HTML or HTM file | Markdown text |
| Local HTML or HTM file | JSP file |

## Requirements

- macOS 14 or later
- No external command-line converter is required

## Usage

1. Drag an HTML file into the app, or click **파일 선택**.
2. Choose PDF, PNG, Markdown, or JSP.
3. Keep the default output folder or choose another folder.
4. Click **변환**.

The JSP output keeps the original HTML content and saves it with a `.jsp` extension.

## Development

```bash
swift build
./script/build_and_run.sh --verify
./script/package_dmg.sh
```

The packaged DMG is written to:

```text
dist/HTMLToAnything.dmg
```

## Release

Version: `1.0.0`
