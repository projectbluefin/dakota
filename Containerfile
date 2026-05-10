FROM ghcr.io/projectbluefin/dakota:latest@sha256:b36848c3cb0e0d75a0b13f33449d98ea7335f40a2ed0669a1222a3032acc8636

RUN bootc container lint || true
