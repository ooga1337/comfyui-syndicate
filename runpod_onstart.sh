#!/bin/bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║   AI Syndicate — ComfyUI Template                               ║
# ║   RunPod On-start Script                                        ║
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
echo "  ██████  ██████  ███████ ███    ██ ██████  █████  ██"
echo " ██    ██ ██   ██ ██      ████   ██ ██   ██ ██  ██ ██"
echo " ██    ██ ██████  █████   ██ ██  ██ ██████  ███████ ██"
echo " ██    ██ ██      ██      ██  ██ ██ ██   ██ ██  ██ ██"
echo "  ██████  ██      ███████ ██   ████ ██████  ██  ██ ██"
echo -e "${NC}"
echo "  AI Syndicate — ComfyUI Template for RunPod"
echo "  ─────────────────────────────────────────"

# ─── Системные зависимости ─────────────────────────────────────────
section "Системные зависимости"
apt-get update -qq && apt-get install -y -qq \
    git wget curl aria2 ffmpeg \
    libgl1 libglib2.0-0 libsm6 libxrender1 \
    > /dev/null 2>&1
log "Зависимости установлены"

# ─── ComfyUI ───────────────────────────────────────────────────────
section "ComfyUI"
if [ -d "$COMFY_DIR/.git" ]; then
    log "ComfyUI уже установлен — обновляю..."
    git -C "$COMFY_DIR" pull --quiet
else
    log "Клонирую ComfyUI..."
    git clone --quiet https://github.com/comfyanonymous/ComfyUI.git "$COMFY_DIR"
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
        git clone --quiet "$repo" "$NODES_DIR/$name"
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
# Пропускает если файл уже есть. aria2c = 16 потоков, быстро.
download() {
    local url="$1"
    local dest_dir="$2"
    local filename="$3"

    if [ -f "$dest_dir/$filename" ]; then
        log "Уже есть: $filename"
        return
    fi

    log "Скачиваю: $filename"
    aria2c --console-log-level=error --summary-interval=0 \
           -c -x 16 -s 16 -k 1M \
           "$url" -d "$dest_dir" -o "$filename" \
        || err "Не удалось скачать: $filename"
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
    "https://huggingface.co/Comfy-Org/mochi-preview/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
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
    pip install --quiet huggingface_hub 2>/dev/null || true
    huggingface-cli download gokaygokay/Florence-2-SD3-Captioner \
        --local-dir "$FLORENCE_DIR" \
        --local-dir-use-symlinks False \
        ${HF_TOKEN:+--token "$HF_TOKEN"} \
        || err "Не удалось скачать Florence-2-SD3-Captioner"
fi

# ─── Запуск ComfyUI ────────────────────────────────────────────────
section "Запуск ComfyUI"
log "Порт: 8188"
log "Открой в браузере: https://$(hostname -I | awk '{print $1}'):8188"

cd "$COMFY_DIR"
exec python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --preview-method auto \
    --dont-print-server
