![image](https://github.com/theapsgroup/steampipe-plugin-gitlab/raw/main/docs/gitlab-plugin-social-graphic.png)

# GitLab plugin for Steampipe

* **[Get started →](https://hub.steampipe.io/plugins/theapsgroup/gitlbb)**
* Documentation: [Table definitions & examples](https://hub.steampipe.io/plugins/theapsgroup/gitlab/tables)
* Community: [Join #steampipe on Slack →](https://turbot.com/community/join)
* Get involved: [Issues](https://github.com/theapsgroup/steampipe-plugin-gitlab/issues)

## Quick start

Install the plugin with [Steampipe](https://steampipe.io/downloads):

```shell
steampipe plugin install theapsgroup/gitlab
```

[Configure the plugin](https://hub.steampipe.io/plugins/theapsgroup/gitlab#configuration) using the configuration file:

```shell
vi ~/.steampipe/gitlab.spc
```

Or environment variables:

```shell
export GITLAB_TOKEN=f7Ea3C3ojOY0GLzmhS5kE
```

Start Steampipe:

```shell
steampipe query
```

Run a query:

```sql
select
  full_path,
  visibility,
  forks_count,
  star_count
from
  gitlab_my_project;
```

## Developing

Prerequisites:

* [Nix](https://nixos.org/download/) with flakes enabled (manages all other dependencies)
* GitLab (either hosted or self-hosted)
* GitLab Token (either private or [personal access token](https://docs.gitlab.com/ee/user/profile/personal_access_tokens.html))

> **NixOS note:** Steampipe downloads a `steampipe-postgres-fdw` binary at first run. On NixOS this fails because the binary expects a standard glibc dynamic linker. The fix is to enable `programs.nix-ld.enable = true` in your NixOS configuration and rebuild, which provides the compatibility layer needed for arbitrary Linux binaries.

Clone:

```sh
git clone https://github.com/theapsgroup/steampipe-plugin-gitlab.git
cd steampipe-plugin-gitlab
```

Enter the dev shell (provides Go, Steampipe, gomod2nix, and helper scripts):

```sh
nix develop
```

Build and install the plugin into the project-local `.steampipe` directory:

```sh
nix run .#install
```

Configure the plugin:

```sh
cp config/* .steampipe/config
vi .steampipe/config/gitlab.spc
```

Try it:

```shell
steampipe --install-dir $(pwd)/.steampipe query
> .inspect gitlab
```

> **Dependency changes:** After any `go get` or `go mod tidy`, run `gomod2nix` to keep `gomod2nix.toml` in sync with `go.mod`.

### Testing

Unit and structural tests live in `gitlab/` and require no network access:

```sh
go test ./...
```

Run a specific test:

```sh
go test -run TestParseAccessLevel -v ./gitlab/
```

The full Nix-sandboxed check (runs tests and lint in an isolated environment):

```sh
nix flake check --print-build-logs
```

The dev shell also provides a `query-project` helper that runs a sample Steampipe query against project ID 82145074 using the project-local `.steampipe` directory:

```sh
query-project
```

#### Test coverage

| File | What is tested |
|------|----------------|
| `main_test.go` | `Plugin()` returns a non-nil plugin |
| `gitlab/plugin_test.go` | Plugin name, all 39 tables registered, each table has columns and a hydrate config |
| `gitlab/utils_test.go` | `sanitizeUrl`, `parseAccessLevel`, `accessLevelTransform`, `isoTimeTransform` |

Further reading:

* [Writing plugins](https://steampipe.io/docs/develop/writing-plugins)
* [Writing your first table](https://steampipe.io/docs/develop/writing-your-first-table)

## Contributing

All contributions are subject to the [Apache 2.0 open source license](https://github.com/theapsgroup/steampipe-plugin-gitlab/blob/main/LICENSE).

`help wanted` issues:

* [Steampipe](https://github.com/turbot/steampipe/labels/help%20wanted)
* [GitLab Plugin](https://github.com/theapsgroup/steampipe-plugin-gitlab/labels/help%20wanted)

## Credits

GitLab API Wrapper [xanzy/go-gitlab](https://github.com/xanzy/go-gitlab) (licensed separately using this [Apache License](https://github.com/xanzy/go-gitlab/blob/master/LICENSE))