# -*- coding: utf-8 -*-
# vim: ft=sls
#
# `apt-get upgrade` equivalent, via Salt's pkg module instead of cmd.run -
# see update.sls for why. Requisites reference repositories.sls's actual
# state IDs rather than assuming its default literal file paths.

apt-upgrade:
  module.run:
    - name: pkg.upgrade
    - dist_upgrade: False
    - onchanges:
      - file: apt-repositories-sources-list
      - file: apt-repositories-sources-list-dir
