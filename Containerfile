# Lint helper only for the published Dakota stable channel image.
# Do not add package installation or overlay logic here; Dakota image contents
# come from BuildStream elements and OCI assembly `.bst` files.
FROM ghcr.io/projectbluefin/dakota:stable

RUN bootc container lint || true
