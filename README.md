# OpsBot for XDevOps

OpsBot is a terminal client for your dedicated XDevOps tenant. It starts your
normal `bash` inside a real pseudo-terminal, so `vim`, `tmux`, `ssh` and other
interactive tools work as usual, and adds a few keyboard shortcuts that let
you ask the XDevOps AI for help or share recent terminal output with it.

OpsBot connects to your tenant over a WebSocket secured with mutual TLS
(mTLS). Your device is identified by a client certificate issued from the
XDevOps portal. There is no interactive login.

This repository distributes the prebuilt OpsBot binaries and the installer.

- [Requirements](#requirements)
- [Install](#install)
- [Get your certificate bundle](#get-your-certificate-bundle)
- [Run OpsBot](#run-opsbot)
- [Shortcuts](#shortcuts)
- [Configuration reference](#configuration-reference)
- [Security and privacy](#security-and-privacy)
- [Troubleshooting](#troubleshooting)
- [Upgrade and uninstall](#upgrade-and-uninstall)
- [Support](#support)

## Requirements

- **Linux** (x86_64 or arm64) or **macOS** (Intel or Apple silicon).
  Windows is not supported natively because OpsBot needs a Unix
  pseudo-terminal. On Windows, use WSL2 and install the Linux build inside it.
- `bash` on your `PATH` (OpsBot starts `bash` and loads your `~/.bashrc`).
- An interactive terminal. OpsBot cannot run with piped or redirected input.
- Outbound HTTPS (TCP 443) to `<tenant-slug>-shell.xdevops.ch`.
- An OpsBot certificate bundle for your tenant, downloaded from the XDevOps
  portal by a tenant **admin** or **operator** (see below).

## Install

### Quick install (recommended)

```sh
curl -fsSL https://raw.githubusercontent.com/xdevops-ai/shell-agentic/main/install.sh | sh
```

The installer detects your OS and CPU, downloads the matching archive from the
[latest release](https://github.com/xdevops-ai/shell-agentic/releases/latest),
verifies its SHA-256 checksum against `SHA256SUMS`, and installs the `opsbot`
binary into `~/.local/bin`. It does not use `sudo` unless the install
directory you chose is not writable.

Options:

```sh
# Install a specific version
curl -fsSL https://raw.githubusercontent.com/xdevops-ai/shell-agentic/main/install.sh | sh -s -- v2.0.0

# Install system-wide (sudo is used only if /usr/local/bin is not writable)
curl -fsSL https://raw.githubusercontent.com/xdevops-ai/shell-agentic/main/install.sh | OPSBOT_INSTALL_DIR=/usr/local/bin sh
```

| Variable | Default | Purpose |
|---|---|---|
| `VERSION` (or first argument) | latest release | Release tag to install, e.g. `v2.0.0` |
| `OPSBOT_INSTALL_DIR` | `~/.local/bin` | Where the `opsbot` binary is placed |
| `OPSBOT_BASE_URL` | `https://github.com/xdevops-ai/shell-agentic/releases/download` | Download base URL, for internal mirrors |

If you prefer to read the script before running it:

```sh
curl -fsSLO https://raw.githubusercontent.com/xdevops-ai/shell-agentic/main/install.sh
less install.sh
sh install.sh
```

### Manual install

1. Download the archive for your platform and `SHA256SUMS` from the
   [releases page](https://github.com/xdevops-ai/shell-agentic/releases):

   | Platform | Archive |
   |---|---|
   | Linux x86_64 | `opsbot_<version>_linux_amd64.tar.gz` |
   | Linux arm64 | `opsbot_<version>_linux_arm64.tar.gz` |
   | macOS Intel | `opsbot_<version>_darwin_amd64.tar.gz` |
   | macOS Apple silicon | `opsbot_<version>_darwin_arm64.tar.gz` |

   ```sh
   VERSION=2.0.0
   OS=linux        # or darwin
   ARCH=amd64      # or arm64
   BASE=https://github.com/xdevops-ai/shell-agentic/releases/download/v$VERSION
   curl -fLO "$BASE/opsbot_${VERSION}_${OS}_${ARCH}.tar.gz"
   curl -fLO "$BASE/SHA256SUMS"
   ```

2. Verify the checksum. The command must print `OK`:

   ```sh
   # Linux
   sha256sum --check --ignore-missing SHA256SUMS
   # macOS
   shasum -a 256 --check --ignore-missing SHA256SUMS
   ```

   Do not continue if the check fails.

3. Extract and install:

   ```sh
   tar -xzf "opsbot_${VERSION}_${OS}_${ARCH}.tar.gz" opsbot
   mkdir -p ~/.local/bin
   install -m 0755 opsbot ~/.local/bin/opsbot
   ```

   Each archive contains `opsbot`, this `README.md`, and `.env.example`.

Make sure `~/.local/bin` is on your `PATH`
(`export PATH="$HOME/.local/bin:$PATH"` in your shell profile).

**macOS:** the binaries are not notarized. Files downloaded with `curl` (and
by the installer) are not quarantined, but if you downloaded the archive with
a browser and macOS refuses to run `opsbot`, remove the quarantine flag:

```sh
xattr -d com.apple.quarantine ~/.local/bin/opsbot
```

## Get your certificate bundle

Each device needs its own client certificate. A user with the **Admin** or
**Operator** role in your tenant downloads it from the XDevOps portal:

1. Sign in at <https://xdevops.ch>.
2. Open **Settings → Devices**.
3. Choose **Install OpsBot → Download certificate bundle**.

The bundle is a zip file with three files:

| File | Contents |
|---|---|
| `.env` | Pre-filled configuration: your tenant endpoint, your client id, certificate paths |
| `opsbot.client.crt` | Your client certificate |
| `opsbot.client.key` | Your client private key. **Keep it secret.** |

`WEBSOCKET_CLIENT_ID` in the bundle's `.env` is your Microsoft Teams user id.
The portal fills it in when your admin has linked your Teams account. If it
is empty or a placeholder, ask your tenant admin to link it before you
connect.

Unpack the bundle into a private directory and lock down the permissions:

```sh
mkdir -p ~/opsbot
chmod 700 ~/opsbot
unzip <downloaded-bundle>.zip -d ~/opsbot
chmod 600 ~/opsbot/opsbot.client.key ~/opsbot/.env
```

## Run OpsBot

> **Important:** OpsBot reads `.env` from the **current working directory**,
> the directory you start it from. It does **not** look next to the binary.
> Relative paths in `.env` (certificates, logs) are also resolved against
> that directory.

Start OpsBot from the directory that holds your bundle:

```sh
cd ~/opsbot && opsbot
```

You will see:

```text
🚀 OpsBot Enterprise Shell v2.0
   - Press 'Ctrl+O' for the Help Menu.
```

followed by a bash prompt that shows the connection state:

| Prompt | Meaning |
|---|---|
| `🤖 OpsBot ~/path ❯` | Connected to your tenant |
| `🔴 Offline ~/path ❯` | Not connected. OpsBot retries every 3 seconds. See [Troubleshooting](#troubleshooting). |

The prompt is refreshed each time bash draws it, so press Enter to see the
latest state. You can `cd` anywhere once the shell is running; the
configuration has already been loaded.

To launch OpsBot from anywhere without leaving your current directory, put
absolute paths in `~/opsbot/.env` (for `SSL_CLIENT_CERT`, `SSL_CLIENT_KEY`,
`LOGURU_LOG_FILE` and `DEBUG_LOG_FILE`) and add this function to your
`~/.bashrc` or `~/.zshrc`:

```sh
opsbot() {
  ( cd ~/opsbot && command opsbot )
}
```

The shell OpsBot opens will start in `~/opsbot`; `cd -` or `cd` to where you
were.

OpsBot takes no command-line flags. Any arguments are ignored, so
`opsbot --version` starts a session too. The version is shown in the start-up
banner.

Type `exit` to end the session.

## Shortcuts

| Keys | Action |
|---|---|
| `Ctrl+E` | Ask the AI a question. Opens an `🤖 Ask OpsBot:` prompt; only the text you type is sent, no terminal output. |
| `^^` | Same as `Ctrl+E`: type two carets in a row. |
| `Ctrl+S` | Share recent terminal output (about the last 16 KB, redacted locally) and ask a question about it. The AI is told to focus on the most recent command. If you submit an empty question, nothing is sent. |
| `Ctrl+T` | Toggle auto-analysis. While on, each time you press Enter OpsBot waits until the command's output has settled (about 0.6 s without new output), then sends that output (redacted) for a short analysis. Off by default; the banner shows `ACTIVE AUTO-ANALYSIS ENABLED` / `DISABLED`. |
| `Ctrl+O` | Show the shortcut help. Press Enter to return. |
| `exit` | End the bash session and quit OpsBot. |

Answers appear inline in your terminal, marked `[AI]`, `[💡 Suggestion]`,
`[Error]` or `[Server]`.

**Key conflicts.** OpsBot intercepts `Ctrl+E`, `Ctrl+S`, `Ctrl+T` and `Ctrl+O`
before they reach bash or any program running in it. Inside OpsBot those keys
do not perform their usual functions, for example bash's end-of-line
(`Ctrl+E`), transpose (`Ctrl+T`), or `Ctrl+O` (save) in `nano`. In the same
way, two consecutive `^` characters always open the ask prompt (the first `^`
is erased), so you cannot type `^^` literally. Use `Ctrl+A`/`End` and your
editor's alternative bindings, or run such tasks outside OpsBot.

## Configuration reference

OpsBot is configured through environment variables, normally set in `.env`
in the directory you start it from. Variables already present in your
environment take precedence over values in `.env`. The certificate bundle
from the portal sets everything you need; you do not normally edit it.

| Variable | Default if unset | Description |
|---|---|---|
| `WEBSOCKET_URI` | **required** | Your tenant endpoint: `wss://<tenant-slug>-shell.xdevops.ch/ws`. TLS settings apply only to `wss://` URIs. |
| `WEBSOCKET_CLIENT_ID` | **required** | Your Microsoft Teams user id, sent to the server as `IDENTIFY\|<id>` on connect. |
| `SSL_VERIFY` | `true` | Server certificate verification. Only the value `false` (any case) disables it. **Never set `false`.** |
| `SSL_CA_CERT` | *(empty)* | **Leave empty.** See the note below. |
| `SSL_CLIENT_CERT` | *(empty)* | Path to the client certificate, e.g. `./opsbot.client.crt`. Required together with `SSL_CLIENT_KEY`. |
| `SSL_CLIENT_KEY` | *(empty)* | Path to the client private key, e.g. `./opsbot.client.key`. |
| `REDACT_PATTERNS` | two built-in patterns (see [Redaction](#redaction)) | Comma-separated regular expressions applied to shared terminal output. Setting it **replaces** the defaults. |
| `LOGURU_LOG_FILE` | `./opsbot_audit.log` | Local transcript of the session (see [Local logs](#local-logs)). |
| `DEBUG_LOG_FILE` | `./opsbot_debug.log` | Connection and TLS diagnostics. |

Older `.env` files may contain `SSL_SERVER_NAME` or `MAX_PAYLOAD_BYTES`.
OpsBot 2.0.0 ignores both. Shared payloads are always capped at 200,000
characters.

**Why `SSL_CA_CERT` must stay empty.** Your tenant endpoint presents a public
(Let's Encrypt) certificate. With `SSL_CA_CERT` empty, OpsBot uses Go's
standard TLS verification: the server's chain is checked against your
operating system's trust store and the certificate must match the host name
in `WEBSOCKET_URI`. If you set `SSL_CA_CERT` to a readable file, OpsBot
*replaces* the system trust store with that one file and switches to a custom
check that accepts only chains signed by it (without a host name check). With
a private CA, or any CA other than the one that signed the server
certificate, every connection fails with `certificate signed by unknown
authority`. If the file cannot be read, OpsBot logs an error and falls back to
the system trust store.

The minimum TLS version is 1.2. Outbound connections honor the standard
`HTTPS_PROXY` / `NO_PROXY` variables. A proxy that intercepts TLS breaks mTLS,
so your tenant host must be excluded from TLS inspection.

## Security and privacy

### What is sent to your tenant

OpsBot does not stream your keystrokes. Data leaves your machine only in
these cases:

| When | What is sent | Redacted? |
|---|---|---|
| On connect (and each reconnect) | `IDENTIFY\|<WEBSOCKET_CLIENT_ID>` | n/a |
| `Ctrl+E` / `^^` | The question you type | **No.** Do not paste secrets into the question. |
| `Ctrl+S` | About the last 16 KB of terminal output, your question, and fixed instructions for the AI | Output: yes |
| Auto-analysis on (`Ctrl+T`) | Output of each command after you press Enter, and fixed instructions | Yes |

Everything goes only to the `WEBSOCKET_URI` you configure, over TLS with your
client certificate. Payloads are capped at 200,000 characters after
redaction.

"Terminal output" is everything bash and your programs print, which includes
the commands you typed (they are echoed) and anything shown on screen, such
as file contents you `cat`. Passwords typed at prompts that do not echo (for
example `sudo`, `ssh`) are not part of the output.

### Redaction

Before output is shared (`Ctrl+S`, auto-analysis), OpsBot applies regular
expressions locally. The built-in defaults mask:

- `Bearer <token>` values, and
- values following `api_key`, `api-key`, `apikey`, `password`, `secret` or
  `token` and a `:` or `=` (case-insensitive).

Redaction is a best-effort safety net, not a guarantee. It does not catch
private keys, cloud credentials in other formats, connection strings, or
secrets without those keywords. **Do not display secrets in the terminal
while auto-analysis is on or before pressing `Ctrl+S`.**

To customize, set `REDACT_PATTERNS` to a comma-separated list of
[Go regular expressions](https://pkg.go.dev/regexp/syntax). Note:

- Your list replaces the defaults. Include them again if you want to keep
  them (see `.env.example`).
- Patterns are split on `,`, so a pattern cannot contain a comma. Write
  `{16}` or `+` instead of `{16,}`.
- Invalid patterns are skipped silently.
- Each match is replaced with `$1[REDACTED]`. Capture group 1 is kept, so
  put the label you want to keep (e.g. `(password=)`) in the first group, or
  use no group at all to mask the whole match.

### Local logs

- `opsbot_audit.log` (`LOGURU_LOG_FILE`) contains **everything shown in the
  OpsBot shell, unredacted**, with session start and end markers. It is
  appended to, never rotated or deleted, and can grow large. Treat it as
  sensitive. Delete or rotate it as your policy requires.
- `opsbot_debug.log` (`DEBUG_LOG_FILE`) records connection attempts, TLS
  set-up and errors, and any server message OpsBot cannot interpret. It does
  not contain your key.

Both files are created in the directory you start OpsBot from, unless you
configure absolute paths, with mode `0644` (subject to your `umask`). Keep
them in a directory only you can read, such as `~/opsbot` with mode `700`.

OpsBot also writes two small helper files to your temporary directory
(`opsbot-rc-*.sh`, `opsbot-status-*`). They hold only the prompt script and
the online/offline flag.

### Protect your certificate

- Keep `opsbot.client.key` readable only by you: `chmod 600 opsbot.client.key`.
- Never commit `.env`, `*.key` or `*.crt` to version control, and never share
  them in chat or tickets. The `.gitignore` in this repository shows the
  patterns to exclude.
- One bundle per person and device. Do not copy a bundle to other machines.
- If the key may have been exposed, or the device is lost, tell your tenant
  admin right away so the device certificate can be revoked, then download a
  new bundle.

## Troubleshooting

When the prompt shows `🔴 Offline`, look at the debug log (in the directory
you started OpsBot from, unless `DEBUG_LOG_FILE` says otherwise):

```sh
tail -n 50 opsbot_debug.log
```

A healthy start looks like this:

```text
Initializing WSManager with URI: wss://<tenant-slug>-shell.xdevops.ch/ws
TLS Config - No SSL_CA_CERT provided in .env
TLS Config - Successfully loaded Client Cert/Key pair
Attempting WebSocket connection to: wss://<tenant-slug>-shell.xdevops.ch/ws
WebSocket connection established successfully.
```

`TLS Config - No SSL_CA_CERT provided in .env` is expected and correct.

| Debug log shows | Cause | Fix |
|---|---|---|
| `opsbot: WEBSOCKET_URI, WEBSOCKET_CLIENT_ID not set` (on start) | `.env` was not found, or the value is empty | Start OpsBot from the directory that contains `.env` (`cd ~/opsbot && opsbot`). If only `WEBSOCKET_CLIENT_ID` is missing, ask your tenant admin to link your Teams account and download a new bundle. |
| `TLS Config - Client Cert/Key paths not fully provided in .env` | `SSL_CLIENT_CERT` or `SSL_CLIENT_KEY` is missing | Restore the values from your bundle. |
| `TLS Error - Failed to load Client Cert/Key: open ...: no such file or directory` | Relative certificate paths resolved against the wrong directory | Start OpsBot from the bundle directory or use absolute paths. |
| `TLS Error - Failed to load Client Cert/Key: tls: private key does not match public key` or `failed to find any PEM data` | Certificate and key are from different bundles, or a file is damaged | Use the `.crt` and `.key` from the same download. Download a fresh bundle if needed. |
| `Connection Error: remote error: tls: certificate required` | No client certificate was sent (see the previous rows) | Fix the certificate loading error higher up in the log. |
| `Connection Error: remote error: tls: bad certificate`, `unknown certificate authority`, `revoked certificate` or `expired certificate` | The server rejected your certificate: it is for another tenant, revoked or expired | Ask your tenant admin to check the device in **Settings → Devices** and download a new bundle. |
| `x509: certificate signed by unknown authority` (or `TLS Custom Verification Failed`) | `SSL_CA_CERT` is set, or a corporate proxy intercepts TLS | Set `SSL_CA_CERT=` (empty). Ask IT to exempt `*.xdevops.ch` from TLS inspection. |
| `x509: certificate is valid for ..., not ...` | Host name in `WEBSOCKET_URI` is wrong | Use exactly `wss://<tenant-slug>-shell.xdevops.ch/ws`. |
| `TLS Config - Security disabled (InsecureSkipVerify: true)` | `SSL_VERIFY=false` | Set `SSL_VERIFY=true`. |
| `dial tcp: lookup ... no such host` | Typo in the tenant slug, or DNS issue | Check the slug in `WEBSOCKET_URI`. |
| `connect: connection refused`, `i/o timeout` | Firewall or proxy blocks outbound 443 | Allow HTTPS to your tenant host, or set `HTTPS_PROXY`. |
| `websocket: bad handshake` plus `HTTP Response Status: 404 ...` | Wrong path | The URI must end in `/ws`. |
| `websocket: bad handshake` plus `HTTP Response Status: 401/403 ...` | The server refused the session | Contact your tenant admin. |
| Connects, then `[Server]` or `[Error]` messages about your identity | `WEBSOCKET_CLIENT_ID` is missing, wrong, or not linked | Ask your tenant admin to link your Teams account and download a new bundle. |

Other problems:

- **`Failed to set raw mode` / `Failed to start pty`** (in the debug log,
  OpsBot exits): OpsBot was started without an interactive terminal (for
  example piped, or in a CI job), or `bash` is not installed.
- **Spinner keeps turning after `Ctrl+E` or `Ctrl+S`:** the connection was
  lost before the answer arrived. Press Enter to check the prompt state and
  ask again once it shows `🤖 OpsBot`.
- **`Warning: Tried to send message, but WebSocket is disconnected.`** in the
  debug log: you used a shortcut while offline. The question was not sent.
- **macOS: "opsbot cannot be opened because the developer cannot be
  verified":** see the quarantine note under [Manual install](#manual-install).

When contacting support, include the last 50 lines of `opsbot_debug.log`, your
OS and architecture (`uname -sm`) and the OpsBot version from the banner.
**Never send** your `.env`, `opsbot.client.key` or `opsbot_audit.log`.

## Upgrade and uninstall

**Upgrade:** run the installer again (optionally with a version). Your bundle
directory is not touched.

**Uninstall:**

```sh
rm -f ~/.local/bin/opsbot            # or the OPSBOT_INSTALL_DIR you used
rm -rf ~/opsbot                     # bundle, key and logs: this deletes your audit log too
rm -f "${TMPDIR:-/tmp}"/opsbot-rc-*.sh "${TMPDIR:-/tmp}"/opsbot-status-*
```

Remove any `opsbot` shell function you added to your shell profile, and ask
your tenant admin to revoke the device in **Settings → Devices**.

## Support

Contact your tenant admin first for access, certificates and Teams linking.
For other issues, email **support@xdevops.ai**.

See [CHANGELOG.md](CHANGELOG.md) for release notes.
