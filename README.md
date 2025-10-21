# GDD — BS + Hero en Timeline (Jam Scope)
##REPO DE ARTE## --> Crear repo de arte reutilizable
## TL;DR

Juego de **bucles continuos** con **corredor único estilo Darkest Dungeon**: el **Héroe** avanza por **salas en línea**, y en cada sala lucha contra enemigos. Mientras tanto, el **BS (jugador artesano)** craftea en paralelo con **4 minijuegos**. Morir es frecuente y parte del diseño del heroe. La **Humanidad** es un **pool amplio** que sube al avanzar y baja al morir; desbloquea **perks** en umbrales. **Progresión jam**: un **solo mundo/corredor**; completas **8 salas** con **8 enemigos** y enfrentas al **Jefe final**. **No hay escalado de calidad por sala, pero los enemigos son cada vez mas fuertes**; la calidad depende solo del crafteo del BS.

Novedades clave del flujo: al morir, el Héroe **reaparece al inicio del corredor** para limpiar salas fáciles y **recolectar materiales** rápidamente. Además, el BS puede activar **Entrega de Material**: el Héroe **deja de pelear** 2 s para equiparse en campo y se cura.

**MVP jam (1–2 días):** 1 bioma, **corredor lineal** de 8 salas (+1 sala de jefe), combate continuo, 4 minijuegos, 2 tiers (N1/N2), 6 objetos, 3 enemigos, 1 jefe, **adaptación por 10 derrotas**. Partidas 8–12 min.

---

## 1) High Concept

“**Timeline Forgemaster**”: no controlas al héroe; controlas la **producción** que condiciona su supervivencia mientras recorre un **corredor de salas en línea**. 

## 2) Fantasía y Fantasma de Diseño

* Fantasía: sentirte **maestro artesano** improvisando equipo y consumibles a contrarreloj para que “tu” héroe supere adversidades crecientes.
* Fantasma: presión de tiempo + lectura del metajuego del enemigo + minijuegos que premian **precisión** sobre **grindeo**.

## 3) Plataforma y Alcance Jam

* **Plataforma**: PC navegador (WebGL/Canvas) o Godot desktop.
* **Scope jam**: 1 nivel corto con combate continuo en **corredor lineal de salas**. Un único layout. Arte estilizado low‑poly o 2D minimal.
* **Controles**: ratón/trackpad (teclas opcionales para accesibilidad).

## 4) Estructura de Partida

* **Corredor lineal**: una sola línea de **8 salas** comunes + **1 sala de jefe**. Cada sala es un combate contra **grupos** de 2–4 enemigos con formaciones simples.
* **Combate continuo**: el Héroe entra en la sala, combate hasta que no queden enemigos y **avanza automáticamente** a la siguiente. No se pausa al abrir la forja ni al jugar minijuegos. **Excepción**: **Entrega de Material**.
* **Respawn al inicio**: al morir, tras 3 s reaparece **en la Sala 1**. Las primeras 2 salas son **fáciles** y con **+20%** drop para acelerar recuperación de materiales.
* **Progresión jam**: completas **8 salas** y aparece el **Jefe final** en la última. Al derrotarlo, **termina la run** con el mensaje: **“Habrá más mundos”**.
* **Blueprints**: cada **20 bajas** conceden un **plano** del siguiente tier (pity si pasan **3 minutos** sin plano nuevo).
* **Adaptación**: cada tipo de enemigo se **adapta** tras **10 derrotas** (resistencias y patrón anti‑build), reduciendo farmeo repetitivo.

## 5) Roles

### 5.1 Héroe (IA ligera)

* **Siempre en combate de sala**: prioriza al úico enemigo que hay en la sala.
* **Multi‑objetivo**: ataques básicos golpean a un objetivo; algunas armas N2 añaden efectos mejores.
* **Uso de consumibles**:? poción a **HP ≤ 35%** si hay stock; tónica al entrar en sala con proyectiles.
* **Slots**: arma, armadura, 2 accesorio, 1 consumibles.
* **Muerte frecuente**: al morir, respawnea **tras 3 s en la Sala 1**, con **−Humanidad**.
* **Entrega de Material (campo)**: al activarla, el Héroe **deja de atacar** y entra en **Burbuja de Entrega** 2 s para equiparse. La Burbuja **bloquea daño** y evita que los enemigos ataquen. **CD**: 20 s.

### 5.2 BS (Player)

El rol protagonista. El Héroe es un crash test dummy glorificado; tú eres el juego. Principios:

* **Juice-first**: cada acción del BS genera respuesta visual/sonora clara.
* **Expresión de habilidad**: precisión en minijuegos, gestión de recursos, riesgo/beneficio al equipar en sala.
* **Decisiones cada 3–7 s**: siempre hay algo útil que hacer.

Acciones núcleo del BS:

* Elegir **recetas** y **planos** en función de resistencias/adaptaciones.
* Jugar **minijuegos** para fijar **calidad** y activar **combos**.
* Gestionar **cola de crafteo (3 slots)** con **prioridades** y **cancelación segura**.
* Activar **Entrega** en el momento oportuno para equipar bajo burbuja.
* Administrar **Catalizadores** para **Infusiones** según bestiario y estado ADAPTADO.
* Activar Entrega cura al jugador. Importante gestionar cuando ir a curar y equiparlo.

Recompensas de maestría:

* **Perfect Chains** en minijuegos → suben el **Medidor de Forjamagia** y pueden otorgar **Crit Craft** (calidad +1 nivel y **reembolso** de 1 material aleatorio).
* **Entrega Perfecta** (click justo al cerrar el anillo de entrega) → reduce el **CD de Entrega** en −5 s.
* **Predicción**: equipar justo antes de entrar a una sala con mas dificultad.

### 5.3 Loop del BS (momento a momento, 60 s)

* **0–4 s**: vistazo al corredor, eliges receta (tooltip de resistencias/ADAPTADO).
* **4–11 s**: minijuego principal (Forja/Martillo/Coser/Agua). Objetivo: 2–3 Perfects.
* **11–13 s**: **Entrega** si el Héroe entra a grupo peligroso. Burbuja 2 s, micro‑QTE de “Entrega Perfecta”.
* **13–25 s**: segundo minijuego o preparar **Infusión** con Agua.
* **25–33 s**: ajustar cola; si el Héroe está cómodo, haces **Coser (OSU)** para bonus de Evasión.
* **33–45 s**: vigilar **Calor** (ver §6.5). Si alto, templas con Agua o esperas 3 s para disipar.
* **45–55 s**: si el Medidor de Forjamagia está lleno, activas **Overclock** (5 s, ventanas más amables).
* **55–60 s**: craft rápido de consumible y pre‑equipar; preparar próxima sala.

## 6) Sistemas Clave

### 6.1 Recursos y Planos

* **Materiales base**: Hierro, Cuero, Tela, Agua destilada, Catalizadores (fuego/hielo/veneno).
* **Fuentes**: drops por sala al eliminar enemigos. **Salas 1–2**: +20% drop tras respawn.
* **Blueprints por bajas**: cada **5 enemigos** derrotados ⇒ 1 **Blueprint** de **siguiente tier**.
* **Tier**: **N1 único**. Los **Blueprints** desbloquean **variantes** y **modificadores** dentro del mismo tier (ej. filo serrado, acolchado reforzado, infusión elemental básica).

### 6.2 Minijuegos (MVP)

1. **Forja (temperatura)**: barra que oscila; click en la **zona dulce** 3 veces.
2. **Martillo (timing)**: 5 golpes con ventana de precisión tipo ritmo.
3. **Coser (ritmo tipo OSU)**: círculos que colapsan; Perfect/Bien/Regular; cadena de 8 notas; bonus de **Evasión** si media ≥ Bien.
4. **Agua (temple)**: suelta en intervalo óptimo para fijar elemento si hay catalizador.

> **Calidad final del ítem** = media ponderada de 2–3 minijuegos + modificadores.

### 6.3 Humanidad, Vidas y Reforzamiento

* **Pool amplio**: Humanidad inicial **10**, máx **20**.
* **Cambios**: Muerte = **−2**; completar **sala** = **+1**; **hito** (mini‑evento/élite) = **+2**; **jefe** = **+3**.
* **Perks por umbral**: 12/16/20 con bonificadores persistentes mientras mantengas el umbral.
* **Rasgos Oscuros**: ≤4 activa **Furia** (+ATQ, mayor penalización por muerte) hasta volver a ≥8.
* **Pociones**: minijuego de Agua; no consumen Humanidad.

### 6.4 Sistemas del BS: combo, calor, cola y entrega+

* **Medidor de Forjamagia**: sube con **Perfect** y **Bien** (2/1 puntos). A 10 puntos → **Overclock 5 s**: ventanas de minijuegos **+20%**, anillo OSU colapsa **+15% más lento**, partícula de “chispas” y **sideshake** 4 px.
* **Calor de Forja**: cada acción sube **Calor (0–100)**. >60: la UI vibra levemente y las ventanas de precisión se estrechan **−10%**; >85: **−20%**. Bajar Calor: 1) esperar, 2) minijuego de **Agua** exitoso, 3) perk **Temple**.
* **Cola de Crafteo (3 slots)**: arrastrar para **reordenar**; **Shift+click** para promoción urgente (coste: +10 Calor). Cancelación devuelve **80%** de materiales.
* **Crit Craft**: 3 Perfect seguidos en cualquier combinación de minijuegos → el ítem sube un grado de calidad y genera **1 Fragmento**; 3 Fragmentos = **Catalizador común**.
* **Entrega+**: micro‑QTE de un solo click. Perfect: **−5 s CD** y aplica **Pulido** (+3% stat del ítem durante 20 s). Fallo: sin penalización extra.
* **Fail‑forward**: si fallas duro un minijuego, generas **Chatarra**; 5 Chatarra = reroll de plano común o +1 intento OSU.

## 7) Condiciones de Victoria y Derrota

* **Ganas**: Derrotas al **Jefe** en la última sala. Pantalla final con **“Habrá más mundos”** y estadísticas.
* **Pierdes**: Humanidad a **0** o el héroe muere 3 veces en < 30 s (soft fail para no alargar sin progreso).

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
* **En la ventana principial del juego**: panel de **Crafteo**, cola de fabricación e **Inventario**.
* **Acción de Entrega**: botón con **CD** y tooltip “El Héroe parará 2 s para equiparse”. Animación de **Burbuja** en la sala.
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
