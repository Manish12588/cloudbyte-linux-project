# CloudByte Solutions: Linux SysAdmin Project

A Linux system administration project, built first on a local VM
and later deployed to AWS EC2. The scenario is CloudByte Solutions, a
fictional 12-person startup that needs a properly configured multi-user
Linux server: user accounts, group-based file access, automated backups,
log analysis, and system health reporting.

**What this project demonstrates:** user and group administration, least-privilege
file permissions (setgid, sticky bit), idempotent Bash automation with strict mode
and `trap` cleanup, cron-scheduled backups with retention and restore, scripted
self-verification, and runbook-style documentation.

## Repository layout
```
.
├── scripts/                  # everything that changes the server
│   ├── create-foundations.sh # S1: groups, users, /shared
│   ├── setup-permissions.sh  # S2: setgid, dropbox
│   ├── onboard-user.sh       # S3: add users (single/CSV)
│   ├── setup-backups.sh      # S4: /shared/backups dir
│   ├── backup-shared.sh      # S4: nightly archive
│   ├── cleanup-backups.sh    # S4: prune after 7 days
│   ├── restore-backup.sh     # S4: interactive restore
│   ├── log-generator.sh      # S7: synthetic app log
│   ├── analyse-logs.sh       # S7: log analysis report
│   ├── system-health.sh      # S8: health report, alerts
│   └── teardown-users.sh     # lab reset (destructive)
├── tests/                    # everything that only checks
│   ├── verify-foundations.sh # S1 check
│   ├── verify-permissions.sh # S2 check
│   ├── verify-onboarding.sh  # S3 check
│   ├── verify-backup.sh      # S4 check
│   ├── verify-ec2.sh         # S6 check (EC2)
│   ├── verify-logs.sh        # S7 check (EC2)
│   ├── verify-health.sh      # S8 check (EC2)
│   └── verify-all.sh         # runs every verify-*.sh
├── data/
│   ├── new-hires.csv         # sample onboarding input
│   └── cloudbyte-users.csv   # S6: 12-user roster
├── docs/
│   ├── server-handbook.md    # sysadmin runbook
│   ├── server-setup-log.txt  # S1 build record
│   ├── permissions-test-report.md # S2 tests
│   └── differences-log.txt   # S6: VM vs EC2 notes
├── lima-al2023.yaml          # Lima VM definition (AL2023)
└── README.md
```
## Quick start

From the repo root, on a Linux host with `sudo` and `cron` installed:

    bash scripts/create-foundations.sh
    bash tests/verify-foundations.sh
 
    sudo bash scripts/setup-permissions.sh
    bash tests/verify-permissions.sh
 
    sudo bash scripts/onboard-user.sh --csv data/new-hires.csv
    bash tests/verify-onboarding.sh
 
    sudo bash scripts/setup-backups.sh
    sudo bash scripts/backup-shared.sh
    sudo crontab -e            # add the two entries from Section 4
    bash tests/verify-backup.sh
 
    bash tests/verify-all.sh   # everything in one run

Using Lima: `limactl start --name=cloudbyte lima-al2023.yaml`,
`limactl shell cloudbyte`, then `cd /host` and run the commands above.

## Section 1: Server Foundations

Built the core of the server: four groups (`engineering`, `marketing`,
`operations`, `admins`), twelve user accounts, and a directory tree under
`/shared` with group-based access control.

### Groups and users

| Group | Members |
|---|---|
| `engineering` | alice, bob, carol, dave |
| `marketing` | emma, frank, grace |
| `operations` | henry, iris, jack, kate, leo |
| `admins` | kate, leo |

### Directory structure

| Path | Group | Mode |
|---|---|---|
| `/shared/engineering` | engineering | `770` |
| `/shared/marketing` | marketing | `770` |
| `/shared/operations` | operations | `770` |
| `/shared/company-docs` | admins | `775` |
| `/logs/reports` | admins | `775` |

### Creation

`scripts/create-foundations.sh` creates the groups, users, directories and setup
log in one go. Run it on the VM with:

    # Track 1 (Lima): repo is mounted at /host inside the VM
    bash /host/create-foundations.sh

### Verification

`tests/verify-foundations.sh` checks the groups, users, directories and setup
log in one go. Run it on the VM with:

    # Track 1 (Vagrant): repo is mounted at /vagrant
    bash /vagrant/verify-foundations.sh

    # Track 2 (Lima): repo is mounted at /host inside the VM
    bash /host/verify-foundations.sh

## Section 2: File Management and Permissions

Hardened the team folders and added a shared dropbox. Setgid makes team
ownership reliable; the sticky bit makes the dropbox tamper-resistant.
A permissions test report records what was attempted and what happened.

### Updated directory modes

| Path | Owner:Group | Mode | What's special |
|---|---|---|---|
| `/shared/engineering` | `root:engineering` | `2770` | setgid set |
| `/shared/marketing` | `root:marketing` | `2770` | setgid set |
| `/shared/operations` | `root:operations` | `2770` | setgid set |
| `/shared/dropbox` | `root:admins` | `1773` | sticky bit; others can write but not list |

### Verification

`tests/verify-permissions.sh` checks the team folders, the dropbox, the sample
files, and setgid propagation. Run it on the VM with:

    # Track 1 (Vagrant): repo is mounted at /vagrant
    bash /vagrant/verify-permissions.sh

    # Track 2 (Lima): repo is mounted at /host inside the VM
    bash /host/verify-permissions.sh

## Section 3: User Onboarding Automation

Replaced Section 1's manual user-creation work with a single script,
`scripts/onboard-user.sh`, that takes either an interactive prompt or a
CSV of new hires. Strict mode catches failures early, a `create_user`
function carries the four mutating commands, and `--dry-run` lets the
script be exercised without touching real accounts.

### Script flags

| Flag             | Purpose                                                   |
|------------------|-----------------------------------------------------------|
| `--csv PATH`     | Read users from a CSV (`username,group,fullname`)         |
| `--dry-run`      | Print intended actions without creating anything          |
| `-h`, `--help`   | Print the Usage block from the script header              |

A sample CSV ships at `data/new-hires.csv` for repeat runs and
idempotency checks.

### Verification

`tests/verify-onboarding.sh` walks the script and the CSV end-to-end and
prints a ✅ or ❌ for each requirement. Run it on the VM with:

    # Track 1 (Vagrant): repo is mounted at /vagrant
    bash /vagrant/verify-onboarding.sh

    # Track 2 (Lima): repo is mounted at /host inside the VM
    bash /host/verify-onboarding.sh

## Section 4: Backup Automation

Built two scheduled scripts to keep the team folders backed up.
`scripts/backup-shared.sh` archives the whole `/shared` tree (excluding the
backup directory itself) into a date-stamped `.tar.gz` under
`/shared/backups`, with a `trap` that removes a partial archive if the
script is interrupted mid-run. `scripts/cleanup-backups.sh` prunes archives
older than seven days, with a `--preview` flag that lists what would go
without deleting anything. Root cron drives both.

### Schedule

| Script                       | Schedule    | Log file                         |
|------------------------------|-------------|----------------------------------|
| `scripts/backup-shared.sh`   | `0 2 * * *` | `/var/log/cloudbyte-backup.log`  |
| `scripts/cleanup-backups.sh` | `0 3 * * 0` | `/var/log/cloudbyte-cleanup.log` |

### Verification

`tests/verify-backup.sh` walks the backup directory, both scripts, and the
crontab in one go and prints a ✅ or ❌ for each requirement. Run it on
the VM with:

    # Vagrant: repo is mounted at /vagrant
    bash /vagrant/verify-backup.sh

    # Lima: repo is mounted at /host inside the VM
    bash /host/verify-backup.sh

## Section 5: Server Handbook

Wrote `docs/server-handbook.md`, a runbook for a new junior sysadmin: server
overview, users and groups, directory layout, a scripts inventory, scheduled jobs,
common operations, and the self-checks that prove the server matches the document.

## Section 6: EC2 Deployment

Deployed the CloudByte server to a t3.micro Amazon Linux 2023 EC2 instance.
Rebuilt the four groups, the twelve users (kate and leo dual-grouped into
`admins`), and the full `/shared/` tree from scratch on the new host. Sent the
two existing docs and the three scripts across with `scp`, re-established the
backup and cleanup cron pipeline with EC2-absolute paths, and wrote a reflective
`differences-log.txt` recording what changed between the local VM and the cloud.

### Files added

| File | Purpose |
| ---- | ------- |
| `tests/verify-ec2.sh` | Runs on EC2; checks users, groups, directories, docs, scripts and cron |
| `data/cloudbyte-users.csv` | The twelve-staffer production roster |
| `docs/differences-log.txt` | Local VM versus EC2 reflection (default user, home directory, paths) |

### Verification

`tests/verify-ec2.sh` prints a ✅ or ❌ for each requirement. Run it on the
EC2 instance with:

    bash ~/cloud-course/linux-project/tests/verify-ec2.sh

## Section 7: Log Analysis Tools

Built two log-analysis scripts on the EC2 server. `log-generator.sh` fabricates a
synthetic application log at `/logs/cloudbyte-app.log` with weighted severity
levels spread across the day. `analyse-logs.sh` summarises it into a timestamped
report under `/logs/reports/`: counts by severity, the busiest hour, and every
CRITICAL entry, using a `sort | uniq -c | sort -rn` pipeline. Scheduled the
analysis hourly via cron, and added `verify-logs.sh` to check the lot.

### Report sections

| Section | What it shows |
| ------- | ------------- |
| Count By Severity | Number of INFO, WARN, ERROR and CRITICAL lines |
| Count By Busiest Hours | The single hour with the most entries |
| CRITICAL Entries | Every CRITICAL line, or `(none)` |

### Schedule

| Script | Schedule | Log file |
| ------ | -------- | -------- |
| `scripts/analyse-logs.sh` | hourly (`0 * * * *`) | `/var/log/cloudbyte-loganalysis.log` |

### Verification

`tests/verify-logs.sh` checks both scripts, the generated log, the report
sections and the cron entry. Run it on the EC2 instance with:

    sudo bash scripts/log-generator.sh      # generate data first
    sudo bash scripts/analyse-logs.sh       # produce a report
    bash tests/verify-logs.sh

## Section 8: System Health Dashboard

Built system-health.sh on the EC2 server. It snapshots uptime/load, memory,
disk, the top processes by CPU, the status of crond and sshd, and logged-in
users into a printf-formatted, timestamped report under /logs/health-reports/.
It raises basic alerts (disk over 80%, zombie processes, a monitored service
down) and archives reports older than a week. Scheduled every 2 hours via cron,
and added verify-health.sh to check the lot.

### Alerts

| Alert | Trigger |
| ----- | ------- |
| Disk | Root filesystem usage above 80% |
| Zombies | One or more zombie processes |
| Service down | `crond` or `sshd` not active |

### Schedule

| Script | Schedule |
| ------ | -------- |
| `scripts/system-health.sh` | every 2 hours (`0 */2 * * *`) |

### Verification

`tests/verify-health.sh` checks the script, a report carrying every section plus
Alerts, the archive directory and the cron entry. Run it on the EC2 instance
(after running `system-health.sh` at least once) with:

    sudo bash scripts/system-health.sh
    bash tests/verify-health.sh
 