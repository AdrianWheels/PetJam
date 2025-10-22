# GDD — BS + Hero en Timeline (Jam Scope)
##REPO DE ARTE## --> Crear repo de arte reutilizable
## TL;DR

Juego de **bucles continuos** con **corredor único estilo Darkest Dungeon**: el **Héroe** avanza por **salas en línea**, y en cada sala lucha contra enemigos. Mientras tanto, el **BS (jugador artesano)** craftea en paralelo con **4 minijuegos**. Morir es frecuente y parte del diseño del heroe. **Progresión jam**: un **solo mundo/corredor**; completas **8 salas** con **8 enemigos** y enfrentas al **Jefe final**. **No hay escalado de calidad por sala, pero los enemigos son mas fuertes conforme avanzas**; la calidad depende solo del crafteo del BS.

Al morir, el Héroe **reaparece al inicio del corredor** para limpiar salas fáciles y **recolectar materiales** rápidamente. El heroe recolectará automaticamente los materiales (Hierro, Cuero, Tela, Agua destilada, Catalizadores[Más raros, que le daran habilidades a los objetos que forjen]) Además, el BS puede activar **Entrega de Material**: el Héroe **deja de pelear** 2 s para equiparse en campo y se cura.

**MVP jam (1–2 días):** 1 bioma, **corredor lineal** de 8 salas (+1 sala de jefe), combate continuo, 4 minijuegos, 2 tiers (N1/N2), 6 objetos, 3 enemigos, 1 jefe, **adaptación por 10 derrotas**. Partidas 8–12 min.

---

## 1) High Concept

“**Timeline Forgemaster**”: no controlas al héroe; controlas la **producción** que condiciona su supervivencia mientras recorre un **corredor de salas en línea**. 

## 2) Fantasía y Fantasma de Diseño

* Fantasía: sentirte **maestro artesano** improvisando equipo y consumibles a contrarreloj para que “tu” héroe supere adversidades crecientes.
* Fantasma: presión de tiempo + lectura del metajuego del enemigo + minijuegos que premian **precisión** sobre **grindeo**.

## 3) Plataforma y Alcance Jam

* **Plataforma**:Godot desktop.
* **Scope jam**: 1 nivel corto con combate continuo en **corredor lineal de salas**. Un único layout. Arte estilizado low‑poly o 2D minimal.
* **Controles**: ratón/trackpad (teclas opcionales para accesibilidad).

## 4) Estructura de Partida

* **Corredor lineal**: una sola línea de **8 salas** comunes + **1 sala de jefe**. Cada sala es un combate contra 1 enemigo.
* **Combate continuo**: el Héroe entra en la sala, combate hasta que no queden enemigos y **avanza automáticamente** a la siguiente. 
* **Respawn al inicio**: al morir, tras 3 s reaparece **en la Sala 1**. 
* **Progresión jam**: completas **8 salas** y aparece el **Jefe final** en la última. Al derrotarlo, **termina la run** con el mensaje: **“Habrá más mundos”**.
* **Blueprints**: cada vez que elimina un enemigo nuevo, recibirá un blueprint que le permitirá avanzar mas adelante.


## 5) Roles

### 5.1 Héroe (IA ligera)

* **Siempre en combate de sala**: prioriza al úico enemigo que hay en la sala.
* **Multi‑objetivo**: ataques básicos golpean a un objetivo;
* **Uso de consumibles**:? poción a **HP ≤ 35%** si hay stock;
* **Slots**: arma, armadura, 2 accesorio, 1 consumibles.
* **Muerte frecuente**: al morir, respawnea **tras 3 s en la Sala 1**.
* **Entrega de Material (campo)**: al activarla, el Héroe **deja de atacar** y entra en **Burbuja de Entrega** 5 s para equiparse. La Burbuja **bloquea daño** y evita que los enemigos ataquen. **CD**: 20 s.

### 5.2 BS (Player)

El rol protagonista. El Héroe es un crash test dummy glorificado; tú eres el juego. Principios:

* **Juice-first**: cada acción del BS genera respuesta visual/sonora clara.
* **Expresión de habilidad**: precisión en minijuegos, gestión de recursos, riesgo/beneficio al equipar en sala.
* **Decisiones cada 3–7 s**: siempre hay algo útil que hacer.

Acciones núcleo del BS:

* Elegir **recetas** y **planos** en función de resistencias.
* Jugar **minijuegos** para fijar **calidad** y activar **combos**.
* Gestionar **cola de crafteo (3 slots)** con **prioridades** y **cancelación segura**.
* Activar **Entrega** en el momento oportuno para equipar bajo burbuja.
* Administrar **Catalizadores** para **Infusiones**  con mejoras en los objetos como daño de fuego, hielo o veneno.
* Activar Entrega cura al jugador. Importante gestionar cuando ir a curar y equiparlo.

Recompensas de maestría:

* **Perfect Chains** en minijuegos → suben el **Medidor de Forjamagia** y pueden otorgar **Crit Craft** (calidad +1 nivel y **reembolso** de 1 material aleatorio).
* **Entrega Perfecta** (click justo al cerrar el anillo de entrega) → reduce el **CD de Entrega** en −5 s.
* **Predicción**: equipar justo antes de entrar a una sala con mas dificultad.

### 5.3 Loop del BS (momento a momento, 60 s)


## 6) Sistemas Clave

### 6.1 Recursos y Planos

* **Materiales base**: Hierro, Cuero, Tela, Agua destilada, Catalizadores (fuego/hielo/veneno).
* **Fuentes**: drops por sala al eliminar enemigos.Los enemigos dropean materiales aleatorios, los catalizadores son mas raros de encontrar. Además dan un blueprint la primera vez que se derrotan
* **Blueprints por bajas**: La primera vez que derrotas a un enemigo te da un blueprint, que te ayuda a avanzar mas adelante.
* **Tier**: **N1 único**. Los **Blueprints** desbloquean **variantes** y **modificadores** dentro del mismo tier (ej. filo serrado, acolchado reforzado, infusión elemental básica).

### 6.2 Minijuegos (MVP)

1. **Forja (temperatura)**: barra que oscila; click en la **zona dulce** 3 veces.
2. **Martillo (timing)**: 5 golpes con ventana de precisión tipo ritmo.
3. **Coser (ritmo tipo OSU)**: círculos que colapsan; Perfect/Bien/Regular; cadena de 8 notas; bonus de **Evasión** si media ≥ Bien.
4. **Agua (temple)**: suelta en intervalo óptimo para fijar elemento si hay catalizador.

> **Calidad final del ítem** = media ponderada de 2–3 minijuegos + modificadores.


### 6.4 Sistemas del BS: combo, calor, cola y entrega+

* **Medidor de Forjamagia**: sube con **Perfect** y **Bien** (2/1 puntos). A 10 puntos → **Overclock 5 s**: ventanas de minijuegos **+20%**, anillo OSU colapsa **+15% más lento**, partícula de “chispas” y **sideshake** 4 px.
* **Calor de Forja**: cada acción sube **Calor (0–100)**. >60: la UI vibra levemente y las ventanas de precisión se estrechan **−10%**; >85: **−20%**. Bajar Calor: 1) esperar, 2) minijuego de **Agua** exitoso, 3) perk **Temple**.
* **Cola de Crafteo (3 slots)**: arrastrar para **reordenar**; **Shift+click** para promoción urgente (coste: +10 Calor). Cancelación devuelve **80%** de materiales.
* **Crit Craft**: 3 Perfect seguidos en cualquier combinación de minijuegos → el ítem sube un grado de calidad y genera **1 Fragmento**; 3 Fragmentos = **Catalizador común**.
* **Entrega+**: micro‑QTE de un solo click. Perfect: **−5 s CD** y aplica **Pulido** (+3% stat del ítem durante 20 s). Fallo: sin penalización extra.
* **Fail‑forward**: si fallas duro un minijuego, generas **Chatarra**; 5 Chatarra = reroll de plano común o +1 intento OSU.

## 7) Condiciones de Victoria y Derrota

* **Ganas**: Derrotas al **Jefe** en la última sala. Pantalla final con **“Habrá más mundos”** y estadísticas.
* **Pierdes**: Cuando el heroe muere 50 veces.

## 8) Enemigos y Jefe (MVP)

* **Esbirro (Melee)**: daño físico, patrón simple.
* **Arquero**: castiga builds lentas (proc de sangrado si el héroe va blindado).
* **Jefe**: abre con **contramedida** contra el tipo de daño más usado. Fase 2 a 50% vida: cambia a segunda contramedida.

## 9) Objetos (MVP)

* **Espada básica**: +ATQ, tipo Físico.
* **Arco ligero**: +ATQ menor, +Velocidad.
* **Peto de cuero**: +DEF, −Velocidad pequeña.
* **Casco acolchado**: +HP.
* **Poción de vida**: cura 40% HP.
* **Poción tónica**: +Velocidad por 10 s.
* **Infusiones**: Fuego/Hielo/Veneno como modificadores de arma o armadura.

## 10) UI/UX (1 Pantalla)

* **Arriba**: **Corredor lineal** con 9 casillas (8 salas + jefe). Se muestran próximos 2 grupos enemigos y estado **ADAPTADO** por tipo.
* **En otra pantalla, puedes ir cuando quieras pero realmente no sabrás el estado de las cosas hasta llegar**: vista lateral tipo **Darkest Dungeon** con el Héroe avanzando y luchando contra enemigos.
* **En la ventana principial del juego**: panel de **Crafteo**, cola de fabricación e **Inventario** con los materiales conseguidos por el heroe y los blueprint que se puede fabricar.
* **Acción de Entrega**: botón con **CD** y tooltip “El Héroe parará 5 s para equiparse”. Animación de **Burbuja** en la sala.
* **Feedback**: colores C/B/A/S e indicadores rítmicos para el minijuego OSU.

## 10.1 Juice & Audio Bible (micro‑detalles que venden el golpe)

**Timing base**

* Hover: 80 ms **easeOutQuad**; click: 120 ms **easeOutCubic**.
* Aparición de paneles: 160 ms **easeOutBack**; cierre 120 ms **easeInQuad**.
* Golpe de martillo: squash y estiramiento 60 ms; **screenshake** 6 px durante 90 ms.

**OSU (Coser) feel**

* Anillo colapsa en **650 ms**; pre‑spark de 150 ms antes del Perfect.
* Partículas de éxito: 12–18, vida 280–320 ms, escala 0.6→0.0, ligera rotación.
* Sonido de Perfect con **pitch random ±3%**; Bien −2 dB; Regular −5 dB.

**Forja/Martillo**

* Chispa de partícula con **additive blend** y leve **glow** 1.5 px.
* Rastro fantasma del martillo 1 frame con alpha 0.35.

**Entrega**

* Burbuja entra con **scale 0.9→1** en 180 ms; low‑pass al audio del combate −6 dB; SFX de “clac” al equipar.

**Audio layering**

* Música en loop simple; **ducking** de −3 dB durante 200 ms cuando suenan impactos fuertes.
* Capas: UI click, forja, martillo pesado, agua, coser Perfect, entrega.

**Accesibilidad**

* Modo **Reduced Motion**: desactiva screenshake, reduce partículas 50% y sustituye por flash suave.
* **Opciones de timing**: ventana OSU ajustable ±20%.

## 10.2 Métricas y tuning

* % de Perfect/Bien/Regular por minijuego.
* Tiempo medio en cola y nº de reordenamientos.
* Uso de Entrega y % de “Entrega Perfecta”.
* Distribución de Calor a lo largo de la run.
* Correlación Medidor de Forjamagia vs victorias de sala.

## 11) Balance rápido (parámetros iniciales)

* Vida Héroe: 100. Daño esbirro: 8. Daño espada: 10.
* **Salas**: 8 comunes + 1 jefe. Grupo 2–4 enemigos por sala.
* **Respawn**:

---

## Godot 4.5 — Setup rápido y AutoLoad (recomendado)

Este proyecto fue desarrollado inicialmente apuntando a Godot 4.5 (la metadata original del proyecto lo indicaba). Para evitar incompatibilidades te recomiendo abrir el proyecto con Godot 4.5. He limpiado las referencias rotas en las cachés del editor; ahora los autoloads deben registrarse manualmente desde el editor si lo deseas.

Cómo registrar los singletons manualmente (recomendado en Godot 4.5):

1. Abre Godot 4.5 y carga el proyecto `d:\Proyectos\PetJam`.
2. Ve a Project → Project Settings → AutoLoad → Add.
3. Añade cada script con el nombre del singleton:
	- `GameManager` -> `res://scripts/autoload/GameManager.gd`
	- `DataManager` -> `res://scripts/autoload/DataManager.gd`
	- `CraftingManager` -> `res://scripts/autoload/CraftingManager.gd`
	- `AudioManager` -> `res://scripts/autoload/AudioManager.gd`
	- `TelemetryManager` -> `res://scripts/autoload/TelemetryManager.gd`

Verificación rápida:

1. Ejecuta `Main.tscn` desde el editor.
2. Observa la consola para mensajes de inicialización como `AudioManager ready` y `TelemetryManager ready`.

Si necesitas que registre los autoloads automáticamente en `project.godot`, lo puedo hacer, pero fue la causa de intentos de carga inválidos en entornos distintos (por ejemplo Godot 5 puede interpretar configuraciones distintas). Prefiero que los registres desde el editor si estás usando Godot 4.5.
