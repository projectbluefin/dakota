# Chunkah metadata finalizer; staged only into OCI assembly sandboxes.
kind: import

sources:
  - kind: local
    path: scripts/ownership_metadata.py

config:
  target: ownership-tool
