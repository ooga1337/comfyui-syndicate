#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   AI Syndicate — ComfyUI Template                               ║
# ║   Template by ooga · RunPod On-start Script                     ║
# ║                                                                 ║
# ║   Base image: runpod/pytorch:2.8.0-py3.11-cuda12.8.1           ║
# ║   GPU support: RTX 3070 → RTX 5090 · A100 · H100               ║
# ║                                                                 ║
# ║   Первый запуск: ~30-60 мин (установка + скачивание ~50 GB)    ║
# ║   Повторный запуск: ~2-3 мин (всё уже на Volume)               ║
# ╚══════════════════════════════════════════════════════════════════╝

set -e

# ─── Пути ──────────────────────────────────────────────────────────
WORKSPACE="/workspace"
COMFY_DIR="$WORKSPACE/ComfyUI"
NODES_DIR="$COMFY_DIR/custom_nodes"
MODELS="$COMFY_DIR/models"

# ─── Цвета ─────────────────────────────────────────────────────────
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
echo -e "  ${YELLOW}Template by ooga${NC} · AI Syndicate · ComfyUI"
echo "  ─────────────────────────────────────────"

# ─── Системные зависимости ─────────────────────────────────────────
# runpod/pytorch:2.8 уже содержит git, curl, wget, python3.11
# Доустанавливаем только то чего нет
section "Системные зависимости"
apt-get update -qq && apt-get install -y -qq \
    aria2 ffmpeg \
    libgl1 libglib2.0-0 libsm6 libxrender1 libxext6 \
    > /dev/null 2>&1
log "Зависимости установлены (CUDA 12.8 · RTX 3070→5090)"

# ─── ComfyUI ───────────────────────────────────────────────────────
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

# ─── Создаём папки для моделей ─────────────────────────────────────
mkdir -p \
    "$MODELS/diffusion_models" \
    "$MODELS/clip" \
    "$MODELS/vae" \
    "$MODELS/model_patches" \
    "$MODELS/LLM"

# ─── Функция установки нода ────────────────────────────────────────
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

# ─── Кастомные ноды ────────────────────────────────────────────────
section "Кастомные ноды"
mkdir -p "$NODES_DIR"

install_node "https://github.com/pythongosssss/ComfyUI-Custom-Scripts"
install_node "https://github.com/pythongosssss/ComfyUI-WD14-Tagger"
install_node "https://github.com/kijai/ComfyUI-Florence2"
install_node "https://github.com/ClownsharkBatwing/RES4LYF"
install_node "https://github.com/cubiq/ComfyUI_essentials"
install_node "https://github.com/Fannovel16/comfyui_controlnet_aux"
install_node "https://github.com/ltdrdata/ComfyUI-Impact-Pack"
install_node "https://github.com/kijai/ComfyUI-KJNodes"
install_node "https://github.com/yolain/ComfyUI-Easy-Use"
install_node "https://github.com/Suzie1/ComfyUI_Comfyroll_CustomNodes"
install_node "https://github.com/rgthree/rgthree-comfy"

log "Все ноды установлены"

# ─── Функция скачивания ────────────────────────────────────────────
# Пропускает если файл уже есть. aria2c = 16 потоков + прогресс в %.
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

# ─── Модели — UNET ─────────────────────────────────────────────────
section "Модели — UNET / Diffusion"

download \
    "https://huggingface.co/T5B/Z-Image-Turbo-FP8/resolve/main/z-image-turbo-fp8-e4m3fn.safetensors" \
    "$MODELS/diffusion_models" \
    "z-image-turbo-fp8-e4m3fn.safetensors"

download \
    "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" \
    "$MODELS/diffusion_models" \
    "z_image_turbo_bf16.safetensors"

download \
    "https://huggingface.co/ooga1337/aaaa/resolve/main/flux-2-klein-9b-fp8.safetensors" \
    "$MODELS/diffusion_models" \
    "flux-2-klein-9b-fp8.safetensors"

# ─── Модели — ControlNet Patch ─────────────────────────────────────
section "Модели — ControlNet"

download \
    "https://huggingface.co/alibaba-pai/Z-Image-Turbo-Fun-Controlnet-Union-2.1/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union-2.1.safetensors" \
    "$MODELS/model_patches" \
    "Z-Image-Turbo-Fun-Controlnet-Union-2.1.safetensors"

# ─── Модели — CLIP / Text Encoders ─────────────────────────────────
section "Модели — CLIP"

download \
    "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
    "$MODELS/clip" \
    "qwen_3_4b.safetensors"

download \
    "https://huggingface.co/Comfy-Org/vae-text-encorder-for-flux-klein-9b/resolve/main/split_files/text_encoders/qwen_3_8b_fp8mixed.safetensors" \
    "$MODELS/clip" \
    "qwen_3_8b_fp8mixed.safetensors"

download \
    "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "$MODELS/clip" \
    "umt5_xxl_fp8_e4m3fn_scaled.safetensors"

# ─── Модели — VAE ──────────────────────────────────────────────────
section "Модели — VAE"

download \
    "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" \
    "$MODELS/vae" \
    "ae.safetensors"

download \
    "https://huggingface.co/Comfy-Org/vae-text-encorder-for-flux-klein-9b/resolve/main/split_files/vae/flux2-vae.safetensors" \
    "$MODELS/vae" \
    "flux2-vae.safetensors"

download \
    "https://huggingface.co/kuuroo/vae/resolve/main/ultrafluxVAEImproved_v10.safetensors" \
    "$MODELS/vae" \
    "ultrafluxVAEImproved_v10.safetensors"

# ─── Модели — Florence-2-SD3-Captioner ─────────────────────────────
section "Модели — Florence-2-SD3-Captioner"

FLORENCE_DIR="$MODELS/LLM/Florence-2-SD3-Captioner"
if [ -f "$FLORENCE_DIR/config.json" ]; then
    log "Florence-2-SD3-Captioner уже скачан"
else
    log "Скачиваю Florence-2-SD3-Captioner..."
    mkdir -p "$FLORENCE_DIR"
    pip install --quiet --upgrade huggingface_hub
    python3 -c "
from huggingface_hub import snapshot_download
import os
snapshot_download(
    repo_id='gokaygokay/Florence-2-SD3-Captioner',
    local_dir='$FLORENCE_DIR',
    local_dir_use_symlinks=False,
    token=os.environ.get('HF_TOKEN') or None
)
print('Florence-2-SD3-Captioner скачан')
" || err "Не удалось скачать Florence-2-SD3-Captioner"
fi

# ─── Запуск JupyterLab ─────────────────────────────────────────────
section "JupyterLab"
pip install --quiet jupyterlab 2>/dev/null || true

JUPYTER_PASSWORD="${JUPYTER_PASSWORD:-}"

jupyter lab \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser \
    --allow-root \
    --NotebookApp.token="$JUPYTER_PASSWORD" \
    --NotebookApp.password="" \
    --ServerApp.root_dir="$WORKSPACE" \
    > /tmp/jupyter.log 2>&1 &

log "JupyterLab запущен на порту 8888"

# ─── Запуск ComfyUI ────────────────────────────────────────────────
section "Запуск ComfyUI"
log "ComfyUI запущен на порту 8188"

cd "$COMFY_DIR"
exec python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --preview-method auto \
    --dont-print-server
