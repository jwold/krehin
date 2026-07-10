# Krehin App

The app is a shared SwiftUI codebase with native macOS and iOS targets. Posts
are stored locally with SwiftData. Publishing sends Markdown to Krehin's
Micropub endpoint, stores the returned permalink, and keeps the access token in
Apple Keychain.

Regenerate the Xcode project after changing `project.yml`:

```sh
cd app
xcodegen generate
```

Schemes:

- `Krehin`: native macOS application
- `Krehin-iOS`: adaptive iPhone and iPad application
