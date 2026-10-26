# Dotfiles

Personlig Pi-, Neovim- och shell-konfiguration, hanterad med Git och GNU Stow.
Bara uttryckligt valda konfigurationer ingår; hemkatalogen är inte ett Git-repo.

## Struktur

```text
pi/.pi/agent/
  agents/
  extensions/
  prompts/
  skills/
  settings.json
pi/.local/bin/pi
nvim/.config/nvim/
shell/
  .profile, .shrc
  .zprofile, .zshrc, .zshenv
  .bash_profile, .bashrc, .bash_logout
  .inputrc, .node-version
  secret-env.sh
  .config/starship.toml
```

Katalogerna `pi`, `nvim` och `shell` är Stow-paket. Filernas sökvägar
inuti paketet motsvarar sökvägar under hemkatalogen. `tests/` innehåller
regressionstester och ska inte länkas med Stow.

`.stowrc` anger hemkatalogen som mål och använder `--no-folding`. Därför
förblir katalogerna under hemkatalogen riktiga kataloger,
med symboliska länkar till de enskilda konfigurationsfilerna i detta repo.
Det hindrar lokalt körningstillstånd från att hamna här genom en länkad
hel katalog. Kör Stow-kommandona nedan från repots rot.

Paketens `.stow-local-ignore` håller hemligheter och beroenden utanför
länkningen. Till skillnad från Stows standardregler tillåter de att
konfigurationens egna `.gitignore`-filer länkas. Git och Stow har separata
ignoreringsregler.

## Installera på en annan dator

Installera Git och GNU Stow samt Pi, Neovim och deras beroenden separat.
På Debian/Ubuntu finns Stow via `sudo apt install stow`.

Efter att repot publicerats på GitHub:

```bash
mkdir -p ~/source
git clone git@github.com:DITT_NAMN/dotfiles.git ~/source/dotfiles
cd ~/source/dotfiles
stow --simulate --verbose pi nvim shell
stow pi nvim shell
```

Ersätt `DITT_NAMN` med rätt GitHub-användare. Förhandsgranska alltid först.
Om befintliga filer ger konflikter: jämför dem och säkerhetskopiera/flytta
undan dem innan du länkar. Använd inte `--adopt` eller tvingande
överskrivning utan att först kontrollera vilken version som ska bevaras.

Pi-inloggningen görs lokalt på varje dator. Modellvalen i `settings.json`
förutsätter tillgång till de konfigurerade modellerna.

## Shell och Node

`.profile` innehåller gemensam miljö och idempotenta PATH-hjälpare.
Interaktiva Bash- och Zsh-sessioner läser samma `.shrc` för alias,
funktioner och fnm. Login-Bash läser även `.bashrc`. Cargo-initieringen
är villkorlig och sker en gång per normalt shell-startförlopp; `.zshenv`
behåller Rust-stödet även för icke-interaktiv Zsh.

fnm använder `--use-on-cd --version-file-strategy recursive` och söker
både `.node-version` och `.nvmrc` uppåt från aktuell katalog. I Bash sker
versionsbytet inför nästa prompt, i Zsh vid katalogbyte. `engines.node`
i `package.json` används inte (`--resolve-engines=false`), och inga
Node-versioner installeras automatiskt av shell-konfigurationen.

```bash
fnm install v26
fnm default v26
```

Ett projekts egna versionsfil får styra dess Node-version. Standardvalet
ovan är ett bevarat personligt val, inte ett automatiskt uppdaterat LTS-val.

Gemensamma hjälpare:

- `up [n]`: gå upp `n` kataloger, normalt en. Noll gör ingenting;
  negativa eller ogiltiga argument avvisas.
- `jwt-decode TOKEN`: avkoda base64url-header och claims med `jq`.
  Signaturen verifieras **inte**.
- `secret_env VARIABELNAMN`: mata in ett miljövärde utan synlig inmatning.
  `secret-env.sh` är bara programkod och kan versionshanteras; inga
  inmatade värden sparas i filen. I Zsh måste eventuell kommandospårning
  först stängas av med `set +x`, eftersom Zsh återställer spårningsläget
  efter funktionsanrop. Bash-helpern stänger själv av spårningen.

### Pi launcher

`pi/.local/bin/pi` startar Pi med dess egen Node-installation, utan att
ändra projektets PATH eller Node-version. Shell-konfigurationen placerar
`~/.local/bin` före fnm:s binärer så att denna launcher används även om
en projektversion av Node också har Pi installerat.

Standardinstallationen är:

```text
${FNM_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/fnm}/aliases/default
```

Det är fnm:s default-alias (en symlänk till vald Node-version), så launchern
följer `fnm default <version>` utan att versionen är hårdkodad. Pi måste vara
installerat i den Node-versionen. På en ny dator:

```bash
fnm install <version> && fnm default <version>
fnm exec --using=default npm install --global --ignore-scripts @earendil-works/pi-coding-agent
```

För en annan installation: sätt `PI_NODE_HOME` till dess `installation`-
katalog, som ska innehålla `bin/node` och `bin/pi`. Detta är en inställning
för dotfiles-launchern, inte en inbyggd Pi-inställning. Om installationen
saknas får du ett felmeddelande; launchern faller inte tyst tillbaka till
projektets Node-version.

Efter ändringar i shell-filerna: öppna en ny terminal/session. Undvik att
återläsa den gamla och nya fnm-initieringen upprepade gånger i samma shell.

## Ändra konfiguration

Befintliga länkade filer kan redigeras via sina vanliga sökvägar, till
exempel `~/.pi/agent/prompts/review.md` eller `~/.config/nvim/init.lua`.
Ändringarna hamnar i repot.

Skapa nya filer direkt under motsvarande paket i repot och kör sedan:

```bash
cd ~/source/dotfiles
stow --simulate --verbose --restow pi nvim shell
stow --restow pi nvim shell
git status --short
git diff
```

En ny fil som skapas direkt i en målkatalog blir inte automatiskt en del
av repot. Om en app ersätter en symbolisk länk med en vanlig fil behöver
du jämföra och ta tillvara ändringen innan du länkar på nytt.

Efter ändringar i ORC:s `taskmaster.md`: kör `/orc on` igen i Pi för att
läsa in instruktionen. Agentdefinitionerna läses vid nästa agentanrop.
För övriga Pi-resurser kan `/reload` behövas; aktivera ORC igen efter reload.

Granska alltid filer och diff innan du lägger till, committar och pushar.
Ett privat GitHub-repo är ingen anledning att versionshantera hemligheter.

## Vad som inte ingår

- `~/.ssh`.
- Pi:s `auth.json`, `sessions/`, `models-store.json`, `trust.json`,
  `models.json`, `npm/` och `bin/`.
- `.env`-filer och installerade `node_modules`.
- Shellhistorik, `.zcompdump*` och annat genererat shell-tillstånd.
- Installerade verktyg under exempelvis `.cargo`, fnm och `.opencode`.
- Neovims data, plugininstallationer och cache utanför `~/.config/nvim`.
- Neovim-konfigurationens tidigare `.git`-katalog.

Pi-katalogen har en tillåtelselista i `.gitignore`: bara `agents`,
`extensions`, `prompts`, `skills` och `settings.json` kan läggas till
normalt. Ändra även paketets Stow-regler om fler Pi-resurser ska ingå.
Ignoreringsregler ersätter inte granskning av innehållet i tillåtna filer.

## Kontroller

Från repots rot:

```bash
stow --simulate --verbose pi nvim shell
python3 tests/shell_test.py
fnm exec --using=default node --test pi/.pi/agent/extensions/orc/index.test.mjs \
  pi/.pi/agent/extensions/subagent/index.test.mjs \
  pi/.pi/agent/extensions/subagent/runner.test.mjs
```

Shelltesterna kräver Python 3, Bash, Zsh och jq. De kör i temporära
hemkataloger med stubbar för verktygsinitiering och påhittade inmatningsvärden;
de läser inte in användarens verkliga startup-filer eller hemligheter.
De kontrollerar login/icke-login, hjälpfunktionerna, PATH och Pi-launchern.

Pi-testerna körs med Pi-installationens Node-version så att både rätt
runtime och den installerade Pi-modulen hittas, oberoende av projektets Node-val.
Neovims dokumentation och tester finns under `nvim/.config/nvim/`.

## Koppla bort länkarna

```bash
cd ~/source/dotfiles
stow --simulate --verbose --delete pi nvim shell
stow --delete pi nvim shell
```

Det tar bort de Stow-hanterade länkarna, inte filerna i repot eller
lokalt tillstånd som Pi-inloggning och sessionshistorik. Återställ egna
säkerhetskopior separat om den tidigare konfigurationen ska användas.

Vid den första migreringen sparades originalkonfigurationen utanför
repot i en katalog med namnet `~/dotfiles-backup.*`. Neovim-backupen
innehåller även dess tidigare Git-repo och lokala ändringar.
Shell-migreringen har en separat backup under `~/dotfiles-shell-backup.*`.
