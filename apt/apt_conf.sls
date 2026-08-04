# -*- coding: utf-8 -*-
# vim: ft=sls
{% from "apt/map.jinja" import apt as apt_map with context %}
{% set remove_apt_conf = salt['pillar.get']('apt:remove_apt_conf', apt_map.remove_apt_conf) %}
{% set confd_dir = salt['pillar.get']('apt:confd_dir', apt_map.confd_dir) %}
{% set clean_apt_conf_d = salt['pillar.get']('apt:clean_apt_conf_d', apt_map.clean_apt_conf_d) %}
{% set apt_conf_d = salt['pillar.get']('apt:apt_conf_d', apt_map.apt_conf_d) %}

apt-conf-file:
  file.managed:
    - name: /etc/apt/apt.conf
    - mode: '0644'
    - user: root
    - group: root
  {% if remove_apt_conf %}
    - contents: ''
    - contents_newline: False
  {% else %}
    - replace: False
  {% endif %}

apt-conf-d-dir:
  file.directory:
    - name: {{ confd_dir }}
    - mode: '0755'
    - user: root
    - group: root
    - clean: {{ clean_apt_conf_d }}

{% for file, contents in apt_conf_d|dictsort %}
apt-conf-d-{{ file }}:
  file.managed:
    - name: {{ confd_dir }}/{{ file }}
    - source: salt://apt/templates/apt_conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - context:
        data: {{ contents }}
    - require_in:
      - file: apt-conf-d-dir
{% endfor %}
