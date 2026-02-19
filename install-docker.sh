#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Cerebras Code — Docker-based installer for devservers
#
# Usage:
#   curl -fsSL https://<hosted-url>/install.sh | bash
#   curl -fsSL https://<hosted-url>/install.sh | bash -s -- --version 1.1.83
#   curl -fsSL https://<hosted-url>/install.sh | bash -s -- --port 4000
# ============================================================================

CEREBRAS_CODE_VERSION="${CEREBRAS_CODE_VERSION:-1.1.83}"
DEFAULT_PORT=3333
PORT="${CEREBRAS_CODE_PORT:-$DEFAULT_PORT}"
INSTALL_DIR="${HOME}/.cerebras-code"
BIN_DIR="${INSTALL_DIR}/bin"
IMAGE_NAME="cerebras-code"
FORWARD_PORTS="${CEREBRAS_CODE_FORWARD_PORTS:-3333}"
FORCE_REBUILD=false

# ---------------------------------------------------------------------------
# Colors & output helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[info]${NC}  $*"; }
ok()    { echo -e "${GREEN}[ok]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
error() { echo -e "${RED}[error]${NC} $*" >&2; }
fatal() { error "$@"; exit 1; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
Cerebras Code Installer (Docker-based)

Usage:
  install.sh [OPTIONS]

Options:
  -v, --version VERSION   Cerebras Code CLI version to install (default: $CEREBRAS_CODE_VERSION)
  -p, --port PORT         Default web UI port (default: $DEFAULT_PORT)
  -f, --forward-ports PORTS Comma-separated ports to forward (default: 3333; e.g., 3000,8000-8010)
  --rebuild               Force rebuild the Docker image
  -h, --help              Show this help

Environment variables:
  CEREBRAS_CODE_VERSION      Same as --version
  CEREBRAS_CODE_PORT         Same as --port
  CEREBRAS_CODE_FORWARD_PORTS Same as --forward-ports (default: 3333)
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--version) CEREBRAS_CODE_VERSION="$2"; shift 2 ;;
        -p|--port)    PORT="$2"; shift 2 ;;
        -f|--forward-ports) FORWARD_PORTS="$2"; shift 2 ;;
        --rebuild)    FORCE_REBUILD=true; shift ;;
        -h|--help)    usage ;;
        *)            fatal "Unknown option: $1" ;;
    esac
done

# ---------------------------------------------------------------------------
# Preflight checks
# ---------------------------------------------------------------------------
info "Checking prerequisites..."

if ! command -v docker &>/dev/null; then
    fatal "Docker is not installed or not on PATH. Please install Docker first."
fi

if ! docker info &>/dev/null 2>&1; then
    fatal "Docker daemon is not running or you lack permission. Try: sudo usermod -aG docker \$USER"
fi

ok "Docker is available"

# ---------------------------------------------------------------------------
# Create install directory
# ---------------------------------------------------------------------------
mkdir -p "$INSTALL_DIR" "$BIN_DIR"

# ---------------------------------------------------------------------------
# Write Dockerfile
# ---------------------------------------------------------------------------
info "Writing Dockerfile..."

cat > "${INSTALL_DIR}/Dockerfile" << 'DOCKERFILE_EOF'
FROM ubuntu:22.04

ARG CEREBRAS_CODE_VERSION=1.1.83

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    python3 \
    python3-pip \
    openssh-client \
    gosu \
    jq \
    less \
    vim \
    && rm -rf /var/lib/apt/lists/*

# Install cerebras-code CLI
RUN curl -fsSL https://raw.githubusercontent.com/kevint-cerebras/cerebras-code-cli/refs/heads/dev/install \
    | bash -s -- --version "${CEREBRAS_CODE_VERSION}" --no-modify-path \
    && cp /root/.cerebras/bin/* /usr/local/bin/

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
DOCKERFILE_EOF

# ---------------------------------------------------------------------------
# Write entrypoint
# ---------------------------------------------------------------------------
info "Writing entrypoint..."

cat > "${INSTALL_DIR}/entrypoint.sh" << 'ENTRYPOINT_EOF'
#!/bin/bash
set -e

HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-1000}"
HOST_HOME="${HOST_HOME:-/home/user}"
HOST_USER="${HOST_USER:-cuser}"

# Create group and user matching the host so file ownership is correct
groupadd -g "$HOST_GID" -o "$HOST_USER" 2>/dev/null || true
useradd -u "$HOST_UID" -g "$HOST_GID" -o -s /bin/bash -d "$HOST_HOME" -M "$HOST_USER" 2>/dev/null || true

# Ensure git trusts mounted directories
git config --global --add safe.directory '*' 2>/dev/null || true

# Make cerebras-code config dir if needed (inside mounted home)
mkdir -p "${HOST_HOME}/.cerebras-code-data" 2>/dev/null || true
mkdir -p "${HOST_HOME}/.config/opencode" 2>/dev/null || true
chown -R "$HOST_UID:$HOST_GID" "${HOST_HOME}/.cerebras-code-data" "${HOST_HOME}/.config" 2>/dev/null || true

# Drop privileges and run cerebras-code in web mode
exec gosu "$HOST_USER" cerebras web "$@"
ENTRYPOINT_EOF

chmod +x "${INSTALL_DIR}/entrypoint.sh"

# ---------------------------------------------------------------------------
# Build Docker image
# ---------------------------------------------------------------------------
if [[ "$FORCE_REBUILD" == "true" ]] || ! docker image inspect "${IMAGE_NAME}:${CEREBRAS_CODE_VERSION}" &>/dev/null; then
    info "Building Docker image ${IMAGE_NAME}:${CEREBRAS_CODE_VERSION} ..."
    docker build --no-cache \
        --build-arg "CEREBRAS_CODE_VERSION=${CEREBRAS_CODE_VERSION}" \
        -t "${IMAGE_NAME}:${CEREBRAS_CODE_VERSION}" \
        -t "${IMAGE_NAME}:latest" \
        "${INSTALL_DIR}"
    ok "Docker image built"
else
    ok "Docker image ${IMAGE_NAME}:${CEREBRAS_CODE_VERSION} already exists (use --rebuild to force)"
fi

# ---------------------------------------------------------------------------
# API key setup
# ---------------------------------------------------------------------------
ENV_FILE="${INSTALL_DIR}/.env"

prompt_api_key() {
    local existing_key=""
    if [[ -f "$ENV_FILE" ]]; then
        existing_key=$(grep -oP '^CEREBRAS_API_KEY=\K.*' "$ENV_FILE" 2>/dev/null || true)
    fi

    if [[ -n "$existing_key" ]]; then
        local masked="${existing_key:0:8}...${existing_key: -4}"
        info "Existing Cerebras API key found: ${masked}"
        echo -n "  Keep existing key? [Y/n] "
        read -r answer </dev/tty
        if [[ "$answer" =~ ^[Nn] ]]; then
            existing_key=""
        fi
    fi

    if [[ -z "$existing_key" ]]; then
        echo ""
        echo -e "${BOLD}Enter your Cerebras API key${NC}"
        echo "  Get one at: https://inference.cerebras.ai/"
        echo -n "  API key: "
        read -r api_key </dev/tty

        if [[ -z "$api_key" ]]; then
            warn "No API key provided. You can set it later:"
            warn "  echo 'CEREBRAS_API_KEY=your-key' > ${ENV_FILE}"
            return
        fi

        # Write to env file (create or replace)
        echo "CEREBRAS_API_KEY=${api_key}" > "$ENV_FILE"
        chmod 600 "$ENV_FILE"
        ok "API key saved to ${ENV_FILE}"
    fi
}

prompt_api_key

# ---------------------------------------------------------------------------
# Write port forwarding config
# ---------------------------------------------------------------------------
PORTS_CONFIG_FILE="${INSTALL_DIR}/ports.conf"
echo "WEB_PORT=${PORT}" > "$PORTS_CONFIG_FILE"
echo "FORWARD_PORTS=${FORWARD_PORTS}" >> "$PORTS_CONFIG_FILE"
ok "Ports to forward: ${FORWARD_PORTS}"
chmod 600 "$PORTS_CONFIG_FILE"

# ---------------------------------------------------------------------------
# Write global opencode config (Cerebras provider pre-configured)
# ---------------------------------------------------------------------------
OPENCODE_CONFIG_DIR="${HOME}/.config/opencode"
mkdir -p "$OPENCODE_CONFIG_DIR"

if [[ ! -f "${OPENCODE_CONFIG_DIR}/opencode.json" ]]; then
    info "Writing default opencode config..."
    cat > "${OPENCODE_CONFIG_DIR}/opencode.json" << 'CONFIG_EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "cerebras": {
      "options": {
        "apiKey": "{env:CEREBRAS_API_KEY}"
      }
    }
  },
  "enabled_providers": ["cerebras"]
}
CONFIG_EOF
    ok "Config written to ${OPENCODE_CONFIG_DIR}/opencode.json"
else
    ok "Existing opencode config preserved at ${OPENCODE_CONFIG_DIR}/opencode.json"
fi

# ---------------------------------------------------------------------------
# Write wrapper script
# ---------------------------------------------------------------------------
info "Installing wrapper script..."

cat > "${BIN_DIR}/cerebras-code" << 'WRAPPER_EOF'
#!/usr/bin/env bash
set -euo pipefail

# ---- Load saved config ----
INSTALL_DIR="${HOME}/.cerebras-code"
if [[ -f "${INSTALL_DIR}/.env" ]]; then
    set -a
    source "${INSTALL_DIR}/.env"
    set +a
fi

# ---- Configuration ----
PORT="${CEREBRAS_CODE_PORT:-3333}"
IMAGE="${CEREBRAS_CODE_IMAGE:-cerebras-code:latest}"
CONTAINER_NAME="cerebras-code-${USER:-dev}"

# ---- Subcommands ----
case "${1:-start}" in
    stop)
        if docker ps -q -f "name=^${CONTAINER_NAME}$" 2>/dev/null | grep -q .; then
            docker stop "$CONTAINER_NAME" >/dev/null
            echo "Stopped."
        else
            echo "Not running."
        fi
        exit 0
        ;;
    status)
        if docker ps -q -f "name=^${CONTAINER_NAME}$" 2>/dev/null | grep -q .; then
            echo "Running — http://localhost:${PORT}"
        else
            echo "Not running."
        fi
        exit 0
        ;;
    logs)
        docker logs -f "$CONTAINER_NAME" 2>/dev/null || echo "Not running."
        exit 0
        ;;
    start) ;; # fall through
    *)
        echo "Usage: cerebras-code [start|stop|status|logs]"
        echo ""
        echo "Environment variables:"
        echo "  CEREBRAS_CODE_PORT       Web UI port (default: 3333)"
        echo "  CEREBRAS_CODE_FORWARD_PORTS Additional ports to forward (comma-separated)"
        echo ""
        echo "To add port forwarding after installation:"
        echo "  echo 'FORWARD_PORTS=3000,8000-8010' >> ~/.cerebras-code/ports.conf"
        exit 0
        ;;
esac

# ---- Parse port forwarding config ----
PORT_FWD_ARGS=(-p "127.0.0.1:${PORT}:${PORT}")

if [[ -f "${INSTALL_DIR}/ports.conf" ]]; then
    source "${INSTALL_DIR}/ports.conf"
fi

if [[ -n "${FORWARD_PORTS:-}" ]]; then
    IFS=',' read -ra PAIR_LIST <<< "$FORWARD_PORTS"
    for pair in "${PAIR_LIST[@]}"; do
        pair=$(echo "$pair" | xargs)
        if [[ "$pair" == *"-"* ]]; then
            IFS='-' read -ra RANGE <<< "$pair"
            start="${RANGE[0]}"
            end="${RANGE[1]}"
            for ((i=start; i<=end; i++)); do
                [[ "$i" == "$PORT" ]] && continue
                PORT_FWD_ARGS+=(-p "127.0.0.1:${i}:${i}")
                echo "  forwarding: localhost:${i} -> container:${i}"
            done
        else
            [[ "$pair" == "$PORT" ]] && continue
            PORT_FWD_ARGS+=(-p "127.0.0.1:${pair}:${pair}")
            echo "  forwarding: localhost:${pair} -> container:${pair}"
        fi
    done
fi

# ---- Check if already running ----
if docker ps -q -f "name=^${CONTAINER_NAME}$" 2>/dev/null | grep -q .; then
    echo "Cerebras Code is already running."
    echo "  Web UI: http://localhost:${PORT}"
    echo "  Stop:   cerebras-code stop"
    exit 0
fi

# Clean up stopped container with same name
docker rm "$CONTAINER_NAME" 2>/dev/null || true

# ---- Collect env vars to pass through ----
ENV_ARGS=()
for var in CEREBRAS_API_KEY \
           OPENCODE_SERVER_PASSWORD OPENCODE_SERVER_USERNAME \
           GITHUB_TOKEN GH_TOKEN; do
    if [[ -n "${!var:-}" ]]; then
        ENV_ARGS+=(-e "$var")
    fi
done

if [[ -z "${CEREBRAS_API_KEY:-}" ]]; then
    echo "WARNING: CEREBRAS_API_KEY is not set."
    echo "  Run the installer again or manually set it:"
    echo "  echo 'CEREBRAS_API_KEY=your-key' > ${INSTALL_DIR}/.env"
    echo ""
fi

# ---- Volume mounts ----
VOLUME_ARGS=(
    -v "${HOME}:${HOME}"
)

# Resolve symlinks under HOME that point outside HOME (e.g., NFS data dirs).
# On devservers, ~/.config, ~/.adobe, etc. are often symlinks to /net/... paths.
# We mount each unique symlink target so they resolve inside the container.
_mounted_targets=()
for _dotpath in "${HOME}"/.config "${HOME}"/.local; do
    if [[ -L "$_dotpath" ]]; then
        _real=$(readlink -f "$_dotpath" 2>/dev/null) || continue
        # Only mount if target is outside HOME and actually exists
        if [[ -d "$_real" ]] && [[ "$_real" != "${HOME}"/* ]]; then
            # Avoid duplicate mounts
            _dup=false
            for _m in "${_mounted_targets[@]+"${_mounted_targets[@]}"}"; do
                [[ "$_m" == "$_real" ]] && _dup=true && break
            done
            if [[ "$_dup" == false ]]; then
                VOLUME_ARGS+=(-v "${_real}:${_real}")
                _mounted_targets+=("$_real")
            fi
        fi
    fi
done

# Mount additional paths if specified (colon-separated)
# e.g., CEREBRAS_CODE_EXTRA_MOUNTS="/data:/opt/workspace"
if [[ -n "${CEREBRAS_CODE_EXTRA_MOUNTS:-}" ]]; then
    IFS=':' read -ra EXTRA_PATHS <<< "$CEREBRAS_CODE_EXTRA_MOUNTS"
    for p in "${EXTRA_PATHS[@]}"; do
        if [[ -d "$p" ]]; then
            VOLUME_ARGS+=(-v "${p}:${p}")
        fi
    done
fi

# ---- Start container ----
echo "============================================"
echo "  Cerebras Code — Web Mode"
echo "============================================"
echo ""
echo "  Web UI:    http://localhost:${PORT}"
echo ""
# Show forwarded ports
if [[ "${#PORT_FWD_ARGS[@]}" -gt 2 ]]; then
    echo "  Forwarded ports:"
    for arg in "${PORT_FWD_ARGS[@]}"; do
        if [[ "$arg" == "-p" ]]; then
            continue
        fi
        if [[ "$arg" == *":"* ]]; then
            port=$(echo "$arg" | cut -d: -f3 | cut -d: -f1)
            if [[ "$port" == "$PORT" ]]; then
                echo "    ${port} (web UI)"
            else
                echo "    ${port}"
            fi
        fi
    done
    echo ""
fi
echo "  VS Code:   Port auto-forwarded by Remote SSH"
echo "  Direct SSH: ssh -L ${PORT}:localhost:${PORT} <devserver>"
echo ""
echo "  Stop:      cerebras-code stop (or Ctrl+C)"
echo "  Logs:      cerebras-code logs"
echo "============================================"
echo ""

# ---- Show port forwarding info ----
echo "  Forwarded ports:"
echo "    ${PORT} (web UI)"
if [[ -n "${FORWARD_PORTS:-}" ]]; then
    IFS=',' read -ra PAIR_LIST <<< "$FORWARD_PORTS"
    for pair in "${PAIR_LIST[@]}"; do
        pair=$(echo "$pair" | xargs)  # trim whitespace
        if [[ "$pair" == *"-"* ]]; then
            IFS='-' read -ra RANGE <<< "$pair"
            echo "    ${RANGE[0]}-${RANGE[1]} (range)"
        else
            echo "    ${pair}"
        fi
    done
fi
echo ""

docker run --rm \
    --name "$CONTAINER_NAME" \
    "${PORT_FWD_ARGS[@]}" \
    "${VOLUME_ARGS[@]}" \
    -e "HOST_UID=$(id -u)" \
    -e "HOST_GID=$(id -g)" \
    -e "HOST_HOME=${HOME}" \
    -e "HOST_USER=${USER:-cuser}" \
    -w "${PWD}" \
    ${ENV_ARGS[@]+"${ENV_ARGS[@]}"} \
    "$IMAGE" \
    --port "$PORT" --hostname 0.0.0.0
WRAPPER_EOF

chmod +x "${BIN_DIR}/cerebras-code"

# ---------------------------------------------------------------------------
# Add to PATH
# ---------------------------------------------------------------------------
add_to_path() {
    local target_line="export PATH=\"${BIN_DIR}:\$PATH\""
    local shell_name rc_file

    shell_name="$(basename "${SHELL:-/bin/bash}")"

    case "$shell_name" in
        zsh)  rc_file="${HOME}/.zshrc" ;;
        fish)
            # Fish uses a different syntax
            mkdir -p "${HOME}/.config/fish"
            rc_file="${HOME}/.config/fish/config.fish"
            target_line="set -gx PATH \"${BIN_DIR}\" \$PATH"
            ;;
        *)    rc_file="${HOME}/.bashrc" ;;
    esac

    if [[ -f "$rc_file" ]] && grep -qF "$BIN_DIR" "$rc_file" 2>/dev/null; then
        return 0  # already on PATH
    fi

    echo "" >> "$rc_file"
    echo "# Cerebras Code" >> "$rc_file"
    echo "$target_line" >> "$rc_file"
}

if echo "$PATH" | tr ':' '\n' | grep -qF "$BIN_DIR"; then
    ok "Already on PATH"
else
    add_to_path
    ok "Added ${BIN_DIR} to PATH (restart shell or: source ~/.bashrc)"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
echo -e "${GREEN}${BOLD}Installation complete!${NC}"
echo ""
echo "  Start:     cerebras-code"
echo "  Stop:      cerebras-code stop"
echo "  Status:    cerebras-code status"
echo ""
echo "  Run from any project directory:"
echo "    cd ~/my-project && cerebras-code"
echo ""
echo "  The web UI will be available at http://localhost:${PORT}"
echo "  VS Code Remote SSH auto-forwards the port."
echo "  For direct SSH, tunnel with: ssh -L ${PORT}:localhost:${PORT} <devserver>"
echo ""
echo "  Forwarded ports: ${FORWARD_PORTS}"
echo "  Add more ports: echo 'FORWARD_PORTS=3333,3000,8000' >> ~/.cerebras-code/ports.conf"
echo ""
echo "  API key stored in: ${INSTALL_DIR}/.env"
echo "  Config stored in:  ${HOME}/.config/opencode/opencode.json"
echo ""
