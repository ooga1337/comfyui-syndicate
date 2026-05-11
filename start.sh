#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  AI SYNDICATE 4v1 Animate — start.sh
#  Запускается RunPod'ом автоматически при старте пода.
#  Базовый образ: runpod/pytorch:2.4.0-py3.11-cuda12.4.1-devel-ubuntu22.04
# ─────────────────────────────────────────────────────────────────────────────
set -e

COMFYUI_PATH="/workspace/ComfyUI"
REPO_DIR="/workspace/setup"   # куда склонирован этот GitHub-репо

echo "============================================"
echo "  AI SYNDICATE 4v1 Animate — RunPod Start  "
echo "============================================"

# ─── Системные зависимости ────────────────────────────────────────────────────
apt-get update -qq && apt-get install -y --no-install-recommends \
    git wget curl aria2 ffmpeg libgl1 libglib2.0-0 \
    libsm6 libxext6 libxrender-dev libgomp1 \
    > /dev/null 2>&1

# ─── ComfyUI ──────────────────────────────────────────────────────────────────
if [ ! -d "$COMFYUI_PATH" ]; then
    echo "[1/3] Клонирую ComfyUI..."
    git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_PATH"
    pip install -r "$COMFYUI_PATH/requirements.txt" -q
else
    echo "[1/3] ComfyUI уже есть, обновляю..."
    cd "$COMFYUI_PATH" && git pull -q
fi

# ─── Папки моделей ────────────────────────────────────────────────────────────
mkdir -p "$COMFYUI_PATH/models/"{unet,vae,clip,clip_vision,loras,controlnet,sams,onnx,model_patches,LLM}
mkdir -p "$COMFYUI_PATH/input"

# ─── Кастомные ноды ───────────────────────────────────────────────────────────
echo "[2/3] Устанавливаю / обновляю кастомные ноды..."
bash "$REPO_DIR/install_nodes.sh"

# ─── Python-зависимости ───────────────────────────────────────────────────────
echo "[3/3] Python-зависимости..."
pip install -q \
    sageattention \
    onnxruntime-gpu \
    "huggingface_hub[hf_xet]" \
    opencv-python-headless \
    einops omegaconf \
    imageio imageio-ffmpeg \
    scipy ultralytics timm \
    2>/dev/null || true

# ─── Копируем воркфлоу ────────────────────────────────────────────────────────
if [ -f "$REPO_DIR/workflow.json" ]; then
    cp "$REPO_DIR/workflow.json" \
       "$COMFYUI_PATH/input/_AI_SYNDICATE__4_v_1_Animate.json"
    echo "[+] Воркфлоу скопирован в ComfyUI/input/"
fi

# ─── Запуск ───────────────────────────────────────────────────────────────────
echo ""
echo "✅ Готово! ComfyUI запускается..."
echo "   Порт:    8188  (Connect → HTTP Service)"
echo "   Модели:  bash /workspace/setup/download_models.sh"
echo ""

cd "$COMFYUI_PATH"
exec python main.py \
    --listen 0.0.0.0 \
    --port 8188 \
    --enable-cors-header \
    --preview-method latent2rgb \
    ${EXTRA_ARGS:-}
