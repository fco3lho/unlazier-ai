<p align="center">
  <img src="docs/images/sloth.png" alt="Sloth" width="250">
</p>

# <p align="center">Unlazier</p>

<p align="center">
  <a href="README.md">English</a> | <a href="README.pt-BR.md">Português (Brasil)</a> | <b>Español</b>
</p>

> Esta es una traducción del [README en inglés](README.md), que es la versión oficial y puede estar más actualizada.

Los asistentes de IA para programar son muy capaces, pero a menudo toman atajos. Adivinan lo que quisiste decir en lugar de preguntar, escriben más código del necesario, cambian cosas que no les pediste tocar y dejan trabajo a medias.

Unlazier es un conjunto de reglas que hace que estos asistentes trabajen con más cuidado. Lo instalas una sola vez y todas las herramientas de IA para programar que uses siguen las mismas reglas en todos tus proyectos.

## Índice

- [Qué obtienes](#qué-obtienes)
- [Herramientas compatibles](#herramientas-compatibles)
- [Instalación](#instalación)
- [Qué cambia en tu computadora](#qué-cambia-en-tu-computadora)
- [Límites de uso y trabajo en paralelo](#límites-de-uso-y-trabajo-en-paralelo)
- [Alertas sonoras](#alertas-sonoras)
- [Desinstalación](#desinstalación)
- [Actualizar desde la versión 1](#actualizar-desde-la-versión-1)
- [Notas para cada herramienta](#notas-para-cada-herramienta)
- [Las reglas](#las-reglas)
- [Personalización](#personalización)
- [Para colaboradores](#para-colaboradores)
- [Licencia](#licencia)

## Qué obtienes

Unlazier agrega cuatro capas a cada herramienta. Todas las herramientas reciben las mismas cuatro capas; lo único que cambia es el lugar donde cada una guarda su configuración.

| Capa | Qué hace | Por qué importa |
|------|----------|-----------------|
| **1. Reglas** | Agrega las reglas a la carpeta de reglas de la herramienta, un archivo pequeño por regla, o a su archivo de instrucciones globales cuando la herramienta no tiene carpeta de reglas. El asistente las lee al inicio de cada sesión. | El asistente sabe qué se espera de él desde el primer mensaje. |
| **2. Recordatorio** | Vuelve a enviar un resumen corto de las reglas con cada uno de tus mensajes, y los principios básicos después de que la conversación se compacta. | En sesiones largas, las instrucciones del inicio pierden peso a medida que la conversación crece. El recordatorio las mantiene presentes. |
| **3. Uso** | Agrega al recordatorio una línea que indica cuánto llevas usado de tus límites de 5 horas y semanal. | El asistente puede hacer tareas en paralelo cuando hay margen y bajar el ritmo antes de que llegues a un límite. |
| **4. Alertas** | Hace sonar tres pitidos cortos cuando el asistente pide tu permiso, te hace una pregunta o termina su turno. | Puedes hacer otra cosa mientras trabaja y volver cuando te necesite. |

## Herramientas compatibles

| Herramienta | 1. Reglas | 2. Recordatorio | 3. Uso | 4. Alertas |
|-------------|:---------:|:---------------:|:------:|:----------:|
| Claude Code | Sí | Sí | Sí, a través de la barra de estado (status line) | Sí |
| Codex CLI | Sí | Sí (requiere una aprobación, ver [notas](#codex-cli)) | Sí, leído del registro de sesión del propio Codex | Sí (misma aprobación) |
| Gemini CLI | Sí | Sí | No disponible | Sí |
| Devin Desktop (antes Windsurf) | Sí | Sí | No disponible | Sí |
| Kiro | Sí | Sí | No disponible | Solo al final del turno |
| Cline | Sí | Sí en Linux y macOS (requiere un ajuste, ver [notas](#cline)) | No disponible | Preguntas y final de la tarea, en Linux y macOS |
| OpenCode | Sí | Sí | No disponible | Sí |
| Amp | Sí | Sí | No disponible | Solo al final del turno |
| GitHub Copilot CLI | Sí | No disponible | No disponible | Sí |

"No disponible" o una entrada parcial siempre significa que la propia herramienta no ofrece forma de hacerlo: Copilot CLI ignora lo que imprime un hook de prompt, solo Claude Code y Codex exponen los límites de uso de una forma que un programa pueda leer, Kiro y Amp solo avisan el final del turno, y Cline no avisa las solicitudes de permiso. Cursor no es compatible porque guarda sus reglas globales en su propia configuración, no en un archivo.

## Instalación

### Linux y macOS

Abre una terminal y ejecuta:

```bash
curl -fsSL https://raw.githubusercontent.com/fco3lho/unlazier/main/install.sh | bash
```

Las capas de recordatorio y de uso necesitan **jq**, una pequeña herramienta para JSON. Si no la tienes, el instalador igual instala las reglas y te muestra el comando exacto para instalar jq en tu sistema (por ejemplo `brew install jq` en macOS o `sudo apt-get install -y jq` en Ubuntu). Instálala y vuelve a ejecutar el instalador.

### Windows

Abre **PowerShell** y ejecuta:

```powershell
irm https://raw.githubusercontent.com/fco3lho/unlazier/main/install.ps1 | iex
```

En Windows no necesitas nada más.

### Cómo elegir tus herramientas

El instalador muestra una lista numerada con todas las herramientas compatibles y marca con `*` las que encontró en tu computadora. El instalador muestra sus mensajes en inglés:

```
Choose the tools to install Unlazier for (* = found on this computer):
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
curl -fsSL https://raw.githubusercontent.com/fco3lho/unlazier/main/install.sh | bash -s -- --harness claude,codex
```

```powershell
# Windows
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/fco3lho/unlazier/main/install.ps1))) -Harness claude,codex
```

Nombres de las herramientas: `claude`, `opencode`, `codex`, `copilot`, `gemini`, `amp`, `kiro`, `cline`, `devin` o `all`. Agrega `--yes` (en Windows: `-Yes`) para responder "sí" automáticamente a las preguntas.

Después de instalar, **reinicia tus herramientas** para que carguen los cambios.

## Qué cambia en tu computadora

El instalador nunca reemplaza tu propia configuración y nunca crea copias de respaldo.

- **Tus archivos siguen siendo tuyos.** Las herramientas que leen una carpeta de reglas (Claude Code, Devin, Kiro, Cline) reciben archivos propios en ella, todos con el nombre `unlazier-*.md`, y tu archivo de instrucciones no se toca. Las demás herramientas leen un único archivo de instrucciones, así que las reglas van dentro de un bloque marcado que empieza con `<!-- unlazier:start -->` y termina con `<!-- unlazier:end -->`; nada de lo que escribiste fuera de ese bloque se toca. Instalar de nuevo solo actualiza esos archivos y bloques.
- **A los archivos de configuración se les agrega, no se reemplazan.** Los hooks se agregan junto a los que ya tienes. Un archivo de configuración que no se puede leer de forma segura (por ejemplo, uno con comentarios) queda sin cambios, y el instalador te avisa.
- **Todo lo demás vive en una carpeta por herramienta**, llamada `unlazier`, junto a la configuración de la propia herramienta.

En Windows, `~` significa tu carpeta de usuario (`C:\Users\<tú>`).

| Herramienta | Reglas | Recordatorio y alertas | Carpeta |
|-------------|--------|--------------|---------|
| Claude Code | `~/.claude/rules/unlazier-*.md` | hooks en `~/.claude/settings.json`; barra de estado si no tienes una | `~/.claude/unlazier/` |
| Codex CLI | `~/.codex/AGENTS.md` | `~/.codex/hooks.json` | `~/.codex/unlazier/` |
| Gemini CLI | `~/.gemini/GEMINI.md` | hook en `~/.gemini/settings.json` | `~/.gemini/unlazier/` |
| Devin Desktop | `~/.devin/rules/unlazier-*.md` | hook en `~/.config/devin/config.json` (Windows: `%APPDATA%\devin\config.json`) | `~/.devin/unlazier/` |
| Kiro | `~/.kiro/steering/unlazier-*.md` | `~/.kiro/hooks/unlazier.json` y `unlazier-alert.json` | `~/.kiro/unlazier/` |
| Cline | `~/Documents/Cline/Rules/unlazier-*.md` | `UserPromptSubmit`, `PreToolUse` y `TaskComplete` en `~/Documents/Cline/Hooks/` | `~/Documents/Cline/unlazier/` |
| OpenCode | `~/.config/opencode/AGENTS.md` | `~/.config/opencode/plugins/unlazier.ts` | `~/.config/opencode/unlazier/` |
| Amp | `~/.config/amp/AGENTS.md` | `~/.config/amp/plugins/unlazier.ts` | `~/.config/amp/unlazier/` |
| GitHub Copilot CLI | `~/.copilot/copilot-instructions.md` | `~/.copilot/hooks/unlazier.json` (solo alertas) | `~/.copilot/unlazier/` |

Si moviste la configuración de una herramienta con su propia variable de entorno (`CLAUDE_CONFIG_DIR`, `CODEX_HOME`, `COPILOT_HOME`, `GEMINI_CLI_HOME`, `KIRO_HOME`), el instalador usa esa ubicación.

## Límites de uso y trabajo en paralelo

Suscripciones como Claude y ChatGPT limitan cuánto puedes usar en una ventana de 5 horas y en una semana. Unlazier le indica al asistente cómo dosificar su ritmo:

| Ventana de 5 horas | Qué hace el asistente |
|--------------------|-----------------------|
| menos de 70% | Hace en paralelo todo el trabajo que puede |
| de 70% a 85% | Hace como máximo 2 tareas a la vez |
| de 85% a 95% | Trabaja en una tarea a la vez, sin agentes auxiliares |
| 95% o más | Detiene los agentes auxiliares en curso, espera en segundo plano a que la ventana se reinicie y retoma el trabajo por su cuenta |

Cuando la ventana **semanal** llega a 99%, el asistente termina el paso actual, te avisa y espera.

En **Claude Code**, la espera al 95% es un script que Unlazier instala (`~/.claude/unlazier/wait-usage.sh`, o `wait-usage.ps1` en Windows). Lee el uso guardado y termina cuando la ventana se reinicia, lo que despierta al asistente. Las demás herramientas no se despiertan con una tarea en segundo plano, así que terminan el paso actual, te avisan y esperan.

Cuando trabaja en paralelo, prefiere, en este orden: agentes auxiliares para partes de la misma tarea, luego tareas distintas del mismo pedido y luego pedidos distintos.

**De dónde salen los números:**

- **Claude Code** envía el uso solo a la barra de estado (la línea de la parte inferior de la pantalla). Si no tienes una barra de estado, el instalador agrega una que muestra las dos ventanas y las guarda para el recordatorio. Se actualiza cada minuto, no solo cuando envías un mensaje:

    ```
    Session 5h: [██░░░░░░░░] 24% · resets in 2h 2m
    Weekly    : [████░░░░░░] 38% · resets in 3d 11h 30m
    ```

    Si ya tienes la tuya, se conserva. Para alimentar el recordatorio, haz que tu barra de estado guarde la parte `rate_limits` de lo que Claude Code le envía en `~/.claude/state/rate_limits.json`, con este formato:

    ```json
    {"captured_at": 1794668291, "five_hour": {"used_percentage": 24, "resets_at": 1794683400}, "seven_day": {"used_percentage": 60, "resets_at": 1794978000}}
    ```

    `captured_at` es la hora actual en segundos. Los datos de uso solo están disponibles en los planes de suscripción de Claude, no con una clave de API.
- **Codex CLI** escribe el uso en su propio registro de sesión, y el recordatorio lo lee de ahí. No hay nada que configurar.
- **Las demás herramientas** no exponen el uso, así que el recordatorio dice `Usage: unknown`. En ese caso, el asistente hace como máximo 2 o 3 tareas a la vez y te pregunta antes de hacer más de 5.

Una lectura con más de 15 minutos de antigüedad cuenta como desconocida.

## Alertas sonoras

Unlazier hace sonar tres pitidos cortos cuando el asistente te necesita: cuando pide permiso para hacer algo, cuando te hace una pregunta y cuando termina su turno. Puedes ocuparte de otra cosa y volver cuando lo escuches.

- **Windows y WSL:** el pitido sale de Windows.
- **macOS:** el sonido del sistema "Tink".
- **Linux:** el sonido "button pressed" del escritorio, o la campana de la terminal cuando no hay reproductor de sonido.

Algunas herramientas avisan en menos momentos; mira la columna Alertas en [Herramientas compatibles](#herramientas-compatibles).

## Desinstalación

Linux y macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/fco3lho/unlazier/main/uninstall.sh | bash
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/fco3lho/unlazier/main/uninstall.ps1 | iex
```

El desinstalador muestra el mismo menú y elimina solo lo que agregó Unlazier: los archivos de reglas `unlazier-*.md`, los bloques marcados, sus hooks, sus plugins, su barra de estado (solo si es la que instaló Unlazier) y las carpetas `unlazier`. Un archivo que queda vacío después de quitar el bloque se elimina. Tu propia configuración, tu historial y tus credenciales se quedan donde están.

## Actualizar desde la versión 1

La versión 1 copiaba sus archivos encima de tu configuración en `~/.claude` y `~/.config/opencode`. Cuando instalas la versión 2, el instalador busca esos archivos antiguos, te los muestra y pregunta antes de eliminarlos. Los archivos antiguos de reglas y de skills solo se ofrecen para eliminar si están exactamente como los dejó la versión 1; un archivo que editaste se conserva.

El antiguo `~/.claude/CLAUDE.md` (o `~/.config/opencode/AGENTS.md`) se reconoce por su primera línea, `# Global Agent Rules`. Si le agregaste tus propias notas después de instalar la versión 1, responde **no** y primero saca tus notas de ahí: la versión 1 reemplazaba ese archivo completo, así que el instalador no puede distinguir tus notas de las reglas antiguas.

La versión 2.0 se llamaba Unlazier AI y usaba `unlazier-ai` en los nombres de archivos y carpetas. Instalar de nuevo los elimina y escribe los nuevos nombres `unlazier` en su lugar.

> **No ejecutes el desinstalador de la versión 1.** Borraba las carpetas `~/.claude` y `~/.config/opencode` completas, incluidas tu configuración y tus credenciales. El desinstalador de la versión 2 elimina solo lo que agregó Unlazier.

## Notas para cada herramienta

### Claude Code

Las reglas van a `~/.claude/rules/` y no a `~/.claude/CLAUDE.md`: Anthropic recomienda mantener cada CLAUDE.md por debajo de 200 líneas, y cada archivo de regla cuenta como un archivo separado y corto. Las reglas de esa carpeta se cargan al inicio de cada sesión, igual que CLAUDE.md. La versión 2.0 ponía las reglas en un bloque dentro de CLAUDE.md; instalar de nuevo las mueve y quita ese bloque.

Claude Code te pide confiar en una carpeta antes de ejecutar hooks en ella; el recordatorio empieza a funcionar después de que aceptas. Los datos de uso requieren una suscripción de Claude y una barra de estado (ver [Límites de uso](#límites-de-uso-y-trabajo-en-paralelo)).

### Codex CLI

Codex ejecuta un hook nuevo solo después de que lo apruebas. Abre Codex, escribe `/hooks` y aprueba una vez los hooks de Unlazier. Si existe un archivo llamado `AGENTS.override.md` en `~/.codex`, Codex ignora `AGENTS.md`, y el instalador te avisa. Por defecto, Codex lee como máximo 32 KiB de instrucciones en total; las reglas de Unlazier ocupan unos 18 KiB, así que instrucciones de proyecto muy largas pueden quedar recortadas. Puedes subir el límite con `project_doc_max_bytes` en `~/.codex/config.toml`.

### Gemini CLI

Gemini vuelve a enviar su archivo de instrucciones con cada mensaje, así que no necesita ningún paso extra después de la compactación. El 18 de junio de 2026, Google reemplazó Gemini CLI por Antigravity CLI para los usuarios gratuitos y de Google One; Antigravity CLI todavía no es compatible.

### Devin Desktop (antes Windsurf)

Devin limita cada archivo de reglas a 12.000 caracteres; cada archivo de regla de Unlazier queda muy por debajo de eso. Devin también ejecuta los hooks que encuentra en `~/.claude/settings.json`; desactivar eso también desactivaría tus reglas de Claude Code dentro de Devin, así que Unlazier lo deja como está. Con ambas herramientas instaladas, puedes oír el pitido de final de turno dos veces en Devin. Devin no documenta ninguna forma de agregar texto después de la compactación, así que solo se usa el recordatorio de cada mensaje.

### Kiro

El recordatorio después de la compactación requiere Kiro CLI 3.1.0 o posterior. Kiro no ofrece eventos para solicitudes de permiso ni para preguntas, así que solo suena al final del turno.

### Cline

Los hooks vienen desactivados. Activa **Enable Hooks** en la sección Feature Settings de Cline. Cline solo admite hooks en Linux y macOS, así que en Windows Cline recibe las reglas sin el recordatorio ni las alertas. Cline no pasa las solicitudes de permiso a los hooks, así que suena con las preguntas y al final de la tarea.

### OpenCode

El plugin funciona con OpenCode 1.18.29 o posterior, incluida la versión 2. OpenCode vuelve a cargar sus archivos de instrucciones por su cuenta después de la compactación. Una vez que existe `~/.config/opencode/AGENTS.md`, OpenCode deja de leer `~/.claude/CLAUDE.md` como alternativa; el instalador te avisa cuando esto aplica.

### Amp

El plugin se carga en los hilos nuevos. En un hilo que ya está abierto, recarga los plugins con `Ctrl+O` y luego `plugins: reload`. Amp no ofrece eventos para solicitudes de permiso ni para preguntas, así que solo suena al final del turno.

### GitHub Copilot CLI

Copilot ignora lo que imprime un hook de prompt, así que recibe las reglas y las alertas sin el recordatorio. La extensión de Copilot para VS Code también puede leer `~/.claude/CLAUDE.md` cuando su ajuste `chat.useClaudeMdFile` está activado, lo que cargaría las reglas dos veces si usas ambas.

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

- **Tus propias reglas globales:** escríbelas en el archivo de instrucciones de tu herramienta (por ejemplo `~/.claude/CLAUDE.md`), fuera de cualquier bloque de Unlazier, o en tus propios archivos dentro de la carpeta de reglas con nombres que no empiecen con `unlazier`. Se mantienen en las actualizaciones y en las desinstalaciones.
- **Cambiar las reglas de Unlazier:** edita los archivos en una copia de este repositorio y ejecuta `./install.sh` (o `.\install.ps1`) desde esa copia. Los cambios hechos directamente en los archivos `unlazier-*.md` instalados o dentro del bloque instalado se reemplazan en la siguiente instalación.
- **Reglas del proyecto:** cada herramienta también lee instrucciones de la carpeta de tu proyecto (por ejemplo `AGENTS.md` o `CLAUDE.md`); esas se aplican además de las reglas globales.

## Para colaboradores

Estructura del repositorio:

| Ruta | Propósito |
|------|-----------|
| `AGENTS.md`, `rules/` | Las reglas (capa 1). `CLAUDE.md` es un enlace a `AGENTS.md`. |
| `reminder.md` | El recordatorio corto (capa 2). |
| `hooks/inject.sh`, `hooks/inject.ps1` | Imprimen el recordatorio y la línea de uso (capas 2 y 3) en el formato que espera cada herramienta. |
| `hooks/alert.sh`, `hooks/alert.ps1` | Hacen sonar los pitidos de alerta (capa 4). |
| `hooks/wait-usage.sh`, `hooks/wait-usage.ps1` | Esperan en segundo plano a que una ventana de uso se reinicie o llegue a un límite; instalados solo para Claude Code. |
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
