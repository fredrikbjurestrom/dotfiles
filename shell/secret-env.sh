# Ladda med: source ~/secret-env.sh
# Använd med: secret_env DB_CONNSTR
# Fungerar i Bash och Zsh. Inga hemligheter sparas i denna fil.

secret_env() {
    # Zsh återställer xtrace när en funktion återvänder. Läs inte in en
    # hemlighet som sedan riskerar att exponeras av anroparens spårning.
    if [ -n "${ZSH_VERSION-}" ]; then
        case $- in
            *x*) printf 'Kör set +x innan secret_env i Zsh.\n' >&2; return 2 ;;
        esac
    fi
    # I Bash lämnas spårningen avstängd även efter funktionsanropet.
    set +x

    if [ "$#" -ne 1 ]; then
        printf 'Användning: secret_env VARIABELNAMN\n' >&2
        return 2
    fi
    case "$1" in
        ''|[0-9]*|*[!a-zA-Z0-9_]*)
            printf 'Ogiltigt miljövariabelnamn.\n' >&2
            return 2
            ;;
    esac

    printf '%s: ' "$1" >&2
    # Läs i en subshell så hjälpvariabeln inte ändrar det aktuella shellet.
    # Prefixet skiljer en lyckad, tom inmatning från en avbruten inläsning.
    set -- "$1" "$(
        if IFS= read -r -s _secret_env_value; then
            printf '=%s' "$_secret_env_value"
        fi
    )"
    printf '\n' >&2
    case "$2" in
        '='*)
            # Ingen eval: värdet behandlas enbart som data.
            builtin export "$1=${2#=}"
            ;;
        *)
            printf 'Avbruten; variabeln har inte ändrats.\n' >&2
            return 1
            ;;
    esac
}
