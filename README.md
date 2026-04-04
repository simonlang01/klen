# Plink

A minimalist, ultra-fast macOS ToDo app focused on quick capture via a global keyboard shortcut.

**Current version:** 1.5.1 · macOS 14+

---

## Features

- Global shortcut to instantly capture tasks (default: `N + Space`)
- Dashboard with open, overdue, and future tasks
- Task groups, priorities, and due dates
- Smart Input — natural language date parsing (e.g. "dentist tomorrow")
- Full Dark / Light / System appearance support
- Accent color theming
- English and German localization
- Search across active and completed tasks
- Trash with permanent delete
- Auto-updates via Sparkle

---

## Tech Stack

- **Language:** Swift
- **UI:** SwiftUI
- **Persistence:** SwiftData
- **Auto-updates:** [Sparkle 2](https://sparkle-project.org)
- **Shortcuts:** [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts)
- **Project generation:** XcodeGen (`project.yml`)

---

## Branch Structure

```
main   ← production only. Sparkle update feed reads this branch.
dev    ← all development happens here
```

Never develop directly on `main`. All code changes go to `dev` first.

---

## Development

Open the project and build the **Debug** scheme. This runs as **Plink Dev** with a separate data store — completely isolated from the production app.

```bash
# Regenerate .xcodeproj after changing project.yml:
xcodegen generate
```

---

## Releasing a New Version

When `dev` is stable and ready to ship, run from the repo root:

```bash
./ship.sh <version> <build>
# Example:
./ship.sh 1.6 3
```

This will:
1. Verify you're on `dev` with no uncommitted changes
2. Merge `dev` → `main`
3. Build the Release configuration
4. Create and sign the DMG
5. Update `appcast.xml`
6. Push everything to GitHub
7. Switch back to `dev`

Then follow the printed instructions to create the GitHub Release and upload the DMG.

### Build number convention
Always increment the build number with each release. Sparkle uses it (not the version string) to detect updates.

| Version | Build |
|---|---|
| 1.5 | 1 |
| 1.5.1 | 2 |
| 1.6 | 3 |
| … | +1 |

---

## Localization

Strings are managed in `Plink/Core/Localizable.xcstrings`. Currently supported:
- English (`en`)
- German (`de`)
- Spanish — coming later this year

---

## License

Copyright © 2025 Simon Lang. All rights reserved.
