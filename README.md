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
├── scripts/                   # everything that changes the server
│   ├── create-foundations.sh  # Section 1: groups, users, /shared tree
│   ├── setup-permissions.sh   # Section 2: setgid, dropbox, sample files
│   ├── onboard-user.sh        # create users singly or from CSV
│   ├── setup-backups.sh       # Section 4: /shared/backups directory
│   ├── backup-shared.sh       # nightly /shared archive
│   ├── cleanup-backups.sh     # prune archives older than 7 days
│   ├── restore-backup.sh      # interactive restore
│   └── teardown-users.sh      # lab reset (destructive)
├── tests/                     # everything that only checks
│   ├── verify-foundations.sh  # Section 1 check
│   ├── verify-permissions.sh  # Section 2 check
│   ├── verify-onboarding.sh   # Section 3 check
│   ├── verify-backup.sh       # Section 4 check
│   └── verify-all.sh          # runs every verify-*.sh
├── data/new-hires.csv         # sample input for onboarding
├── docs/
│   ├── server-handbook.md     # runbook for a new junior sysadmin
│   ├── server-setup-log.txt   # Section 1 build record
│   └── permissions-test-report.md
├── lima-al2023.yaml           # VM definition (Amazon Linux 2023, Lima)
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