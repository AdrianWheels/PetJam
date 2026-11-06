# Notas de prueba y revisión de PetJam

Fecha: 2 de octubre de 2026. Documento de conversación y propuestas; no implica aprobación de implementación.

## Observaciones y preferencias del usuario

- Los fondos de botones, marcos y paneles ocupan demasiado espacio. Dar protagonismo a iconos grandes y reconocibles; reducir el peso de los contenedores.
- La tienda es demasiado voluminosa. Simplificar y compactar su presentación.
- Hay dos espacios que se perciben como mochilas: el botín físico y una mochila adicional. El usuario quiere eliminar la adicional y conservar el espacio físico.
- Girar piezas con el botón secundario del ratón, no con el principal. El principal debe permitir seleccionar y arrastrar.
- En móvil, buscar un gesto cómodo para girar mientras se mantiene la pieza pulsada. El usuario aún no ha elegido el gesto exacto.
- Tico y la herrera se ven minúsculos. Aumentar su protagonismo visual.
- Tico debería ocupar aproximadamente el 90 % de la altura de la zona de mazmorra.
- Combate con presentación tipo VS: Tico y el enemigo frente a frente en posiciones fijas, sin desplazamiento por el corredor y con sus animaciones. Esto no supone eliminar movimientos locales propios de las animaciones.
- No se ha concretado todavía el tamaño objetivo de la herrera ni del enemigo.
- Anotar todo y presentar los puntos antes de implementar.

## Feedback de la prueba del asistente

- La herrería tiene personalidad y buena ambientación, con iluminación cálida y una composición coherente.
- Fabricar mientras Tico combate aporta actividad constante.
- Las formas de las piezas en la cuadrícula introducen decisiones sobre el espacio.
- Mejorar legibilidad de ingredientes, estadísticas y recetas: mayor tamaño y contraste; reservar la fuente ornamental para títulos.
- Mejorar feedback de colocación: previsualización clara y explicación cuando una pieza no cabe. El primer arrastre probado volvió al botín; el segundo funcionó.
- Mostrar comparación de atributos para entender cuánto mejora o empeora una pieza el equipo actual.
- Integrar visualmente la forja: el fondo gris del minijuego rompe la continuidad con la herrería ilustrada.
- Evitar superposición de nombres y cifras de daño en combate.
- Explicar mejor las muertes, el retroceso de salas y qué mejoras podrían ayudar.

## Propuestas del asistente pendientes de validar

- Iconos grandes con etiquetas cortas y zonas cómodas para pulsar, reduciendo los grandes fondos rectangulares.
- Tienda en filas compactas con icono, cantidad y precio.
- Equipo de Tico y botín físico como únicas zonas de piezas; trasladar al botín los objetos de la mochila eliminada al cargar partidas, sin perderlos.
- Clic derecho para girar también durante el arrastre.
- En móvil, segundo dedo para girar mientras el primero arrastra. El código actual ya contempla ese gesto; falta decidir si será la interacción final.

## Contexto y límites de la prueba

- Se probó una partida avanzada, alrededor de la sala 82; no se evaluó el tutorial.
- Se aceptó un pedido, se fabricó un casco, se guardó en la mochila y se exploraron equipo, planos y tienda.
- El control remoto añade retraso, por lo que la puntuación de forja no permite juzgar su dificultad.
- No se modificó el código del juego durante esta revisión.
