# MCP — 3-sided diff test project

Sample Flyway Desktop project for validating the 3-sided diff working end-to-end.

The end-to-end walkthrough scripts — snapshot, simulate pull, create diff, apply —
lives in [`scripts/README.md`](scripts/README.md). 

## Prerequisites

### 1. SQL Server

A reachable SQL Server instance with a login that can create and drop
tables in a `dev` database. Any host, port, and credentials will do — you'll
plug them into `flyway.toml` and the scripts below.

### 2. Python 3

Used by `scripts/apply_pull_edits.py`. No external packages required. On
Windows use `python`, not `python3` (the latter resolves to the Store
alias).

### 3. Flyway build with the 3-sided diff branch

You need a local Flyway CLI built with the most recent changes of the 3-sided-diff. From a checkout of `flyway-main`:

That produces the CLI under
`flyway-redgate-dist/target/install dir/flyway-<version>/flyway.cmd`. Note
the full path — you'll wire it into `.mcp.json` below.

### 4. MCP client

Any MCP client that can launch a stdio server (Claude Desktop, Claude Code,
etc.). The `.mcp.json` in this repo is set up for Claude Code — adapt if
you use a different client.

## One-time setup

### Update `.mcp.json` to point at your Flyway build

Open [`.mcp.json`](.mcp.json) and replace the `command` path with the
absolute path to *your* `flyway.cmd`:

```json
{
  "mcpServers": {
    "flyway": {
      "type": "stdio",
      "command": "C:\\path\\to\\flyway-main\\flyway-redgate-dist\\target\\install dir\\flyway-<version>\\flyway.cmd",
      "args": ["mcp"],
    }
  }
}
```

### Point `flyway.toml` at your database

Edit [`flyway.toml`](flyway.toml) and update `[environments.development]`
so `url`, `user`, and `password` match your SQL Server. That's the only
environment the walkthrough uses.

### Match the scripts to the same credentials

The reset commands in `scripts/README.md` invoke `sqlcmd` with `-S -U -P -d`
flags — use the same values you put in `flyway.toml`. Substitute your own
`<server>`, `<user>`, `<password>`, and `<database>` wherever you see
those flags in this README or in `scripts/README.md`.

### Seed the dev database

From the project root, using your own credentials:

```
sqlcmd -S <server> -U <user> -P <password> -d <database> -i scripts/00_setup_dev.sql
```

This creates the baseline `Customers.*` tables plus the local drift
(`Customer.LoyaltyPoints`, widened `Newsletter.Title`). Schema-model on
disk is already at the pre-pull baseline — leave it alone.

## Running the scenario

Open this directory in your MCP client, then follow
[`scripts/README.md`](scripts/README.md) from step 1.

## Reset between runs

```
sqlcmd -S <server> -U <user> -P <password> -d <database> -i scripts/99_reset.sql
python scripts/apply_pull_edits.py --revert
sqlcmd -S <server> -U <user> -P <password> -d <database> -i scripts/00_setup_dev.sql
```

That returns you to step 2 of the walkthrough.
