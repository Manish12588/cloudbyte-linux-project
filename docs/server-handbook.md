# CloudByte Server Handbook

## Server overview

The CloudByte server is one multi-user Linux host that serves the company's twelve staff. It holds the three team folders, a shared notice board, a write-only dropbox, and the nightly backups of all of it. Everything on it is built and checked by scripts in this repo, so a broken server is rebuilt from the repo rather than repaired by hand.

| Item | Value |
|---|---|
| Operating system | Amazon Linux 2023 (aarch64) |
| Where it runs | Lima VM (`vz`) on a macOS host; a later section moves it to AWS EC2 |
| Size | 2 vCPU, 2 GiB RAM, 30 GiB disk |
| Repo location in the VM | `/host` (the project repo, mounted read/write from the Mac) |
| Scheduler | `crond`, root crontab |
| Sysadmins | `kate` and `leo` (the `admins` group) |

`admins` is a file-access group, not a sudo group. Nothing in this repo gives `kate` or `leo` sudo rights, so privileged work runs from the VM's own login account.

How the server has changed:

| Stage | What was added | Where it lives |
|---|---|---|
| Foundations (28 Sep 2026) | Four groups, twelve users, team folders at mode `770`, company-docs and reports directories | `scripts/create-foundations.sh`, `tests/verify-foundations.sh` |
| Permissions (29 Sep) | Setgid on team folders, sticky-bit dropbox, permissions test report | `tests/verify-permissions.sh`, `docs/permissions-test-report.md` |
| Onboarding (1 Oct) | One script that creates users singly or from a CSV | `scripts/onboard-user.sh`, `tests/verify-onboarding.sh` |
| Backups (2 Oct) | Nightly archive, weekly prune, interactive restore, root cron | `scripts/backup-shared.sh`, `scripts/cleanup-backups.sh`, `scripts/restore-backup.sh`, `tests/verify-backup.sh` |

Each stage tightened or automated the one before it and never replaced it, and every stage ships with a verify script, so the server can be proven to match this document instead of trusted to.


## Users and groups

CloudByte runs with twelve staff across three teams: Engineering, Marketing, and Operations. Each team has its own group, and two Operations staff also sit in the `admins` group for sysadmin work. Every user has a standard home directory and a shell login.

| Username | Full name | Group(s) | Department |
|---|---|---|---|
| alice | Alice Tan | engineering | Engineering |
| bob | Bob Patel | engineering | Engineering |
| carol | Carol O'Sullivan | engineering | Engineering |
| dave | Dave Yamamoto | engineering | Engineering |
| emma | Emma Kowalski | marketing | Marketing |
| frank | Frank Nguyen | marketing | Marketing |
| grace | Grace Okafor | marketing | Marketing |
| henry | Henry Mendez | operations | Operations |
| iris | Iris Brennan | operations | Operations |
| jack | Jack Hossain | operations | Operations |
| kate | Kate Reilly | operations, admins | Operations |
| leo | Leo Costa | operations, admins | Operations |

| Group | Members | Access |
|---|---|---|
| engineering | alice, bob, carol, dave | Read/write to `/shared/engineering` |
| marketing | emma, frank, grace | Read/write to `/shared/marketing` |
| operations | henry, iris, jack, kate, leo | Read/write to `/shared/operations` |
| admins | kate, leo | Write to `/shared/company-docs` and `/logs/reports`; read dropbox submissions |

Admins post to the company notice board and reports directories and triage the dropbox; team members write only to their own folder. Least-privilege as usual.

## Server layout
All shared data lives under `/shared`, with one reports directory under `/logs`. Every directory is owned by `root`; access is decided by the group, so removing a person from a group is the only step needed to revoke their access.

```
/shared/
├── engineering/   root:engineering   2770
├── marketing/     root:marketing     2770
├── operations/    root:operations    2770
├── company-docs/  root:admins        775
├── dropbox/       root:admins        1773
└── backups/       root:admins        2770
/logs/
└── reports/       root:admins        775
```
| Path | Owner:Group | Mode | What it means |
|---|---|---|---|
| `/shared/engineering` | `root:engineering` | `2770` | Team only; setgid so new files inherit the `engineering` group |
| `/shared/marketing` | `root:marketing` | `2770` | Team only; setgid so new files inherit the `marketing` group |
| `/shared/operations` | `root:operations` | `2770` | Team only; setgid so new files inherit the `operations` group |
| `/shared/company-docs` | `root:admins` | `775` | Everyone reads; only admins write (company notice board) |
| `/shared/dropbox` | `root:admins` | `1773` | Anyone can drop a file in but cannot list it; sticky bit stops deleting other people's files; admins triage |
| `/shared/backups` | `root:admins` | `2770` | Backup archives; admins only, and excluded from the archives themselves |
| `/logs/reports` | `root:admins` | `775` | Everyone reads; only admins write |

Log files for the scheduled jobs sit outside this tree in `/var/log`: `cloudbyte-backup.log`, `cloudbyte-cleanup.log`, and `cloudbyte-onboarding.log`.

Setgid keeps "which files belong to the team" answerable, the sticky bit keeps submissions safe from other staff, and `other` has no access to any team folder, which is the least-privilege default. One known gap: the dropbox hides filenames but not contents, so anyone who already knows a filename can read that file.

## Scripts inventory

Scripts that change the server live in `scripts/`; scripts that only check it live in `tests/`. Anything that changes users, groups, or backups must run as root; the scripts refuse to run otherwise.

| Script | Purpose | Trigger |
|---|---|---|
| `scripts/create-foundations.sh` | Creates the four groups, twelve users, and the `/shared` and `/logs/reports` directories with their groups and modes | Manual, once, when building the server |
| `scripts/onboard-user.sh` | Creates a user with a temporary password, adds them to a team group, and forces a password change at first login; takes `--csv PATH` and `--dry-run` | Manual, when someone joins |
| `scripts/backup-shared.sh` | Archives `/shared` into a date-stamped `.tar.gz` in `/shared/backups`, removing a partial archive if interrupted | Cron, daily at 02:00; also manual |
| `scripts/cleanup-backups.sh` | Deletes archives older than seven days; `--preview` lists them without deleting | Cron, Sundays at 03:00; also manual |
| `scripts/restore-backup.sh` | Lists archives, lets you pick one, and extracts it to a path you choose; refuses to extract over `/shared` | Manual, when something must be recovered |
| `scripts/teardown-users.sh` | Lab reset: deletes the twelve staff users, their private groups, the four team groups, and their home directories; no confirmation prompt | Manual, only to wipe a practice server |
| `tests/verify-foundations.sh` | Self-check for groups, users, and base directories | Manual, after a build or change |
| `tests/verify-permissions.sh` | Self-check for team-folder modes, setgid, and the dropbox | Manual, after a build or change |
| `tests/verify-onboarding.sh` | Self-check for the onboarding script and its CSV run | Manual, after a change to the script |
| `tests/verify-backup.sh` | Self-check for the backup directory, both backup scripts, and cron | Manual, after a change to the backups |
| `tests/verify-handbook.sh` | Checks this handbook has every section and mentions every script | Manual, after editing this file |
| `tests/verify-all.sh` | Runs every `verify-*.sh` in turn and prints one summary | Manual, before handing over the server |

Most scripts that change the system support a preview (`--dry-run`, `--preview`) or ask before acting (`restore-backup.sh`), so a junior can look first. `teardown-users.sh` does neither, so never run it on a server with real users.

## Scheduled jobs
Two jobs run from root's crontab, one backing up and one pruning, and on Sundays the prune starts an hour after that night's backup so the two never overlap. Edit them with `sudo crontab -e` and read them with `sudo crontab -l`.

| Schedule | Command | Log |
|---|---|---|
| `0 2 * * *` (daily, 02:00) | `/host/scripts/backup-shared.sh >> /var/log/cloudbyte-backup.log 2>&1` | `/var/log/cloudbyte-backup.log` |
| `0 3 * * 0` (Sundays, 03:00) | `/host/scripts/cleanup-backups.sh >> /var/log/cloudbyte-cleanup.log 2>&1` | `/var/log/cloudbyte-cleanup.log` |

Both entries use absolute paths because cron has almost no `PATH`, and both redirect output to a log because cron otherwise discards it. The scripts are read from `/host`, so if the repo mount is missing after a reboot the jobs fail silently: check `ls /host/scripts` first when a log has stopped growing.

## Common operations

These are the routine tasks, each as the one-liner to run. Run them on the VM with `sudo` unless a step says otherwise.

| Task | Command |
|---|---|
| Add one user interactively | `sudo bash /host/scripts/onboard-user.sh` |
| Add users from a CSV (`username,group,fullname`) | `sudo bash /host/scripts/onboard-user.sh --csv /host/data/new-hires.csv` |
| Rehearse onboarding without creating anyone | `sudo bash /host/scripts/onboard-user.sh --csv /host/data/new-hires.csv --dry-run` |
| Force a password change at next login | `sudo chage -d 0 USERNAME` |
| List who is in a group | `getent group engineering` |
| Remove someone from a team group | `sudo gpasswd -d USERNAME engineering` |
| Run a backup now | `sudo bash /host/scripts/backup-shared.sh` |
| See which archives the weekly prune would delete | `sudo bash /host/scripts/cleanup-backups.sh --preview` |
| Restore from a backup | `sudo bash /host/scripts/restore-backup.sh` |
| Check the scheduled jobs | `sudo crontab -l` |
| Read the latest backup log lines | `sudo tail -n 20 /var/log/cloudbyte-backup.log` |
| Remove the accounts left by `tests/verify-onboarding.sh` | `for u in testuser1 testuser2 testuser3; do sudo userdel -r "$u"; done` |

Each command is a script or a standard tool that checks before it acts, so a typo costs a re-run and not a recovery. A restore always lands in a fresh directory, never over `/shared`, so a junior can inspect the old files before copying anything back.

## Self-checks

Each build stage has a verify script that prints a ✅ or ❌ per requirement and exits non-zero if any fails. Run them on the VM, where the repo is mounted at `/host`; `tests/verify-all.sh` runs the whole set.

| Invocation | What it confirms |
|---|---|
| `bash /host/tests/verify-foundations.sh` | The four groups exist, all twelve users are in the right groups, the five base directories have the right group and mode, and the setup log exists |
| `bash /host/tests/verify-permissions.sh` | Team folders are `2770` with the right group, new files inherit the team group, and the dropbox is sticky, admin-owned, writable but not listable by staff |
| `bash /host/tests/verify-onboarding.sh` | The onboarding script has strict mode and a `create_user` function, `--help` and `--dry-run` behave, a CSV run creates users in the right groups, and a second run skips them |
| `bash /host/tests/verify-backup.sh` | `/shared/backups` is `root:admins 2770`, both backup scripts are executable with strict mode, the latest archive holds the team folders and excludes the backups directory, root cron has both jobs, and `crond` is active |
| `bash /host/tests/verify-handbook.sh` | This handbook has all seven headings in order, no empty sections, and mentions every script in the repo |
| `bash /host/tests/verify-all.sh` | Runs all of the above and prints a combined result |

Run `tests/verify-backup.sh` after at least one backup exists, or its archive checks fail. `tests/verify-onboarding.sh` leaves `testuser1` to `testuser3` behind, so remove them with the command under Common operations.

A green run of these scripts is the definition of "the server matches the handbook", so a failure means either the server drifted or this document did, and either way someone should fix it that day.
