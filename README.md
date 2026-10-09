# azahar-rgds

Build otimizada do [Azahar](https://github.com/azahar-emu/azahar) (emulador de 3DS) para o
**Anbernic RG DS** rodando [ROCKNIX](https://github.com/ROCKNIX/distribution) /
[ROCKNIXDS](https://github.com/JorreFog/ROCKNIXDS), mais os scripts que corrigem travamentos e
ganham desempenho no aparelho.

O RG DS usa um Rockchip RK3568 (4× Cortex-A55 a 1.99GHz, GPU Mali-G52). O gargalo do Azahar nele é
um único núcleo da CPU (`EmuThread`), e não a GPU.

## Resultados (Zelda: A Link Between Worlds, mesmo ponto do jogo)

| Configuração | FPS |
|---|---|
| Azahar 2126.0 do ROCKNIX, padrão | 42–47 |
| + CPU emulada em 80% | 45–48 |
| + Azahar 2126.1.2 com `-O3`, LTO e sem stack protector | 49–51 |
| + frameskip (patch 0100) | 55–60 |

A build com PGO é a última etapa. Ela ainda não foi medida.

## O que tem aqui

| Caminho | O que é |
|---|---|
| `patches/0001-*` | Patch do ROCKNIX: caminhos de configuração (igual ao pacote `azahar-sa`). |
| `patches/0003-*` | Patch do ROCKNIX: liberar a surface nativa antes do Wayland destruí-la. Adaptado ao 2126.1.2. |
| `patches/0100-frameskip-hack.patch` | Frameskip real e "apresentar só frames novos" (ver abaixo). |
| `Dockerfile`, `build.sh` | Ambiente de build arm64 (Debian trixie, glibc 2.41, igual ao ROCKNIX) e script de compilação. |
| `fetch-src.sh` | Baixa o Azahar 2126.1.2 com submódulos e aplica os patches. |
| `device/` | Scripts instalados no aparelho e `install.sh`. |
| `device/lsfg-vk/` | Tentativa de geração de frames com [lsfg-vk](https://github.com/PancakeTAS/lsfg-vk). **Experimental, não funciona ainda.** |

## Problemas encontrados e corrigidos

### Jogo "travava" por minutos ao carregar o save

Era o shader cache. O Azahar só grava o cache de pipelines do driver Vulkan
(`shaders/vulkan/pipeline/*.bin`) quando é fechado normalmente. No ROCKNIX, porém, ele é sempre morto
com `SIGKILL` por dois caminhos:

1. O hotkey de saída do ROCKNIX roda `killall -9 azahar` (via `set_kill` / `/tmp/.process-kill-data`).
2. O `gptokeyb`, iniciado junto com o Azahar, tem o próprio atalho de saída, que também roda `killall -9 azahar`.

Sem o cache, todo boot recompilava todas as pipelines do jogo (~3 minutos no ALBW). A correção:

- `device/profile.d/100-azahar-graceful-exit` sobrescreve `set_kill` só para o Azahar. O hotkey passa
  a mandar `SIGUSR1` para um helper.
- `device/azahar/azahar-gexit` é esse helper. Ele fecha a janela via `swaymsg kill`, o que faz o Azahar
  encerrar normalmente e gravar o cache. Se o Azahar não fechar em 60s, ele usa `-9`.
- O emulador roda com o nome de processo `azahar-rgds`, então o `killall -9 azahar` do gptokeyb não o atinge.
- `confirmClose=false` no `qt-config.ini`, para o fechamento não abrir diálogo.

### Janela principal na tela errada

O sway só tinha regra para a janela "Secondary". O `install.sh` adiciona uma regra que fixa a janela
principal no `DSI-2`.

## Patch 0100: frameskip

Configurado pela variável `AZAHAR_FRAMESKIP=N`: desenha 1 de cada N+1 frames. Diferente do frameskip
do Mandarine-Neo, que só pula a apresentação, este pula os draws de verdade, e é isso que alivia a CPU.

- Em frames pulados, `PicaCore::DrawArrays` retorna antes de `AccelerateDrawBatch`. O `delay_generator`
  continua contando os vértices, então o timing da GPU emulada não muda.
- Um display transfer ou texture copy é descartado se algum draw foi pulado desde a cópia anterior.
  Sem isso, a tela de cima mostrava a imagem da tela de baixo, porque o jogo usa o mesmo render target
  para as duas.
- Framebuffers que ficaram desatualizados são marcados, e o swap para eles é ignorado. Sem isso,
  o double buffer exibiria uma imagem mais velha.
- **Apresentar só frames novos** (`AZAHAR_PRESENT_NEW_ONLY=1`, ligado automaticamente com frameskip):
  quando nada novo chegou às telas, o vblank chama só `EndFrame()` (limitador de velocidade e
  estatísticas), sem apresentar. Para jogos que escrevem direto no framebuffer, há uma apresentação
  forçada a cada 4 vblanks.

É um hack. Funciona bem no ALBW, mas quebra a renderização no Mario Kart 7 (imagem "comendo" frames,
tela de baixo branca) e no Super Mario 3D Land (telas azuis). Por isso ele é ligado **por jogo**.

## Compilar

Num host arm64 com Docker. No Mac Apple Silicon: `brew install colima docker && colima start --cpu 8 --memory 12`.

```bash
./fetch-src.sh
docker build -t azahar-rgds-build .
MODE=release ./build.sh            # -> build/bin/Release/azahar
```

### PGO (opcional)

```bash
MODE=pgo-gen ./build.sh            # build instrumentada (mais lenta), grava em /storage/pgo no aparelho
# instale build-pgo/bin/Release/azahar no aparelho, jogue alguns jogos e saia pelo hotkey
mkdir pgo-data && ssh root@<ip> 'cd /storage/pgo && tar cf - .' | tar xf - -C pgo-data
MODE=pgo-use ./build.sh            # -> build-pgo/bin/Release/azahar
```

O perfil mede o código do emulador (JIT, comandos da GPU, cache de texturas), então serve para
qualquer jogo, não só para os usados na coleta.

## Instalar no aparelho

```bash
device/install.sh <ip-do-rgds> build/bin/Release/azahar
```

A instalação não modifica o sistema. O binário fica em `/storage/.config/azahar/bin/real/azahar-rgds`,
e o autostart faz bind mount de um wrapper sobre `/usr/bin/azahar`. Para voltar ao Azahar original,
apague `/storage/.config/autostart/azahar-custom` e reinicie.

## Opções por jogo

Ficam em `/storage/.config/azahar/rgds.cfg`. Não use o `system.cfg` para elas: o EmulationStation
regrava esse arquivo e apaga as chaves que não conhece. A configuração por jogo tem prioridade sobre a global.

```
3ds["<arquivo da rom>.3ds"].frameskip=1           # frameskip só nesse jogo
3ds.frameskip=0                                   # global (padrão: desligado)
```

A CPU emulada continua sendo configurada pelo menu do ROCKNIX (`cpu_speed`: 1=90% ... 5=50%).

O wrapper também aplica a regra do sway que põe a janela principal no `DSI-2` a cada execução, porque o
ROCKNIXDS restaura `/storage/.config/sway/config`.

## Geração de frames (lsfg-vk), experimental

O lsfg-vk usa os shaders do Lossless Scaling, que é pago. Por isso o `Lossless.dll` **não** está neste
repositório: cada um precisa do próprio. O estado atual no RG DS:

- Com GCC, a camada sai sem exportar `layer_vkGetInstanceProcAddr`. É preciso compilar com clang.
- A camada WSI implícita da Mali (`VK_LAYER_window_system_integration`) implementa o swapchain
  sozinha. O lsfg precisa ficar acima dela, o que é feito via `device/lsfg-vk/vk_loader_settings.json`.
- `device/lsfg-vk/lsfg-vk-v1.0.0-rgds.patch` aceita instâncias sem extensões de superfície.
- Ainda falha: o Azahar cai com `SIGSEGV` (ponteiro nulo) em `Vulkan::CreateInstance` quando o lsfg
  está na cadeia acima da WSI da Mali.

## Licença

GPL-2.0-or-later, a mesma do Azahar.
