<p align="center">
  <img src="docs/images/sloth.png" alt="Sloth" width="250">
</p>

# <p align="center">Unlazier AI</p>

<p align="center">
  <a href="README.md">English</a> | <b>Português (Brasil)</b> | <a href="README.es.md">Español</a>
</p>

> Esta é uma tradução do [README em inglês](README.md), que é a versão oficial e pode estar mais atualizada.

Assistentes de IA para programação são poderosos, mas costumam pegar atalhos. Eles adivinham o que você quis dizer em vez de perguntar, escrevem mais código do que o necessário, mexem em coisas que você não pediu e deixam trabalho pela metade.

O Unlazier AI é um conjunto de regras que faz esses assistentes trabalharem com mais cuidado. Você instala uma vez, e todas as ferramentas de IA para programação que você usa passam a seguir as mesmas regras em todos os projetos.

## Índice

- [O que você ganha](#o-que-você-ganha)
- [Ferramentas suportadas](#ferramentas-suportadas)
- [Instalação](#instalação)
- [O que muda no seu computador](#o-que-muda-no-seu-computador)
- [Limites de uso e trabalho em paralelo](#limites-de-uso-e-trabalho-em-paralelo)
- [Desinstalação](#desinstalação)
- [Atualizando da versão 1](#atualizando-da-versão-1)
- [Notas para cada ferramenta](#notas-para-cada-ferramenta)
- [As regras](#as-regras)
- [Personalização](#personalização)
- [Para contribuidores](#para-contribuidores)
- [Licença](#licença)

## O que você ganha

O Unlazier AI adiciona três camadas a cada ferramenta. Todas as ferramentas recebem as mesmas três camadas; só muda o lugar onde cada uma guarda as próprias configurações.

| Camada | O que faz | Por que importa |
|--------|-----------|-----------------|
| **1. Regras** | Coloca as regras no arquivo de instruções globais da ferramenta, para que o assistente as leia no início de cada sessão. | O assistente sabe o que se espera dele desde a primeira mensagem. |
| **2. Lembrete** | Reenvia um resumo curto das regras a cada mensagem sua, e os princípios principais de novo depois que a conversa é compactada. | Em sessões longas, as instruções do início perdem peso conforme a conversa cresce. O lembrete mantém as regras frescas. |
| **3. Uso** | Acrescenta ao lembrete uma linha dizendo quanto dos seus limites de uso de 5 horas e semanal já foi consumido. | O assistente pode rodar tarefas em paralelo quando há folga e desacelerar antes de você atingir um limite. |

## Ferramentas suportadas

| Ferramenta | 1. Regras | 2. Lembrete | 3. Uso |
|------------|:---------:|:-----------:|:------:|
| Claude Code | Sim | Sim | Sim, pela status line |
| Codex CLI | Sim | Sim (precisa de uma aprovação, veja as [notas](#codex-cli)) | Sim, lido do próprio log de sessão do Codex |
| Gemini CLI | Sim | Sim | Não disponível |
| Devin Desktop (antigo Windsurf) | Sim | Sim | Não disponível |
| Kiro | Sim | Sim | Não disponível |
| Cline | Sim | Sim no Linux e no macOS (precisa de uma configuração, veja as [notas](#cline)) | Não disponível |
| OpenCode | Sim | Sim | Não disponível |
| Amp | Sim | Sim | Não disponível |
| GitHub Copilot CLI | Sim | Não disponível | Não disponível |

"Não disponível" sempre significa que a própria ferramenta não oferece um jeito de fazer aquilo: o Copilot CLI ignora o que um hook de prompt imprime, e só o Claude Code e o Codex expõem os limites de uso num formato que um programa consegue ler. O Cursor não é suportado porque guarda as regras globais nas próprias configurações, e não num arquivo.

## Instalação

### Linux e macOS

Abra um terminal e rode:

```bash
curl -fsSL https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/install.sh | bash
```

As camadas de lembrete e de uso precisam do **jq**, uma pequena ferramenta de JSON. Se ele não estiver instalado, o instalador instala as regras mesmo assim e mostra o comando exato para instalar o jq no seu sistema (por exemplo `brew install jq` no macOS ou `sudo apt-get install -y jq` no Ubuntu). Instale o jq e rode o instalador de novo.

### Windows

Abra o **PowerShell** e rode:

```powershell
irm https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/install.ps1 | iex
```

No Windows não é preciso instalar mais nada.

### Escolhendo suas ferramentas

O instalador mostra uma lista numerada com todas as ferramentas suportadas e marca com `*` as que encontrou no seu computador. As mensagens do instalador aparecem em inglês:

```
Choose the tools to install Unlazier AI for (* = found on this computer):
  1) * Claude Code
  2)   OpenCode
  3) * Codex CLI
  ...
Type numbers separated by spaces, "all", or press Enter for the tools marked with *:
```

Aperte **Enter** para instalar nas ferramentas marcadas com `*`, ou digite os números que quiser (por exemplo `1 3`).

### Sem o menu

Para escolher as ferramentas no próprio comando, o que é útil em scripts:

```bash
# Linux and macOS, from a downloaded copy of this repository
./install.sh --harness claude,codex

# Linux and macOS, without downloading
curl -fsSL https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/install.sh | bash -s -- --harness claude,codex
```

```powershell
# Windows
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/install.ps1))) -Harness claude,codex
```

Nomes das ferramentas: `claude`, `opencode`, `codex`, `copilot`, `gemini`, `amp`, `kiro`, `cline`, `devin` ou `all`. Acrescente `--yes` (no Windows: `-Yes`) para responder "sim" às perguntas automaticamente.

Depois de instalar, **reinicie suas ferramentas** para que elas carreguem as mudanças.

## O que muda no seu computador

O instalador nunca substitui as suas configurações e nunca cria cópias de backup.

- **Seus arquivos continuam seus.** As regras ficam dentro de um bloco marcado, que começa com `<!-- unlazier-ai:start -->` e termina com `<!-- unlazier-ai:end -->`. Nada do que você escreveu fora desse bloco é alterado. Instalar de novo só atualiza o bloco.
- **Os arquivos de configuração recebem acréscimos, não substituições.** Os hooks são adicionados ao lado dos que você já tem. Um arquivo de configuração que não pode ser lido com segurança (por exemplo, um com comentários) fica como está, e o instalador avisa você.
- **Todo o resto fica numa pasta por ferramenta**, chamada `unlazier-ai`, ao lado das configurações da própria ferramenta.

No Windows, `~` significa a sua pasta de usuário (`C:\Users\<você>`).

| Ferramenta | Regras | Lembrete | Pasta |
|------------|--------|----------|-------|
| Claude Code | `~/.claude/CLAUDE.md` | hooks em `~/.claude/settings.json`; status line se você não tiver uma | `~/.claude/unlazier-ai/` |
| Codex CLI | `~/.codex/AGENTS.md` | `~/.codex/hooks.json` | `~/.codex/unlazier-ai/` |
| Gemini CLI | `~/.gemini/GEMINI.md` | hook em `~/.gemini/settings.json` | `~/.gemini/unlazier-ai/` |
| Devin Desktop | `~/.devin/rules/unlazier-ai-principles.md` e `unlazier-ai-rules.md` | hook em `~/.config/devin/config.json` (Windows: `%APPDATA%\devin\config.json`) | `~/.devin/unlazier-ai/` |
| Kiro | `~/.kiro/steering/unlazier-ai.md` | `~/.kiro/hooks/unlazier-ai.json` | `~/.kiro/unlazier-ai/` |
| Cline | `~/Documents/Cline/Rules/unlazier-ai.md` | `~/Documents/Cline/Hooks/UserPromptSubmit` | `~/Documents/Cline/unlazier-ai/` |
| OpenCode | `~/.config/opencode/AGENTS.md` | `~/.config/opencode/plugins/unlazier-ai.ts` | `~/.config/opencode/unlazier-ai/` |
| Amp | `~/.config/amp/AGENTS.md` | `~/.config/amp/plugins/unlazier-ai.ts` | `~/.config/amp/unlazier-ai/` |
| GitHub Copilot CLI | `~/.copilot/copilot-instructions.md` | nenhum | `~/.copilot/unlazier-ai/` |

Se você mudou o lugar das configurações de uma ferramenta com a variável de ambiente dela (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `COPILOT_HOME`, `GEMINI_CLI_HOME`, `KIRO_HOME`), o instalador usa esse lugar.

## Limites de uso e trabalho em paralelo

Assinaturas como as do Claude e do ChatGPT limitam quanto você pode usar numa janela de 5 horas e numa semana. O Unlazier AI diz ao assistente como dosar o ritmo:

| Janela de 5 horas | O que o assistente faz |
|-------------------|------------------------|
| abaixo de 70% | Roda em paralelo o máximo de trabalho que conseguir |
| de 70% a 85% | Roda no máximo 2 tarefas ao mesmo tempo |
| de 85% a 95% | Trabalha numa tarefa por vez, sem agentes auxiliares |
| 95% ou mais | Termina o passo atual, avisa você e espera |

Quando a janela **semanal** chega a 99%, o assistente termina o passo atual, avisa você e espera.

Quando paraleliza, ele prefere, nesta ordem: agentes auxiliares para partes da mesma tarefa, depois tarefas diferentes do mesmo pedido, depois pedidos diferentes.

**De onde vêm os números:**

- **Claude Code** envia o uso só para a status line (a barra na parte de baixo da tela). Se você não tem status line, o instalador adiciona uma que mostra as duas janelas e as salva para o lembrete. Se você já tem a sua, ela é mantida. Para alimentar o lembrete, faça a sua status line salvar a parte `rate_limits` do que o Claude Code envia para ela em `~/.claude/state/rate_limits.json`, neste formato:

    ```json
    {"captured_at": 1794668291, "five_hour": {"used_percentage": 24, "resets_at": 1794683400}, "seven_day": {"used_percentage": 60, "resets_at": 1794978000}}
    ```

    `captured_at` é o horário atual em segundos. Os dados de uso só existem nos planos de assinatura do Claude, não com chave de API.
- **Codex CLI** grava o uso no próprio log de sessão, que o lembrete lê. Não é preciso configurar nada.
- **As outras ferramentas** não expõem o uso, então o lembrete diz `Usage: unknown`. Nesse caso, o assistente roda no máximo 2 a 3 tarefas ao mesmo tempo e pergunta a você antes de rodar mais de 5.

Uma leitura com mais de 15 minutos conta como desconhecida.

## Desinstalação

Linux e macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/uninstall.sh | bash
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/uninstall.ps1 | iex
```

O desinstalador mostra o mesmo menu e remove só o que o Unlazier AI adicionou: os blocos marcados, os hooks, os plugins, a status line (só se for a que o Unlazier AI instalou) e as pastas `unlazier-ai`. Um arquivo que fica vazio depois que o bloco é removido é apagado. Suas configurações, seu histórico e suas credenciais continuam lá.

## Atualizando da versão 1

A versão 1 copiava os arquivos dela por cima da sua configuração em `~/.claude` e `~/.config/opencode`. Quando você instala a versão 2, o instalador procura esses arquivos antigos, mostra a lista e pergunta antes de removê-los. Os arquivos antigos de regras e de skills só são oferecidos para remoção se estiverem exatamente como a versão 1 os deixou; um arquivo que você editou é mantido.

O antigo `~/.claude/CLAUDE.md` (ou `~/.config/opencode/AGENTS.md`) é reconhecido pela primeira linha, `# Global Agent Rules`. Se você acrescentou anotações suas nele depois de instalar a versão 1, responda **não** e tire suas anotações de lá antes: a versão 1 substituía o arquivo inteiro, então o instalador não consegue separar as suas anotações das regras antigas.

> **Não rode o desinstalador da versão 1.** Ele apagava as pastas `~/.claude` e `~/.config/opencode` inteiras, incluindo suas configurações e credenciais. O desinstalador da versão 2 remove só o que o Unlazier AI adicionou.

## Notas para cada ferramenta

### Claude Code

O Claude Code pede que você confie numa pasta antes de rodar hooks nela; o lembrete começa a funcionar depois que você aceita. Os dados de uso precisam de uma assinatura do Claude e de uma status line (veja [Limites de uso](#limites-de-uso-e-trabalho-em-paralelo)).

### Codex CLI

O Codex só roda um hook novo depois que você o aprova. Abra o Codex, digite `/hooks` e aprove os dois hooks do Unlazier AI uma única vez. Se existir um arquivo chamado `AGENTS.override.md` em `~/.codex`, o Codex ignora o `AGENTS.md`, e o instalador avisa você. Por padrão, o Codex lê no máximo 32 KiB de instruções no total; as regras do Unlazier AI ocupam cerca de 18 KiB, então instruções de projeto muito longas podem ser cortadas. Você pode aumentar o limite com `project_doc_max_bytes` em `~/.codex/config.toml`.

### Gemini CLI

O Gemini reenvia o arquivo de instruções a cada mensagem, então não precisa de nenhum passo extra depois da compactação. O Google substituiu o Gemini CLI pelo Antigravity CLI para usuários gratuitos e do Google One em 18 de junho de 2026; o Antigravity CLI ainda não é suportado.

### Devin Desktop (antigo Windsurf)

O Devin limita cada arquivo de regras a 12.000 caracteres, então as regras ficam divididas em dois arquivos. O Devin também roda os hooks que encontra em `~/.claude/settings.json`; desligar isso desligaria também as suas regras do Claude Code dentro do Devin, então o Unlazier AI deixa como está. O Devin não documenta nenhum jeito de adicionar texto depois da compactação, então só o lembrete a cada mensagem é usado.

### Kiro

O lembrete depois da compactação precisa do Kiro CLI 3.1.0 ou mais recente.

### Cline

Os hooks vêm desligados. Ligue **Enable Hooks** nas Feature Settings do Cline. O Cline só suporta hooks no Linux e no macOS, então no Windows o Cline recebe as regras sem o lembrete.

### OpenCode

O plugin funciona com o OpenCode 1.18.29 ou mais recente, incluindo a versão 2. O OpenCode recarrega os arquivos de instruções sozinho depois da compactação. Depois que `~/.config/opencode/AGENTS.md` existe, o OpenCode para de ler `~/.claude/CLAUDE.md` como alternativa; o instalador avisa você quando isso se aplica.

### Amp

O plugin é carregado em threads novas. Numa thread em andamento, recarregue os plugins com `Ctrl+O` e depois `plugins: reload`.

### GitHub Copilot CLI

O Copilot ignora o que um hook de prompt imprime, então recebe as regras sem o lembrete. A extensão do Copilot no VS Code também pode ler `~/.claude/CLAUDE.md` quando a configuração `chat.useClaudeMdFile` está ligada, o que carregaria as regras duas vezes se você usar os dois.

## As regras

Os princípios em [`AGENTS.md`](AGENTS.md) definem como o assistente trabalha:

1. **Think Before Coding** (pensar antes de codar): explicitar as suposições e perguntar quando algo não está claro (uma pergunta por vez, com uma resposta recomendada).
2. **Simplicity First** (simplicidade primeiro): a menor mudança que resolve o problema, sem abstrações especulativas.
3. **Surgical Changes** (mudanças cirúrgicas): mexer só no que o pedido exige e seguir o estilo que já existe.
4. **Goal-Driven Execution** (execução guiada por objetivos): definir como o sucesso é verificado e verificar antes de dizer que terminou.
5. **Commit Messages** (mensagens de commit): seguir o formato Conventional Commits.
6. **Communication Brevity** (comunicação breve): respostas curtas e diretas, sem enrolação.

> **Atribuição:** Os quatro primeiros princípios vêm das [observações de Andrej Karpathy](https://x.com/karpathy/status/2015883857489522876) sobre as armadilhas de LLMs ao programar, popularizadas pelo repositório [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills).

As regras por tema em [`rules/`](rules/) trazem mais detalhes, cada uma com um exemplo ruim e um bom:

| Regra | Foco |
|-------|------|
| [`structure.md`](rules/structure.md) | Código legível, uma função para cada tarefa, funções pequenas |
| [`correctness.md`](rules/correctness.md) | Tratamento de erros, casos extremos, segurança |
| [`style.md`](rules/style.md) | Formatação, consistência, tom profissional |
| [`completeness.md`](rules/completeness.md) | Sem placeholders, código morto ou restos de depuração |
| [`performance.md`](rules/performance.md) | Evitar consultas e processamento desnecessários |
| [`testability.md`](rules/testability.md) | Código fácil de testar, testes que verificam comportamento |
| [`async.md`](rules/async.md) | Lidar com trabalho assíncrono e com a liberação de recursos |
| [`naming.md`](rules/naming.md) | Nomes claros, que seguem as convenções de cada linguagem |
| [`documentation.md`](rules/documentation.md) | Comentários que explicam o porquê, e instruções de execução |
| [`parallelism.md`](rules/parallelism.md) | Dosar o trabalho em paralelo pelos limites de uso |

O lembrete enviado a cada mensagem está em [`reminder.md`](reminder.md).

## Personalização

- **Suas próprias regras globais:** escreva-as no mesmo arquivo do bloco do Unlazier AI, fora dos marcadores. Elas sobrevivem a atualizações e desinstalações.
- **Mudar as regras do Unlazier AI:** edite os arquivos numa cópia deste repositório e rode `./install.sh` (ou `.\install.ps1`) a partir dessa cópia. Edições feitas direto dentro do bloco instalado são substituídas na próxima instalação.
- **Regras de projeto:** cada ferramenta também lê instruções da pasta do seu projeto (por exemplo `AGENTS.md` ou `CLAUDE.md`); elas valem por cima das regras globais.

## Para contribuidores

Organização do repositório:

| Caminho | Função |
|---------|--------|
| `AGENTS.md`, `rules/` | As regras (camada 1). `CLAUDE.md` é um link para `AGENTS.md`. |
| `reminder.md` | O lembrete curto (camada 2). |
| `hooks/inject.sh`, `hooks/inject.ps1` | Imprime o lembrete e a linha de uso (camadas 2 e 3) no formato que cada ferramenta espera. |
| `statusline/` | Status line do Claude Code que salva o uso para o lembrete. |
| `plugins/` | Plugins do OpenCode e do Amp, que chamam o mesmo script de hook. |
| `install.sh`, `install.ps1` | Instaladores; cada ferramenta é um adaptador numa mesma tabela. Os `uninstall.*` chamam os instaladores no modo de desinstalação. |
| `tests/` | Testes do instalador e do hook; `tests/fixtures/v1/` guarda arquivos da versão 1 para os testes de atualização. |

Para rodar os testes:

```bash
bash tests/install_test.sh        # Linux and macOS, needs jq
```

```powershell
./tests/install_test.ps1          # Windows PowerShell 5.1 or PowerShell 7
```

Os testes usam uma pasta pessoal temporária e nunca mexem na sua configuração real. O GitHub Actions roda os testes no Ubuntu, no macOS e no Windows, além do `shellcheck` nos scripts de shell.

O [`README.md`](README.md) em inglês é a versão oficial. Este arquivo e o [`README.es.md`](README.es.md) são traduções dele; quem alterar o README em inglês deve atualizá-los na mesma mudança.

## Licença

MIT
