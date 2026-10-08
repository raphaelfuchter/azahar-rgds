# Build env for Azahar targeting ROCKNIX RK3566/RK3568 (glibc 2.41, Qt 6.10 runtime)
FROM debian:trixie
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential cmake ninja-build git pkg-config ccache python3 ca-certificates \
    qt6-base-dev qt6-base-private-dev qt6-multimedia-dev \
    libgl-dev libegl-dev libx11-dev libxext-dev libwayland-dev libxkbcommon-dev \
    libasound2-dev libpulse-dev libdbus-1-dev \
    && rm -rf /var/lib/apt/lists/*
