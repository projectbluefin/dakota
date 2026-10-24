# Thin-layer OCI assembler; staged only into the final OCI elements.
kind: import

sources:
  - kind: local
    path: scripts/oci_append_layer.py

config:
  target: oci-append-tool
