# -*- coding: utf-8 -*-
# vim: ft=sls
#
# Refreshes the apt package database when sources change. Previously this
# shelled out to `apt-get -y update` via cmd.run; module.run: pkg.refresh_db
# goes through Salt's own apt backend instead - proper `test=True` dry-run
# support, structured error handling, no dependency on a specific shell.
#
# Also fixes a latent bug: the old `onchanges` here referenced the literal
# paths `/etc/apt/sources.list` and `/etc/apt/sources.list.d`, which only
# worked because repositories.sls happened to manage states with those
# exact literal names by default. Setting `apt:sources_list_dir` in pillar
# to anything else would silently break this cross-file reference. It now
# references repositories.sls's actual (namespaced) state IDs instead.

apt-update:
  module.run:
    - name: pkg.refresh_db
    - onchanges:
      - file: apt-repositories-sources-list
      - file: apt-repositories-sources-list-dir
