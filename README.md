# apt formula

Manage `apt` on Debian and Ubuntu: sources, keyrings, pinning preferences,
`apt.conf.d` snippets, unattended-upgrades, apt-listchanges, PPAs, and
package refresh/upgrade.

This is a refactor of `saltstack-formulas/apt-formula`, narrowed to a
single, modern target so the states can be simpler and more correct.

## Scope

- OS: Debian 12 (bookworm) / 13 (trixie), Ubuntu 24.04+
- Salt: 3008+
- Older OS releases, other distros (RHEL/SUSE/etc.), and pre-3008 Salt are
  out of scope. If you need those, use the upstream `apt-formula` instead.

## Why this fork exists

This formula was pulled in alongside a refactored `salt` formula (also in
this repo) and hit a real "Detected conflicting IDs" failure the two
formulas caused together: both used the bare path `/etc/apt/keyrings` as a
literal state ID. Salt state IDs must be globally unique across an entire
compiled highstate, not just within one SLS file, so any two formulas that
happen to manage the same path with a naive `<path>: file.directory: ...`
state will collide the moment they're both applied to the same host.

Fixing that properly meant going through every state in this formula, not
just the one that collided. Along the way a few other genuine bugs
surfaced and got fixed too - see below.

### Bugs fixed

**Dead SKS keyserver.** `map.jinja`'s Debian block defaulted
`default_keyserver` to `pool.sks-keyservers.net`. The SKS keyserver pool
was decommissioned around 2021; any repo relying on `keyid` + `keyserver`
resolution against that host just fails. Default is now
`keyserver.ubuntu.com`. Prefer `key_url` over `keyid`/`keyserver` in your
own repo definitions regardless - see "Adding a repository" below.

**Wrong Debian security-repo layout.** The built-in `security-stable`
repository entry used the pre-Debian-9 suite layout
(`<codename>/updates` under bare `security.debian.org/`). Debian 9 onward
(including 12/13) uses `<codename>-security` under
`security.debian.org/debian-security/`. Fixed in `map.jinja`.

**Dead package name in `ppa.sls`.** It installed `python-software-properties`,
which was renamed to `software-properties-common` around the Ubuntu
16.04 / Debian 9 era and no longer exists as a package on any supported
target here. Fixed.

**`cmd.run: apt-get ...` instead of the `pkg` module.** `update.sls`,
`upgrade.sls`, and `dist_upgrade.sls` used to shell out directly
(`apt-get -y update`, etc.). Rewritten to use `module.run` against
`pkg.refresh_db` / `pkg.upgrade` (the latter with `dist_upgrade: True|False`),
which goes through Salt's own apt backend - proper `test=True` dry-run
support, structured error/return handling, no dependency on a specific
shell or apt's own output format. Their `onchanges` requisites also used
to reference `repositories.sls`'s managed paths by their literal default
names (`/etc/apt/sources.list`, `/etc/apt/sources.list.d`), which silently
broke if you customized `apt:sources_list_dir` in pillar. They now
reference `repositories.sls`'s actual state IDs instead.

**Orphaned `auth.conf.jinja` template.** The template for
`/etc/apt/auth.conf` (HTTP basic auth credentials for authenticated repos)
existed in `templates/` but nothing rendered it. `repositories.sls` now
has an `apt-repositories-auth-conf` state that renders it whenever
`apt:auth` is set in pillar.

**State ID namespacing.** Every state ID in this formula is now prefixed
`apt-*` (or `apt-repo-<name>-*` for per-repository states) with an
explicit `name:` parameter carrying the actual managed path, instead of
using the path itself as the ID. This is the actual fix for the
conflicting-IDs failure, and it also makes `test=True` output and state
run logs readable (you see `apt-repositories-sources-list-dir`, not a
bare path that could belong to any formula).

## Usage

```yaml
include:
  - apt
```

`apt/init.sls` includes only the safe, idempotent baseline:
`apt.repositories`, `apt.preferences`, `apt.apt_conf`. It deliberately does
**not** pull in `apt.unattended`, `apt.listchanges`, `apt.ppa`,
`apt.update`, `apt.upgrade`, or `apt.dist_upgrade` - those either install
extra packages, change upgrade behavior, or actually upgrade packages, so
they're opt-in per host:

```yaml
include:
  - apt
  - apt.unattended
  - apt.listchanges
```

Available states:

| State | What it does |
|---|---|
| `apt.repositories` | Manages `/etc/apt/sources.list`, the keyrings dir, and any repos in `apt:repositories` (default: the OS's standard main/security/updates repos) |
| `apt.preferences` | Manages `/etc/apt/preferences` and pin files in `apt:preferences` |
| `apt.apt_conf` | Manages `/etc/apt/apt.conf` and snippets in `apt:apt_conf_d` |
| `apt.unattended` | Installs `unattended-upgrades`, configures `50unattended-upgrades` and `10periodic` |
| `apt.listchanges` | Installs `apt-listchanges`, configures `/etc/apt/listchanges.conf` |
| `apt.ppa` | Installs `software-properties-common` (for `add-apt-repository`) |
| `apt.update` | Refreshes the package DB (`pkg.refresh_db`), reacting to repo changes |
| `apt.upgrade` | `pkg.upgrade` (equivalent to `apt-get upgrade`) |
| `apt.dist_upgrade` | `pkg.upgrade` with `dist_upgrade: True` (equivalent to `apt-get dist-upgrade`) |
| `apt.transports.https` | Installs `apt-transport-https` (built into apt itself since Debian 10 / Ubuntu 18.04 - rarely needed) |
| `apt.transports.debtorrent` | Installs `apt-transport-debtorrent` |

## Pillar reference

Every key below is optional; the formula ships sensible OS-specific
defaults in `map.jinja` for anything you don't set. See
`pillar.example` for a full worked example.

```yaml
apt:
  # /etc/apt/sources.list itself. Default: left alone (not templated/emptied).
  remove_sources_list: false          # true => truncate sources.list to empty
  sources_list_dir: /etc/apt/sources.list.d
  clean_sources_list_d: false         # true => remove any *.list Salt didn't put there

  # Keyring storage for signed-by= repos.
  keyrings_dir: /etc/apt/keyrings
  clean_keyrings_d: false

  # /etc/apt/preferences (apt pinning).
  remove_preferences: false
  preferences_dir: /etc/apt/preferences.d
  clean_preferences_d: false
  preferences:
    pin-nginx:
      package: 'nginx*'
      pin: 'origin nginx.org'
      priority: 900
      explanation:
        - Prefer nginx.org's own packages over the distro's

  # /etc/apt/apt.conf and apt.conf.d/*.
  remove_apt_conf: false
  clean_apt_conf_d: false
  apt_conf_d:
    99no-recommends:
      - 'APT::Install-Recommends "0";'
      - 'APT::Install-Suggests "0";'

  # HTTP basic auth for authenticated repos -> /etc/apt/auth.conf (mode 0600).
  auth:
    - host: packages.example.com
      login: myuser
      password: '{{ pillar["vault"]["apt_repo_password"] }}'

  # Repositories. Keys are arbitrary names; a `.list` (or `.sources`-style
  # single-file) entry is generated per repo under sources_list_dir.
  # Defaults (main/security/updates for your OS) already exist under this
  # key from map.jinja and get merged with anything you add here.
  repositories:
    docker:
      distro: '{{ grains["oscodename"] }}'
      url: https://download.docker.com/linux/{{ grains['os']|lower }}
      comps:
        - stable
      # Prefer key_url over keyid+keyserver - see "Adding a repository" below.
      key_url: https://download.docker.com/linux/{{ grains['os']|lower }}/gpg
      opts:
        signed-by: /etc/apt/keyrings/docker.gpg

  # apt.unattended
  unattended:
    unattended_config_template: salt://apt/templates/unattended_config.jinja
    periodic_config_template: salt://apt/templates/periodic_config.jinja

  # apt.listchanges
  listchanges:
    listchanges_config_template: salt://apt/templates/listchanges_config.jinja
```

### Adding a repository

Each entry under `apt:repositories` maps to one `pkgrepo.managed` state.
Prefer `key_url` (fetch the vendor's own published key file directly) over
`keyid` + `keyserver` resolution: keyservers, including
`keyserver.ubuntu.com`, are a slower and less reliable resolution path,
and are more prone to becoming stale or disappearing entirely - which is
exactly the `pool.sks-keyservers.net` bug this formula fixed. `key_text`
(an inline armored key) also works if you'd rather not fetch anything at
apply time.

```yaml
apt:
  repositories:
    my-repo:
      distro: '{{ grains["oscodename"] }}'
      url: https://example.com/apt
      comps: [main]
      key_url: https://example.com/apt/gpg.key
      opts:
        signed-by: /etc/apt/keyrings/my-repo.gpg
```

Set `unmanaged: true` on a repository entry to have this formula leave an
existing `.list`/`.sources` file alone (excluded from the sources-list-dir
`clean` pass) instead of managing it.

## Notes

- `_mapdata/` is a debug helper (`salt-call state.show_sls apt._mapdata`
  or similar) that dumps the resolved map - useful for checking what
  values a given host actually resolved to before troubleshooting a
  pillar issue.
- `transports/https.sls` and `transports/debtorrent.sls` are standalone,
  rarely-needed states; `apt-transport-https` has been part of apt itself
  (not a separate package requirement) since Debian 10 / Ubuntu 18.04, so
  most hosts on this formula's supported OS range don't need it.

## Relationship to upstream

**This is a heavily modified fork of
[`saltstack-formulas/apt-formula`](https://github.com/saltstack-formulas/apt-formula). Do not treat it as a drop-in
replacement for it.**

States have been renamed, split, merged, and removed; pillar keys have moved;
defaults differ; and behaviour has changed in ways that are not backward
compatible. Pointing an existing deployment at this formula without reading
`pillar.example` and the state list above will not do what you expect.

It is also not a newer version of upstream — it diverged and was maintained
separately, so upstream may well have fixes and platform support that this
does not. If you want the maintained original, use
[`saltstack-formulas/apt-formula`](https://github.com/saltstack-formulas/apt-formula).

### Credit

The foundation of this formula, and much of what still works well in it, is
the work of the [saltstack-formulas](https://github.com/saltstack-formulas) authors and contributors. Any
bugs introduced in the divergence are this fork's own.

Specific third-party files bundled here, with their own authors and
licenses, are itemised in [THIRD-PARTY.md](THIRD-PARTY.md).

## License

Dedicated to the public domain under [CC0 1.0 Universal](LICENSE), with the
exception of the third-party files listed in [THIRD-PARTY.md](THIRD-PARTY.md).
