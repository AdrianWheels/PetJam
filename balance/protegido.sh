#!/usr/bin/env bash
# Ejecuta un comando dejando la partida de PetJam (user://save.json) como estaba: el juego carga y guarda ese fichero en
# cuanto arranca sus autoloads, y lo comparten todos los worktrees y sesiones. Se copia antes y se restaura al terminar,
# también si el comando falla o se corta (Ctrl-C o kill); si no había partida, no queda ninguna. La salida del script es
# la del comando. Lo usa arnes.sh, y debe usarlo cualquier ejecución directa de Godot sobre PetJam:
#   bash balance/protegido.sh timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn
set -u
if [ "$#" -eq 0 ]; then
	echo "uso: bash balance/protegido.sh <comando> [argumentos…]" >&2
	exit 64
fi
SAVE="${APPDATA:?protegido.sh: falta APPDATA}/Godot/app_userdata/PetJam/save.json"
BACKUP="$(mktemp)" || { echo "protegido.sh: no pude crear la copia temporal de la partida" >&2; exit 70; }
HAD=0
if [ -f "$SAVE" ]; then
	if ! cp -p "$SAVE" "$BACKUP"; then
		echo "protegido.sh: no pude copiar $SAVE; no se ejecuta nada" >&2
		rm -f "$BACKUP"
		exit 70
	fi
	HAD=1
fi
HIJO=""
CODE=0
RESTAURADA=0

# Deja la partida como estaba. Solo actúa la primera vez (EXIT, INT y TERM pueden coincidir). Si la copia de vuelta
# falla, no borra la copia temporal: avisa de dónde ha quedado y devuelve 1.
restaurar() {
	[ "$RESTAURADA" = 1 ] && return 0
	RESTAURADA=1
	if [ "$HAD" = 1 ]; then
		if ! cp -p "$BACKUP" "$SAVE"; then
			echo "protegido.sh: no pude restaurar $SAVE; la copia de la partida ha quedado en $BACKUP" >&2
			return 1
		fi
	else
		rm -f "$SAVE"
	fi
	rm -f "$BACKUP"
	return 0
}

# Al salir, por la razón que sea: restaura y sale con el código del comando (70 si no pudo restaurar).
al_salir() {
	restaurar || CODE=70
	exit "$CODE"
}

# Ctrl-C o kill sobre este script: para el comando (un hijo en segundo plano no recibe Ctrl-C), espera a que acabe para
# que no vuelva a guardar después de restaurar, y sale; al salir actúa el trap de EXIT.
cortar() {
	trap '' INT TERM
	CODE=$1
	if [ -n "$HIJO" ] && kill -0 "$HIJO" 2>/dev/null; then
		kill -TERM "$HIJO" 2>/dev/null
		for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25; do
			kill -0 "$HIJO" 2>/dev/null || break
			sleep 0.2
		done
		kill -0 "$HIJO" 2>/dev/null && kill -KILL "$HIJO" 2>/dev/null
		wait "$HIJO" 2>/dev/null
	fi
	exit "$CODE"
}

trap al_salir EXIT
trap 'cortar 130' INT
trap 'cortar 143' TERM

# En segundo plano (y con la entrada de este script) para poder atender INT y TERM mientras corre
"$@" <&0 &
HIJO=$!
wait "$HIJO"
CODE=$?
exit "$CODE"
