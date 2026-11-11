#!/bin/sh
# apps-deutsch.sh – läuft nach jeder Paket-Installation (APT-Hook)
# Manche Programme (SuperTuxKart) starten englisch, obwohl das System
# deutsch ist. Ihr Starter bekommt Deutsch fest mitgegeben.
# Weil solche Spiele erst über den App Store kommen, reicht ein Build-Hook
# nicht – deshalb läuft das nach jedem apt/dpkg erneut (auch nach Updates,
# die den Starter überschreiben).
for f in /usr/share/applications/supertuxkart.desktop /usr/share/applications/*supertuxkart*.desktop; do
    [ -f "$f" ] || continue
    grep -q '^Exec=env LANGUAGE=de_DE:de:en ' "$f" && continue
    sed -i -E 's#^Exec=(env LANGUAGE=[^ ]+ )?(/usr/games/)?supertuxkart#Exec=env LANGUAGE=de_DE:de:en \2supertuxkart#' "$f"
done
exit 0
