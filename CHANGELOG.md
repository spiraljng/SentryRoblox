# Changelog

## 2.1.0 - 2026-10-07

### Fixed

- Client exceptions from the relay carry `mechanism = { type = "generic", handled = false }`, so client crashes land under `handled:false` the same way server crashes do
- Events are sent to `envelope/`. They were going to the deprecated `store/` endpoint while sessions already used `envelope/`
- A traceback made up entirely of SDK frames no longer comes back with those frames marked in-app. The fallback that restores them now marks them as library frames
- SDK frame matching is a boundary check instead of a raw prefix, so a module named `SentryRobloxTools` stops counting as part of the SDK
- `Init` warns and returns in Studio edit mode instead of registering silently, and the server-only message on the client is no longer hidden behind `Debug`

### Added

- `DisabledIntegrations` drops one built-in by name, so turning off `TrackSessions` no longer means `DefaultIntegrations = false` and relisting everything
- Integrations are deduped by `Name`. Passing a configured `TrackSessions` replaces the default instead of running a second copy, which was two sessions per player

### Changed

- `Transport.CaptureEvent` takes the event id as a second argument. Custom transports keep working, the argument is additive
