<p align="center">
  <img src="docs/images/sloth.png" alt="Sloth" width="250">
</p>

# <p align="center">Unlazier AI</p>

<p align="center">
  <a href="README.md">English</a> | <a href="README.pt-BR.md">Português (Brasil)</a> | <b>Español</b>
</p>

> Esta es una traducción del [README en inglés](README.md), que es la versión oficial y puede estar más actualizada.

Los asistentes de IA para programar son muy capaces, pero a menudo toman atajos. Adivinan lo que quisiste decir en lugar de preguntar, escriben más código del necesario, cambian cosas que no les pediste tocar y dejan trabajo a medias.

Unlazier AI es un conjunto de reglas que hace que estos asistentes trabajen con más cuidado. Lo instalas una sola vez y todas las herramientas de IA para programar que uses siguen las mismas reglas en todos tus proyectos.

## Índice

- [Qué obtienes](#qué-obtienes)
- [Herramientas compatibles](#herramientas-compatibles)
- [Instalación](#instalación)
- [Qué cambia en tu computadora](#qué-cambia-en-tu-computadora)
- [Límites de uso y trabajo en paralelo](#límites-de-uso-y-trabajo-en-paralelo)
- [Desinstalación](#desinstalación)
- [Actualizar desde la versión 1](#actualizar-desde-la-versión-1)
- [Notas para cada herramienta](#notas-para-cada-herramienta)
- [Las reglas](#las-reglas)
- [Personalización](#personalización)
- [Para colaboradores](#para-colaboradores)
- [Licencia](#licencia)

## Qué obtienes

Unlazier AI agrega tres capas a cada herramienta. Todas las herramientas reciben las mismas tres capas; lo único que cambia es el lugar donde cada una guarda su configuración.

| Capa | Qué hace | Por qué importa |
|------|----------|-----------------|
| **1. Reglas** | Agrega las reglas al archivo de instrucciones globales de la herramienta, para que el asistente las lea al inicio de cada sesión. | El asistente sabe qué se espera de él desde el primer mensaje. |
| **2. Recordatorio** | Vuelve a enviar un resumen corto de las reglas con cada uno de tus mensajes, y los principios básicos después de que la conversación se compacta. | En sesiones largas, las instrucciones del inicio pierden peso a medida que la conversación crece. El recordatorio las mantiene presentes. |
| **3. Uso** | Agrega al recordatorio una línea que indica cuánto llevas usado de tus límites de 5 horas y semanal. | El asistente puede hacer tareas en paralelo cuando hay margen y bajar el ritmo antes de que llegues a un límite. |

## Herramientas compatibles

| Herramienta | 1. Reglas | 2. Recordatorio | 3. Uso |
|-------------|:---------:|:---------------:|:------:|
| Claude Code | Sí | Sí | Sí, a través de la barra de estado (status line) |
| Codex CLI | Sí | Sí (requiere una aprobación, ver [notas](#codex-cli)) | Sí, leído del registro de sesión del propio Codex |
| Gemini CLI | Sí | Sí | No disponible |
| Devin Desktop (antes Windsurf) | Sí | Sí | No disponible |
| Kiro | Sí | Sí | No disponible |
| Cline | Sí | Sí en Linux y macOS (requiere un ajuste, ver [notas](#cline)) | No disponible |
| OpenCode | Sí | Sí | No disponible |
| Amp | Sí | Sí | No disponible |
| GitHub Copilot CLI | Sí | No disponible | No disponible |

"No disponible" siempre significa que la propia herramienta no ofrece forma de hacerlo: Copilot CLI ignora lo que imprime un hook de prompt, y solo Claude Code y Codex exponen los límites de uso de una forma que un programa pueda leer. Cursor no es compatible porque guarda sus reglas globales en su propia configuración, no en un archivo.

## Instalación

### Linux y macOS

Abre una terminal y ejecuta:

```bash
curl -fsSL https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/install.sh | bash
```

Las capas de recordatorio y de uso necesitan **jq**, una pequeña herramienta para JSON. Si no la tienes, el instalador igual instala las reglas y te muestra el comando exacto para instalar jq en tu sistema (por ejemplo `brew install jq` en macOS o `sudo apt-get install -y jq` en Ubuntu). Instálala y vuelve a ejecutar el instalador.

### Windows

Abre **PowerShell** y ejecuta:

```powershell
irm https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/install.ps1 | iex
```

En Windows no necesitas nada más.

### Cómo elegir tus herramientas

El instalador muestra una lista numerada con todas las herramientas compatibles y marca con `*` las que encontró en tu computadora. El instalador muestra sus mensajes en inglés:

```
Choose the tools to install Unlazier AI for (* = found on this computer):
  1) * Claude Code
  2)   OpenCode
  3) * Codex CLI
  ...
Type numbers separated by spaces, "all", or press Enter for the tools marked with *:
```

Presiona **Enter** para instalar en las herramientas marcadas con `*`, o escribe los números que quieras (por ejemplo `1 3`).

### Sin el menú

Para elegir las herramientas en el mismo comando, algo útil en scripts:

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

Nombres de las herramientas: `claude`, `opencode`, `codex`, `copilot`, `gemini`, `amp`, `kiro`, `cline`, `devin` o `all`. Agrega `--yes` (en Windows: `-Yes`) para responder "sí" automáticamente a las preguntas.

Después de instalar, **reinicia tus herramientas** para que carguen los cambios.

## Qué cambia en tu computadora

El instalador nunca reemplaza tu propia configuración y nunca crea copias de respaldo.

- **Tus archivos siguen siendo tuyos.** Las reglas van dentro de un bloque marcado que empieza con `<!-- unlazier-ai:start -->` y termina con `<!-- unlazier-ai:end -->`. Nada de lo que escribiste fuera de ese bloque se toca. Instalar de nuevo solo actualiza el bloque.
- **A los archivos de configuración se les agrega, no se reemplazan.** Los hooks se agregan junto a los que ya tienes. Un archivo de configuración que no se puede leer de forma segura (por ejemplo, uno con comentarios) queda sin cambios, y el instalador te avisa.
- **Todo lo demás vive en una carpeta por herramienta**, llamada `unlazier-ai`, junto a la configuración de la propia herramienta.

En Windows, `~` significa tu carpeta de usuario (`C:\Users\<tú>`).

| Herramienta | Reglas | Recordatorio | Carpeta |
|-------------|--------|--------------|---------|
| Claude Code | `~/.claude/CLAUDE.md` | hooks en `~/.claude/settings.json`; barra de estado si no tienes una | `~/.claude/unlazier-ai/` |
| Codex CLI | `~/.codex/AGENTS.md` | `~/.codex/hooks.json` | `~/.codex/unlazier-ai/` |
| Gemini CLI | `~/.gemini/GEMINI.md` | hook en `~/.gemini/settings.json` | `~/.gemini/unlazier-ai/` |
| Devin Desktop | `~/.devin/rules/unlazier-ai-principles.md` y `unlazier-ai-rules.md` | hook en `~/.config/devin/config.json` (Windows: `%APPDATA%\devin\config.json`) | `~/.devin/unlazier-ai/` |
| Kiro | `~/.kiro/steering/unlazier-ai.md` | `~/.kiro/hooks/unlazier-ai.json` | `~/.kiro/unlazier-ai/` |
| Cline | `~/Documents/Cline/Rules/unlazier-ai.md` | `~/Documents/Cline/Hooks/UserPromptSubmit` | `~/Documents/Cline/unlazier-ai/` |
| OpenCode | `~/.config/opencode/AGENTS.md` | `~/.config/opencode/plugins/unlazier-ai.ts` | `~/.config/opencode/unlazier-ai/` |
| Amp | `~/.config/amp/AGENTS.md` | `~/.config/amp/plugins/unlazier-ai.ts` | `~/.config/amp/unlazier-ai/` |
| GitHub Copilot CLI | `~/.copilot/copilot-instructions.md` | ninguno | `~/.copilot/unlazier-ai/` |

Si moviste la configuración de una herramienta con su propia variable de entorno (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `COPILOT_HOME`, `GEMINI_CLI_HOME`, `KIRO_HOME`), el instalador usa esa ubicación.

## Límites de uso y trabajo en paralelo

Suscripciones como Claude y ChatGPT limitan cuánto puedes usar en una ventana de 5 horas y en una semana. Unlazier AI le indica al asistente cómo dosificar su ritmo:

| Ventana de 5 horas | Qué hace el asistente |
|--------------------|-----------------------|
| menos de 70% | Hace en paralelo todo el trabajo que puede |
| de 70% a 85% | Hace como máximo 2 tareas a la vez |
| de 85% a 95% | Trabaja en una tarea a la vez, sin agentes auxiliares |
| 95% o más | Termina el paso actual, te avisa y espera |

Cuando la ventana **semanal** llega a 99%, el asistente termina el paso actual, te avisa y espera.

Cuando trabaja en paralelo, prefiere, en este orden: agentes auxiliares para partes de la misma tarea, luego tareas distintas del mismo pedido y luego pedidos distintos.

**De dónde salen los números:**

- **Claude Code** envía el uso solo a la barra de estado (la línea de la parte inferior de la pantalla). Si no tienes una barra de estado, el instalador agrega una que muestra las dos ventanas y las guarda para el recordatorio. Si ya tienes la tuya, se conserva. Para alimentar el recordatorio, haz que tu barra de estado guarde la parte `rate_limits` de lo que Claude Code le envía en `~/.claude/state/rate_limits.json`, con este formato:

    ```json
    {"captured_at": 1794668291, "five_hour": {"used_percentage": 24, "resets_at": 1794683400}, "seven_day": {"used_percentage": 60, "resets_at": 1794978000}}
    ```

    `captured_at` es la hora actual en segundos. Los datos de uso solo están disponibles en los planes de suscripción de Claude, no con una clave de API.
- **Codex CLI** escribe el uso en su propio registro de sesión, y el recordatorio lo lee de ahí. No hay nada que configurar.
- **Las demás herramientas** no exponen el uso, así que el recordatorio dice `Usage: unknown`. En ese caso, el asistente hace como máximo 2 o 3 tareas a la vez y te pregunta antes de hacer más de 5.

Una lectura con más de 15 minutos de antigüedad cuenta como desconocida.

## Desinstalación

Linux y macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/uninstall.sh | bash
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/fco3lho/unlazier-ai/main/uninstall.ps1 | iex
```

El desinstalador muestra el mismo menú y elimina solo lo que agregó Unlazier AI: los bloques marcados, sus hooks, sus plugins, su barra de estado (solo si es la que instaló Unlazier AI) y las carpetas `unlazier-ai`. Un archivo que queda vacío después de quitar el bloque se elimina. Tu propia configuración, tu historial y tus credenciales se quedan donde están.

## Actualizar desde la versión 1

La versión 1 copiaba sus archivos encima de tu configuración en `~/.claude` y `~/.config/opencode`. Cuando instalas la versión 2, el instalador busca esos archivos antiguos, te los muestra y pregunta antes de eliminarlos. Los archivos antiguos de reglas y de skills solo se ofrecen para eliminar si están exactamente como los dejó la versión 1; un archivo que editaste se conserva.

El antiguo `~/.claude/CLAUDE.md` (o `~/.config/opencode/AGENTS.md`) se reconoce por su primera línea, `# Global Agent Rules`. Si le agregaste tus propias notas después de instalar la versión 1, responde **no** y primero saca tus notas de ahí: la versión 1 reemplazaba ese archivo completo, así que el instalador no puede distinguir tus notas de las reglas antiguas.

> **No ejecutes el desinstalador de la versión 1.** Borraba las carpetas `~/.claude` y `~/.config/opencode` completas, incluidas tu configuración y tus credenciales. El desinstalador de la versión 2 elimina solo lo que agregó Unlazier AI.

## Notas para cada herramienta

### Claude Code

Claude Code te pide confiar en una carpeta antes de ejecutar hooks en ella; el recordatorio empieza a funcionar después de que aceptas. Los datos de uso requieren una suscripción de Claude y una barra de estado (ver [Límites de uso](#límites-de-uso-y-trabajo-en-paralelo)).

### Codex CLI

Codex ejecuta un hook nuevo solo después de que lo apruebas. Abre Codex, escribe `/hooks` y aprueba una vez los dos hooks de Unlazier AI. Si existe un archivo llamado `AGENTS.override.md` en `~/.codex`, Codex ignora `AGENTS.md`, y el instalador te avisa. Por defecto, Codex lee como máximo 32 KiB de instrucciones en total; las reglas de Unlazier AI ocupan unos 18 KiB, así que instrucciones de proyecto muy largas pueden quedar recortadas. Puedes subir el límite con `project_doc_max_bytes` en `~/.codex/config.toml`.

### Gemini CLI

Gemini vuelve a enviar su archivo de instrucciones con cada mensaje, así que no necesita ningún paso extra después de la compactación. El 18 de junio de 2026, Google reemplazó Gemini CLI por Antigravity CLI para los usuarios gratuitos y de Google One; Antigravity CLI todavía no es compatible.

### Devin Desktop (antes Windsurf)

Devin limita cada archivo de reglas a 12.000 caracteres, por eso las reglas se dividen en dos archivos. Devin también ejecuta los hooks que encuentra en `~/.claude/settings.json`; desactivar eso también desactivaría tus reglas de Claude Code dentro de Devin, así que Unlazier AI lo deja como está. Devin no documenta ninguna forma de agregar texto después de la compactación, así que solo se usa el recordatorio de cada mensaje.

### Kiro

El recordatorio después de la compactación requiere Kiro CLI 3.1.0 o posterior.

### Cline

Los hooks vienen desactivados. Activa **Enable Hooks** en la sección Feature Settings de Cline. Cline solo admite hooks en Linux y macOS, así que en Windows Cline recibe las reglas sin el recordatorio.

### OpenCode

El plugin funciona con OpenCode 1.18.29 o posterior, incluida la versión 2. OpenCode vuelve a cargar sus archivos de instrucciones por su cuenta después de la compactación. Una vez que existe `~/.config/opencode/AGENTS.md`, OpenCode deja de leer `~/.claude/CLAUDE.md` como alternativa; el instalador te avisa cuando esto aplica.

### Amp

El plugin se carga en los hilos nuevos. En un hilo que ya está abierto, recarga los plugins con `Ctrl+O` y luego `plugins: reload`.

### GitHub Copilot CLI

Copilot ignora lo que imprime un hook de prompt, así que recibe las reglas sin el recordatorio. La extensión de Copilot para VS Code también puede leer `~/.claude/CLAUDE.md` cuando su ajuste `chat.useClaudeMdFile` está activado, lo que cargaría las reglas dos veces si usas ambas.

## Las reglas

Los principios de [`AGENTS.md`](AGENTS.md) definen cómo trabaja el asistente (los nombres originales en inglés van entre paréntesis):

1. **Pensar antes de programar** (Think Before Coding): explicitar las suposiciones y preguntar cuando algo no está claro (una pregunta a la vez, con una respuesta recomendada).
2. **La simplicidad primero** (Simplicity First): el cambio más pequeño que resuelve el problema, sin abstracciones especulativas.
3. **Cambios quirúrgicos** (Surgical Changes): tocar solo lo que el pedido necesita y respetar el estilo existente.
4. **Ejecución guiada por objetivos** (Goal-Driven Execution): definir cómo se comprueba el éxito y verificar antes de dar algo por terminado.
5. **Mensajes de commit** (Commit Messages): seguir el formato Conventional Commits.
6. **Comunicación breve** (Communication Brevity): respuestas cortas y directas, sin relleno.

> **Atribución:** Los cuatro primeros principios provienen de las [observaciones de Andrej Karpathy](https://x.com/karpathy/status/2015883857489522876) sobre los errores típicos de los LLM al programar, popularizadas por el repositorio [andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills).

Las reglas por tema en [`rules/`](rules/) agregan detalle, cada una con un ejemplo malo y uno bueno:

| Regla | Enfoque |
|-------|---------|
| [`structure.md`](rules/structure.md) | Código legible, una responsabilidad por función, funciones pequeñas |
| [`correctness.md`](rules/correctness.md) | Manejo de errores, casos límite, seguridad |
| [`style.md`](rules/style.md) | Formato, consistencia, tono profesional |
| [`completeness.md`](rules/completeness.md) | Sin marcadores pendientes, código muerto ni restos de depuración |
| [`performance.md`](rules/performance.md) | Evitar consultas y cálculos innecesarios |
| [`testability.md`](rules/testability.md) | Código fácil de probar, pruebas que verifican el comportamiento |
| [`async.md`](rules/async.md) | Manejo del trabajo asíncrono y la liberación de recursos |
| [`naming.md`](rules/naming.md) | Nombres claros que siguen las convenciones de cada lenguaje |
| [`documentation.md`](rules/documentation.md) | Comentarios que explican el porqué, más instrucciones para ejecutar |
| [`parallelism.md`](rules/parallelism.md) | Dosificar el trabajo en paralelo según los límites de uso |

El recordatorio que se envía con cada mensaje está en [`reminder.md`](reminder.md).

## Personalización

- **Tus propias reglas globales:** escríbelas en el mismo archivo que el bloque de Unlazier AI, fuera de los marcadores. Se mantienen en las actualizaciones y en las desinstalaciones.
- **Cambiar las reglas de Unlazier AI:** edita los archivos en una copia de este repositorio y ejecuta `./install.sh` (o `.\install.ps1`) desde esa copia. Los cambios hechos directamente dentro del bloque instalado se reemplazan en la siguiente instalación.
- **Reglas del proyecto:** cada herramienta también lee instrucciones de la carpeta de tu proyecto (por ejemplo `AGENTS.md` o `CLAUDE.md`); esas se aplican además de las reglas globales.

## Para colaboradores

Estructura del repositorio:

| Ruta | Propósito |
|------|-----------|
| `AGENTS.md`, `rules/` | Las reglas (capa 1). `CLAUDE.md` es un enlace a `AGENTS.md`. |
| `reminder.md` | El recordatorio corto (capa 2). |
| `hooks/inject.sh`, `hooks/inject.ps1` | Imprimen el recordatorio y la línea de uso (capas 2 y 3) en el formato que espera cada herramienta. |
| `statusline/` | Barra de estado de Claude Code que guarda el uso para el recordatorio. |
| `plugins/` | Plugins de OpenCode y Amp, que llaman al mismo script del hook. |
| `install.sh`, `install.ps1` | Instaladores; cada herramienta es un adaptador dentro de una sola tabla. Los `uninstall.*` los llaman en modo de desinstalación. |
| `tests/` | Pruebas del instalador y del hook; `tests/fixtures/v1/` contiene archivos de la versión 1 para las pruebas de actualización. |

Ejecuta las pruebas:

```bash
bash tests/install_test.sh        # Linux and macOS, needs jq
```

```powershell
./tests/install_test.ps1          # Windows PowerShell 5.1 or PowerShell 7
```

Las pruebas usan una carpeta personal temporal y nunca tocan tu configuración real. GitHub Actions las ejecuta en Ubuntu, macOS y Windows, además de `shellcheck` sobre los scripts de shell.

El [`README.md`](README.md) en inglés es la versión oficial. Este archivo y [`README.pt-BR.md`](README.pt-BR.md) son traducciones de él; quien cambie el README en inglés debe actualizarlos en el mismo cambio.

## Licencia

MIT
