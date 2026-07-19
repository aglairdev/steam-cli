<div align="center">

<video src="https://github.com/user-attachments/assets/1755d10f-b979-44e3-a8d4-41a4f2d01304" controls width="400"></video>

[![Release](https://img.shields.io/github/v/release/aglairdev/steam-tui?style=for-the-badge&color=94baf2&label=release)](https://github.com/aglairdev/steam-tui/releases)
![OS](https://img.shields.io/badge/OS-Linux-94baf2?style=for-the-badge&logo=linux&logoColor=white)
[![License](https://img.shields.io/github/license/aglairdev/steam-tui?style=for-the-badge&color=94baf2)](LICENSE)
![Bash](https://img.shields.io/badge/%3C%2F%3E-Bash-94baf2?style=for-the-badge)

Biblioteca steam TUI.

</div>

## Instalação

**Requisitos:** `steam` · `bash` · `curl` · `nerdfonts`

**1. Adicionar path**

*bash/zsh* (`~/.bashrc` ou `~/.zshrc`):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

*fish* (`~/.config/fish/config.fish`):

```bash
set -Ux PATH $HOME/.local/bin $PATH
```

Reinicie o terminal após configurar o path.

**2. Instalar**

```bash
curl -fsSL steamcli.pages.dev/install | bash
```

> [!CAUTION]
> Jogos windows exigem **proton instalado**. O script detecta e usa o primeiro proton encontrado no sistema (ou o configurado em `~/.config/steam-tui/proton.conf`).

> [!WARNING]
> Abra a steam GUI **pelo menos uma vez** antes de usar, para que bibliotecas alternativas sejam registradas (necessário se você não usa apenas a biblioteca padrão `~/.steam/steam`, ou se for usar o *Manifest* para baixar jogos).

> [!NOTE]
> O download de jogos via [Manifest](https://github.com/aglairdev/manifest) é opcional ~ sem ele, o steam-tui gerencia normalmente os jogos já instalados pela interface gráfica.

## Uso

```bash
steam-tui
```

| Flag | Descrição |
|:---:|---|
| `-d` | modo debug, grava log completo em `~/.config/steam-tui/debug.log` |
| `-v` | exibe a versão instalada |
| `-h` | mostra ajuda |

## Funcionalidades

**Biblioteca**
- Lista jogos instalados, ordenados por último jogado

**Lançamento**
- Exibe total de horas jogadas (atualmente sem compatibilidade em flatpak/snap)
- Nativo linux ~ corrige permissões e recorre ao steam runtime quando necessário
- Windows via proton ~ detecta o primeiro proton disponível, com fallback e configuração por AppID
- Parâmetros de lançamento por jogo 

**Controle**
- O usuário define suporte nativo e/ou mapeamento SDL manualmente
- Mapeamento global ou por jogo
- Integração com [gamepad-tool](https://github.com/General-Arcade/sdl2-gamepad-tool) ~ download, atualização e remoção pelo próprio menu

**Dependências**
- Checagem e instalação de `mangohud`, `gamemode` e bibliotecas 32-bit
- Detecção automática de distro (Arch, Fedora e Debian)

**Gerenciamento**
- Remove jogos diretamente pelo menu
- Download opcional de jogos via [Manifest](https://github.com/aglairdev/manifest)

## Estrutura

```
~/.config/steam-tui/
├── steam-tui                # script principal
├── proton.conf              # proton global e por AppID
├── params/
│   └── <appid>              # parâmetros de lançamento por jogo
├── controle/
│   ├── global.conf          # mapeamento de controle global
│   ├── jogos/
│   │   └── <appid>          # suporte nativo / mapeamento por jogo
│   └── gamepad-tool/        # binário e versão do gamepad-tool
├── lastplayed/
│   └── <appid>              # timestamp do último jogado
├── lib/
│   ├── core.sh
│   ├── responsiveness.sh
│   ├── ui.sh
│   ├── logo.sh
│   ├── config.sh
│   ├── deps.sh
│   ├── steam.sh
│   ├── games.sh
│   ├── controller.sh
│   └── menus.sh
└── deps/
    └── deps.conf            # pacotes de dependências por distro
```

## Atualização

O script verifica novas versões ao iniciar:

```
Nova versão v2.0.3 disponível (atual v2.0.2). Atualizar?
> Não
> Sim
```

## Remoção

```bash
rm ~/.local/bin/steam-tui
rm -r ~/.config/steam-tui
```

## Créditos

- [manifest](https://github.com/aglairdev/Manifest) ~ TUI para baixar manifests
- [gamepad-tool](https://github.com/General-Arcade/sdl2-gamepad-tool) ~ geração de mapeamentos de controle
- [nerd fonts](https://www.nerdfonts.com/) ~ ícones do menu

<p align="center">ꕤ AGL</p>
