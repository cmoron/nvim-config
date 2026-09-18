#!/usr/bin/env bash
# Regression checks: only temporary homes, fake binaries, no network.
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/nvim-packaging-test.XXXXXX")
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/repo/scripts" "$TEST_ROOT/source/.local/share/nvim/lazy/lazy.nvim" "$TEST_ROOT/bin"
cp "$REPO_DIR/scripts/"{export-offline,install-offline}.sh "$TEST_ROOT/repo/scripts/"
cp "$REPO_DIR/init.lua" "$REPO_DIR/lazy-lock.json" "$TEST_ROOT/repo/"
git -C "$TEST_ROOT/source/.local/share/nvim/lazy/lazy.nvim" init -q
git -C "$TEST_ROOT/source/.local/share/nvim/lazy/lazy.nvim" -c user.name=Test -c user.email=test@example.invalid commit -q --allow-empty -m fixture
REVISION=$(git -C "$TEST_ROOT/source/.local/share/nvim/lazy/lazy.nvim" rev-parse HEAD)
printf '{"lazy.nvim":{"branch":"main","commit":"%s"}}\n' "$REVISION" > "$TEST_ROOT/repo/lazy-lock.json"
mkdir -p "$TEST_ROOT/source/.local/share/nvim/lazy/obsolete-plugin"
mkdir -p "$TEST_ROOT/source/.local/share/nvim/lazy/lazy.nvim/tests" "$TEST_ROOT/source/.local/share/nvim/lazy/lazy.nvim/lua/test"
touch "$TEST_ROOT/source/.local/share/nvim/lazy/lazy.nvim/tests/fixture.png" "$TEST_ROOT/source/.local/share/nvim/lazy/lazy.nvim/lua/test/runtime.lua"
# Variables expanded by the generated fake binaries.
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\nprintf "NVIM v%%s\\n" "${TEST_NVIM_VERSION:-0.12.0}"\n' > "$TEST_ROOT/bin/nvim"
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\necho "tree-sitter ${TEST_TS_VERSION:-0.26.1}"\n' > "$TEST_ROOT/bin/tree-sitter"
chmod +x "$TEST_ROOT/bin/"*
export PATH="$TEST_ROOT/bin:$PATH"
HOME="$TEST_ROOT/source" bash "$TEST_ROOT/repo/scripts/export-offline.sh" > "$TEST_ROOT/export.log"
BUNDLE="$TEST_ROOT/repo/dist/nvim-config-offline"
mkdir -p "$BUNDLE/jdtls/plugins" "$BUNDLE/java-debug" "$BUNDLE/java-test"
touch "$BUNDLE/jdtls/plugins/new.jar" "$BUNDLE/java-debug/new.jar" "$BUNDLE/java-test/new.jar"

outside_cwd() {
    (cd "$TEST_ROOT" && HOME="$TEST_ROOT/outside" bash "$BUNDLE/install.sh") > "$TEST_ROOT/outside.log" 2>&1
    cmp "$BUNDLE/config/init.lua" "$TEST_ROOT/outside/.config/nvim/init.lua"
}
foreign_platform() {
    printf 'OtherOS othercpu\n' > "$BUNDLE/PLATFORM"
    local rc=0
    (cd "$TEST_ROOT" && HOME="$TEST_ROOT/foreign" bash "$BUNDLE/install.sh") > "$TEST_ROOT/foreign.log" 2>&1 || rc=$?
    printf '%s %s\n' "$(uname -s)" "$(uname -m)" > "$BUNDLE/PLATFORM"
    [ "$rc" -ne 0 ] && [ ! -e "$TEST_ROOT/foreign/.config/nvim" ]
}
preserve_config() {
    mkdir -p "$TEST_ROOT/linked/.config" "$TEST_ROOT/original"
    echo 'original config' > "$TEST_ROOT/original/init.lua"
    ln -s "$TEST_ROOT/original" "$TEST_ROOT/linked/.config/nvim"
    (cd "$BUNDLE" && HOME="$TEST_ROOT/linked" bash ./install.sh < /dev/null) > "$TEST_ROOT/linked.log" 2>&1
    [ "$(cat "$TEST_ROOT/original/init.lua")" = 'original config' ]
    [ ! -L "$TEST_ROOT/linked/.config/nvim" ]
    [ -n "$(find "$TEST_ROOT/linked/.config" -name 'nvim.bak-*' -print)" ]
    cmp "$BUNDLE/config/init.lua" "$TEST_ROOT/linked/.config/nvim/init.lua"
}
replace_java() {
    for component in jdtls java-debug java-test; do
        mkdir -p "$TEST_ROOT/java/.local/share/$component"
        touch "$TEST_ROOT/java/.local/share/$component/obsolete.jar"
    done
    (cd "$BUNDLE" && HOME="$TEST_ROOT/java" bash ./install.sh) > "$TEST_ROOT/java.log" 2>&1
    for component in jdtls java-debug java-test; do
        [ ! -e "$TEST_ROOT/java/.local/share/$component/obsolete.jar" ] || return 1
    done
    [ -f "$TEST_ROOT/java/.local/share/jdtls/plugins/new.jar" ]
}
reject_old() {
    local rc=0
    (cd "$BUNDLE" && HOME="$TEST_ROOT/old" TEST_NVIM_VERSION=0.11.5 bash ./install.sh) > "$TEST_ROOT/old.log" 2>&1 || rc=$?
    [ "$rc" -ne 0 ] && [ ! -e "$TEST_ROOT/old/.config/nvim" ]
}
accept_major() {
    (cd "$BUNDLE" && HOME="$TEST_ROOT/major" TEST_NVIM_VERSION=1.0.0 bash ./install.sh) > "$TEST_ROOT/major.log" 2>&1
    ! grep -q 'Attention:.*0.12' "$TEST_ROOT/major.log"
}
online_version() {
    local rc=0
    HOME="$TEST_ROOT/online" TEST_NVIM_VERSION=0.11.5 bash "$REPO_DIR/scripts/install.sh" --check > "$TEST_ROOT/online.log" 2>&1 || rc=$?
    [ "$rc" -ne 0 ] && grep -q 'version 0.12+ requise' "$TEST_ROOT/online.log"
}
treesitter_version() {
    local rc=0
    HOME="$TEST_ROOT/ts" TEST_TS_VERSION=0.25.0 bash "$REPO_DIR/scripts/install.sh" --check > "$TEST_ROOT/ts.log" 2>&1 || rc=$?
    [ "$rc" -ne 0 ] && grep -q '0.26.1' "$TEST_ROOT/ts.log"
}
require_bun() {
    cat > "$TEST_ROOT/without-bun.sh" <<'BASHENV'
command() {
    if [ "$*" = '-v bun' ]; then return 1; fi
    builtin command "$@"
}
BASHENV
    local rc=0
    HOME="$TEST_ROOT/no-bun" BASH_ENV="$TEST_ROOT/without-bun.sh" bash "$REPO_DIR/scripts/install.sh" --check > "$TEST_ROOT/no-bun.log" 2>&1 || rc=$?
    [ "$rc" -ne 0 ] && grep -q 'bun absent' "$TEST_ROOT/no-bun.log"
}
java_home() {
    mkdir -p "$TEST_ROOT/jdk/bin"
    printf '#!/usr/bin/env bash\necho '\''openjdk version "25.0.4"'\'' >&2\n' > "$TEST_ROOT/jdk/bin/java"
    printf '#!/usr/bin/env bash\necho '\''java version "1.8.0_472"'\'' >&2\n' > "$TEST_ROOT/bin/java"
    printf '#!/usr/bin/env bash\necho jdt-language-server-test.tar.gz\n' > "$TEST_ROOT/bin/curl"
    chmod +x "$TEST_ROOT/jdk/bin/java" "$TEST_ROOT/bin/java" "$TEST_ROOT/bin/curl"
    HOME="$TEST_ROOT/java-home" JDTLS_JAVA_HOME="$TEST_ROOT/jdk" bash "$REPO_DIR/scripts/install.sh" --dry-run > "$TEST_ROOT/java-home.log" 2>&1
    grep -q 'installerait jdt-language-server-1.61.0-202609031315.tar.gz' "$TEST_ROOT/java-home.log"
}
locked_plugins() {
    [ -d "$BUNDLE/plugins/lazy.nvim" ]
    [ ! -e "$BUNDLE/plugins/obsolete-plugin" ]
    [ ! -e "$BUNDLE/plugins/lazy.nvim/tests" ]
    [ -f "$BUNDLE/plugins/lazy.nvim/lua/test/runtime.lua" ]
}
reject_drift() {
    git -C "$TEST_ROOT/source/.local/share/nvim/lazy/lazy.nvim" -c user.name=Test -c user.email=test@example.invalid commit -q --allow-empty -m drift
    local rc=0
    HOME="$TEST_ROOT/source" bash "$TEST_ROOT/repo/scripts/export-offline.sh" > "$TEST_ROOT/drift.log" 2>&1 || rc=$?
    [ "$rc" -ne 0 ] && grep -q 'lazy.nvim.*lockfile' "$TEST_ROOT/drift.log"
}
empty_parsers() {
    mkdir -p "$TEST_ROOT/source/.local/share/nvim/site/parser"
    HOME="$TEST_ROOT/source" bash "$TEST_ROOT/repo/scripts/export-offline.sh" > "$TEST_ROOT/empty.log" 2>&1
    grep -q 'Parsers Treesitter non trouvés' "$TEST_ROOT/empty.log"
}
bundled_toolchain() {
    local fixture="$TEST_ROOT/toolchain-bundle"
    cp -R "$BUNDLE" "$fixture"
    mkdir -p "$fixture/licenses"
    echo 'fixture licence' > "$fixture/licenses/NOTICE"
    mkdir -p "$fixture/tools/jdk-25/bin" "$fixture/tools/node/bin" "$fixture/tools/bin"
    mkdir -p "$TEST_ROOT/runtime/nvim-linux-x86_64/bin"
    cat > "$TEST_ROOT/runtime/nvim-linux-x86_64/bin/nvim" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = --toolchain ]; then
    printf '%s\n%s\n%s\n' "$JDTLS_JAVA_HOME" "$JAVA25_HOME" "$PATH"
else
    echo 'NVIM v0.12.5'
fi
SH
    chmod +x "$TEST_ROOT/runtime/nvim-linux-x86_64/bin/nvim"
    tar -czf "$fixture/nvim-linux-x86_64.tar.gz" -C "$TEST_ROOT/runtime" nvim-linux-x86_64
    mkdir -p "$TEST_ROOT/toolchain-home/.local/bin" "$TEST_ROOT/toolchain-home/.local/share/neovim"
    echo 'previous launcher' > "$TEST_ROOT/toolchain-home/.local/bin/nvim"
    echo 'previous runtime' > "$TEST_ROOT/toolchain-home/.local/share/neovim/keep"
    HOME="$TEST_ROOT/toolchain-home" bash "$fixture/install.sh" > "$TEST_ROOT/toolchain.log" 2>&1
    cmp "$fixture/licenses/NOTICE" "$TEST_ROOT/toolchain-home/.local/share/nvim/licenses/NOTICE"
    grep -q 'previous launcher' "$TEST_ROOT/toolchain-home/.local/bin/"nvim.bak-*
    grep -q 'previous runtime' "$TEST_ROOT/toolchain-home/.local/share/"neovim.bak-*/keep
    local output
    output=$(env -u JDTLS_JAVA_HOME -u JAVA25_HOME HOME="$TEST_ROOT/toolchain-home" "$TEST_ROOT/toolchain-home/.local/bin/nvim" --toolchain)
    [ "$(echo "$output" | head -1)" = "$TEST_ROOT/toolchain-home/.local/share/nvim-tools/jdk-25" ]
    [[ "$output" == *"$TEST_ROOT/toolchain-home/.local/share/nvim-tools/node/bin"* ]]
    output=$(HOME="$TEST_ROOT/toolchain-home" JDTLS_JAVA_HOME=/custom/jdk "$TEST_ROOT/toolchain-home/.local/bin/nvim" --toolchain)
    [ "$(echo "$output" | head -1)" = /custom/jdk ]
}
failures=0
export TEST_ROOT BUNDLE REPO_DIR
export -f outside_cwd foreign_platform preserve_config replace_java reject_old accept_major online_version treesitter_version require_bun java_home locked_plugins empty_parsers reject_drift bundled_toolchain
for check in outside_cwd foreign_platform preserve_config replace_java reject_old accept_major online_version treesitter_version require_bun java_home locked_plugins empty_parsers reject_drift bundled_toolchain; do
    if bash -e -u -o pipefail -c "$check" &> "$TEST_ROOT/$check.result"; then
        echo "PASS $check"
    else
        echo "FAIL $check"
        cat "$TEST_ROOT/$check.result"
        failures=$((failures + 1))
    fi
done
[ "$failures" -eq 0 ]
