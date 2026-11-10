#!/bin/sh
# Baixa o MPFB e os pacotes CC0 do MakeHuman usados pelos personagens.
cd "$(dirname "$0")/../assets_dl"
curl -sL -o mpfb/mpfb.zip "https://extensions.blender.org/download/sha256:c075b3e9b94b8e5556a5f03f4653602d02ea306de08126e8f55ed6dee28a2dad/add-on-mpfb-v2.0.18.zip?repository=%2Fapi%2Fv1%2Fextensions%2F&blender_version_min=4.2.0"
for p in makehuman_system_assets system_clothes_materials01 system_hair_materials01 pants01 shirts01 shoes01 suits01 equipment01 gloves01 hair01 eyebrows01 eyelashes01 skins01 skins02; do
  curl -sL -o "mh_packs/$p.zip" "https://files.makehumancommunity.org/asset_packs/$p/${p}_cc0.zip" || echo "falhou $p"
done
ls -la mpfb mh_packs
