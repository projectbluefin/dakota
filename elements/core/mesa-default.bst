kind: manual
description: fdsdk's vm/mesa-default.bst, pointed at mesa-extra for the full video codec set.

(@):
- freedesktop-sdk.bst:elements/flatpak-images/include/platform-vars.yml

build-depends:
- freedesktop-sdk.bst:public-stacks/runtime-gnu.bst

runtime-depends:
- freedesktop-sdk.bst:extensions/mesa/mesa-extra.bst
- freedesktop-sdk.bst:integration/ldconfig.bst

variables:
  ld_so_conf_d: "%{sysconfdir}/ld.so.conf.d"
  strip-binaries: ''

config:
  install-commands:
  - |
    paths="%{gl_merge_dirs}"
    OLDIFS="$IFS"
    IFS=';'
    for i in $paths; do
      mkdir -pv "%{install-root}%{libdir}/GL/$(dirname "${i}")"
      ln -rvs "%{install-root}%{libdir}/GL/default/${i}" "%{install-root}%{libdir}/GL/${i}"
    done
    IFS="$OLDIFS"
  - |
    mkdir -p %{install-root}%{ld_so_conf_d}
    echo "%{libdir}/GL/default/lib" > %{install-root}%{ld_so_conf_d}/00_mesa.conf
