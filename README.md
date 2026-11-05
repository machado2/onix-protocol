# Protocolo Ônix

Jogo original de tática em tempo real com visão isométrica, ambientado num Brasil cyberpunk. Feito em JavaScript com Three.js; roda direto no navegador.

**Jogar:** https://onix.fbmac.net

## Estrutura

| Pasta | Conteúdo |
|---|---|
| `v2/` | O jogo: `index.html` (gerado), `js/` (simulação, render, UI, missões, roteiro), `audio/` (vozes), `models/` (personagens, veículos e objetos em glTF), `tex/` (texturas PBR) |
| `v2/js/missions/` | Uma missão por arquivo |
| `protocolo-onix.html` | Protótipo original em arquivo único; o CSS base do `v2/index.html` sai daqui |
| `tools/build_index.py` | Monta `v2/index.html` a partir de `protocolo-onix.html`, `v2/hud.css`, `v2/theme.css` e `v2/body.html` |
| `tools/assetpipe/` | Pipeline de assets (Node): empacota modelos e texturas CC0 com compressão meshopt |
| `tools/gen_vo.py`, `tools/vo_en.py` | Geração das falas (vozes provisórias) |
| `tools/dev/bot.js` | Bot de balanceamento que joga campanhas em simulação acelerada |
| `tools/patch_*.py` | Histórico das mudanças grandes, aplicadas como patches; o código atual em `v2/` é a referência |
| `deploy/` | Configuração do Cloudflare Workers (assets estáticos) |

## Rodar localmente

```bash
python tools/build_index.py .
python -m http.server 8766 --directory v2
```

Depois abra http://localhost:8766.

## Refazer os assets

Os pacotes originais (Quaternius, Kenney, Poly Haven) não estão no repositório. Baixe-os numa pasta `assets_dl/` e rode:

```bash
cd tools/assetpipe && npm install
node build.mjs ../../assets_dl ../../v2/models
node props.mjs ../../assets_dl ../../v2/models
node textures.mjs ../../assets_dl/polyhaven ../../v2/tex
for f in chars anims cars props; do node tojson.mjs ../../v2/models/$f.glb ../../v2/models/$f.json; done
```

## Créditos

Modelos 3D e texturas são CC0 (domínio público): Quaternius, Kenney e Poly Haven. Detalhes em [`v2/models/CREDITS.txt`](v2/models/CREDITS.txt).
