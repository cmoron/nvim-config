#!/usr/bin/env bash
# Real bundle acceptance: no network, no root, no host Neovim or plugins.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARCHIVE="${1:-$REPO_DIR/dist/nvim-config-offline-linux-x86_64.tar.gz}"
IMAGE="${2:-fedora:43}"
if [ ! -f "$ARCHIVE" ]; then
    echo "Archive introuvable : $ARCHIVE" >&2
    exit 1
fi
ARCHIVE="$(cd "$(dirname "$ARCHIVE")" && pwd)/$(basename "$ARCHIVE")"
JDK_MOUNTS=()
if [ -n "${TEST_JDKS:-}" ]; then
    TEST_JDKS="$(cd "$TEST_JDKS" && pwd)"
    JDK_MOUNTS+=(-v "$TEST_JDKS:/project-jdks:ro")
fi

docker run --rm --network none --read-only --user 10001:10001 \
    --tmpfs /tmp:rw,exec,mode=1777 \
    -e HOME=/tmp/nvim-home \
    -v "$ARCHIVE:/bundle.tar.gz:ro" \
    -v "$REPO_DIR/scripts:/checks:ro" \
    ${JDK_MOUNTS[@]+"${JDK_MOUNTS[@]}"} \
    "$IMAGE" bash -euo pipefail -c '
    report_failure() {
        status=$?
        if [ "$status" -ne 0 ]; then
            if [ -f "$HOME/.local/state/nvim/lsp.log" ]; then
                cat "$HOME/.local/state/nvim/lsp.log"
            fi
            for directory in "$HOME/.cache/jdtls" "$HOME/.local/share/jdtls/config_linux"; do
                if [ -d "$directory" ]; then
                    find "$directory" -name "*.log" -exec tail -80 {} \;
                fi
            done
        fi
        exit "$status"
    }
    trap report_failure EXIT
    cat /etc/os-release
    getconf GNU_LIBC_VERSION
    mkdir -p "$HOME"
    tar -xzf /bundle.tar.gz -C /tmp
    CHECKS=/checks
    if [ -d /tmp/nvim-config-offline/checks ]; then
        CHECKS=/tmp/nvim-config-offline/checks
        for check in check-runtime.lua check-lsp.lua; do
            read -r checksum _ < <(sha256sum "/checks/$check")
            printf "%s  %s\n" "$checksum" "$CHECKS/$check" | sha256sum -c -
        done
        test ! -e /tmp/nvim-config-offline/tools/node/include
        test ! -e /tmp/nvim-config-offline/tools/node/bin/npm
        test ! -e /tmp/nvim-config-offline/plugins/snacks.nvim/tests
        test -s /tmp/nvim-config-offline/licenses/neovim/LICENSE.txt
        test -s /tmp/nvim-config-offline/build-info/source-notices.txt
    fi
    /tmp/nvim-config-offline/install.sh
    export PATH="$HOME/.local/bin:$PATH"
    nvim --version
    timeout 60 nvim --headless -c "luafile $CHECKS/check-runtime.lua"
    if [ -d "$HOME/.local/share/nvim-tools" ]; then
        "$HOME/.local/share/nvim-tools/jdk-25/bin/java" -version
        "$HOME/.local/share/nvim-tools/bin/ruff" --version
        timeout 180 nvim --headless -c "luafile $CHECKS/check-lsp.lua"
        if [ -d /project-jdks ]; then
            for version in 8 11 17 21; do
                test -x "/project-jdks/$version/bin/java"
                export "JAVA${version}_HOME=/project-jdks/$version"
                JAVA_HOME="/project-jdks/$version" PATH="/project-jdks/$version/bin:$PATH" \
                    NVIM_TEST_JAVA_VERSION="$version" \
                    timeout 180 nvim --headless -c "luafile $CHECKS/check-lsp.lua"
            done
        fi
    fi
    '
