# Changelog

## 2.1.3 - 2026-10-07

### Fixed

- A throwing `BeforeSend` or `BeforeBreadcrumb` is reported once instead of dropping the event or breadcrumb without a trace
- `LogServiceMessageOut` only drops messages prefixed `[SentryRoblox]`. Any game message that mentioned the SDK name anywhere was filtered before

### Changed

- `Client.Flush` and `Client.Close` hand off to the transport when it implements them, so a queued transport no longer reports as drained. They follow the transport that last sent an event instead of the one the hub was built with

## 2.1.2 - 2026-10-07

### Fixed

- Relayed client exceptions carry `level = "error"` now, matching the server path
- Relayed client events no longer inherit the server's breadcrumb trail through the cloned hub
- `event.user` is no longer scrubbed into `<PLAYER>`, and an inferred player no longer overrides an attached user

## 2.1.1 - 2026-10-07

### Fixed

- `PlayerContext` attaches the same user as `SetUser` now: `id`, `username`, `data` and `geo` with PII on, `id` alone with it off. It used to stop at `id` and `username`, and attach nothing when PII was off
- Events no longer carry `"tags": []`, `"extra": []` or `"contexts": []`. Empty tables are skipped when the scope merges into an event, and the relay sanitizer drops them too

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
