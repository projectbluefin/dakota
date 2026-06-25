kind: script

build-depends:
  - gnome-build-meta.bst:freedesktop-sdk.bst:components/oci-builder.bst
  - filename: oci/layers/python-micro.bst
    config:
      location: /layer

config:
  commands:
    - |
      cd /layer
      rm -rf usr/lib/python3.*/tkinter
      rm -rf usr/lib/python3.*/idlelib
      rm -rf usr/lib/python3.*/turtledemo
      rm -rf usr/lib/python3.*/pydoc_data
      rm -rf usr/lib/python3.*/ensurepip
      rm -rf usr/lib/x86_64-linux-gnu/gconv
      rm -rf usr/include
      rm -rf usr/share/doc
      rm -rf usr/share/man
      oci-builder \
        --name ghcr.io/projectbluefin/python-micro \
        --entrypoint /usr/bin/python3 \
        . /oci-image
