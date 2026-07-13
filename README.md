<div align="center">

[![STEAM-CLI](https://img.shields.io/badge/STEAM--CLI-3a6f8f?style=for-the-badge)](https://github.com/aglairdev/steam-cli)
</div>

## Que isso?

Gerenciador de jogos Steam no terminal, com lançamento nativo e via Proton.

![Bash](https://img.shields.io/badge/Bash-333333?style=flat-square&logo=gnubash&logoColor=white)

<div align="center">

| Menu | Nativo |
|:---:|:---:|
| ![menu demo](https://github.com/user-attachments/assets/8b526ca5-fa35-4e38-922d-d5774553089c) | ![nativo demo](https://github.com/user-attachments/assets/4f4dfc66-311a-4c8b-8069-b2041a3929e0) |
| Proton | Parâmetros |
| ![proton demo](https://github.com/user-attachments/assets/7640d4aa-51db-4f5a-8bd5-4d983714783e) | ![params demo](https://github.com/user-attachments/assets/38b7e2f0-c89c-489a-aa2f-e8ef7c4236cb) |

</div>

**Instalação**

```bash
git clone -b backup/v1.0.3 https://github.com/aglairdev/steam-tui.git 
```

> [!CAUTION]
> Jogos Windows exigem **Proton instalado** ~ o script detecta e usa o primeiro Proton que encontrar.

> [!WARNING]
> Você precisa abrir a Steam GUI **pelo menos uma vez** para definir bibliotecas alternativas (se não quiser usar a padrão `~/.steam/steam` e caso escolha usar o manifest para baixar jogos).

> [!NOTE]
> A opção de baixar jogos via [Manifest](https://github.com/aglairdev/Manifest) é opcional; sem ela o script gerencia apenas jogos já instalados.

**Requisitos:** `steam` `bash` `curl`

## Uso

```bash
bash steam-cli.sh
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

> [!TIP]
> Atualizações funcionam a partir da [v2.0.0](https://github.com/aglairdev/steam-tui/tree/main)

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
