# -*- coding: utf-8 -*-
# vim: ft=sls
#
# Core apt configuration: repositories/keyrings, pinning preferences, and
# apt.conf.d snippets. This is what `include: - apt` in a top file pulls
# in - the safe, idempotent baseline every host managed by this formula
# wants.
#
# Deliberately NOT included here (opt in explicitly per-host instead, since
# they're either invasive or situational):
#   - apt.unattended    (installs + enables unattended-upgrades)
#   - apt.listchanges   (installs apt-listchanges)
#   - apt.ppa           (installs software-properties-common)
#   - apt.update / apt.upgrade / apt.dist_upgrade (actually upgrades packages)
#   - apt.transports.https / apt.transports.debtorrent (rarely needed on
#     modern Debian/Ubuntu - HTTPS transport has been built into apt itself
#     since Debian 10 / Ubuntu 18.04)

include:
  - apt.repositories
  - apt.preferences
  - apt.apt_conf
