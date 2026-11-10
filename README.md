# Protocolo Ônix

Jogo original de tática em tempo real com visão isométrica, ambientado num Brasil cyberpunk.

Há duas versões no repositório:

- **`godot/`: nova versão em Godot 4.7 (Forward+)**, com gráficos 3D de alta qualidade. Por enquanto é uma fatia visual: a cidade gerada, a iluminação noturna e os personagens com mocap. A lógica do jogo ainda vai ser portada.
- **`v2/`: versão original em JavaScript/Three.js**, jogável no navegador em https://onix.fbmac.net.

## Versão Godot

### Como os assets são feitos

| Parte | Ferramenta | Saída |
|---|---|---|
| Texturas PBR (asfalto, concreto, reboco, tijolo, granito, metal, madeira, folhas…) | `tools/texgen/texgen.py`: ruído periódico por FFT e Voronoi em numpy, sem fotos | `godot/assets/tex/*_a/_n/_orm.png` (geradas, fora do git) |
| Peças de fachada (concreto, pele de vidro, favela, térreo comercial) | `tools/blender/kit_arch.py` | `godot/assets/kit/arch.glb` |
| Objetos de rua e telhado (postes, fiação, semáforos, caixas-d'água, ar-condicionado…) | `tools/blender/props.py` | `godot/assets/kit/props.glb` |
| Carros (sedã, hatch, van, táxi, viatura) | `tools/blender/cars.py` | `godot/assets/kit/cars.glb` |
| Árvores e palmeiras | `tools/blender/trees.py` | `godot/assets/kit/trees.glb` |
| Personagens: humanos do MPFB2 (MakeHuman), mocap do CMU redirecionado, equipamento ajustado ao corpo, IK das mãos na arma | `tools/blender/humans.py`, `mocap.py`, `build_chars.py` | `godot/assets/chars/<nome>.glb` |
| Efeitos sonoros, ambiente, motor e as 6 camadas da trilha dinâmica (mesma síntese da versão web, sem chuva) | `tools/sfxgen/sfxgen.py`: osciladores, biquads e reverb por FFT em numpy | `godot/assets/audio/sfx/*.wav`, `mus_*.wav`, `amb_loop.wav` (gerados, fora do git) |

Para refazer tudo:

```bash
python tools/texgen/texgen.py
python tools/sfxgen/sfxgen.py
B="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
for s in kit_arch props cars trees; do "$B" -b --factory-startup -P tools/blender/$s.py -- "$(pwd)/godot/assets/kit/${s/kit_arch/arch}.glb"; done
sh tools/build_all_chars.sh
```

Os personagens precisam de algumas instalações no Blender:

- A extensão MPFB2, de extensions.blender.org.
- Os pacotes CC0 do MakeHuman, baixados com `tools/dl_mh.sh` e descompactados na pasta de dados do MPFB.
- Os BVH do CMU em `assets_dl/cmu/`, vindos do espelho `meshula/cmu-mocap` no GitHub.

### Campanha

Sem argumentos, o jogo abre a campanha. A cidade 3D gira ao fundo dos menus.

- **Mapa tático de Nova Aurora.** Os 10 distritos aparecem com briefing, recompensa e renda. Cada vitória abre os distritos vizinhos.
- **Território.** Cada distrito tem imposto e lealdade. Lealdade em zero vira revolta, que se reprime numa missão procedural contra agitadores.
- **Arsenal.** Esquadrão de até 4 agentes em campo e 8 na folha. Implantes Mk I–III, clínica, inventário de 6 espaços e a loja do mercado cinza.
- **Laboratório.** 23 pesquisas em 5 áreas. Cientistas produzem PD e recebem salário.
- **Interceptações.** Mensagens dos Ponteiros e do Conselho, e a escolha final sobre o Coral.

### Carros e dicas

- **Carros.** O tráfego é simulado: segue a faixa (mão direita), para atrás de pedestres e de outros carros, buzina e dá a volta no mapa. Com agentes selecionados, clique num carro para entrar. Depois, clique no mapa para dirigir pelas ruas. A tecla V faz o esquadrão descer. Em velocidade, o carro atropela quem estiver na frente.
- **Dicas.** São 16 dicas contextuais, cada uma mostrada uma vez, salvas em `user://config.cfg`. Podem ser desligadas no título ou no menu de pausa.

### Mostradores neurais e áudio

- **Mostradores neurais.** Cada agente tem três canais: reflexo (velocidade e cadência), percepção (precisão e alcance) e controle (discrição, resistência e força da sonda). Ficam no painel ao lado dos cartões e podem ser arrastados ou ajustados com a roda do mouse. A tecla F alterna as predefinições CONTIDO, PADRÃO e SOBRECARGA.
- **Sobrecarga e colapso.** Passar de 1,5 no total drena a estabilidade; em zero, o agente entra em colapso. O tempo em sobrecarga vira dependência neural, que reduz a estabilidade máxima nas missões seguintes até passar pela clínica.
- **Áudio.** Fica no autoload `Snd` (`scripts/core/snd.gd`): efeitos posicionais em 3D, trilha em camadas que muda com a intensidade (discrição, alerta, combate), ambiente noturno e vozes. As falas de agentes e do Controle passam por filtro de rádio; Ponteiros e guardas, por capacete; a polícia, por megafone. A música abaixa durante as falas.
- **Volumes.** Ajustáveis no título e no menu de pausa, salvos em `user://config.cfg`.

O estado fica em `scripts/campaign/camp.gd`, autoload `Camp`, e é salvo em `user://campanha.sav`. As telas ficam em `scripts/ui/menu.gd`. Esc pausa a missão e permite abortá-la. No fim da missão, Enter volta ao relatório.

### Executável para Windows

```bash
godot --headless --path godot --export-release "Windows Desktop" build/ProtocoloOnix.exe
```

Gera `godot/build/ProtocoloOnix.exe` e `ProtocoloOnix.pck` (fora do git). Os dois arquivos precisam ficar na mesma pasta. Antes de exportar, gere as texturas e os sons e abra o projeto uma vez no editor, ou rode `--import`.

### Rodar e capturar imagens

```bash
godot --path godot --gpu-index 0
godot --path godot --gpu-index 0 -- --mission=docas --skipcine
godot --path godot --gpu-index 0 -- --cam=84,96,70,45,42,30 --crowd --quality=high
```

Opções depois de `--`:

- `--mission=docas|favela|…|torre` ou `--mission=assassinato|extracao|sabotagem|eliminacao`: pula a campanha e abre uma missão de teste.
- `--camptest=pasta [--launch=N] [--rich] [--revolt] --auto --speed=4`: percorre as telas da campanha e salva uma captura de cada uma. Com `--launch`, também joga a missão do distrito N no piloto automático e captura o relatório. Usa `user://teste.sav`.
- `--recaudio=arquivo.wav`: grava a saída de áudio. Com `--audio-driver Dummy` não toca nada nas caixas de som.
- `--headless -- --simtest`: testa a simulação sem gráficos (Chave Fantasma, manto, incendiária, implantes, pesquisas, resultado).
- `--shot=arquivo.jpg --frames=120`: salva uma captura e imprime o tempo de GPU.
- `--seed`: muda o distrito gerado.
- `--chars`: mostra uma fileira de personagens.
- `--quality=low|medium|high`: escolhe o nível de qualidade.
- `--off=fog,ssr,ssil,ssao,glow,shadows,moon`: desliga efeitos.

## Versão Three.js (`v2/`)

| Pasta | Conteúdo |
|---|---|
| `v2/` | O jogo: `index.html` (gerado), `js/` (simulação, render, UI, missões, roteiro), `audio/` (vozes), `models/`, `tex/` |
| `protocolo-onix.html` | Protótipo original em arquivo único |
| `tools/build_index.py` | Monta `v2/index.html` |
| `tools/assetpipe/` | Empacota modelos e texturas CC0 da versão web |
| `tools/gen_vo.py`, `tools/vo_en.py` | Geração das falas (vozes provisórias) |
| `tools/dev/bot.js` | Bot de balanceamento |
| `deploy/` | Configuração do Cloudflare Workers |

```bash
python tools/build_index.py .
python -m http.server 8766 --directory v2
```

## Créditos

- **Versão Godot:**
  - Texturas, prédios, objetos, carros e árvores foram feitos por código neste repositório.
  - Os humanos usam o MPFB2/MakeHuman: o código é GPL e os ativos (corpos, peles, roupas, cabelos) são CC0.
  - As animações vêm do banco de captura de movimento da Carnegie Mellon University (mocap.cs.cmu.edu), na conversão para BVH de Bruce Hahne, de uso livre.
- **Versão web:** usa modelos e texturas CC0 de Quaternius, Kenney e Poly Haven. Detalhes em [`v2/models/CREDITS.txt`](v2/models/CREDITS.txt).
