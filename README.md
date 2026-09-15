# Zimbra Move Mailbox Script

A Bash script for migrating mailboxes between **Zimbra Open Source** servers, including signatures, mail filters (sieve scripts), forwarding addresses, and distribution list memberships. Useful for server-to-server mailbox migrations without long downtime.

> ⚠️ **This script performs destructive operations** (account renaming, temporary file cleanup, creating new accounts). Read this entire README and **test in a staging environment** before using it in production.

## Features

- Backup & restore **HTML signature** and signature name per account.
- Backup & restore **mail filter** (`zimbraMailSieveScript`).
- Copy account attributes: `displayName`, `givenName`, `initials`, `sn`, `description`, `zimbraCOSid`, `zimbraIsAdminAccount`.
- Migrate **mail forwarding address**.
- Migrate **distribution list** memberships (via `ldapsearch`).
- Transfer mailbox content (email, calendar, etc.) using the Zimbra REST API (`fmt=tgz`).
- **Double-sync mechanism**: after the main mailbox is moved, a re-sync is performed to capture emails received during the migration process (via the `.backup` account).
- Sets the mailbox quota to *unlimited* temporarily during migration, then restores it to the COS default once complete.

## Workflow (per account)

For each account `user` listed in the account list file, the script does the following:

1. **Backup metadata** — signature, filter, and contact attributes from the source account.
2. **Create a temporary account** `user.move@domain` on the destination server with a default password, then apply the backed-up attributes (quota set to `0`/unlimited for now).
3. **Restore** forwarding address, distribution list membership, filter, and signature to the `user.move` account.
4. **Download** the `user@domain` mailbox content from the source server (`.tgz` format), then **upload** it to `user.move@domain` on the destination server.
5. **Rename**: `user@domain` → `user.backup@domain` (on the source), then `user.move@domain` → `user@domain` (on the destination). The primary email address is now active on the destination server.
6. **Finalize sync**: re-download the `user.backup@domain` mailbox from the source (capturing any new emails received during the process) and upload it to `user@domain` on the destination with `resolve=skip` (to avoid duplicates).
7. **Restore the quota** back to the default (no longer unlimited) for both the active and backup accounts.

## Prerequisites

- SSH access to both the source **and** destination Zimbra servers.
- The following tools available in PATH: `zmprov`, `ldapsearch`, `curl`, `sed`, `grep`, `cut`, `tr`.
- Zimbra admin credentials (source & destination) and the LDAP password (`uid=zimbra,cn=admins,cn=zimbra`).
- Run by a user with permission to execute `zmprov` (typically the `zimbra` user, or via `sudo -u zimbra`).
- The following working directories **must be created manually** before running the script (the script does not create them automatically):
  ```bash
  mkdir -p tmp signature filter
  ```

## Configuration

Set the following variables at the top of the script before running it:

| Variable | Description |
|---|---|
| `DOMAIN` | The email domain being migrated (e.g. `example.com`) |
| `FILELISTACCOUNT` | Path to the file containing the list of usernames to migrate (default: `/tmp/listmove`) |
| `SOURCEMAILBOXIP` | IP/hostname of the source Zimbra server |
| `SOURCEADMIN` / `SOURCEPASSWORD` | Admin REST API credentials for the source server |
| `DESTINATIONMAILBOXIP` | IP/hostname of the destination Zimbra server |
| `DESTINATIONADMIN` / `DESTINATIONPASSWORD` | Admin REST API credentials for the destination server |
| `PASSWORDLDAP` | LDAP bind password used for querying distribution lists |
| `HOSTNAMEMAILBOXDESTINATION` | Value for `zimbraMailHost` on the newly created destination account |

### Account list file format (`FILELISTACCOUNT`)

One username (without the domain) per line:

```
budi
siti
andi
```

## Usage

```bash
chmod +x zimbra-movemailbox.sh
./zimbra-movemailbox.sh
```

Run it on a server that has access to `zmprov` on the source server (typically executed directly on the source mailbox server as the `zimbra` user).

## ⚠️ Security Notes & Important Warnings

Before using this in production, it is strongly recommended to fix the following:

1. **Replace it with variables** (`$SOURCEADMIN:$SOURCEPASSWORD`) and never commit real credentials to a public repository. Consider using environment variables or a separate secrets file (`.env`, excluded from version control).
2. **Default password for temporary accounts** — `DefaultPasswordQAZXSW` is static and weak. Replace it with a strong, randomly generated password per account, or disable login for `.move` accounts during migration.
3. **`curl -k`** — disables SSL certificate validation. This is generally acceptable for internal migrations, but make sure traffic stays within a trusted network (VPN/private network).
4. **No error handling** — the script does not stop if a `zmprov`/`curl` command fails (no `set -e` or exit code checks). For large-scale migrations, it's recommended to add logging and status checks at each step so failed accounts can be identified.
5. **Account rename operations** are sensitive — if the process is interrupted midway (e.g. after renaming but before the final sync), an account could end up in an inconsistent state. Consider adding a resume/rollback mechanism, or at minimum log progress per account.
6. **Temporary unlimited quota** — make sure there's enough disk space on the destination server during migration, since the quota is set to unlimited before the transfer completes.

## License

Use and modify as needed (add your preferred license here, e.g. MIT).
