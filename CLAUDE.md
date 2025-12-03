# Claude Code Guidelines - Frontend

## Release Process

**Important:** Do not add and commit files between releases. A release should include all changes committed together and pushed all the way to the remote repository on GitHub.

### Release Workflow

1. **Accumulate Changes** - Make all code changes without intermediate commits
2. **Build & Test** - Ensure the project builds successfully before release
3. **Single Commit** - Stage and commit all changes together with a comprehensive message
4. **Push to Remote** - Push the commit to the remote repository
5. **Create GitHub Release** - Use `gh release create` with detailed release notes
6. **Verify** - Confirm the release is visible on GitHub

### Version Naming

- Format: `v{major}.{minor}.{patch}` (e.g., v1.0.3)
- Major: Breaking changes or significant new features
- Minor: New features, backward compatible
- Patch: Bug fixes, improvements, refinements

### Commit Message Format

```
Release v{version}: Brief summary

## Changes
- Feature/fix description
- Another change

## Technical Details
- Implementation specifics
- Files modified

🤖 Generated with [Claude Code](https://claude.ai/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### GitHub Release Notes Format

```markdown
## What's New
- Key feature/change highlights

## Changes
### Category (e.g., Training, API, UI)
- Detailed change list

## Technical Details
- Implementation notes
- Breaking changes (if any)

## Files Changed
- List of significant files modified
```

## Project Structure

```
Frontend/
├── ReconstructionApp/
│   └── Sources/
│       ├── Models/         # Data models (Job.swift, etc.)
│       ├── Views/          # SwiftUI views
│       ├── Services/       # API client, networking
│       └── App/            # App entry point
├── ReconstructionApp.xcodeproj
└── CLAUDE.md              # This file
```

## Key Files

- `Sources/Models/Job.swift` - All data models including training pipeline
- `Sources/Services/APIClient.swift` - Backend API communication
- `Sources/Views/TrainingTab.swift` - Training management UI

## Build Command

```bash
xcodebuild -scheme ReconstructionApp -destination 'platform=iOS Simulator,id={simulator-id}' build
```

## API Timeout Policy

All API calls should have timeouts (typically 3 seconds for data loading, 5-10 seconds for actions) to prevent UI hangs when the backend is unavailable. On timeout, show appropriate empty state messages - no mock data fallbacks.
