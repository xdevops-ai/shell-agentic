#!/bin/sh
# OpsBot installer - https://github.com/xdevops-ai/shell-agentic
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/xdevops-ai/shell-agentic/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/xdevops-ai/shell-agentic/main/install.sh | sh -s -- v2.0.0
#   sh install.sh [VERSION]
#
# Environment:
#   VERSION              Release to install (e.g. v2.0.0). Default: latest release.
#                        A version given as the first argument takes precedence.
#   OPSBOT_INSTALL_DIR   Where to put the binary. Default: $HOME/.local/bin
#   OPSBOT_BASE_URL      Download base URL (for mirrors).
#                        Default: https://github.com/xdevops-ai/shell-agentic/releases/download

set -eu

REPO="xdevops-ai/shell-agentic"
BASE_URL="${OPSBOT_BASE_URL:-https://github.com/${REPO}/releases/download}"
INSTALL_DIR="${OPSBOT_INSTALL_DIR:-${HOME}/.local/bin}"
REQUESTED_VERSION="${1:-${VERSION:-}}"

tmp_dir=""

say() { printf '%s\n' "opsbot-install: $*"; }
die() { printf '%s\n' "opsbot-install: error: $*" >&2; exit 1; }

cleanup() {
    if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
        rm -rf -- "$tmp_dir"
    fi
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

have() { command -v "$1" >/dev/null 2>&1; }

use_sudo=0
# run_priv CMD... : run a command, through sudo when the install dir needs it
run_priv() {
    if [ "$use_sudo" -eq 1 ]; then
        sudo "$@"
    else
        "$@"
    fi
}

# download URL DEST
download() {
    if have curl; then
        curl -fsSL --retry 3 -o "$2" "$1"
    elif have wget; then
        wget -q -O "$2" "$1"
    else
        die "neither curl nor wget is installed"
    fi
}

# Print the tag of the latest release (e.g. v2.0.0).
latest_tag() {
    api="https://api.github.com/repos/${REPO}/releases/latest"
    tag=""
    if have curl; then
        tag=$(curl -fsSL -H 'Accept: application/vnd.github+json' "$api" 2>/dev/null \
            | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1) || tag=""
        if [ -z "$tag" ]; then
            # Fallback when the API is rate limited: follow the /releases/latest redirect.
            effective=$(curl -fsSLI -o /dev/null -w '%{url_effective}' \
                "https://github.com/${REPO}/releases/latest" 2>/dev/null) || effective=""
            case "$effective" in
                */releases/tag/*) tag=${effective##*/} ;;
            esac
        fi
    elif have wget; then
        tag=$(wget -qO- "$api" 2>/dev/null \
            | sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1) || tag=""
    fi
    [ -n "$tag" ] || die "could not determine the latest release (GitHub API unreachable or rate limited); pass a version, e.g. 'sh install.sh v2.0.0'"
    printf '%s\n' "$tag"
}

detect_os() {
    os=$(uname -s)
    case "$os" in
        Linux) printf 'linux\n' ;;
        Darwin) printf 'darwin\n' ;;
        MINGW* | MSYS* | CYGWIN* | Windows_NT)
            die "Windows is not supported (OpsBot needs a Unix PTY). Use WSL2 and run this installer inside your Linux distribution." ;;
        *) die "unsupported operating system: $os (supported: Linux, macOS)" ;;
    esac
}

detect_arch() {
    arch=$(uname -m)
    case "$arch" in
        x86_64 | amd64) arch=amd64 ;;
        aarch64 | arm64) arch=arm64 ;;
        *) die "unsupported CPU architecture: $arch (supported: amd64, arm64)" ;;
    esac
    # Apple silicon running this script under Rosetta reports x86_64; prefer native.
    if [ "$1" = darwin ] && [ "$arch" = amd64 ] \
        && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || echo 0)" = 1 ]; then
        arch=arm64
    fi
    printf '%s\n' "$arch"
}

# sha256 FILE -> prints the hex digest
sha256() {
    if have sha256sum; then
        sha256sum "$1" | awk '{print $1}'
    elif have shasum; then
        shasum -a 256 "$1" | awk '{print $1}'
    elif have openssl; then
        openssl dgst -sha256 "$1" | awk '{print $NF}'
    else
        die "no SHA-256 tool found (need sha256sum, shasum or openssl)"
    fi
}

main() {
    have tar || die "tar is required"
    have uname || die "uname is required"

    os=$(detect_os)
    arch=$(detect_arch "$os")

    if [ -n "$REQUESTED_VERSION" ]; then
        tag="$REQUESTED_VERSION"
    else
        say "looking up the latest release..."
        tag=$(latest_tag)
    fi
    case "$tag" in
        v*) ;;
        *) tag="v$tag" ;;
    esac
    version=${tag#v}

    asset="opsbot_${version}_${os}_${arch}.tar.gz"
    say "installing OpsBot ${tag} (${os}/${arch}) into ${INSTALL_DIR}"

    tmp_dir=$(mktemp -d 2>/dev/null || mktemp -d -t opsbot-install)
    [ -d "$tmp_dir" ] || die "could not create a temporary directory"

    download "${BASE_URL}/${tag}/${asset}" "${tmp_dir}/${asset}" \
        || die "download failed: ${BASE_URL}/${tag}/${asset} (does release ${tag} exist?)"
    download "${BASE_URL}/${tag}/SHA256SUMS" "${tmp_dir}/SHA256SUMS" \
        || die "download failed: ${BASE_URL}/${tag}/SHA256SUMS"

    expected=$(awk -v f="$asset" '$2 == f || $2 == "*" f { print $1; exit }' "${tmp_dir}/SHA256SUMS")
    [ -n "$expected" ] || die "${asset} is not listed in SHA256SUMS"
    actual=$(sha256 "${tmp_dir}/${asset}")
    if [ "$expected" != "$actual" ]; then
        die "checksum mismatch for ${asset} (expected ${expected}, got ${actual}); not installing"
    fi
    say "checksum verified (sha256 ${actual})"

    mkdir -p "${tmp_dir}/x"
    tar -xzf "${tmp_dir}/${asset}" -C "${tmp_dir}/x" opsbot \
        || die "could not extract the opsbot binary from ${asset}"
    [ -f "${tmp_dir}/x/opsbot" ] || die "archive does not contain an opsbot binary"
    chmod 0755 "${tmp_dir}/x/opsbot"

    if ! mkdir -p "$INSTALL_DIR" 2>/dev/null || [ ! -w "$INSTALL_DIR" ]; then
        if [ "$(id -u)" -ne 0 ] && have sudo; then
            say "${INSTALL_DIR} is not writable; using sudo"
            use_sudo=1
            run_priv mkdir -p "$INSTALL_DIR" || die "could not create ${INSTALL_DIR}"
        else
            die "${INSTALL_DIR} is not writable. Choose another directory with OPSBOT_INSTALL_DIR."
        fi
    fi

    # Install atomically: copy next to the target, then rename over it.
    run_priv cp "${tmp_dir}/x/opsbot" "${INSTALL_DIR}/.opsbot.new" \
        || die "could not write to ${INSTALL_DIR}"
    run_priv chmod 0755 "${INSTALL_DIR}/.opsbot.new"
    run_priv mv -f "${INSTALL_DIR}/.opsbot.new" "${INSTALL_DIR}/opsbot" \
        || die "could not install ${INSTALL_DIR}/opsbot"

    say "installed ${INSTALL_DIR}/opsbot"

    case ":${PATH}:" in
        *":${INSTALL_DIR}:"*) ;;
        *)
            say "note: ${INSTALL_DIR} is not on your PATH. Add this to your shell profile:"
            printf '\n    export PATH="%s:%s"\n\n' "$INSTALL_DIR" "\$PATH"
            ;;
    esac

    if ! have bash; then
        say "warning: bash was not found on PATH; OpsBot starts a bash shell and needs it."
    fi

    cat <<'EOF'
Next steps:
  1. In the XDevOps portal (https://xdevops.ch): Settings -> Devices -> Install OpsBot
     -> Download certificate bundle. (Requires a tenant admin or operator.)
  2. Unpack it into a private directory, e.g.:
       mkdir -p ~/opsbot && chmod 700 ~/opsbot
       unzip <downloaded-bundle>.zip -d ~/opsbot
       chmod 600 ~/opsbot/opsbot.client.key ~/opsbot/.env
  3. Start OpsBot from that directory (it reads ./.env from where you start it):
       cd ~/opsbot && opsbot
EOF
}

main
