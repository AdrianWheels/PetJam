# Primer lote de arte ilustrado

Generado el 2 de octubre de 2026 con la herramienta integrada `image_gen` de Codex. Referencias: las espadas antiguas `art/assets/Imagenes/Items/sword_basic.png` y `sword_masterwork.png`. Los prompts exactos están en los archivos `prompt_*.txt` de esta carpeta.

## Entregables

- `sword_basic.png`: espada básica vertical, con fondo transparente.
- `hammer.png`: primer concepto de martillo, con mango largo.
- `hammer_fit.png`: variante seleccionada de martillo, proporcionada para una T de 3×2, con cuatro casillas ocupadas. Es una propuesta de arma futura, sin estadísticas ni receta nuevas.
- `tico.png`: Tico ilustrado, mirando a la derecha, con bufanda roja, cuero y espada básica; una pose.
- `skeleton.png`: esqueleto ilustrado, mirando a la izquierda, con espada gastada; una pose.
- `catacombs.png`: fondo lateral de Catacumbas; una imagen completa, todavía sin capas separadas de parallax ni continuidad certificada entre extremos.
- `forge.png`: estación de martillo con horno, yunque y herramientas.
- `preview.png`: captura de la escena de Godot a 540×960.
- `preview_rotation_1.png`: comprobación visual del giro de las dos piezas.
- `demo/`: proyecto de Godot autónomo que consume estos originales y monta la muestra.

## Ver la muestra

Abrir `demo/project.godot` en Godot y ejecutar. También se puede lanzar desde PowerShell:

```powershell
& 'D:/Software/Godot/godot.exe' --path 'D:/Proyectos/PetJam/art/pilot_illustrated_2026_10_02/demo'
```

Los botones permiten girar las dos armas, mostrar/ocultar sus casillas y cambiar el color del marco. Se utiliza la escala actual de inventario, 110 px por casilla en un lienzo de 1080×1920. La muestra no altera guardados, recetas ni el arranque del juego principal.

## Resultado y límites

El lote conserva el trazo irregular, metal azul grisáceo, reflejos rojizos y cuero desaturado de las armas antiguas. El martillo comparte materiales y explica su T. Los personajes se reconocen sobre el fondo oscuro y conservan una escala común en la muestra.

La espada necesita una composición específica para el icono compacto: el detalle del original se pierde al reducirla a dos casillas. El ajuste del martillo tiene un halo suave residual que conviene eliminar en la limpieza final. La correspondencia de su ilustración con la huella se revisa visualmente; aún no es una textura final enmascarada para producción.

Los personajes tienen la espada incorporada en la pose y todavía no están separados en capas ni animados. El taller es una composición de revisión, no el minijuego interactivo de martillo. Faltan plano del objeto, aristas, variantes de calidad definitivas, otros objetos y materiales, resto del elenco, otros cuatro biomas, interfaz completa y efectos. Este lote realiza la muestra inicial del plan; no completa todo el catálogo.

## Comprobación

Carga de las seis imágenes seleccionadas y recorrido de los cuatro giros en Godot, más render y revisión de las capturas. Transparencia comprobada en los cuatro recortes de objetos/personajes; fondos opacos. Prompts y originales conservados en el proyecto.

Siguiente lote: simplificar icono de espada, limpiar martillo y separar/animar las capas de Tico. Después aplicar el acabado confirmado a las 12 piezas activas antes de extender las armas futuras.
