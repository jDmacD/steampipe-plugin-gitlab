# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build and install plugin into the project-local .steampipe directory
nix run .#install
# equivalent: go build -o .steampipe/plugins/hub.steampipe.io/plugins/theapsgroup/gitlab@latest/steampipe-plugin-gitlab.plugin

# Run tests
go test -v ./...
go test -run TestFunctionName -v ./...

# Lint
golangci-lint run

# Nix-based (runs tests + lint in sandboxed env)
nix flake check --print-build-logs

# Enter Nix dev shell
nix develop
```

When using the Nix dev shell, `gomod2nix.toml` must be kept in sync with `go.mod`. Run `gomod2nix` after any `go get` / `go mod tidy`.

## Running an sql query
```bash
steampipe --install-dir "$(git rev-parse --show-toplevel)/.steampipe" query "select name, tag_list from gitlab_group_project where group_id = 1292;" --output json
```
```bash
nix develop --command steampipe --install-dir "$(git rev-parse --show-toplevel)/.steampipe" query "select * FROM gitlab_project WHERE id = 82145074;" --output json
```
Add a `LIMIT` unless explicitly told not to

## Publishing to GHCR

The `publish` command (available in `nix develop`) pushes the plugin to `ghcr.io/jdmacd/steampipe-plugin-gitlab` as an OCI artifact in the format Steampipe expects.

```bash
# Build release artifacts first
release --clean          # runs goreleaser, outputs to dist/

# Push to GHCR (authenticates via gh CLI, no extra token needed)
publish 0.2.0            # pushes :0.2.0 and retags :latest
```

The OCI format uses a **single manifest** (not a multi-arch index) with one layer per platform, each with a platform-specific media type (`application/vnd.turbot.steampipe.plugin.linux-amd64.layer.v1+gzip` etc.) and a config blob (`application/vnd.turbot.steampipe.config.v1+json`). This is how Steampipe selects the right binary — by layer media type, not OCI platform fields.

The GHCR package must be set to **Public** (GitHub → Packages → steampipe-plugin-gitlab → Settings → Change visibility). Users install with:

```bash
steampipe plugin install ghcr.io/jdmacd/steampipe-plugin-gitlab:latest
```

## Architecture

This is a [Steampipe](https://steampipe.io) plugin that exposes GitLab resources as SQL tables. Steampipe loads the plugin binary and queries it via gRPC using the plugin SDK.

**Entry point:** `main.go` → `plugin.Serve()` → `gitlab/plugin.go`

**plugin.go** registers all 38 tables in a `TableMap`. Each table maps to a file `gitlab/table_gitlab_<name>.go`.

**Connection & client:** `gitlab/connection_config.go` defines `GitLabConfig` (fields: `Token`, `BaseUrl`). The `connect()` helper in `gitlab/utils.go` creates a `*go_gitlab.Client` (using `github.com/xanzy/go-gitlab`) and caches it in `d.ConnectionCache` so it is reused across hydrate calls within a connection.

Config is read from `~/.steampipe/config/gitlab.spc` or env vars `GITLAB_TOKEN` / `GITLAB_ADDR`.

**Table pattern:** Every table file defines:
1. A function returning `*plugin.Table` with `Name`, `Description`, `List`/`Get` hydrators, and `Columns`.
2. One or more hydrate functions that call the GitLab API, paginate via `resp.NextPage`, and stream rows with `d.StreamListItem(ctx, item)`. Check `d.RowsRemaining(ctx) == 0` to short-circuit pagination early.
3. Columns typed with `proto.ColumnType_*` and optional transforms (e.g., `transform.FromField("FieldName")`).

**Public GitLab guard:** `gitlab/utils.go` `isPublicGitLab()` detects when the configured endpoint is `gitlab.com`. Tables that could enumerate millions of rows (users, projects, issues, MRs) require an `=` qualifier when running against public GitLab and return an error otherwise.

**Shared transforms / helpers in `gitlab/utils.go`:**
- `sanitizeUrl` — strips trailing `/api/v4` from base URL
- `isoTimeTransform` — converts `*time.Time` to ISO 8601 string column
- `accessLevelTransform` — maps numeric GitLab access level to human-readable string

## Adding a New Table

1. Create `gitlab/table_gitlab_<name>.go` following the existing pattern.
2. Register it in the `TableMap` in `gitlab/plugin.go`.
3. Add a doc page at `docs/tables/gitlab_<name>.md`.
