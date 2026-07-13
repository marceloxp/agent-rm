# agent-rm

![banner](https://raw.githubusercontent.com/marceloxp/agent-rm/refs/heads/main/images/banner.png)

A safe deletion command for AI agents. It moves a single file to the system
trash instead of permanently deleting it. It is **explicit** — it does not alias
or override `rm`.

Under the hood it delegates to `gio trash`, so files land in the FreeDesktop
trash with their original path and deletion date recorded, and can be restored.

## Disclaimer

This tool is provided **as is, without warranty of any kind**. Installing and
using it — including configuring any AI agent to use it, and relying on the
deletion blocks — is **entirely your own responsibility**. The author is **not
responsible** for how any AI agent or tool behaves in your environment, nor for
any data loss, damage, or other consequence arising from its use. If you need a
guarantee, verify the behavior yourself (see
[Verifying the blocks are active](#verifying-the-blocks-are-active)).

## Requirements

- `gio` (package `libglib2.0-bin`, present on most Linux desktops).
- `jq` (for hooks only).

## What gets blocked

When hooks are installed, the following are blocked and the agent is redirected
to `agent-rm`:

| Pattern              | Example                              |
| -------------------- | ------------------------------------ |
| `rm`                 | `rm foo.txt`, `sudo rm foo`          |
| `/bin/rm`            | `/bin/rm foo.txt`, `/usr/bin/rm foo` |
| `command rm`         | `command rm foo.txt`                 |
| `xargs rm`           | `find . -print \| xargs rm`          |
| `unlink`             | `unlink foo.txt`                     |
| `find -delete`       | `find . -name '*.tmp' -delete`       |
| Cursor `Delete` tool | Native delete (permanent, no trash)  |

**Allowed:** `agent-rm <file>` — one file at a time, no directories.

## Supported agents

| Agent           | Enforcement                                    | Config                                               |
| --------------- | ---------------------------------------------- | ---------------------------------------------------- |
| **Claude Code** | `PreToolUse` hook + `permissions.deny`         | `~/.claude/settings.json` or `.claude/settings.json` |
| **Cursor**      | `beforeShellExecution` + `preToolUse` (Delete) | `.cursor/hooks.json` or `~/.cursor/hooks.json`       |

See [`integrations/`](integrations/) for example config snippets.

### Cursor Delete tool

Cursor's native **Delete** tool permanently removes files from disk — it does
**not** go to the system trash. The `block-delete.sh` hook blocks it and
redirects the agent to `agent-rm` via Shell. Without this hook, only shell-based
deletion commands are intercepted.

## Installation

There are two ways to install. Pick one.

### Option 1 — Let your AI agent install it (recommended)

This repo ships a guided playbook so an AI agent can install the tool **and**
enforce the deletion rules in your environment. From your agent prompt — even
while working in another project — type:

```
Install this tool: @/absolute/path/to/agent-rm/INSTALL.md
```

(Replace `/absolute/path/to/agent-rm` with where you cloned this repo.)

The agent will install the executable, ask which agent(s) and scope you want,
set up the hooks, and verify they work. See [`INSTALL.md`](INSTALL.md) for the
full playbook.

> Instructions alone only *suggest* using `agent-rm`; the **hooks** are what
> actually prevent permanent deletion. Option 1 installs both. Option 2 below
> installs only the tool — add the hooks yourself if you want the guarantee.

### Option 2 — Install manually

`agent-rm` is a standalone executable. Put it on your `PATH`:

```bash
chmod +x agent-rm
install agent-rm ~/.local/bin/   # or: sudo install agent-rm /usr/local/bin/
```

Confirm with `command -v agent-rm`.

To also enforce the deletion blocks, install the hooks from
[`hooks/`](hooks/) into your agent's config. The steps in [`INSTALL.md`](INSTALL.md)
work fine to do by hand.

## Verifying the blocks are active

Verification has three parts. Run them in order.

### 1. Hook simulation

Does the hook script make the right decision? (Works even before the agent
reloads its config.)

```bash
# Claude Code — must BLOCK:
echo '{"tool_input":{"command":"rm foo.txt"}}' | bash hooks/claude-code/block-rm.sh

# Claude Code — must PASS:
echo '{"tool_input":{"command":"agent-rm foo.txt"}}' | bash hooks/claude-code/block-rm.sh

# Cursor shell — must BLOCK:
echo '{"command":"/bin/rm foo.txt"}' | bash hooks/cursor/block-rm.sh

# Cursor Delete — must BLOCK:
echo '{"tool_name":"Delete","tool_input":{"path":"foo.txt"}}' | bash hooks/cursor/block-delete.sh
```

### 2. Trash round-trip

`command -v gio` passing is not enough — the trash backend can fail at runtime
on SSH/headless sessions, WSL, containers, or across filesystems. Prove the
full round-trip with the bundled script:

```bash
scripts/check-gio-trash.sh        # OK → exit 0
scripts/check-gio-trash.sh /path  # test a specific mount/volume
```

If it exits non-zero, the trash backend is not working in this environment.

### 3. Live block test

Ask the agent to run `rm` against a file that does not exist:

```bash
rm /tmp/agent-rm-block-test-does-not-exist
```

Never test with a real file. Interpret the result as one of three states:

- **Blocked** — denied with the hook's message. Protection is active in this
  session.
- **Real installation error** — not blocked, and parts 1 or 2 above also failed.
  Fix the installation and re-verify.
- **Installed but not yet loaded** — not blocked, but part 1 passed. The config
  is correct but the hook is not active until the agent session reloads. Restart
  the session and re-run this test.

## Usage

```bash
agent-rm <file>     # move one file to the trash
agent-rm -h         # show help
```

By design it accepts **exactly one file** and **refuses directories**.

```bash
agent-rm notes.txt
# Moved to trash: notes.txt
```

### Symlinks

Broken symlinks (links whose target no longer exists) are accepted — `agent-rm`
moves the link itself to the trash.

## Restoring & managing the trash

```bash
gio trash --list                       # list trashed files and their origins
gio trash --restore trash:///notes.txt # restore by trash URI (name as shown by --list)
gio trash --empty                      # empty the trash
```

## Notes

- Files with the same name never overwrite each other — `gio` renames
  duplicates (e.g. `dup.txt`, `dup.2.txt`) while keeping each origin.
- Directories and multiple-file/glob deletions are intentionally **not**
  supported.
- Not blocked: `git clean`, `shred`, `truncate`, Python `os.remove`, etc.
- Platform: Linux desktop (FreeDesktop trash via `gio`). No macOS/Windows
  support in this release.
