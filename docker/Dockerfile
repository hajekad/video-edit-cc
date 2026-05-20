FROM archlinux:base-devel

# ---------------------------------------------------------------------------
# Core system + media baseline (one layer, one cache flush)
#
#   git curl wget jq procps-ng sudo libnotify — dev / process / notify
#   nodejs npm                                — Claude Code + Codex runtime
#   python python-pip uv                      — scripts, ML libs, glue (uv = fast pip)
#   rust rust-analyzer                        — system-wide Rust toolchain + LSP
#   ffmpeg                                    — full ffmpeg (not the -free fork)
#   mediainfo mkvtoolnix-cli yt-dlp           — video inspection / muxing / fetch
#   imagemagick libheif libraw                — photo manipulation + HEIC/RAW
#   perl-image-exiftool                       — metadata read/write
#   chromium xorg-server-xvfb                 — headless browser w/ virtual X
# ---------------------------------------------------------------------------
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm --needed \
        git curl wget jq procps-ng sudo libnotify \
        nodejs npm \
        python python-pip uv \
        rust rust-analyzer \
        ffmpeg mediainfo mkvtoolnix-cli yt-dlp \
        imagemagick libheif libraw perl-image-exiftool \
        chromium xorg-server-xvfb && \
    pacman -Scc --noconfirm

# ---------------------------------------------------------------------------
# AUR access
#
# makepkg refuses to run as root, so we set up a passwordless-sudo `builder`
# user and build `paru` from source under it (source build avoids the
# libalpm.so version skew that paru-bin from AUR is prone to on rolling Arch).
# At runtime the `agent-install` wrapper shells out to builder for paru work
# while the agent itself stays root.
# ---------------------------------------------------------------------------
RUN useradd -m -G wheel -s /bin/bash builder && \
    echo 'builder ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/builder && \
    su builder -c 'cd /tmp && \
        git clone https://aur.archlinux.org/paru.git && \
        cd paru && makepkg -si --noconfirm' && \
    rm -rf /tmp/paru /home/builder/.cargo /home/builder/.cache

# ---------------------------------------------------------------------------
# Project package manifest — agent-curated list of extra system packages.
# Pulled in after paru is available so AUR + official repos both work.
# Build is reproducible: whatever's in agents/system-packages.txt becomes
# permanent on the next `docker compose up --build`.
# ---------------------------------------------------------------------------
COPY agents/system-packages.txt /tmp/system-packages.txt
RUN pkgs=$(grep -vE '^\s*(#|$)' /tmp/system-packages.txt | tr '\n' ' ') && \
    if [ -n "$pkgs" ]; then \
        sudo -u builder paru -S --noconfirm --needed $pkgs; \
    fi && \
    rm -f /tmp/system-packages.txt

# ---------------------------------------------------------------------------
# Node CLIs (npm globals)
# ---------------------------------------------------------------------------
RUN npm install -g \
        @anthropic-ai/claude-code \
        @openai/codex

# ---------------------------------------------------------------------------
# Rust toolchain comes from the official `rust` pacman package above
# (cargo/rustc/rustfmt/clippy at /usr/bin, available to every user).
# Per-user cargo state lives in $HOME/.cargo and survives container restart.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Local AI / ML stack (GPU-backed, host RTX 3080 Ti 12GB via NVIDIA-CTK).
#
# Shared venv at /opt/ml-venv used by every Python ML skill:
#   - torch / torchaudio / torchvision  — PyTorch wheels bundle CUDA 12.1 runtime
#   - nvidia-cudnn-cu12                 — cuDNN, required by CTranslate2 (WhisperX)
#   - whisperx + faster-whisper         — word-level transcription + diarization
#                                         (replaces ElevenLabs Scribe in video-use)
#   - pyannote.audio                    — speaker diarization backend for WhisperX
#
# Model weights download lazily on first use to /root/.cache (HuggingFace +
# whisper cache) — persisted across container recreates via the named
# `hf-models` volume mounted in docker-compose.yml.
#
# The PyTorch CUDA index URL bakes CUDA 12.1 runtime libs into the wheels.
# Container only needs the host driver + nvidia-container-toolkit (already
# wired); no system cuda / cudnn pacman packages required.
# ---------------------------------------------------------------------------
ENV ML_VENV=/opt/ml-venv \
    VIRTUAL_ENV=/opt/ml-venv \
    PATH=/opt/ml-venv/bin:${PATH}

# Arch's system python is 3.14 (too new for whisperx, which pins
# ctranslate2==4.4.0 — that version only ships wheels through 3.13).
# Use uv to install + manage a Python 3.12 interpreter for the ML venv.
# uv caches the interpreter at /root/.local/share/uv/python/.
#
# --index-strategy unsafe-best-match lets uv compare across indexes,
# which is required to actually pick the CUDA-wheel torch from
# download.pytorch.org over the CPU-only one on PyPI.
RUN uv python install 3.12 && \
    uv venv --python 3.12 ${VIRTUAL_ENV} && \
    uv pip install --no-cache \
        --index-strategy unsafe-best-match \
        --extra-index-url https://download.pytorch.org/whl/cu121 \
        torch torchvision torchaudio && \
    uv pip install --no-cache \
        nvidia-cudnn-cu12 \
        whisperx \
        faster-whisper \
        pyannote.audio

# ---------------------------------------------------------------------------
# Project Python package manifest — agent-curated list of pip-installable
# packages added on top of the ml-venv baseline. Mirror of
# system-packages.txt but for /opt/ml-venv. The agent appends to this
# file via `agent-pip-install <pkg>` so installs survive image rebuild.
# ---------------------------------------------------------------------------
COPY agents/python-packages.txt /tmp/python-packages.txt
RUN pkgs=$(grep -vE '^\s*(#|$)' /tmp/python-packages.txt | tr '\n' ' ') && \
    if [ -n "$pkgs" ]; then \
        /opt/ml-venv/bin/uv pip install --no-cache $pkgs; \
    fi && \
    rm -f /tmp/python-packages.txt

# ---------------------------------------------------------------------------
# Pre-warm WhisperX large-v3 weights into a baked path. Reason: smoke test
# discovered the first-run HuggingFace download stalled mid-stream (the
# .incomplete file never grew), forcing the agent to recover by hand with
# curl. Baking the model into the image makes the first transcription
# deterministic and removes the runtime network dependency.
#
# ~3 GB. Lives at /opt/whisper-models/ — agent code reads FSH_WHISPER_MODEL_DIR.
# If the model file already exists in the layer cache, the download is a no-op.
# ---------------------------------------------------------------------------
ENV FSH_WHISPER_MODEL_DIR=/opt/whisper-models \
    FSH_WHISPER_MODEL_NAME=large-v3
RUN mkdir -p "$FSH_WHISPER_MODEL_DIR" && \
    /opt/ml-venv/bin/python -c "from faster_whisper import WhisperModel; WhisperModel('$FSH_WHISPER_MODEL_NAME', download_root='$FSH_WHISPER_MODEL_DIR', compute_type='int8')" && \
    ls -lh "$FSH_WHISPER_MODEL_DIR"

# ---------------------------------------------------------------------------
# agent-install: canonical install path inside the container. Installs the
# requested package(s) via paru (official repos or AUR) AND appends each one
# to /agents/system-packages.txt so the package survives image rebuild.
#
# Lives in /usr/local/bin so it's on PATH for every shell — including the
# non-interactive bash that claude's Bash tool spawns, which does not source
# /root/.bashrc.
# ---------------------------------------------------------------------------
RUN cat > /usr/local/bin/agent-install <<'EOF' && chmod +x /usr/local/bin/agent-install
#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "usage: agent-install <package> [<package>...]" >&2
    exit 2
fi

sudo -u builder paru -S --noconfirm --needed "$@"

manifest=/agents/system-packages.txt
if [ ! -d "$(dirname "$manifest")" ]; then
    echo "warn: $(dirname "$manifest") not mounted; install not persisted" >&2
    exit 0
fi
touch "$manifest"
for pkg in "$@"; do
    if ! grep -qxF "$pkg" "$manifest"; then
        echo "$pkg" >> "$manifest"
    fi
done
EOF

# ---------------------------------------------------------------------------
# agent-pip-install: the pip equivalent of agent-install. Installs into
# /opt/ml-venv AND appends to /agents/python-packages.txt so the package
# is bundled on next image rebuild. See /docs/HARNESS_SELF_EXTENSION.md.
# ---------------------------------------------------------------------------
RUN cat > /usr/local/bin/agent-pip-install <<'EOF' && chmod +x /usr/local/bin/agent-pip-install
#!/usr/bin/env bash
set -euo pipefail

if [ $# -eq 0 ]; then
    echo "usage: agent-pip-install <pip-spec> [<pip-spec>...]" >&2
    echo "  examples:" >&2
    echo "    agent-pip-install playwright" >&2
    echo "    agent-pip-install 'transformers>=4.40' accelerate" >&2
    echo "  installs into /opt/ml-venv and appends to" >&2
    echo "  /agents/python-packages.txt for next-image persistence." >&2
    exit 2
fi

/opt/ml-venv/bin/uv pip install "$@"

manifest=/agents/python-packages.txt
if [ ! -d "$(dirname "$manifest")" ]; then
    echo "warn: $(dirname "$manifest") not mounted; install not persisted" >&2
    exit 0
fi
touch "$manifest"
for spec in "$@"; do
    if ! grep -qxF "$spec" "$manifest"; then
        echo "$spec" >> "$manifest"
    fi
done
EOF

# ---------------------------------------------------------------------------
# Claude config seed
#
# Baked at /opt/claude-config; seed.sh upserts settings.json + statusline.sh
# into /root/.claude on every container start. The named /root/.claude volume
# keeps auth/sessions/history; the seed only touches the config + script.
# ---------------------------------------------------------------------------
COPY docker/claude-config /opt/claude-config
RUN chmod +x /opt/claude-config/seed.sh \
             /opt/claude-config/statusline.sh \
             /opt/claude-config/scaffold-project.sh \
             /opt/claude-config/hooks/*.sh \
             /opt/claude-config/tools/*

# Put fsh-context / timeline-view / cut-boundary / ffprobe-json on PATH
# so the agent can call them by name from any cwd.
ENV PATH=/opt/claude-config/tools:${PATH}

WORKDIR /work

VOLUME ["/root/.claude"]

ENTRYPOINT ["/opt/claude-config/seed.sh"]
CMD ["tail", "-f", "/dev/null"]
