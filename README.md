# CloudByte Solutions: Linux SysAdmin Project

A Linux system administration project, built first on a local VM
and later deployed to AWS EC2. The scenario is CloudByte Solutions, a
fictional 12-person startup that needs a properly configured multi-user
Linux server: user accounts, group-based file access, automated backups,
log analysis, and system health reporting.

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

`create-foundations.sh` creates the groups, users, directories and setup
log in one go. Run it on the VM with:

    # Track 1 (Lima): repo is mounted at /host inside the VM
    bash /host/create-foundations.sh

### Verification

`verify-foundations.sh` checks the groups, users, directories and setup
log in one go. Run it on the VM with:

    # Track 1 (Vagrant): repo is mounted at /vagrant
    bash /vagrant/verify-foundations.sh

    # Track 2 (Lima): repo is mounted at /host inside the VM
    bash /host/verify-foundations.sh