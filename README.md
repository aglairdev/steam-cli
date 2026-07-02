<div align="center">

[![STEAM-CLI](https://img.shields.io/badge/STEAM--CLI-1b2838?style=for-the-badge)](https://github.com/aglairdev/steam-cli)
</div>

## Que isso?

Gerenciador de jogos Steam no terminal, com lançamento nativo e via Proton.

![Bash](https://img.shields.io/badge/Bash-333333?style=flat-square&logo=gnubash&logoColor=white)

<div align="center">

| Menu principal | Nativo | Proton | Parâmetros |
|:---:|:---:|:---:|:---:|
| ![menu](https://github.com/user-attachments/assets/00000000-0000-0000-0000-000000000001) | ![nativo](https://github.com/user-attachments/assets/00000000-0000-0000-0000-000000000002) | ![proton](https://github.com/user-attachments/assets/00000000-0000-0000-0000-000000000003) | ![params](https://github.com/user-attachments/assets/00000000-0000-0000-0000-000000000004) |

</div>

## Instalação

```bash
curl -fsSL steam-cli.pages.dev/install | bash
```

> [!WARNING]
> Você precisa abrir a Steam GUI **pelo menos uma vez** para definir bibliotecas alternativas (se não quiser usar a padrão `~/.steam/steam` e caso escolha usar o manifest para baixar jogos).  
> Jogos Windows exigem **Proton instalado** ~ o script detecta e usa o primeiro Proton que encontrar.  
> A opção de baixar jogos via [Manifest](https://github.com/aglairdev/Manifest) é opcional; sem ela o script gerencia apenas jogos já instalados.

**Requisitos:** `steam` `bash` `curl`

## Uso

```bash
steam-cli
```

### Flags

| Flag | Descrição |
|------|-----------|
| `-d` | modo debug (`~/.config/steam-cli/debug.log`) |
| `-v` | exibe versão |
| `-h` | mostra ajuda |

## Funcionalidades

- **Lista jogos instalados** ordenados por último jogado
- **Inicia jogos nativos Linux** ~ corrige permissões automaticamente e usa Steam Runtime quando necessário
- **Inicia jogos Windows via Proton** ~ detecta o primeiro Proton disponível no sistema
- **Parâmetros por jogo** ~ define flags de lançamento individuais (ex.: `-opengl`, `-windowed`)
- **Proton configurável** ~ define um Proton padrão global ou um específico por AppID em `~/.config/steam-cli/proton.conf`
- **Remove jogos** diretamente pelo menu
- **Download opcional** via [Manifest](https://github.com/aglairdev/Manifest) ~ baixa manifests Steam sem abrir a GUI

## Configuração

| Arquivo | Conteúdo |
|---|---|
| `~/.config/steam-cli/proton.conf` | Proton global e por AppID |
| `~/.config/steam-cli/params/<appid>` | parâmetros de lançamento por jogo |
| `~/.config/steam-cli/debug.log` | logs do modo debug |

## Atualização

O script verifica atualizações ao iniciar:

```
  ꕤ nova versão: v1.0.1 (atual: v1.0.0)
-----------------------------------------------
  Atualizar? (s/N):
```

Responda `s` para baixar e reiniciar automaticamente.

## Remoção

```bash
rm ~/.local/bin/steam-cli
rm -r ~/.config/steam-cli
```

## Créditos

- [Manifest](https://github.com/aglairdev/Manifest) ~ CLI para baixar manifests Steam

## Licença

[MIT](https://github.com/aglairdev/steam-cli/blob/main/LICENSE)

<p align="center">ꕤ AGL</p>