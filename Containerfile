FROM ghcr.io/projectbluefin/dakota:latest@sha256:c2169eef206040f74c4197a0669fd9d32274ce18d5b27ce357a06c82df61a1eb

RUN bootc container lint || true
