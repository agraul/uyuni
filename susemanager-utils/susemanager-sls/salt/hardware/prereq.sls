{%- if grains['cpuarch'] in ['i386', 'i486', 'i586', 'i686', 'x86_64', 'aarch64'] %}
mgr_install_dmidecode:
  pkg.installed:
{%- if grains['os_family'] == 'Suse' and grains['osrelease'] in ['11.3', '11.4'] %}
    - name: pmtools
{%- else %}
    - name: dmidecode
{%- endif %}
    - require:
{%- if grains.get('__suse_reserved_saltutil_states_support', False) %}
      - saltutil: sync_states
{%- else %}
      - mgrcompat: sync_states
{%- endif %}
{%- endif %}
