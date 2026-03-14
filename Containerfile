FROM ghcr.io/projectbluefin/egg:latest@sha256:62424c9744e6a0a0994f58378f395a6d3046c64b40f057eeb10cf28e828484dd

RUN bootc container lint || true
