# Job: browser C2 "handoff" page for a WhatsApp link

Deliver a working, hosted two-way remote-inspection page. One link is sent over WhatsApp; whoever taps it becomes a "device", and I drive it from an operator panel in my browser. Target device can be Android, iPhone, macOS or Windows.

Be honest in the README: this is a browser-capability agent, not real root. No install, no jailbreak, no native APIs.

## Hosting (no new infra, no auth needed)
Use the existing Supabase project `dudhizyikddpfmgqigbf` (see `~/.config/supabase-lumavir.url` for the connection string, admin key; never print secrets).
- New schema `agent`, tables `devices`, `events`, `commands`.
- Client page is a single static `index.html`, uploaded to a **public** Storage bucket `agent`, served as `text/html` so the link renders. Content-type must actually be `text/html; charset=utf-8`.
- Realtime for both directions (`supabase-js` from CDN, WSS). Poll every 2s as fallback if the socket drops.
- Auth model: a random per-run token `run` (22 chars). Every row carries `run`. RLS: anon may only touch rows where `current_setting('request.headers', true)::json->>'x-run'` equals `run`. Both client and panel send that header. No service key in the browser.

## Client page (the link)
On load: generate/pick `run` from a query param `?r=`, register itself in `devices` (ua, platform, screen, dpr, timezone, language, cores, memory, battery, connection, model hints, whether standalone/A2HS), then open the realtime channel and execute commands from `commands`.

Capabilities, each triggered by a command, results written to `events`:
- `eval` arbitrary JS in page context, return JSON-safe result
- `fingerprint` deep device/browser/GPU/feature matrix
- `perm` request a permission: camera, mic, geolocation, notifications, clipboard-read, midi, bluetooth, nfc (Android), screen-wake-lock, motion sensors
- `cam` start/stop: `getUserMedia` front/rear switch, canvas snapshot every 1200 ms as JPEG base64 into `events`, plus a `camframe` row
- `mic` start/stop: MediaRecorder 5s chunks base64
- `geo` watchPosition stream, `geofence` single shot
- `screen` getDisplayMedia once, snapshot loop (desktop only)
- `clip` read clipboard text
- `notify` post a notification with custom title/body
- `files` on Chrome desktop: `showDirectoryPicker` → list a directory (name, size, kind) and fetch one file's bytes as base64
- `persist` register service worker, request persistent storage, prompt A2HS
- `wake` screen wake lock on/off, `vibrate` pattern, `open` URL in new tab, `reload`
- `lock` set an overlay so the page keeps focus, `unlock`

Realtime must survive screen lock and reload: reconnect with exponential backoff, restore `run` from localStorage, queue unsent events in localStorage and flush on reconnect. Service worker caches the shell for offline reload.

UI on the target: minimal, one calm screen, a single visible "Allow" button that requests camera/mic/geo in one gesture (browsers require a gesture), and a subtle status line. Nothing that looks like a hack tool.

Mobile-correct: viewport meta, safe-area insets, no hover-only affordances, no fixed-width layout. iOS Safari quotas respected (MediaRecorder chunking, no `showDirectoryPicker`).

## Operator panel
Same file with `?r=<run>&op=1`. Device list, live event stream (newest first, filterable), command palette with args, live camera pane, screen pane, geo map link, and a raw console. Buttons disable when a device lacks the capability. Shows online/offline from `last_seen`.

## Deliverables in `/Users/tahabilal/Documents/GitHub/wa-agent` (local only, do NOT push)
- `index.html` (the whole thing, vanilla JS, no build step)
- `sql/schema.sql` with tables, indexes, RLS policies, realtime publication
- `README.md`: deploy commands, the exact WhatsApp message text (short, casual, UK, no em dashes), capability matrix per platform, hard limits (iOS cannot read files or stay alive in background, camera needs the tap, geolocation needs HTTPS, WhatsApp in-app browser is limited)
- `deploy.sh` that applies the SQL, creates the bucket, sets public + content-type, uploads, and prints the final link

## Rules
- Answer first, then the diff summary. No chatter.
- Verify against the live project: the link must actually return 200 `text/html`, and a headless smoke test must show a row landing in `devices`.
- Keep total payload under 400 KB.
