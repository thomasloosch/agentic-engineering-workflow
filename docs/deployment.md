# Deployment Runbook — Node cron services on Hetzner

Durable procedure for deploying a Node-based scheduled service (e.g. jobs-radar)
to a Hetzner box running it as a host cron job. Derived from the jobs-radar v1
deploy; the rules here are the operationalized "Rule for future deploys" findings
from `docs/metrics/stage-2-retro.md` (D2, D4, D5).

This is the reusable procedure. The retro is the historical record of why each
rule exists. Read this to deploy; read the retro to understand the reasoning.

---

## The target box is not necessarily clean

The Hetzner box in use (`sovary-app`, Nuremberg) is a live, Coolify-managed
product server, not a dedicated host. Consequences:

- Coolify apps carry their own Node **inside Docker**. The host itself may have
  **no system Node** — do not assume `node` exists on the box.
- A deployed cron service runs as a **host cron job alongside** Coolify-managed
  containers. It shares the box; it is not isolated.
- This softens the tooling/product separation the project rules assert. Accept it
  deliberately or deploy to a separate box — do not discover it by surprise.

Verify host Node before anything else:

```bash
which node || echo "NO SYSTEM NODE — install via NodeSource (step 1)"
```

---

## 1. Install Node via NodeSource (D2)

If the host has no system Node, install it apt-managed via NodeSource so it lands
in the system PATH at `/usr/bin/node` and is visible to cron.

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt-get install -y nodejs
which node    # must print /usr/bin/node
node -v       # confirm v22.x
```

**Do not use nvm.** Cron runs without shell init and cannot see nvm-managed
binaries. NodeSource's apt install puts Node on the system PATH where cron and
absolute-path invocations both find it. This is the whole reason for the choice —
nvm would work interactively and then fail silently at 07:00.

---

## 2. Register a read-only deploy key (D4)

A fresh box has no outbound SSH key. HTTPS clone of a private repo fails (GitHub
removed password auth; HTTPS would require a PAT). Use a repo-scoped deploy key —
least privilege for a pull-only box.

```bash
# On the server:
ssh-keygen -t ed25519 -C "deploy-<service>-<host>" -f ~/.ssh/<service>_deploy -N ""
cat ~/.ssh/<service>_deploy.pub
```

Then on GitHub: repo → Settings → Deploy keys → Add deploy key. Paste the public
key. **Leave "Allow write access" unchecked** — the box only pulls.

Point SSH at the key and clone over SSH (not HTTPS):

```bash
cat >> ~/.ssh/config << 'SSHEOF'
Host github.com-<service>
  HostName github.com
  User git
  IdentityFile ~/.ssh/<service>_deploy
  IdentitiesOnly yes
SSHEOF

git clone git@github.com-<service>:<owner>/<repo>.git /opt/<service>
```

Scope the key to the single repo, never account-wide. A pull-only box should not
hold a credential that can write anywhere.

---

## 3. Install production dependencies

On the Linux box this is clean — none of the WSL/MINGW toolchain friction.

```bash
cd /opt/<service>
npm install --omit=dev
```

---

## 4. Configure environment

```bash
cp .env.example .env
nano .env
```

Fill real secrets (SMTP credentials, etc.) and set `NODE_ENV=production` so
fail-closed error branches activate. Never commit `.env` — confirm it is
gitignored.

---

## 5. First manual run — the real end-to-end test

```bash
cd /opt/<service> && NODE_ENV=production /usr/bin/node src/index.js
```

This is the first time the code meets real network sources, real SMTP, real
filesystem state. Watch for the expected first-deploy surprises (scrapers meeting
live markup, etc.). A failure here is debugging, not a build break.

---

## 6. Schedule via cron — absolute interpreter path (D5)

Cron runs with a **stripped PATH** that does not include the NodeSource location.
A bare `node` in a cron entry produces a silent "command not found" at run time —
the job appears scheduled and never runs. Always use the absolute interpreter
path.

```bash
crontab -e
# add (note /usr/bin/node, NOT bare node):
0 7 * * * cd /opt/<service> && NODE_ENV=production /usr/bin/node src/index.js >> /var/log/<service>.log 2>&1
```

**Rule: every cron entry uses absolute interpreter paths. Never rely on PATH in cron.**

### Crontab footgun — user crontab has no username field

`crontab -e` edits a **user crontab**, which has five time fields then the command:
0 7 * * * /usr/bin/node /opt/<service>/src/index.js
│ │ │ │ │ └─ command
└─┴─┴─┴─┴─ minute hour dom mon dow

A **system crontab** (`/etc/crontab`, `/etc/cron.d/*`) inserts a **sixth field —
the username** — between schedule and command:
0 7 * * * thomas /usr/bin/node /opt/<service>/src/index.js
└─ username (system crontab ONLY)

If you paste a system-style line (with username) into a user crontab, cron tries
to run the username as the command and the job silently fails. Match the line
format to the crontab type. When in doubt, `crontab -e` = no username field.

---

## 7. Verify and monitor

```bash
crontab -l                      # confirm the entry registered
tail -f /var/log/<service>.log  # watch the first scheduled run
```

Monitor the log for the first 2–3 scheduled runs. Silent cron failure is the
failure mode these rules exist to prevent — confirm a real run produced real
output, not just that the entry exists.
