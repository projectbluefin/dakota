FROM ghcr.io/projectbluefin/dakota:latest

RUN bootc container lint || true
