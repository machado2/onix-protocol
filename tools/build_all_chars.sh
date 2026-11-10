#!/bin/sh
# Gera todos os personagens (MPFB2 + mocap CMU) em godot/assets/chars/.
cd "$(dirname "$0")/.."
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
for n in ${@:-agent_m agent_f guard police civ_m1 civ_m2 civ_m3 civ_f1 civ_f2 civ_f3 vip scientist}; do
  "$B" -b -P tools/blender/build_chars.py -- $n "$(pwd)/godot/assets/chars/$n.glb" "$(pwd)/assets_dl/cmu" 2>&1 | grep -iE "error|traceback|exportado|line [0-9]" | cut -c1-200
done
ls -la godot/assets/chars
