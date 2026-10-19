# Dotfiles

Personlig Pi- och Neovim-konfiguration, hanterad med Git och GNU Stow.
Bara uttryckligt valda konfigurationer ingår; hemkatalogen är inte ett Git-repo.

## Struktur

```text
pi/.pi/agent/
  agents/
  extensions/
  prompts/
  skills/
  settings.json
nvim/.config/nvim/
```

Varje toppnivåkatalog (`pi`, `nvim`) är ett Stow-paket. Filernas sökvägar
inuti paketet motsvarar sökvägar under hemkatalogen.

`.stowrc` anger hemkatalogen som mål och använder `--no-folding`. Därför
blir katalogerna under `~/.pi` och `~/.config/nvim` riktiga kataloger,
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
stow --simulate --verbose pi nvim
stow pi nvim
```

Ersätt `DITT_NAMN` med rätt GitHub-användare. Förhandsgranska alltid först.
Om befintliga filer ger konflikter: jämför dem och säkerhetskopiera/flytta
undan dem innan du länkar. Använd inte `--adopt` eller tvingande
överskrivning utan att först kontrollera vilken version som ska bevaras.

Pi-inloggningen görs lokalt på varje dator. Modellvalen i `settings.json`
förutsätter tillgång till de konfigurerade modellerna.

## Ändra konfiguration

Befintliga länkade filer kan redigeras via sina vanliga sökvägar, till
exempel `~/.pi/agent/prompts/review.md` eller `~/.config/nvim/init.lua`.
Ändringarna hamnar i repot.

Skapa nya filer direkt under motsvarande paket i repot och kör sedan:

```bash
cd ~/source/dotfiles
stow --simulate --verbose --restow pi nvim
stow --restow pi nvim
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
- Neovims data, plugininstallationer och cache utanför `~/.config/nvim`.
- Neovim-konfigurationens tidigare `.git`-katalog.

Pi-katalogen har en tillåtelselista i `.gitignore`: bara `agents`,
`extensions`, `prompts`, `skills` och `settings.json` kan läggas till
normalt. Ändra även paketets Stow-regler om fler Pi-resurser ska ingå.
Ignoreringsregler ersätter inte granskning av innehållet i tillåtna filer.

## Kontroller

Från repots rot:

```bash
stow --simulate --verbose pi nvim
node --test pi/.pi/agent/extensions/orc/index.test.mjs \
  pi/.pi/agent/extensions/subagent/index.test.mjs \
  pi/.pi/agent/extensions/subagent/runner.test.mjs
```

Testerna använder de lokalt installerade Node- och Pi-versionerna.
Neovims dokumentation och tester finns under `nvim/.config/nvim/`.

## Koppla bort länkarna

```bash
cd ~/source/dotfiles
stow --simulate --verbose --delete pi nvim
stow --delete pi nvim
```

Det tar bort de Stow-hanterade länkarna, inte filerna i repot eller
lokalt tillstånd som Pi-inloggning och sessionshistorik. Återställ egna
säkerhetskopior separat om den tidigare konfigurationen ska användas.

Vid den första migreringen sparades originalkonfigurationen utanför
repot i en katalog med namnet `~/dotfiles-backup.*`. Neovim-backupen
innehåller även dess tidigare Git-repo och lokala ändringar.
