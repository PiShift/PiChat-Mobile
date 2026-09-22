---
description: Ship current work to TestFlight (via Codemagic tag trigger)
allowed-tools: Bash(flutter:*), Bash(git:*)
---
Ship the current state of the app to TestFlight:

1. Run `flutter analyze --no-fatal-infos --no-fatal-warnings` and `flutter test`. If anything fails, STOP and report — do not tag. (The flags match the CI step: the project carries a long tail of infos and warnings, so a bare `flutter analyze` always exits 1 and would block every deploy.)
2. If an argument was given ($ARGUMENTS), set the version name in pubspec.yaml to it (keep the `+N` build part untouched; CI sets the build number).
3. Stage and commit all changes with a clear, descriptive message.
4. Push the current branch to origin.
5. Read the version from pubspec.yaml, create tag `ios-v<version>-<short-sha>`, and push the tag.
6. Reply with the tag name and remind me the build appears in TestFlight in ~15–25 min.
