# Clipport + iTerm2: Copy/Paste Images to a Remote VPS via SSH

Clipport lets you copy an image (or text) on your Mac clipboard and paste it
directly into an iTerm2 SSH session — text pastes as text, images upload to
the remote host and the local path is inserted at the prompt. This guide
covers install, onboarding, and the SSH wiring required to make image paste
actually work over a remote VPS, including the failure modes you're likely to
hit.

## Requirements

- macOS + iTerm2
- Homebrew
- Passwordless SSH (key-based) to each remote host
- A writable `/tmp` on each remote host

## 1. Install

```bash
brew install arihantsethia/tap/clipport
```

This installs three binaries plus a menu bar app:

- `clipctl` — the CLI you actually run
- `clipportd` — the background daemon (spawned/supervised by the app, not
  by you directly)
- `Clipport.app` — an `LSUIElement` menu bar app that launchd keeps running
  and that supervises `clipportd`

## 2. Onboard (interactive — must be run in a real terminal, not scripted)

```bash
clipctl onboard
```

This reads `~/.ssh/config`, lets you pick which SSH host aliases to enable,
and writes the selection into `~/.config/clipport/config.toml` as `[[hosts]]`
blocks. `clipctl onboard --list` only *lists* candidate hosts — it does not
write config, so running only `--list` looks like onboarding happened but
leaves `config.toml` with zero hosts.

**Verify hosts actually got written:**

```bash
grep -A2 '\[\[hosts\]\]' ~/.config/clipport/config.toml
```

If this is empty, `clipportd` will crash-loop with:

```
clipportd: config must define at least one host
```

and every `clipctl doctor` check will fail, because the daemon's socket and
HTTP token file never stay up long enough to be read. Re-run
`clipctl onboard` and actually select hosts.

## 3. Start the daemon

```bash
clipctl start
clipctl doctor
```

`clipctl doctor` is the single source of truth for "is this working." A
correct baseline (before wiring remote hosts) looks like:

```
ok   pngpaste           /opt/homebrew/bin/pngpaste
ok   daemon             N hosts, 0 recent transfers
ok   http api           127.0.0.1:18765
ok   launchd            com.clipport.app
ok   iterm key          clipctl paste
ok   registry           N hosts
ok   config             /Users/you/.config/clipport/config.toml
```

**Never run `clipctl`/`clipctl doctor` with `sudo`.** It's a per-user tool
tied to your login session's launchd domain (`gui/<uid>`) and your own
`~/.ssh/config`. Under `sudo` it looks at root's home directory and a
different launchd domain, producing misleading errors like:

```
Bootstrap failed: 125: Domain does not support specified action
fail daemon   dial unix /tmp/clipport/0/clipportd.sock: ...
ssh: Could not resolve hostname ...
```

None of that reflects your real setup — it's `sudo` looking in the wrong
place entirely.

### If `clipctl start` says `Bootstrap failed: 5: Input/output error`

This means the launchd job is already loaded in a stuck state. Force a clean
reload instead of relying on `clipctl start`'s bootstrap call:

```bash
launchctl bootout gui/$(id -u)/com.clipport.app
launchctl bootstrap gui/$(id -u) /opt/homebrew/Cellar/clipport/*/libexec/com.clipport.app.plist
launchctl print gui/$(id -u)/com.clipport.app | grep -E "state|pid"
```

You want `state = running` with a `pid`.

## 4. Install the iTerm paste shortcut and SSH session hooks

Onboarding normally offers to do this, but if you need to (re)install for a
specific host:

```bash
clipctl ssh install-session-hook --host <ssh-alias> --machine <machine-name>
```

This inserts a block like this into `~/.ssh/config` (backed up automatically
before every edit):

```
# clipport session begin <ssh-alias>
Host <ssh-alias>
    PermitLocalCommand yes
    LocalCommand '/opt/homebrew/bin/clipctl' session register --machine '<machine-name>' --session-key "${TERM_SESSION_ID:-}" --ssh-alias '%n' --ssh-host '%h' --ssh-port '%p' --ssh-user '%r'
# clipport session end <ssh-alias>
```

This alone only handles **session/machine detection** (so Clipport knows
which remote you're in). It does **not** set up the tunnel image uploads need
— that's a separate step below and is the part most likely to be missed.

## 5. Install the RemoteForward tunnel (required for image paste)

Image paste works by the remote host making an authenticated HTTP call back
to `clipportd` on your Mac, over an SSH `RemoteForward` tunnel. Install it per
host:

```bash
clipctl ssh install-forward --host <ssh-alias>
```

This adds a block like:

```
Host <ssh-alias>
    ControlMaster no
    ExitOnForwardFailure yes
    ServerAliveInterval 15
    ServerAliveCountMax 2
    RemoteForward 127.0.0.1:18765 127.0.0.1:18765
```

If you see `clipport forward already installed for <host>`, that's fine — it
means this step is already done; move on.

**SSH config quirk to know about:** SSH resolves each config *keyword* from
the *first* `Host <alias>` block that mentions it, across the entire file —
not per-block. It's normal (and fine) to end up with multiple `Host
<same-alias>` stanzas in the file (one from `install-forward`, one from
`install-session-hook`, one from your original manual entry) as long as no
two blocks set the *same* keyword differently. Don't try to merge them.

## 6. Push the auth token and confirm the shim on the remote host

This is the step that's easy to skip and produces the most confusing
failure. The remote host needs a **local copy of Clipport's bearer token** at
`~/.config/clipport/token` so it can authenticate its callback to your Mac.
`onboard`/`install-forward` do not push this automatically — you must run:

```bash
clipctl shims setup --host <machine-name>
```

(Use the **machine name** from `config.toml`, e.g. `dgx`, not the SSH alias
like `dgx-spark-remote`.) Expected output:

```
machine <machine-name>
- <ssh-alias> / <ssh-alias>: forward already present; shims installed
```

Verify the token actually landed:

```bash
ssh <ssh-alias> 'cat ~/.config/clipport/token'
```

It should print the same token as `cat ~/.config/clipport/token` locally.

## 7. Verify end-to-end

Open a **real interactive SSH session** to the host in iTerm (this matters —
see the note below) and run:

```bash
clipctl doctor
```

Fully healthy output looks like:

```
ok   ssh <machine>/<alias>      <alias>
ok   tmp <machine>/<alias>      /tmp/clipport writable
ok   forward <machine>/<alias>  remote can reach 127.0.0.1:18765
```

Then test without touching your clipboard:

```bash
clipctl test-paste --host <machine-name>
```

And test the real flow: copy an image on your Mac, focus the iTerm SSH tab,
press the Clipport paste shortcut (shown by `clipctl doctor`'s `iterm key`
line, e.g. `0x76-0x120000` / usually Cmd+Shift+V or your configured binding).
The remote shell should receive a path like:

```
/tmp/clipport/<remote-user>/clipboard-20260706-134300.123456.png
```

## Why `fail forward` shows up, and how to read it

`clipctl doctor`'s forward check does **not** open its own SSH connection —
it checks whether an SSH session you *already have open* is holding the
`RemoteForward` tunnel alive, then curls through it. That means:

| Symptom | Meaning |
|---|---|
| `remote forward unavailable ...: connect: connection refused` (no active SSH session) | No persistent session is open to that host right now. Open one (a real iTerm tab, or `ssh -fN <alias>` for a background test) and re-run doctor. |
| `remote forward unavailable ...: HTTP 401` | A session is open and the tunnel works, but the remote host has no (or a stale) `~/.config/clipport/token`. Run `clipctl shims setup --host <machine>` again. |
| `remote port forwarding failed for listen port 18765` when opening a *new* SSH session | Another SSH connection to the same host is already holding that forwarded port. `ExitOnForwardFailure yes` makes the new connection refuse the forward. Find and close the older session (`ps aux \| grep 'ssh .*<alias>'`) before opening a fresh one. |

In short: **the forward check reflects live state, not a one-time
installation step.** As long as you have an iTerm SSH tab open to the host,
and the token has been pushed once via `clipctl shims setup`, it should stay
green for normal day-to-day use.

## Quick reference: full setup for one new host

```bash
clipctl onboard                                   # select the host (interactive)
clipctl ssh install-session-hook --host <alias> --machine <name>
clipctl ssh install-forward --host <alias>
clipctl shims setup --host <name>
clipctl start
clipctl doctor                                    # run this with an SSH tab to <alias> open
```

## Troubleshooting checklist

1. `clipctl doctor` fails on `daemon`/`http api`/`config` →
   check `config.toml` has `[[hosts]]` entries; re-run `clipctl onboard`.
2. Ran with `sudo` → don't; re-run as your normal user.
3. `clipctl start` → `Bootstrap failed: 5: I/O error` →
   `launchctl bootout` + `launchctl bootstrap` the plist directly.
4. `fail forward ... connection refused` → open a live SSH session to that
   host, then retest.
5. `fail forward ... HTTP 401` → `clipctl shims setup --host <machine>`.
6. `remote port forwarding failed` on a new SSH connection → kill the
   older lingering SSH process to the same host first.
7. Still stuck → `cat /tmp/clipportd.err.log` and `cat /tmp/clipport.err.log`
   on your Mac for the daemon/app's own error output.
