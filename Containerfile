FROM ghcr.io/projectbluefin/dakota:latest@sha256:46cdb7dee4858e570a94ecc220f8a6b7af77fed5d968f470380ac0c9f7949e7d

RUN bootc container lint || true
