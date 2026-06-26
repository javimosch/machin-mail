# machin-mail — a self-contained SMTP toolkit, in one MFL binary

**Send** email (an SMTP client) and **catch** it (a local SMTP sink + a web inbox to read
what was sent) — both in one static native binary, pure
[MFL](https://github.com/javimosch/machin), no library, no Node, no cgo. The catcher makes
the sender testable with **zero external dependencies**: no real mail server, no
credentials, no network. It doubles as a dev **mail catcher** (MailHog / Mailpit in one
binary) — point your app's SMTP at it and read the messages in a browser.

```bash
./build.sh                          # -> ./machin-mail   (needs machin v0.80.0+ and a C compiler)

# 1) run the catcher: SMTP on :1025, a web inbox on :8025
./machin-mail sink --smtp-port 1025 --web-port 8025

# 2) send something to it (from another terminal)
./machin-mail send --host 127.0.0.1 --port 1025 \
    --from app@acme.test --to alice@acme.test --subject "Welcome" --body "Your account is ready."

# 3) read it at http://localhost:8025
```

## Why this exists

machin-mail is a **dogfood**: building it drove an **SMTP toolkit** into machin
(`framework/smtp.src`, [v0.80.0](https://github.com/javimosch/machin/blob/main/CHANGELOG.md)).
Transactional email — password resets, receipts, alerts — is the one universal SaaS
primitive machin had no support for. Now it does, in pure MFL over `dial`/`listen` +
read/write:

- **`smtp_send(...)`** — the full `220` / `EHLO` / `AUTH LOGIN` / `MAIL` / `RCPT` / `DATA`
  / `QUIT` conversation, with base64 AUTH, multiple recipients, and dot-stuffing.
- **`smtp_recv(conn)`** — the receiving side of one session, so you can build a catcher
  (this app) or a real mailbox.

Kept self-contained on purpose: the `sink` lets you exercise the `send` path end-to-end
with nothing else installed. (Verified both directions against Python's stdlib `smtplib` —
machin client → Python server and Python client → machin sink — all without any external
package.)

## Commands

```
machin-mail
  send   --host H --port P --from F --to T --subject S --body B [--user U --pass W]
  sink   [--smtp-port 1025] [--web-port 8025] [--db machin-mail.db]
  help-json | version
```

`--to` accepts a comma-separated list. `send` is **agent-first**: JSON on stdout, a
structured error on stderr, and semantic exit codes (`0` ok · `80` input · `100`
integration/SMTP failure):

```bash
machin-mail send --from a@x --to b@y --subject Hi --body Yo
# {"ok":true,"to":"b@y","subject":"Hi"}        exit 0
machin-mail send --to b@y
# {"ok":false,"error":{"code":80,"type":"input","message":"--from and --to are required"}}   exit 80
```

## The catcher (`sink`)

A tiny SMTP server that accepts every message (and any AUTH) and stores it in an embedded
SQLite file, with a web inbox to browse them:

| Path | Purpose |
|---|---|
| `GET /` | the inbox (list of caught mail) |
| `GET /m/<id>` | one message (headers + body) |
| `GET /api/mails` | the list as JSON (agent-friendly) |
| `POST /clear` | delete all caught mail |
| `GET /_health` | `{"ok":true,"service":"machin-mail"}` |

```bash
curl -s http://localhost:8025/api/mails | jq '.[].subject'
```

Each SMTP session runs in its own goroutine; messages land in SQLite, so the web side just
reads the table — no shared mutable state.

## Use it from your app

Point any app's SMTP transport at the catcher in dev. For example, Python:

```python
import smtplib
from email.mime.text import MIMEText
m = MIMEText("hello"); m["From"]="app@acme"; m["To"]="user@acme"; m["Subject"]="Hi"
smtplib.SMTP("127.0.0.1", 1025).send_message(m)   # appears in the web inbox instantly
```

## v1 scope (honest edges)

- **Plaintext SMTP + AUTH LOGIN/PLAIN.** No STARTTLS / implicit TLS yet — so for a public
  relay (Gmail, SendGrid, SES) that *requires* TLS you'd need that added to machin first
  (a wrap-an-fd-in-TLS primitive). It works today with a relay that accepts plaintext
  submission, and with the local catcher.
- **The catcher accepts everything** (any recipient, any AUTH) — it's a dev sink, not a
  real MTA. No spam handling, no delivery, no queueing.
- **No attachments / MIME multipart** in the helpers (the body is `text/plain`); raw DATA
  is preserved, so you can build MIME yourself.

Built with [machin](https://github.com/javimosch/machin) · part of
[awesome-machin](https://github.com/javimosch/awesome-machin).
