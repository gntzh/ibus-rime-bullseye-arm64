FROM debian:bullseye
ENV DEBIAN_FRONTEND=noninteractive
RUN printf 'deb http://archive.debian.org/debian bullseye main\ndeb http://archive.debian.org/debian-security bullseye-security main\n' > /etc/apt/sources.list \
    && printf 'Acquire::Check-Valid-Until "false";\n' > /etc/apt/apt.conf.d/99archive \
    && apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates git wget curl bsdextrautils file binutils \
    libboost-dev libibus-1.0-dev libnotify-dev libnotify-bin \
    gettext pkg-config patchelf python3 python3-pip ninja-build \
    && pip3 install --no-cache-dir cmake==3.31.6 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /work
