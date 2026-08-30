# FicWrite

**FicWrite** is a distraction-free text editor designed specifically for writing fiction.

It runs in a terminal, is written in **Free Pascal**, and is intended to be portable across platforms. Its interface is deliberately keyboard-oriented and keeps the writer's attention on the text rather than on the editor.

## Features

* Terminal-based TUI
* Cross-platform design
* Plain-text documents
* Keyboard-driven editing
* WordStar-style block operations
* Paragraph-oriented editing
* Automatic text reflow

## Design

FicWrite is built around a separation between the document and its presentation.

The document model understands paragraphs and cursor positions. The terminal interface handles editing and input, while a separate screen representation handles word wrapping and display.
The goal is to keep the editor simple, predictable, and responsive while avoiding unnecessary dependencies on desktop GUI systems.

FicWrite does **not** require an operating-system clipboard for its normal block operations. Copying a block inserts the copied text at the current cursor position, following the classic WordStar model.

## Status

The core editor is functional and has undergone some manual testing, including:

* Cursor movement at document boundaries
* Paragraph creation and deletion
* Empty documents and empty paragraphs
* Scrolling and word wrapping
* Terminal resizing
* Block operations
* File loading and saving
* GPM mouse interaction (sketchy at best)
* Testing with multiple terminal emulators, as well as Linux tty.

## Building

FicWrite is written in Pascal and is currently developed using:

* Free Pascal Compiler 3.2.2
* Linux
* Terminal-based development environment

A basic build can be performed with:

```bash
fpc ficwrite.pas
```

The source is intended to remain portable rather than being tied to a particular IDE.

## License

FicWrite is free software released under the **GNU General Public License, version 3**.

See [`LICENSE`](LICENSE) for the complete license.

---

*FicWrite: writing without the furniture.*
