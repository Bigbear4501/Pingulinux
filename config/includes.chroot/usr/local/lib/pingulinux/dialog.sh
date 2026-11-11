# shellcheck shell=bash
#
# /usr/local/lib/pingulinux/dialog.sh
#
# Gemeinsame Dialog-Fenster für alle Pingulinux-Skripte.
# Nimmt kdialog (KDE, sieht aus wie der Rest des Systems) und fällt auf
# zenity zurück, falls kdialog fehlt. Einbinden mit:
#     . /usr/local/lib/pingulinux/dialog.sh
#
# Texte: „\n“ wird zum Zeilenumbruch, einfache Auszeichnung wie <b>…</b>
# ist erlaubt. Für Texte mit fremdem Inhalt (Fehlerprotokolle) die
# *_roh-Varianten nehmen, die zeigen alles wörtlich.
#
#   pd_info     TITEL TEXT [OK-BESCHRIFTUNG]
#   pd_fehler   TITEL TEXT          pd_fehler_roh TITEL TEXT
#   pd_frage    TITEL TEXT [JA] [NEIN]          -> Rückgabe 0 = ja
#   pd_passwort TITEL TEXT                      -> Ausgabe: Passwort
#   pd_eingabe  TITEL TEXT [VORGABE]            -> Ausgabe: Text
#   pd_menue    TITEL TEXT tag text [tag text …] -> Ausgabe: tag
#   pd_radio    TITEL TEXT tag text an|aus …     -> Ausgabe: tag
#   pd_auswahl  TITEL TEXT tag text an|aus …     -> Ausgabe: tags, je Zeile
#   pd_combo    TITEL TEXT VORGABE eintrag …     -> Ausgabe: eintrag
#   pd_regler   TITEL TEXT MIN MAX SCHRITT WERT  -> Ausgabe: Zahl
#   pd_textdatei TITEL DATEI
#   pd_warten   TITEL TEXT befehl …  (Wartefenster, bis der Befehl fertig ist;
#                                     Rückgabe = Rückgabe des Befehls)
#   pd_fortschritt TITEL TEXT        (liest Zeilen: Zahl 0–100 oder „# Text“)

PD_ICON=/usr/share/pingulinux/icons/pingu.png
if command -v kdialog >/dev/null 2>&1 && [ -z "$PD_ZENITY" ]; then PD_KDE=1; else PD_KDE=; fi

# Text für kdialog: \n -> Umbruch; mit Auszeichnung -> <br>
_pd_t() {
    local t
    t=$(printf '%b' "$1")
    if [[ "$t" == *"<"*">"* ]]; then
        t="${t//$'\n'/<br>}"
        printf '%s' "<qt>$t</qt>"
    else
        printf '%s' "$t"
    fi
}
# Wörtlicher Text (nichts wird als Auszeichnung gelesen)
_pd_roh() {
    local t="$1"
    # Ersatztext in Anführungszeichen: in bash 5.2 stünde & sonst für den Fund
    t="${t//&/"&amp;"}"; t="${t//</"&lt;"}"; t="${t//>/"&gt;"}"; t="${t//$'\n'/"<br>"}"
    printf '%s' "<qt>$t</qt>"
}
_pd_k() { kdialog --icon "$PD_ICON" "$@"; }
_pd_z() { zenity --window-icon="$PD_ICON" "$@"; }

pd_info() {
    if [ -n "$PD_KDE" ]; then _pd_k --title "$1" --ok-label "${3:-OK}" --msgbox "$(_pd_t "$2")"
    else _pd_z --info --title="$1" --width=420 --ok-label="${3:-OK}" --text="$2"; fi
}
pd_fehler() {
    if [ -n "$PD_KDE" ]; then _pd_k --title "$1" --error "$(_pd_t "$2")"
    else _pd_z --error --title="$1" --width=420 --text="$2"; fi
}
pd_fehler_roh() {
    if [ -n "$PD_KDE" ]; then _pd_k --title "$1" --error "$(_pd_roh "$2")"
    else _pd_z --error --title="$1" --width=460 --no-markup --text="$2"; fi
}
pd_frage() {
    if [ -n "$PD_KDE" ]; then _pd_k --title "$1" --yes-label "${3:-Ja}" --no-label "${4:-Nein}" --yesno "$(_pd_t "$2")"
    else _pd_z --question --title="$1" --width=440 --ok-label="${3:-Ja}" --cancel-label="${4:-Nein}" --text="$2"; fi
}
pd_passwort() {
    if [ -n "$PD_KDE" ]; then _pd_k --title "$1" --password "$(printf '%b' "$2")"
    else _pd_z --password --title="$1 – $(printf '%b' "$2")"; fi
}
pd_eingabe() {
    if [ -n "$PD_KDE" ]; then _pd_k --title "$1" --inputbox "$(printf '%b' "$2")" "${3:-}"
    else _pd_z --entry --title="$1" --text="$2" --entry-text="${3:-}"; fi
}
pd_menue() {
    local title="$1" text="$2"; shift 2
    if [ -n "$PD_KDE" ]; then _pd_k --title "$title" --menu "$(_pd_t "$text")" "$@"
    else
        local args=() i
        for ((i=1; i<=$#; i+=2)); do args+=("${!i}" "${@:i+1:1}"); done
        _pd_z --list --title="$title" --width=520 --height=480 --text="$text" \
            --column=tag --column=Auswahl --hide-column=1 --print-column=1 --hide-header "${args[@]}"
    fi
}
pd_radio() {
    local title="$1" text="$2"; shift 2
    if [ -n "$PD_KDE" ]; then
        local args=() a
        for a in "$@"; do case "$a" in an) args+=(on);; aus) args+=(off);; *) args+=("$a");; esac; done
        _pd_k --title "$title" --radiolist "$(_pd_t "$text")" "${args[@]}"
    else
        local args=()
        while [ $# -ge 3 ]; do args+=("$([ "$3" = an ] && echo TRUE || echo FALSE)" "$1" "$2"); shift 3; done
        _pd_z --list --radiolist --title="$title" --width=520 --height=360 --text="$text" \
            --column="" --column=tag --column=Auswahl --hide-column=2 --print-column=2 "${args[@]}"
    fi
}
pd_auswahl() {
    local title="$1" text="$2"; shift 2
    if [ -n "$PD_KDE" ]; then
        local args=() a
        for a in "$@"; do case "$a" in an) args+=(on);; aus) args+=(off);; *) args+=("$a");; esac; done
        _pd_k --title "$title" --separate-output --checklist "$(_pd_t "$text")" "${args[@]}"
    else
        local args=()
        while [ $# -ge 3 ]; do args+=("$([ "$3" = an ] && echo TRUE || echo FALSE)" "$1" "$2"); shift 3; done
        _pd_z --list --checklist --title="$title" --width=560 --height=520 --text="$text" --separator=$'\n' \
            --column="✓" --column=tag --column=Auswahl --hide-column=2 --print-column=2 "${args[@]}"
    fi
}
pd_combo() {
    local title="$1" text="$2" def="$3"; shift 3
    if [ -n "$PD_KDE" ]; then _pd_k --title "$title" --default "$def" --combobox "$(printf '%b' "$text")" "$@"
    else
        local vals; vals=$(printf '%s|' "$@"); vals="${vals%|}"
        _pd_z --forms --title="$title" --text="$text" --add-combo="" --combo-values="$vals"
    fi
}
pd_regler() {
    if [ -n "$PD_KDE" ]; then _pd_k --title "$1" --slider "$(printf '%b' "$2")" "$3" "$4" "$5"
    else _pd_z --scale --title="$1" --width=420 --text="$2" --min-value="$3" --max-value="$4" --step="$5" --value="${6:-$3}"; fi
}
pd_textdatei() {
    if [ -n "$PD_KDE" ]; then _pd_k --title "$1" --textbox "$2" 600 460
    else _pd_z --text-info --title="$1" --width=560 --height=440 --filename="$2"; fi
}

# Wartefenster, solange ein Befehl läuft
pd_warten() {
    local title="$1" text="$2"; shift 2
    local rcf; rcf=$(mktemp)
    ( "$@"; echo $? > "$rcf" ) &
    local pid=$!
    if [ -n "$PD_KDE" ]; then
        local ref svc path
        ref=$(_pd_k --title "$title" --progressbar "$(printf '%b' "$text")" 0 2>/dev/null)
        svc=${ref% *}; path=${ref#* }
        wait "$pid"
        [ -n "$svc" ] && dbus-send --session --type=method_call --dest="$svc" "$path" \
            org.kde.kdialog.ProgressDialog.close >/dev/null 2>&1
    else
        ( while kill -0 "$pid" 2>/dev/null; do echo "# $text"; sleep 2; done; echo 100 ) \
            | _pd_z --progress --pulsate --auto-close --no-cancel --title="$title" --width=460 --text="$text"
        wait "$pid"
    fi
    local rc; rc=$(cat "$rcf" 2>/dev/null); rm -f "$rcf"
    return "${rc:-1}"
}

# Fortschrittsbalken: liest von stdin Zahlen (0–100) und „# Text“
pd_fortschritt() {
    local title="$1" text="$2"
    if [ -n "$PD_KDE" ]; then
        local ref svc path line
        ref=$(_pd_k --title "$title" --progressbar "$(printf '%b' "$text")" 100 2>/dev/null)
        svc=${ref% *}; path=${ref#* }
        while IFS= read -r line; do
            [ -n "$svc" ] || continue
            case "$line" in
                "#"*) dbus-send --session --type=method_call --dest="$svc" "$path" \
                        org.kde.kdialog.ProgressDialog.setLabelText string:"${line#\# }" >/dev/null 2>&1 ;;
                [0-9]*) dbus-send --session --type=method_call --dest="$svc" "$path" \
                        org.freedesktop.DBus.Properties.Set string:org.kde.kdialog.ProgressDialog \
                        string:value variant:int32:"${line%%[!0-9]*}" >/dev/null 2>&1 ;;
            esac
        done
        [ -n "$svc" ] && dbus-send --session --type=method_call --dest="$svc" "$path" \
            org.kde.kdialog.ProgressDialog.close >/dev/null 2>&1
        return 0
    else
        _pd_z --progress --title="$title" --width=420 --text="$text" --auto-close --no-cancel
    fi
}
