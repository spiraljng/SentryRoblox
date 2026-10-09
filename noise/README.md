# Noise blocklist

Rules that drop unavoidable Roblox engine noise before it reaches Sentry.

The SDK fetches this file at runtime.

`src/Integrations/Detection/Noise.luau` carries a snapshot of it as the offline fallback, and `pesde run test` fails if your snapshot has a rule this file does not

## Schema

```json
{
	"schema": 1,
	"updated": "YYYY-MM-DD",
	"rules": [
		{ "id": "some-case-id", "match": "text to look for", "type": "substring", "reason": "why" }
	]
}
```

- `id` - stable and kebab-case. Used to dedupe and to talk about a rule.
- `match` - the text to look for.
- `type` - `substring` (default) or `pattern` (a Lua pattern). Prefer `substring`.
- `reason` - why this is engine noise rather than game code. Required.

## What can be matched

Rules run against the raw message and traceback, before PII scrubbing. Never match a player name, user id or key: those change per event and the rule would stop matching. Match the stable part of the message instead.

## What belongs here

- Roblox transport failures where the player's connection is what failed
- Engine warnings and lifecycle races the game cannot prevent
- CoreGui and CorePackages output

## What does not

- Anything the game can fix
- Asset load failures, because a bad asset id is yours to fix
- HTTP status codes like `HTTP 429`, because they mean your backend asked for less traffic.
- `API Services rejected request`, because it is the only signal that saves stopped working
