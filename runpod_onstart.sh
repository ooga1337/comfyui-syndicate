#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   AI Syndicate — ComfyUI Animator Template                      ║
# ║   Template by ooga · RunPod On-start Script                     ║
# ║                                                                 ║
# ║   Base image: runpod/pytorch:2.4.0-py3.11-cuda12.4.1           ║
# ║   GPU support: RTX 3070 → RTX 5090 · A100 · H100               ║
# ║                                                                 ║
# ║   Первый запуск: ~30-60 мин (установка + скачивание ~70 GB)    ║
# ║   Повторный запуск: ~2-3 мин (всё уже на Volume)               ║
# ╚══════════════════════════════════════════════════════════════════╝

set -e

WORKSPACE="/workspace"
COMFY_DIR="$WORKSPACE/ComfyUI"
NODES_DIR="$COMFY_DIR/custom_nodes"
MODELS="$COMFY_DIR/models"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log()     { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
err()     { echo -e "${RED}[✗]${NC} $1"; }
section() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

echo -e "${CYAN}"
echo "   ██████   ██████   ██████   █████  "
echo "  ██    ██ ██    ██ ██       ██   ██ "
echo "  ██    ██ ██    ██ ██   ███ ███████ "
echo "  ██    ██ ██    ██ ██    ██ ██   ██ "
echo "   ██████   ██████   ██████  ██   ██ "
echo -e "${NC}"
echo -e "  ${YELLOW}Template by ooga${NC} · AI Syndicate · ComfyUI Animator"
echo "  ─────────────────────────────────────────────────"

section "Системные зависимости"
apt-get update -qq && apt-get install -y -qq \
    aria2 ffmpeg \
    libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 \
    > /dev/null 2>&1
log "Зависимости установлены (CUDA 12.4 · RTX 3070→5090)"

# ─── PyTorch — обновляем до cu130 если нужно ───────────────────────
section "PyTorch"
CUDA_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || echo "0")
TORCH_VER=$(python3 -c "import torch; print(torch.version.cuda or '0')" 2>/dev/null || echo "0")
log "Драйвер NVIDIA: $CUDA_VER | PyTorch CUDA: $TORCH_VER"

# RTX 5090 / Blackwell и новее требуют cu130+
if python3 -c "import torch; assert torch.cuda.is_available()" 2>/dev/null; then
    log "CUDA доступна — PyTorch в порядке"
else
    warn "CUDA недоступна — устанавливаю PyTorch cu130 для новых GPU (RTX 5090+)..."
    pip install --quiet --no-cache-dir \
        torch torchvision torchaudio \
        --index-url https://download.pytorch.org/whl/cu130
    log "PyTorch cu130 установлен"
fi

section "ComfyUI"
if [ -d "$COMFY_DIR/.git" ]; then
    log "ComfyUI уже установлен — обновляю..."
    git -C "$COMFY_DIR" pull --quiet
else
    log "Клонирую ComfyUI..."
    git clone --quiet --depth 1 https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
fi
pip install --quiet --no-cache-dir -r "$COMFY_DIR/requirements.txt"
log "ComfyUI готов"

install_node() {
    local repo="$1"
    local name=$(basename "$repo")
    if [ -d "$NODES_DIR/$name/.git" ]; then
        git -C "$NODES_DIR/$name" pull --quiet 2>/dev/null && log "Обновлён: $name" || true
    else
        log "Устанавливаю: $name"
        git clone --quiet --depth 1 "$repo" "$NODES_DIR/$name"
    fi
    if [ -f "$NODES_DIR/$name/requirements.txt" ]; then
        pip install --quiet --no-cache-dir -r "$NODES_DIR/$name/requirements.txt" 2>/dev/null || true
    fi
}

section "Кастомные ноды"
mkdir -p "$NODES_DIR"

install_node "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
install_node "https://github.com/kijai/ComfyUI-KJNodes"
install_node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite"
install_node "https://github.com/kijai/ComfyUI-WanVideoWrapper"
install_node "https://github.com/kijai/ComfyUI-WanAnimatePreprocess"
install_node "https://github.com/kijai/ComfyUI-segment-anything-2"
install_node "https://github.com/plugcrypt/CRT-Nodes"
install_node "https://github.com/teskor-hub/comfyui-teskors-utils"

log "Все ноды установлены"

download() {
    local url="$1"
    local dest_dir="$2"
    local filename="$3"

    if [ -f "$dest_dir/$filename" ]; then
        log "Уже есть: $filename"
        return
    fi

    echo -e "${CYAN}[↓]${NC} Скачиваю: ${YELLOW}$filename${NC}"
    aria2c --console-log-level=warn \
           --summary-interval=5 \
           --download-result=hide \
           -c -x 16 -s 16 -k 1M \
           "$url" -d "$dest_dir" -o "$filename" 2>&1 \
        | grep --line-buffered -E '\[#|ETA|DL:|%' \
        | while IFS= read -r line; do
              echo -e "    ${line}"
          done
    if [ -f "$dest_dir/$filename" ]; then
        log "Готово: $filename"
    else
        err "Не удалось скачать: $filename"
    fi
}

mkdir -p \
    "$MODELS/diffusion_models" \
    "$MODELS/vae" \
    "$MODELS/clip" \
    "$MODELS/clip_vision" \
    "$MODELS/loras" \
    "$MODELS/controlnet"

section "Модели — Diffusion"
download \
    "https://huggingface.co/Kijai/WanVideo_comfy_fp8_scaled/resolve/main/Wan22Animate/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors" \
    "$MODELS/diffusion_models" \
    "WanModel.safetensors"

section "Модели — VAE"
download \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1_VAE_bf16.safetensors" \
    "$MODELS/vae" \
    "vae.safetensors"

section "Модели — Text Encoder"
download \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/umt5-xxl-enc-bf16.safetensors" \
    "$MODELS/clip" \
    "text_enc.safetensors"

section "Модели — CLIP Vision"
download \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors" \
    "$MODELS/clip_vision" \
    "klip_vision.safetensors"

section "Модели — ControlNet"
download \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan21_Uni3C_controlnet_fp16.safetensors" \
    "$MODELS/controlnet" \
    "Wan21_Uni3C_controlnet_fp16.safetensors"

section "Модели — LoRA"
download \
    "https://huggingface.co/wangkanai/wan21-lightx2v-i2v-14b-480p/resolve/main/loras/wan/wan21-lightx2v-i2v-14b-480p-cfg-step-distill-rank256-bf16.safetensors" \
    "$MODELS/loras" \
    "light.safetensors"

download \
    "https://huggingface.co/f5aiteam/Wan/resolve/f0800d3b9c36764514ede2bedacb5f30072c1d38/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" \
    "$MODELS/loras" \
    "wan.reworked.safetensors"

download \
    "https://huggingface.co/rahul7star/wan2.2Lora/resolve/main/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors" \
    "$MODELS/loras" \
    "WanFun.reworked.safetensors"

download \
    "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Pusa/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors" \
    "$MODELS/loras" \
    "WanPusa.safetensors"

section "JupyterLab"
pip install --quiet jupyterlab 2>/dev/null || true
jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --NotebookApp.token="${JUPYTER_PASSWORD:-}" \
    --NotebookApp.password="" \
    --ServerApp.root_dir="$WORKSPACE" \
    > /tmp/jupyter.log 2>&1 &
log "JupyterLab запущен на порту 8888"

section "Запуск ComfyUI"
log "ComfyUI запущен на порту 8188"
cd "$COMFY_DIR"
exec python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --preview-method auto \
    --dont-print-server
