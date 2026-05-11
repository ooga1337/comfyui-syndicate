#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  download_models.sh
#  Запускать вручную по SSH после старта пода:
#    bash /workspace/setup/download_models.sh
#
#  Переменные окружения:
#    HF_TOKEN   — токен HuggingFace (нужен для gated-моделей)
# ─────────────────────────────────────────────────────────────────────────────

MODELS="/workspace/ComfyUI/models"
mkdir -p "$MODELS/"{unet,vae,clip,clip_vision,loras,controlnet,sams,onnx,model_patches,LLM}

# Быстрое скачивание через aria2
get() {
    local url="$1" dst="$2"
    if [ -f "$dst" ]; then
        echo "  [✓] $(basename "$dst") — уже есть, пропускаю"
        return
    fi
    echo "  [↓] $(basename "$dst")"
    aria2c -x 8 -s 8 -k 1M -q --allow-overwrite=false \
        -o "$(basename "$dst")" -d "$(dirname "$dst")" "$url"
}

# HuggingFace через huggingface-cli (нужен для Xet-хранилища)
hf_get() {
    local repo="$1" file="$2" dst_dir="$3"
    local fname
    fname="$(basename "$file")"
    if [ -f "$dst_dir/$fname" ]; then
        echo "  [✓] $fname — уже есть, пропускаю"
        return
    fi
    echo "  [↓] $fname (HF: $repo)"
    HF_HUB_ENABLE_HF_TRANSFER=1 huggingface-cli download "$repo" "$file" \
        --local-dir "$dst_dir" \
        --local-dir-use-symlinks False \
        ${HF_TOKEN:+--token "$HF_TOKEN"} -q 2>/dev/null
    # Убираем вложенные папки если huggingface-cli создал их
    find "$dst_dir" -name "$fname" ! -path "$dst_dir/$fname" \
        -exec mv {} "$dst_dir/$fname" \; 2>/dev/null || true
    find "$dst_dir" -type d -empty -delete 2>/dev/null || true
}

HF="https://huggingface.co"

echo ""
echo "══════════════════════════════════════════════════════"
echo "  Загрузка моделей для AI SYNDICATE 4v1 Animate"
echo "  HF_TOKEN: ${HF_TOKEN:+установлен}${HF_TOKEN:-НЕ УСТАНОВЛЕН}"
echo "══════════════════════════════════════════════════════"

# ─── 1. Основная модель ───────────────────────────────────────────────────────
echo ""
echo "[ UNet / Diffusion ]"
get "$HF/Kijai/WanVideo_comfy/resolve/main/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors" \
    "$MODELS/unet/Wan2_2-Animate-14B_fp8_scaled_e4m3fn_KJ_v2.safetensors"

get "$HF/Kijai/WanVideo_comfy/resolve/main/z_image_turbo_bf16.safetensors" \
    "$MODELS/unet/z_image_turbo_bf16.safetensors"

# ─── 2. Text encoders ─────────────────────────────────────────────────────────
echo ""
echo "[ CLIP / Text encoders ]"
get "$HF/Kijai/WanVideo_comfy/resolve/main/umt5_xxl_fp8_e4m3fn_scaled.safetensors" \
    "$MODELS/clip/umt5_xxl_fp8_e4m3fn_scaled.safetensors"

get "$HF/Kijai/WanVideo_comfy/resolve/main/qwen_3_4b.safetensors" \
    "$MODELS/clip/qwen_3_4b.safetensors"

get "$HF/h94/IP-Adapter/resolve/main/models/image_encoder/model.safetensors" \
    "$MODELS/clip_vision/clip_vision_h.safetensors"

# ─── 3. VAE ───────────────────────────────────────────────────────────────────
echo ""
echo "[ VAE ]"
get "$HF/Kijai/WanVideo_comfy/resolve/main/wan_2.1_vae.safetensors" \
    "$MODELS/vae/wan_2.1_vae.safetensors"

get "$HF/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors" \
    "$MODELS/vae/ae.safetensors"

# ─── 4. ControlNet ────────────────────────────────────────────────────────────
echo ""
echo "[ ControlNet ]"
get "$HF/Kijai/WanVideo_comfy/resolve/main/Z-Image-Turbo-Fun-Controlnet-Union-2.1.safetensors" \
    "$MODELS/controlnet/Z-Image-Turbo-Fun-Controlnet-Union-2.1.safetensors"

# ─── 5. LoRAs ─────────────────────────────────────────────────────────────────
echo ""
echo "[ LoRAs ]"
get "$HF/Kijai/WanVideo_comfy/resolve/main/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors" \
    "$MODELS/loras/lightx2v_I2V_14B_480p_cfg_step_distill_rank256_bf16.safetensors"

get "$HF/Kijai/WanVideo_comfy/resolve/main/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors" \
    "$MODELS/loras/wan2.2_i2v_lightx2v_4steps_lora_v1_high_noise.safetensors"

get "$HF/alibaba-pai/Wan2.2-Fun-14B-InP/resolve/main/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors" \
    "$MODELS/loras/Wan2.2-Fun-A14B-InP-low-noise-HPS2.1.safetensors"

get "$HF/Kijai/WanVideo_comfy/resolve/main/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors" \
    "$MODELS/loras/Wan21_PusaV1_LoRA_14B_rank512_bf16.safetensors"

# ─── 6. Qwen-Image DiffSynth ControlNets (через huggingface-cli, Xet) ─────────
echo ""
echo "[ Qwen-Image DiffSynth model_patches ]"
pip install -q "huggingface_hub[hf_xet]" 2>/dev/null || true

hf_get "Comfy-Org/Qwen-Image-DiffSynth-ControlNets" \
    "split_files/model_patches/qwen_image_canny_diffsynth_controlnet.safetensors" \
    "$MODELS/model_patches"

hf_get "Comfy-Org/Qwen-Image-DiffSynth-ControlNets" \
    "split_files/model_patches/qwen_image_depth_diffsynth_controlnet.safetensors" \
    "$MODELS/model_patches"

hf_get "Comfy-Org/Qwen-Image-DiffSynth-ControlNets" \
    "split_files/model_patches/qwen_image_inpaint_diffsynth_controlnet.safetensors" \
    "$MODELS/model_patches"

hf_get "Comfy-Org/Qwen-Image-DiffSynth-ControlNets" \
    "split_files/loras/qwen_image_union_diffsynth_lora.safetensors" \
    "$MODELS/loras"

# ─── 7. SAM2 ──────────────────────────────────────────────────────────────────
echo ""
echo "[ SAM2 ]"
get "$HF/Kijai/SAM2-safetensors/resolve/main/sam2.1_hiera_large.safetensors" \
    "$MODELS/sams/sam2.1_hiera_large.safetensors"

# ─── 8. ONNX (ViTPose + YOLO) ─────────────────────────────────────────────────
echo ""
echo "[ ONNX — ViTPose / YOLO ]"
get "$HF/hr16/yolo-nas-fp16/resolve/main/yolov10m.onnx" \
    "$MODELS/onnx/yolov10m.onnx" 2>/dev/null || \
    echo "  [!] yolov10m.onnx — скачай вручную из репо ViTPose-нод"

get "$HF/nicehorse/ViTPose/resolve/main/vitpose-l-wholebody.onnx" \
    "$MODELS/onnx/vitpose-l-wholebody.onnx" 2>/dev/null || \
    echo "  [!] vitpose-l-wholebody.onnx — скачай вручную из репо ViTPose-нод"

# ─── Итог ─────────────────────────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════"
echo "✅ Загрузка завершена!"
echo ""
echo "⚠️  Требует ручной загрузки:"
echo "   • kariu_000003000(1).safetensors → $MODELS/loras/"
echo ""
echo "Использование диска:"
du -sh "$MODELS"/*/  2>/dev/null | sort -h
echo "══════════════════════════════════════════════════════"
