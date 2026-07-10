# Krehin App

The app is a shared SwiftUI codebase with native macOS and iOS targets. Posts
are stored locally with SwiftData. Publishing currently changes local status
only; Micropub synchronization will be connected after the editor workflow is
settled.

Regenerate the Xcode project after changing `project.yml`:

```sh
cd app
xcodegen generate
```

Schemes:

- `Krehin`: native macOS application
- `Krehin-iOS`: adaptive iPhone and iPad application
