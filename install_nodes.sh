#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
#  install_nodes.sh — устанавливает все кастомные ноды для воркфлоу
# ─────────────────────────────────────────────────────────────────────────────

NODES_DIR="/workspace/ComfyUI/custom_nodes"
mkdir -p "$NODES_DIR"

node() {
    local repo="$1"
    local name
    name="$(basename "$repo" .git)"
    local dir="$NODES_DIR/$name"

    if [ ! -d "$dir" ]; then
        printf "  [+] %-45s" "$name"
        git clone --depth=1 "$repo" "$dir" -q
        if [ -f "$dir/requirements.txt" ]; then
            pip install -r "$dir/requirements.txt" -q 2>/dev/null || true
        fi
        if [ -f "$dir/install.py" ]; then
            (cd "$dir" && python install.py -q 2>/dev/null || true)
        fi
        echo " ✓"
    else
        printf "  [=] %-45s" "$name"
        (cd "$dir" && git pull -q 2>/dev/null)
        echo " (обновлено)"
    fi
}

echo ""
echo "── Кастомные ноды ───────────────────────────────────"

# Движок и сэмплеры
node "https://github.com/kijai/ComfyUI-KJNodes.git"
node "https://github.com/Clybius/ComfyUI-Extra-Samplers.git"

# Видео
node "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"

# Qwen VL (AILab_QwenVL_Advanced, QwenVL Prompt Enhancer)
node "https://github.com/1038lab/ComfyUI-QwenVL.git"

# Утилиты
node "https://github.com/rgthree/rgthree-comfy.git"
node "https://github.com/yolain/ComfyUI-Easy-Use.git"
node "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"
node "https://github.com/chflame163/ComfyUI_LayerStyle.git"
node "https://github.com/WASasquatch/was-node-suite-comfyui.git"

# Сегментация и поза
node "https://github.com/kijai/ComfyUI-segment-anything-2.git"
node "https://github.com/Fannovel16/comfyui_controlnet_aux.git"

# Impact Pack (ImpactSwitch)
node "https://github.com/ltdrdata/ComfyUI-Impact-Pack.git"

echo "── Ноды установлены ─────────────────────────────────"
echo ""
