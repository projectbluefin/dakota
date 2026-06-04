# Lint helper only for an already-built Dakota image.
# Do not add package installation or overlay logic here; Dakota image contents
# come from BuildStream elements and OCI assembly `.bst` files.
FROM ghcr.io/projectbluefin/dakota:latest

RUN bootc container lint || true
