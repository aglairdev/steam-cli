<div align="center">

[![STEAM-CLI](https://img.shields.io/badge/STEAM--CLI-3a6f8f?style=for-the-badge)](https://github.com/aglairdev/steam-cli)
</div>

## Que isso?

Gerenciador de jogos Steam no terminal, com lançamento nativo e via Proton.

![Bash](https://img.shields.io/badge/Bash-333333?style=flat-square&logo=gnubash&logoColor=white)

<div align="center">

| Menu | Nativo |
|:---:|:---:|
| ![menu demo](https://github.com/user-attachments/assets/a7b0ec43-71ff-449c-a7a3-94382bb50075) | ![nativo demo](https://github.com/user-attachments/assets/cd8297a7-fdc6-4070-804c-b27241f5cb6d) |
| Proton | Parâmetros |
| ![proton demo](https://github.com/user-attachments/assets/9f6394fa-8eba-426e-afee-7d413fa5099b) | ![params demo](https://github.com/user-attachments/assets/1e3ec7ed-a9de-4f29-8015-e49dcd1abfbe) |

</div>

## Instalação

```bash
curl -fsSL steam-cli.pages.dev/install | bash
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
