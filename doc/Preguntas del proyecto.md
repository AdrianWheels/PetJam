# A — Diseño de juego y visión

## A1. Pitch del juego
> **¿Cuál es el pitch de una frase del juego?**  
> (Ej: "Eres un herrero que craftea equipo en tiempo real mientras un héroe IA muere una y otra vez en la dungeon.")

**Respuesta:**
Eres un herrero que craftea equipo en tiempo real mientras un héroe IA muere una y otra vez en la dungeon. El heroe sigue muriendo indefinidamente, tienes que mejorar su equipo para que pueda avanzar en los niveles
---

## A2. Condición de victoria y derrota
> **¿Cuál es la condición de victoria y de derrota?**  
> (El README dice: matar al boss = victoria, 50 muertes del héroe = game over. ¿Sigue vigente?)

**Respuesta:**
No hay condicion de victoria o derrota. La idea es que el heroe pelee de forma infinita y escalen los niveles de manera infinita. La idea es tener un juego de movil similar a un candy crush o similar. El heroe debe simular al lucha aun cuando el juego no está abierto, haciendo calculos de cuanto habría luchado el heroe segun la ultima entrada
---

## A3. Cantidad de salas
> **¿Cuántas salas tiene la dungeon?**  
> (El copilot-instructions dice 8 + jefe, pero el código maneja MAX_ENEMY_LEVEL = 9 con boss en level 9. ¿Son 8 normales + 1 boss?)

**Respuesta:**
Infinitas. Es un endless mode. Tener en cuenta la puntuacion para una leader board
---

## A4. Reset del héroe al morir
> **¿El héroe siempre resetea a nivel 1 al morir, o hay algún sistema de checkpoint previsto?**

**Respuesta:**
El heroe se retea a nivel 1 con los items que lleve
---

## A5. Progresión permanente
> **¿Existe algún sistema de progresión permanente entre runs, o cada partida empieza desde cero?**

**Respuesta:**
Solo existe una partida, asi que la progresion es el equipo que le demos al heroe. Las mejoras que obtengamos en la armeria
---

## A6. Features del README para MVP
> **¿Los consumibles (pociones), infusiones (fuego/hielo/veneno), el Medidor de Forjamagia, el sistema de Heat, Crit Craft chains y la Entrega QTE descritos en el README están planeados para el MVP o son post-jam?**  
> Se detecta que hay variables de heat/forjamagia en CraftingManager pero la lógica está vacía.

**Respuesta:**
Los consumibles serán opciones donde gastar el oro, igual que algunos materiales. Las infusiones / blueprint apareceran en la mazmorra. El medidor de forja magia está siempre presente en el crafteo de items, el sistema de heat y crit tambien deben estar implementados. La entrega de QTE ya no lo necesitamos. Es un sistema deprecated
---

## A7. Duración target de partida
> **¿Cuál es la duración target de una partida completa?**  
> (¿5 min? ¿15 min? ¿30 min?)

**Respuesta:**
Las partidas se definen por minijuegos, tu juegas tantos minijuegos como quieras el heroe sigue luchando en segundo plano
---

## A8. Fallos en minijuegos
> **¿El jugador puede perder/fallar un minijuego completamente, o siempre produce un resultado (aunque sea de baja calidad)?**

**Respuesta:**
Siempre se produce un resultado aunque la calidad sea 1% 
---

## A9. Impacto del sistema de requests
> **¿El sistema de requests (pedidos de NPCs) tiene algún impacto en gameplay más allá de dar dirección al crafteo?**  
> ¿Hay penalizaciones por ignorarlos?

**Respuesta:**
De momento no hay ningun penalizador por ignorarlo
---

## A10. Dificultad escalada
> **¿Hay algún sistema de dificultad escalada?**  
> ¿Los minijuegos se vuelven más difíciles conforme avanza la run?

**Respuesta:**
Cada vez los enemigos del heroe se vuelven mas dificil y debes tener mas equipo para superarlo. Eso se ve tambien afectado a los minijuegos que serán mas dificil y mas largos donde habrá que encadenar mas combos para obtener de mejor calidad
---

---

# B — Arquitectura y flujo técnico
## B1. Flujo de escenas
> **¿Cuál es el flujo exacto de escenas desde que se abre el juego?**  
> (Investigación confirma: StartScreen.tscn → Main.tscn. ¿Hay Game Over → restart? ¿Victoria → créditos?)

**Respuesta:**
StartScreen - Main (minijuegos, venta de objetos, obtener materiales, dar item al heroe,)
---

## B2. Escenas Main duplicadas
> **¿Por qué existen dos escenas Main (Main.tscn y MainNew.tscn)?**  
> MainNew.tscn usa MainSimplified.gd + HUD_Main.tscn, parece un intento de layout móvil. ¿Cuál es la canónica? ¿Se descarta MainNew?

**Respuesta:**
La que está en el flujo actual es la buena. Creo que es Main. El resto se puede eliminar porque son pruebas
---

## B3. Instancia de Corridor
> **¿El Corridor.tscn se instancia una vez y se reutiliza, o se crea/destruye en cada run?**

**Respuesta:**
Siempre es la misma escena. No hay run como tal. habria que poner una opcion de "borrar todos los datos"
---

## B4. Comunicación Forja-Dungeon
> **¿Cómo fluye la comunicación entre la zona de Forja y la Dungeon?**  
> (Las dos se ejecutan en paralelo: ¿signals? ¿autoloads compartidos? ¿UIManager.switch_area()?)

**Respuesta:**
Se ejecutan a la vez en la misma ventana. Ya no necesitamos el switch_area deprecado era de la JAM
---

## B5. AutoLoads — Responsabilidades

### B5a. GameManager
> **GameManager**: ¿solo estado de la run, o también maneja respawn/death timer?

**Respuesta:**
Deberia tener en cuenta todo esto
---

### B5b. DataManager
> **DataManager**: ¿solo lee datos estáticos, o muta en runtime?

**Respuesta:**
Lo desconozco pero es posible que deba ser mutable para ir guardando los datos
---

### B5c. InventoryManager
> **InventoryManager**: ¿persiste entre runs?

**Respuesta:**
Si, no existen runs como tal
---

### B5d. CraftingManager
> **CraftingManager**: ¿cuántos slots realmente? (código dice 5, GDD dice 3)

**Respuesta:**
Deberia estar separado el crafting manager del request manager. Puede que hay lio con estos dos sistemas
---

### B5e. DebugManager
> **DebugManager**: ¿qué categorías existen y cómo activar/desactivar?

**Respuesta:**
Deberia unificarse a una unico sistemas, ya no hay escenas separadas
---

### B5f. AudioManager
> **AudioManager**: ¿cómo funciona el dual-context FORGE/DUNGEON?

**Respuesta:**
Ahora mismo todo está en un mismo contexto, tendremos que diseñar el sonido respecto a eso
---

### B5g. TelemetryManager
> **TelemetryManager**: ¿qué eventos se loguean y en qué formato?

**Respuesta:**
De momento nada
---

### B5h. UIManager
> **UIManager**: ¿qué paneles registra y cómo gestiona área switching?

**Respuesta:**
Ya no hace falta el area switching
---

### B5i. RequestManager
> **RequestManager**: ¿cómo genera requests? ¿Timer? ¿Evento?

**Respuesta:**
Deberia ir por timer para ir poniendo mas pedidos pero tambien necesitamos meter eventos prefijados para partes de "historia"
---

## B6. Diagrama de flujo de señales
> **¿Hay algún diagrama de flujo de señales entre autoloads?**  
> Si no, ¿cuáles son las dependencias cruzadas más importantes?

**Respuesta:**
No, sería interesante generarlo
---

## B7. Ciclo de vida de minijuegos
> **¿Cómo se maneja el ciclo de vida de los minijuegos?**  
> (instanciar → start_trial() → jugar → trial_completed() → liberar. ¿Quién libera la escena? ¿MinigameContainer? ¿HUDMinigameLauncher?)

**Respuesta:**
Habrá que montar un sistema robusto para gestionar esto
---

## B8. Room.tscn obsoleto
> **¿Room.tscn está efectivamente obsoleto?**  
> Si sí, ¿por qué sigue en el repo?

**Respuesta:**
Necesidad de eliminar
---

---

# C — Sistema de combate y dungeon
## C1. Sistema de hit-frames
> **¿Cómo funciona el sistema de hit-frames?**  
> (CombatController escucha hit_frame_reached del spritesheet. ¿Qué determina cuál frame es el "hit frame"?)

**Respuesta:**
Quiero simplificar este sistema a formas geometricas, sistemas de golpes basados en cooldown al estar a rango los enemigos
---

## C2. Cálculo de stats
> **¿Cómo se calculan las stats del héroe?**  
> (InventoryManager.get_total_stats() suma stats base + equipment. ¿Cuáles son las stats base del héroe? ¿Cómo escalan las del enemigo por nivel?)

**Respuesta:**
El heroe escala segun los objetos que tenga, a mas objetos mejores estadisticas y poderes
Para los enemigos necesitamos crear un sistema de formulas de escalado por nivel para un escalado infinito
---

## C3. Sistema de daño
> **¿Hay algún sistema de tipos de daño o resistencias, o es puro HP vs ATK?**

**Respuesta:**
Necesitamos crear un sistema de tipos de daños. Tengo varias ideas. Un sistema de armaduras parecido a warcraf3
Fortificada, pesada, ligera, heroe, divina con sus daños correspondients segun el tipo de daño siege, perforante, cortante, caos
---

## C4. Sistema de drops
> **¿Cómo funciona el sistema de drops?**  
> (DropTable.gd + DropEntry.gd. ¿Los enemigos dan materiales al morir? ¿Cómo se integra con InventoryManager?)

**Respuesta:**
Los enemigos solo dropean blueprints y infusiones elementales. Cuando el player pulse en esos items los obtendrá en su inventario. 
Necesitamos el inventario de materiales y luego el stash de objetos crafteados
---

## C5. Mecánicas del boss
> **¿El boss (level 9, tank type) tiene mecánicas especiales o es solo un enemigo con más stats?**

**Respuesta:**
Es un personaje con mas stats. Tendrá una habilidad pasiva, se diseñará un pool para el escado infinito. Cuando salgan todos las del pool entonces pasarán a tener 2 pasivas, cuando salgan todas las combinaciones, 3 pasivas y asi..
---

## C6. Animaciones del héroe
> **¿Qué animaciones tiene el héroe y cómo se gestionan?**  
> (Investigación revela: spritesheets con 14 strips a distintos FPS. ¿Hay una tabla de qué strip va con qué acción?)

**Respuesta:**
Quiero simplificarlo mucho el sistema de combate. Formas geometricas y ataques por CD.
---

## C7. Parallax del corredor
> **¿El parallax del corredor es solo visual o afecta gameplay?**

**Respuesta:**
El parallax solo es visual es para que se ve que el heroe está avanzando por algun lado
---

---

# D — Sistema de crafteo

## D1. Flujo completo de crafteo
> **¿Cuál es el flujo completo de crafteo paso a paso?**  
> (Request → accept → enqueue → start → trial 1 → trial 2 → ... → finalize → CraftedItem → deliver)

**Respuesta:**
Request → accept → enqueue → start → trial 1 → trial 2 → ... → finalize → CraftedItem → deliver. Teniendo en cuenta todo el rato el nivel de pureza del objeto con el nivel de forjamagia
---

## D2. Cantidad de trials por blueprint
> **¿Cuántos trials tiene cada blueprint?**  
> (¿Siempre es la secuencia completa forge→hammer→sew→quench, o varía por blueprint?)

**Respuesta:**
Varia segun blueprint, cada prueba se le puede/debe pasar una peticion la secuencia y luego cada prueba su tipo
---

## D3. Cálculo de calidad final
> **¿Cómo se calcula la calidad final del item?**  
> (CraftingManager._finalize_task() agrega scores de todos los trials. ¿Es un promedio? ¿Hay pesos por trial?)

**Respuesta:**
Debberia ser una puntuacion total calculada en el mismo blueprint, imagina que un blueprint tiene 2 pruebas y puedes conseguir maximos 50 puntos(me lo estoy inventnado) si lo haces perfecto sacarás el 100% asi se calcula la calidad. Si tiene 6 pruebas entonces sumará X puntos y necesitaras acertar muchas mas secuencias seguidas
--- 

## D4. Propiedades de materiales
> **¿Los materiales tienen propiedades únicas que afecten al crafteo, o son solo requisitos para desbloquear el blueprint?**

**Respuesta:**
Los materiales estan relacionados un poco con las pruebas que harás. Normalmente metal pasará por la prueba de la forja y las telas o cueros por la de coser. Puede que un blueprint combine varios tipos de materiales
---

## D5. Grados de calificación
> **¿Los grados del sistema de calificación (Perfect/Bien/Regular/Miss) mapean a thresholds numéricos consistentes en los 4 minijuegos?**

**Respuesta:**
Deberia tener un sistema de calculo perfecto para esto
---

## D6. Delivery
> **¿El sistema de delivery (entregar items al héroe) tiene algún delay, QTE, o es instantáneo?**

**Respuesta:**
Dberia ser instanteo, simplemente pulsando un boton se abrirá el modal donde se puede equipar al heroe
---

## D7. Slots de equipment
> **¿Qué slots de equipment tiene el héroe?**  
> (Se ven: weapon, shield, helmet, boots en los blueprints. ¿Hay body/armor?)

**Respuesta:**
Main hand, off hand, helmet, chest , boots , 2 trinkets
---

## D8. Reemplazo de items
> **¿Se puede reemplazar un item ya equipado?**  
> ¿Se pierde el anterior?

**Respuesta:**
Cuando se reemplaza un item el anteior se pierde
---

---

# E — Minijuegos
## E1. TrialConfig tipados
> **¿Cada minijuego tiene su propio TrialConfig tipado?**  
> (ForgeTrialConfig, HammerTrialConfig, SewTrialConfig, QuenchTrialConfig. ¿Qué parámetros expone cada uno?)

**Respuesta:**
Cada una de las pruebas tiene diferentes tipos de parametros, habria que unificarlos en la medida de los posible. Por ejemplo algunas como la velocidad o el punto dulce de las pruebas se puede modificar
---

## E2. Minijuego Forge (ForgeTemp)
> **¿Cómo funciona el cursor senoidal? ¿Qué es "3 aciertos en zona target"?**  
> ¿Es un timing o un click en zona?

**Respuesta:**
Es un timing 
---

## E3. Minijuego Hammer (HammerMinigame)
> **¿Es como un rhythm game con BPM?**  
> ¿Cuántas notas por trial?

**Respuesta:**
Debe ser un parametro que se debe poder cambiar segun la calidad del blueprint
---

## E4. Minijuego Sew (SewOSU)
> **¿Cuántos puntos tiene? ¿Cómo se genera su posición (random vs predefinida)?**  
> ¿Qué es el sistema de hilo/puntada visual?

**Respuesta:**
Son parametros, Hay varias posiciones predefinidas para poder genera patrones de cosido. La prueba la quiero simplificar, quiero quitar el hecho de que tengas que pulsar los puntos. Quiero que sea de timing tambien esta prueba 
---

## E5. Minijuego Quench (QuenchWater)
> **¿Es un solo click de timing?**  
> ¿Qué es el catalizador que amplía ventana +20%?

**Respuesta:**
Es una prueba de soltar. Es decir se pulsa y se va metiendo en el agua y al soltar es cuando se para. Esta prueba tambien deberia tener sus parametros
---

## E6. Pantallas de minijuegos
> **¿Los minijuegos tienen pantalla de título y fin integradas?**  
> ¿Cómo se manejan las transiciones (fade in/out)?

**Respuesta:**
Los minijuegos solo deben tener una pantalla de titulo. Por ejemplo Hammer time! que luego se desvanezca con una animacion suave. Pero solamente el texto. 
Por otro lado, al final no debe ocurrir nada. Solo es al final de TODAS las pruebas cuando debe salir el fin con el calculo de la calidad del objeto crafteado. Esta parte es importante quiero hacer algo visualmente potente rellenando un barra vertical con animaciones
---

## E7. Sistema anti-spam
> **¿Qué es el sistema anti-spam de MinigameBase?**  
> ¿Cómo previene clicks rápidos?

**Respuesta:**
No se previene, ademas no deberia ser clicks sino touch. Juego de android
---

## E8. Dificultad de minijuegos
> **¿MinigameDifficultyPreset.gd genera configs automáticas o se editan a mano?**

**Respuesta:**
Ahora mismo a mano, pero deberiamos tener la posibilidad de hacer un sistema que calculo automatico
---

---

# F — Interfaz de usuario

## F1. Layout target
> **¿Cuál es el layout target actual?**  
> (project.godot dice 1080x1920 portrait. ¿Es para móvil? ¿Desktop? El copilot-instructions dice 1280x720 desktop.)

**Respuesta:**
Es para movil. Hay que actualizar el copilot-instructions con toda esta informacion. Además de la información de que en esta ruta D:\Proyectos\PetJam\.agent\skills hay skills relacionada con buenas practicas, mobile y game development
---

## F2. Organización HUD principal
> **¿Cómo está organizado el HUD principal?**  
> (HUD_Forge.tscn contiene: ¿panel de blueprints, cola de crafteo, requests, MinigameContainer, botón de cambio a dungeon?)

**Respuesta:**
El hud tiene arriba del todo el heroe luchando vs los enemigos. Luego tiene una zona idle que es donde se podran los miniujuegos. Abajo hay 2 paneles con los request y botones que permite ver los blueprint, ver el inventario del heroe y la tienda de materiales y pociones 
---

## F3. DungeonStatus.tscn
> **¿Qué muestra el DungeonStatus.tscn?**  
> (¿barra de HP del héroe, nivel actual, muertes?)

**Respuesta:**
No deberia, deberia estar unificado con la otra escena del heroe. La vida deberia aparecer encima del heroe. En el centro arriba las muerts y No hay nivel de heroe
---

## F4. MinigameContainer
> **¿Cómo funciona el MinigameContainer?**  
> (¿Es un SubViewport con shader circular? ¿Cómo se dimensiona?)

**Respuesta:**
Tiene un shader que oculta los bordes para que quede mas unificado
---

## F5. BlueprintLibraryPanel
> **¿El BlueprintLibraryPanel muestra todos los blueprints o solo los desbloqueados?**

**Respuesta:**
Muestra todos los blueprints pero los bloqueados deben salir con un candado y en gris hasta que sean desbloqueados
---

## F6. DeliveryPanel
> **¿Cómo funciona el DeliveryPanel?**  
> (¿Drag&drop? ¿Click? ¿Se abre automáticamente al crafear?)

**Respuesta:**
No se abre automaticamente, hay un boton que debe abrir ese panel o del inventario del heroe (el otro está deprecated), osea que el jugador puede acceder cuando quiera. En este panel deberia poder equipar los objetos al heroe
---

## F7. Accesibilidad y controles
> **¿Hay soporte de accesibilidad o controles de teclado?**  
> (copilot-instructions dice "Espacio confirma en minijuegos")

**Respuesta:**
Quiero que sea para android, por cuestion de testeo tambien que funcione con raton pero no nos hace falta mas controles
---

## F8. Paneles UIManager
> **¿Qué paneles registra UIManager y en qué orden se muestran?**

**Respuesta:**
Deberia registrar todos. Tener un control desde el UI manager de todo. Sistema robusto
---

## F9. EquipmentPanel
> **¿EquipmentPanel es funcional o WIP?**  
> ¿Cómo se visualiza el loadout del héroe?

**Respuesta:**
Está completamente wip, muchas partes no funcionan como aumentar las estadisticas del heroe segun los items
---

---

# G — Audio y efectos

## G1. Dual-context AudioManager
> **¿Cómo funciona el dual-context de AudioManager?**  
> (¿Suena música de forja mientras estás en forja, y dungeon ambient en dungeon? ¿Crossfade?)

**Respuesta:**
Hay un unico contexto ahora. Simplificarlo todo el sonido funcionará la vez 
---

## G2. SFX por minijuego
> **¿Qué SFX hay por minijuego?**  
> (minigame_sounds_default.tres, minigame_sounds_hammer.tres. ¿Hay sets para sew y quench?)

**Respuesta:**
Cada minijuego tiene su propio SFX y luego hay SFX comunes como la calidad, aciertos y errores
---

## G3. MinigameAudio y MinigameFX
> **¿MinigameAudio.gd y MinigameFX.gd son independientes o trabajan juntos?**  
> ¿Quién los instancia?

**Respuesta:**
Deberia trabajar juntos
---

## G4. Voces del herrero
> **¿Hay voces/comentarios del herrero o todo es SFX?**

**Respuesta:**
Solo SFX, en el futuro quizás ponga un narrador para explicar el juego,tutoriales
---

---

# H — Datos y recursos
## H1. Estructura BlueprintResource
> **¿Cómo se estructura un BlueprintResource?**  
> (¿Qué campos tiene? trial_sequence, materials_required, icon, equipment_slot, stats?)

**Respuesta:**
Todos esos que dices efectivamente. Las estadisticas no se si estan implementadas pero hace falta para añadirselas al heroe
---

## H2. ItemResource vs CraftedItem
> **¿Los ItemResource son el "template" del item y CraftedItem es la instancia con calidad?**

**Respuesta:**
Es correcto. Compruebalo si es necesario
---

## H3. Desbloqueo de blueprints
> **¿Cómo se desbloquean blueprints?**  
> (GameManager emite algo al matar un enemigo por primera vez. ¿Es automático o el jugador elige?)

**Respuesta:**
Los blueprints se desbloquean al eliminar enemigos por primera vez.
---

## H4. Blueprints vs ItemResources
> **¿Por qué hay 15 blueprints pero solo 12 ItemResources?**  
> ¿Faltan items por crear?

**Respuesta:**
Faltan items por crear
---

## H5. MaterialResource
> **¿MaterialResource tiene propiedades especiales (rareza, efecto) o solo nombre + icono?**

**Respuesta:**
Los materiales pueden ser especiales (las infusiones que añaden dificultad a las recetas y una encantamiento al arma)
---

---

# I — Convenciones de desarrollo

## I1. Nombres de archivos
> **¿Cómo se nombran archivos, clases y señales?**  
> (Confirmado: archivos snake_case, clases PascalCase, señales lower_snake_case. ¿Hay excepciones?)

**Respuesta:**
Comprobar  D:\Proyectos\PetJam\.agent\skills\godot-gdscript-patterns\SKILL.md
---  

## I2. Onboarding para contribuidores
> **¿Qué debe hacer un nuevo contributor para empezar?**  
> (Clonar, abrir en Godot 4.5.1, los autoloads ya están en project.godot...)

**Respuesta:**
Trabajar sobre el proyecto
---

## I3. Añadir nuevo blueprint
> **¿Cómo se añade un nuevo blueprint?**  
> (¿Crear .tres a mano? ¿Usar editor scripts?)

**Respuesta:**
Crea una escena para creacion de pruebas porque se hacen a mano y necesitamos tener un buen flujo de trabajo
---

## I4. Añadir nuevo minijuego
> **¿Cómo se añade un nuevo minijuego?**  
> (Extender MinigameBase, implementar start_trial/trial_completed, crear escena .tscn, registrar en ¿dónde?)

**Respuesta:**
No se a que te refieres con esta pregunta
---

## I5. Testing de minijuego aislado
> **¿Cómo se prueba un minijuego aislado?**  
> (¿Sandboxes? ¿DebugManager? ¿Atajo de teclado?)

**Respuesta:**
Por las escenas individuales. Debemos tener un sistema para poder probar los minijuegos con distintos tipos de trials 
---

## I6. DebugManager en autorun
> **¿Qué hace el DebugManager en modo * (autorun enabled)?**  
> ¿Cómo se activa/desactiva?

**Respuesta:**
Tiene un boton para activarlo y desactivarlo
---

## I7. Flujo de export
> **¿Cuál es el flujo de export?**  
> (export_build.ps1 + export_presets.cfg. ¿Desktop solo? ¿Web? ¿Móvil?)

**Respuesta:**
La idea es que el juego sea para movil. Solo desarrollo en pc
---

---

# J — Estado actual y roadmap

## J1. Estado de Roadmap
> **¿Cuál es el estado real del Roadmap?**  
> (ROADMAP.md dice Fase 0-2 completas, Fase 3 "Mobile Ready" pendiente. ¿Es correcto?)

**Respuesta:**
Realmente no hay nada completado. Estamos en la fase de crear los fundamentos del juego y continuar con el desarrollo de la JAM
---

## J2. MainNew y Fase 3
> **¿MainNew.tscn + HUD_Main.tscn son parte de la Fase 3 o se descartaron?**

**Respuesta:**
Son pruebas probablemente 
---

## J3. Features no implementadas
> **¿Qué features del GDD NO están implementadas y NO se van a implementar en el MVP?**

**Respuesta:**
Recopila toda la info de este doc, para saber cómo está
---

## J4. Bugs conocidos
> **¿Hay bugs conocidos actualmente?**

**Respuesta:**
Bastantes y relacionados con el heroe y el sistema de sprites que quiero simplificar a formas geometricas como te comentaba 
---

## J5. Testing en móvil
> **¿Se ha probado en dispositivo móvil real?**  
> ¿Cuáles fueron los resultados?

**Respuesta:**
No, nisuiqiera se ha compilado, necesitamos aun algunas fundamentos
---

## J6. Plataformas de distribución
> **¿Qué plataformas de distribución se contemplan?**  
> (Itch.io, Google Play, solo compartir .exe?)

**Respuesta:**
Google play
---