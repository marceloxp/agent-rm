# AI-assisted installation

> **For the human:** you don't have to install anything by hand. In your agent
> prompt — even from another project — type:
>
> > **`Install this tool: @/absolute/path/to/agent-rm/INSTALL.md`**
>
> (Replace `/absolute/path/to/agent-rm` with where you cloned this repo.)
>
> The rest of this file is a playbook for the AI agent to run with you. If you'd
> rather set it up yourself, see **Manual installation** in the [README](README.md).
>
> **Disclaimer:** this tool is provided *as is, without warranty of any kind*.
> Choosing to install it and to let an AI agent use it — and relying on the
> deletion blocks — is *entirely your own responsibility*. The author is not
> responsible for how any agent or tool behaves in your environment, nor for any
> data loss or damage arising from its use.

---

> **For the AI agent reading this:** before installing anything, get the user's
> **explicit acceptance** of the disclaimer via a confirmation dialog (Step 0).
> They are choosing to install this and are solely responsible for the outcome.
> Do not present the deletion blocks as an absolute guarantee; they are a safety
> net the user must verify (Step 7).

---

## Installation instructions

You are installing `agent-rm` in this environment. **End goal:** after install,
you must **never permanently delete files** — to delete a file you use
`agent-rm <file>`, which moves **one** file (never a directory) to the system's
restorable trash.

**Path note (read first):** the user may have invoked this from a *different*
project, so their current working directory is probably **not** this repo. The
files referenced below live in the **same directory as this `INSTALL.md`**.
Resolve them relative to *this file's* location, not the user's cwd.

This requires **two things**, and the hooks are what actually enforce the rule:

1. **The `agent-rm` executable** on the `PATH` (the tool).
2. **Hooks** that block permanent deletion and redirect you to `agent-rm`
   (the enforcement). Without hooks this is only a suggestion — **do not skip
   the hooks.**

Follow the steps in order. Ask the user where the playbook says to ask; do not
decide scope or agent on your own.

### Step 0 — Get explicit acceptance of the disclaimer (do this first)

Before doing anything else, **open a confirmation dialog** that shows the user
the responsibility disclaimer and makes them choose explicitly. Options:

- **I accept and want to install** — proceed.
- **Cancel** — stop the installation.

Show the core of the disclaimer: *this tool is provided as is, without warranty;
installing it and letting an AI agent use it is entirely your own responsibility;
the author is not responsible for any agent's behavior or any data loss.*

If the user does not explicitly accept, **stop here** and install nothing.

### Step 1 — Prerequisite

Confirm `gio` exists (`command -v gio`). If it doesn't, tell the user to install
the `libglib2.0-bin` package and stop here.

### Step 2 — Install the executable

Put the `agent-rm` file (in this repo's root, next to this INSTALL.md) on the
user's `PATH`. Prefer, in order:

- `~/.local/bin/agent-rm` (if `~/.local/bin` is on `PATH`) — no `sudo`.
- `/usr/local/bin/agent-rm` — needs `sudo`, ask the user.

Ensure `chmod +x`. Confirm with `command -v agent-rm`.

### Step 3 — ASK which agent(s)

Ask the user which agent(s) they want to configure:

- **(A) Claude Code**
- **(B) Cursor**
- **(C) Both**

Do not proceed without an answer.

### Step 4 — ASK for the block scope

Ask the user which scope they want:

- **(1) Global** — applies to all sessions/projects.
- **(2) This project only** — applies only in the user's current project.

Do not proceed without an answer.

Agent-specific paths:

| Agent       | Global       | Project                    |
| ----------- | ------------ | -------------------------- |
| Claude Code | `~/.claude/` | `.claude/` in project root |
| Cursor      | `~/.cursor/` | `.cursor/` in project root |

For Claude Code project scope, warn that Claude Code asks the user to **approve
hooks** when the project is opened.

### Step 5 — Install the hooks (the enforcement)

#### Claude Code (if chosen in Step 3)

Use the ready-made hook at `hooks/claude-code/block-rm.sh` (relative to this
INSTALL.md). It blocks: `rm`, `/bin/rm`, `command rm`, `xargs rm`, `unlink`,
`find -delete`. **`agent-rm` is allowed.**

**Important when editing `settings.json`:** back it up first, and **merge** with
`jq` — never overwrite an existing settings file. Add:

1. Under `hooks.PreToolUse`, a `Bash` matcher pointing at the installed path of
   `block-rm.sh`.
2. Under `permissions.deny`, the entry `"Bash(rm:*)"` (belt and suspenders).

See [`integrations/claude-code/settings.example.json`](integrations/claude-code/settings.example.json).

- **Global:** copy hook to `~/.claude/hooks/block-rm.sh` (`chmod +x`), merge into
  `~/.claude/settings.json`.
- **Project:** copy to `.claude/hooks/block-rm.sh`, merge into
  `.claude/settings.json`.

#### Cursor (if chosen in Step 3)

Install **two** hooks from `hooks/cursor/`:

1. **`block-rm.sh`** — blocks destructive shell commands (`beforeShellExecution`).
2. **`block-delete.sh`** — blocks the native Delete tool (`preToolUse`, matcher
   `Delete`). Cursor's Delete permanently removes files; this hook is essential.

See [`integrations/cursor/hooks.example.json`](integrations/cursor/hooks.example.json).

- **Global:** copy both to `~/.cursor/hooks/`, merge into `~/.cursor/hooks.json`.
- **Project:** copy both to `.cursor/hooks/`, merge into `.cursor/hooks.json`.

Set `failClosed: true` on both hooks. **Merge** with existing hooks — never
overwrite.

### Step 6 — Teach the positive behavior

Add guidance so you naturally prefer `agent-rm`:

- **Claude Code:** add to `CLAUDE.md` (global `~/.claude/CLAUDE.md` or project):
  > To delete files, use `agent-rm <file>` (one at a time, no directories). Never
  > use `rm`, `unlink`, `find -delete`, or the Delete tool.

- **Cursor:** add a rule in `.cursor/rules/agent-rm.mdc` or the project's
  `AGENTS.md`:
  > To delete files, use `agent-rm <file>` via Shell (one at a time, no
  > directories). Never use `rm`, `unlink`, `find -delete`, or the Delete tool.

### Step 7 — VERIFY (do not skip)

#### Hook simulation

```bash
REPO=<path-to-this-repo>

# Claude Code hook
H="$REPO/hooks/claude-code/block-rm.sh"
echo '{"tool_input":{"command":"rm foo.txt"}}' | bash "$H"           # → deny JSON
echo '{"tool_input":{"command":"/bin/rm foo"}}' | bash "$H"          # → deny JSON
echo '{"tool_input":{"command":"unlink foo"}}' | bash "$H"           # → deny JSON
echo '{"tool_input":{"command":"find . -delete"}}' | bash "$H"       # → deny JSON
echo '{"tool_input":{"command":"echo f | xargs rm"}}' | bash "$H"    # → deny JSON
echo '{"tool_input":{"command":"agent-rm foo"}}' | bash "$H"         # → empty (allowed)

# Cursor shell hook
H="$REPO/hooks/cursor/block-rm.sh"
echo '{"command":"rm foo.txt"}' | bash "$H"                          # → deny JSON
echo '{"command":"agent-rm foo"}' | bash "$H"                        # → allow JSON

# Cursor Delete hook
H="$REPO/hooks/cursor/block-delete.sh"
echo '{"tool_name":"Delete","tool_input":{"path":"foo.txt"}}' | bash "$H"  # → deny JSON
```

#### Live test (safe)

Run `rm` via the agent's shell tool against a file that does not exist:

```bash
rm /tmp/agent-rm-block-test-does-not-exist
```

- Hook active → denied with the hook's message.
- Hook missing → `No such file or directory` — nothing lost.

Never test with a real file. Only after blocks are confirmed, tell the user
you're done.

### Uninstall

Remove the hook entries from the chosen scope's config, delete the installed hook
scripts. The `agent-rm` executable can stay.
