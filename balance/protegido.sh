#!/usr/bin/env bash
# Ejecuta un comando sin tocar nunca la partida de PetJam: el juego carga y guarda user://save.json en cuanto arranca sus
# autoloads, y esa partida la comparten todos los worktrees y el usuario, que puede estar jugando. En vez de copiarla y
# restaurarla, se aísla: Godot en Windows saca user:// de la variable APPDATA, y el comando corre con un APPDATA propio,
# una carpeta temporal vacía (así save.json y telemetry.log viven ahí y cada ejecución parte de una partida nueva, igual
# para todas). Se borra al terminar, también si el comando falla o se corta (Ctrl-C o kill). La partida real no se lee ni
# se escribe, así que no hay nada que restaurar. La salida del script es la del comando. Lo usa arnes.sh, y debe usarlo
# cualquier ejecución directa de Godot sobre PetJam:
#   bash balance/protegido.sh timeout 300 D:/Software/Godot/godot_ver4.5.exe --headless --path . res://scenes/tests/RankTests.tscn
# Si alguna vez hace falta probar con la partida real, se copia a mano a esa carpeta (como hace el lanzador del worktree
# del inventario); aquí no, para que las medidas y las pruebas no dependan de lo que el usuario lleve jugado.
set -u
if [ "$#" -eq 0 ]; then
	echo "uso: bash balance/protegido.sh <comando> [argumentos…]" >&2
	exit 64
fi
AISLADA="$(mktemp -d)" || { echo "protegido.sh: no pude crear la carpeta temporal de datos de usuario" >&2; exit 70; }
HIJO=""
CODE=0

# Borra la carpeta aislada. Si no puede (un fichero abierto), avisa de dónde ha quedado.
limpiar() {
	rm -rf "$AISLADA"
	if [ -d "$AISLADA" ]; then
		echo "protegido.sh: no pude borrar la carpeta temporal $AISLADA" >&2
		return 1
	fi
	return 0
}

# Al salir, por la razón que sea: borra la carpeta y sale con el código del comando (70 si no pudo borrarla).
al_salir() {
	limpiar || CODE=70
	exit "$CODE"
}

# Ctrl-C o kill sobre este script: para el comando (un hijo en segundo plano no recibe Ctrl-C), espera a que acabe para
# que no siga escribiendo en la carpeta que se va a borrar, y sale; al salir actúa el trap de EXIT.
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

# Godot es un programa de Windows: necesita la ruta en formato Windows (cygpath viene con Git Bash)
if command -v cygpath >/dev/null 2>&1; then
	APPDATA_AISLADO="$(cygpath -w "$AISLADA")"
else
	APPDATA_AISLADO="$AISLADA"
fi

# En segundo plano (y con la entrada de este script) para poder atender INT y TERM mientras corre
APPDATA="$APPDATA_AISLADO" "$@" <&0 &
HIJO=$!
wait "$HIJO"
CODE=$?
exit "$CODE"
