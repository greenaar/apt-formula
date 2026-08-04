# -*- coding: utf-8 -*-
# vim: ft=sls
#
# Installs utilities for working with APT repositories, notably
# `add-apt-repository` / `apt-add-repository`. PPAs (Launchpad Personal
# Package Archives) themselves are an Ubuntu-only concept, but this
# package is installable and occasionally useful on Debian too.
#
# `python-software-properties` (the old name) doesn't exist on Debian 12/13
# or Ubuntu 24.04+ - it was renamed to `software-properties-common` years
# ago (Ubuntu 16.04 / Debian 9 era). Installing the old name here would
# just fail with "package not found".

apt-ppa-software-properties-common:
  pkg.installed:
    - name: software-properties-common
