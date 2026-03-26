# StickyToDo

StickyToDo is a lightweight macOS desktop to-do widget built with SwiftUI. It stays close at hand, keeps your daily tasks visible, and is designed to be fast, minimal, and easy to use.

## Features

- Floating desktop-style task window
- Quick add with the global shortcut `Option + Command + N`
- Mark tasks as done, in progress, or important
- Create and organize tasks with categories
- Compact mode for a smaller always-available view
- Menu bar access and launch-at-login support
- Local persistence between sessions

## Built With

- Swift
- SwiftUI
- Swift Package Manager
- macOS 13+

## Run Locally

```bash
cd StickyToDo
swift build
swift run
```

## Project Structure

```text
StickyToDo/
├── Package.swift
└── Sources/StickyToDo/
```

## Notes

- Tasks and categories are stored locally on your Mac.
- The app is currently set up as a macOS app, not an iPhone or iPad app.

