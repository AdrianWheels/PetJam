#!/usr/bin/env bash
# Lanza el arnés de Balanza en PetJam con Godot 4.5.1. El aislamiento de la partida vive en protegido.sh: el arnés arranca
# los autoloads del juego, y GameManager carga y guarda user://save.json; protegido.sh lo ejecuta con un APPDATA temporal,
# así que la partida real del usuario no se toca (tampoco si se corta el arnés). Uso, desde la raíz del juego:
#   bash balance/arnes.sh <measure|check> [--dir res://balance] [--stats] [--items] …
exec bash "$(dirname "$0")/protegido.sh" timeout 600 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://addons/balanza/run.tscn -- "$@"
