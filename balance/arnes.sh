#!/usr/bin/env bash
# Lanza el arnés de Balanza en PetJam con Godot 4.5.1 y deja la partida como estaba: el arnés arranca los autoloads
# del juego, y GameManager carga y guarda user://save.json. Uso, desde la raíz del juego:
#   bash balance/arnes.sh <measure|check> [--dir res://balance] [--stats] [--items] …
set -u
SAVE="$APPDATA/Godot/app_userdata/PetJam/save.json"
BACKUP="$(mktemp)"
HAD=0
if [ -f "$SAVE" ]; then cp "$SAVE" "$BACKUP"; HAD=1; fi
timeout 600 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://addons/balanza/run.tscn -- "$@"
CODE=$?
if [ "$HAD" = 1 ]; then cp "$BACKUP" "$SAVE"; else rm -f "$SAVE"; fi
rm -f "$BACKUP"
exit $CODE
