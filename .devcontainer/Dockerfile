FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Flutter revision matches the project's Dart >=3.13 requirement.
ARG FLUTTER_REVISION=9584c6713b324636289d067944a46fd6b49df14b
ARG EMSDK_VERSION=4.0.15
ARG NODE_VERSION=22.14.0
USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg git-lfs cmake ninja-build build-essential \
    pkg-config libgtk-3-dev liblzma-dev libglu1-mesa libsecret-1-dev \
    libssl-dev libffi-dev libedit-dev libxml2-dev zlib1g-dev libzstd-dev \
    unzip xz-utils zip python3 \
    && curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key \
       | gpg --dearmor -o /usr/share/keyrings/llvm.gpg \
    && echo 'deb [signed-by=/usr/share/keyrings/llvm.gpg] https://apt.llvm.org/noble/ llvm-toolchain-noble-22 main' \
       > /etc/apt/sources.list.d/llvm.list \
    && apt-get update && apt-get install -y --no-install-recommends \
       clang-22 libclang-22-dev llvm-22-dev lld-22 \
    && rm -rf /var/lib/apt/lists/*

# Use real compiler binaries ahead of any wrappers; keep Clang and LLVM aligned.
ENV PATH="/opt/flutter/bin:/opt/node/bin:/usr/lib/llvm-22/bin:${PATH}" \
    LLVM_DIR=/usr/lib/llvm-22/lib/cmake/llvm \
    Clang_DIR=/usr/lib/llvm-22/lib/cmake/clang \
    CC=/usr/lib/llvm-22/bin/clang CXX=/usr/lib/llvm-22/bin/clang++ \
    EMSDK=/opt/emsdk
RUN case "$(dpkg --print-architecture)" in \
      amd64) node_arch=x64 ;; arm64) node_arch=arm64 ;; *) exit 1 ;; esac \
    && cd /tmp \
    && curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" \
    && curl -fsSLO "https://nodejs.org/dist/v${NODE_VERSION}/SHASUMS256.txt" \
    && grep " node-v${NODE_VERSION}-linux-${node_arch}.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
    && mkdir /opt/node \
    && tar -xJf "node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" -C /opt/node --strip-components=1 \
    && rm "node-v${NODE_VERSION}-linux-${node_arch}.tar.xz" SHASUMS256.txt
RUN git init /opt/flutter \
    && git -C /opt/flutter remote add origin https://github.com/flutter/flutter.git \
    && git -C /opt/flutter fetch --depth 1 origin "$FLUTTER_REVISION" \
    && git -C /opt/flutter checkout --detach FETCH_HEAD \
    && git clone --depth 1 --branch "$EMSDK_VERSION" https://github.com/emscripten-core/emsdk.git /opt/emsdk \
    && /opt/emsdk/emsdk install "$EMSDK_VERSION" \
    && /opt/emsdk/emsdk activate "$EMSDK_VERSION" \
    && chown -R vscode:vscode /opt/flutter /opt/emsdk
USER vscode
ARG FLUTTER_VERSION=3.47.4
RUN git -C /opt/flutter fetch --depth 1 origin "refs/tags/${FLUTTER_VERSION}:refs/tags/${FLUTTER_VERSION}" \
    && test "$(git -C /opt/flutter rev-parse "${FLUTTER_VERSION}^{commit}")" = "$FLUTTER_REVISION" \
    && git -C /opt/flutter switch -c stable \
    && git lfs install && flutter config --no-analytics --enable-web --enable-linux-desktop \
    && flutter precache --web --linux
