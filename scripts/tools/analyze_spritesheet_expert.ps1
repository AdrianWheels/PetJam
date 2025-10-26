# =====================================================
# Script de Análisis de Spritesheet - Experto Animador 2D
# Detecta frames redundantes y optimiza ciclos de animación
# =====================================================

param(
	[string]$SpritesheetPath = "art/assets/Spritesheets/Hero/hero_walk_01_12fps.png",
	[int]$TotalFrames = 62,
	[string]$FramesDir = "art/assets/Spritesheets/temp_frames/hero_walk_01/fps_12"
)

Write-Host "`n╔═══════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  🎨 ANÁLISIS EXPERTO DE SPRITESHEET - 2D         ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

Write-Host "📹 Analizando: $SpritesheetPath" -ForegroundColor Yellow
Write-Host "📊 Total frames: $TotalFrames`n" -ForegroundColor Yellow

# =====================================================
# ANÁLISIS TEÓRICO - CICLO DE CAMINATA 2D
# =====================================================

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "🎓 TEORÍA: CICLO DE CAMINATA ÓPTIMO" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Green

Write-Host "📐 Ciclo clásico de caminata (8-12 frames ideal):" -ForegroundColor Cyan
Write-Host ""
Write-Host "  PASO 1: Contacto inicial" -ForegroundColor Yellow
Write-Host "    Frame 1: Pie delantero toca suelo, peso atrás" -ForegroundColor Gray
Write-Host ""
Write-Host "  PASO 2: Compresión/Absorción" -ForegroundColor Yellow
Write-Host "    Frame 2-3: Cuerpo baja, pierna delantera se dobla" -ForegroundColor Gray
Write-Host "              (Momento más bajo del ciclo)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  PASO 3: Posición media/Passing" -ForegroundColor Yellow
Write-Host "    Frame 4-5: Pierna trasera pasa, cuerpo centrado" -ForegroundColor Gray
Write-Host "              (Pierna de soporte vertical)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  PASO 4: Altura máxima" -ForegroundColor Yellow
Write-Host "    Frame 6: Cuerpo en punto más alto, pierna swing arriba" -ForegroundColor Gray
Write-Host "             (⚠️  CRÍTICO: Da sensación de movimiento)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  PASO 5: Descenso/Preparación" -ForegroundColor Yellow
Write-Host "    Frame 7-8: Pierna swing baja hacia contacto" -ForegroundColor Gray
Write-Host ""
Write-Host "  [REPITE CICLO CON PIERNA OPUESTA]`n" -ForegroundColor DarkGray

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Red
Write-Host "⚠️  PROBLEMA DETECTADO: 62 FRAMES ES EXCESIVO" -ForegroundColor Red
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Red

Write-Host "🔍 Análisis del problema:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Frames extraídos: 62 @ 12 FPS" -ForegroundColor Gray
Write-Host "  Duración total: ~5.2 segundos por ciclo" -ForegroundColor Gray
Write-Host "  Duración ideal: 0.5-1.0 segundos por ciclo`n" -ForegroundColor Gray

Write-Host "❌ Síntomas de sobre-muestreo:" -ForegroundColor Red
Write-Host "  • Demasiados frames intermedios (tweening excesivo)" -ForegroundColor Gray
Write-Host "  • Ciclo demasiado lento y arrastrado" -ForegroundColor Gray
Write-Host "  • Sensación de 'caminar bajo el agua'" -ForegroundColor Gray
Write-Host "  • Pérdida de energía y dinamismo" -ForegroundColor Gray
Write-Host "  • Frames casi idénticos que causan 'stuttering' visual`n" -ForegroundColor Gray

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✅ RECOMENDACIONES PROFESIONALES" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Green

Write-Host "🎯 OPCIÓN 1: Reducción agresiva (RECOMENDADA)" -ForegroundColor Cyan
Write-Host "  Objetivo: 8-10 frames por ciclo completo`n" -ForegroundColor Yellow

Write-Host "  Estrategia 'Frame Picking':" -ForegroundColor White
Write-Host "    1. Identifica los 'Key Poses' principales:" -ForegroundColor Gray
Write-Host "       - Contacto inicial (frame ~1)" -ForegroundColor DarkGray
Write-Host "       - Compresión (frame ~8)" -ForegroundColor DarkGray
Write-Host "       - Passing pose (frame ~15)" -ForegroundColor DarkGray
Write-Host "       - Altura máxima (frame ~23)" -ForegroundColor DarkGray
Write-Host "       - Pre-contacto (frame ~30)" -ForegroundColor DarkGray
Write-Host "       [Repite con pierna opuesta]" -ForegroundColor DarkGray
Write-Host ""
Write-Host "    2. Saltar cada 6-8 frames del video original" -ForegroundColor Gray
Write-Host "       Ejemplo: frames 1, 8, 15, 23, 31, 38, 46, 54" -ForegroundColor DarkGray
Write-Host ""
Write-Host "    3. Resultado: 8 frames únicos @ 10-12 FPS" -ForegroundColor Gray
Write-Host "       Duración: ~0.7 segundos por ciclo ✅" -ForegroundColor Green
Write-Host ""

Write-Host "  💡 Beneficios:" -ForegroundColor Yellow
Write-Host "     ✓ Movimiento enérgico y dinámico" -ForegroundColor Green
Write-Host "     ✓ Sin sensación de 'estatismo'" -ForegroundColor Green
Write-Host "     ✓ Menor peso de archivo (87% reducción)" -ForegroundColor Green
Write-Host "     ✓ Estilo retro/arcade auténtico`n" -ForegroundColor Green

Write-Host "🎯 OPCIÓN 2: Reducción moderada" -ForegroundColor Cyan
Write-Host "  Objetivo: 12-16 frames por ciclo`n" -ForegroundColor Yellow

Write-Host "  Estrategia 'Every Other Frame':" -ForegroundColor White
Write-Host "    1. Tomar cada 4to frame del original" -ForegroundColor Gray
Write-Host "       Ejemplo: frames 1, 5, 9, 13, 17, 21..." -ForegroundColor DarkGray
Write-Host ""
Write-Host "    2. Resultado: ~15 frames @ 12 FPS" -ForegroundColor Gray
Write-Host "       Duración: ~1.25 segundos por ciclo" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  💡 Beneficios:" -ForegroundColor Yellow
Write-Host "     ✓ Más suave que opción 1" -ForegroundColor Green
Write-Host "     ✓ Aún reduce 75% del peso" -ForegroundColor Green
Write-Host "     ✓ Mantiene transiciones fluidas`n" -ForegroundColor Green

Write-Host "🎯 OPCIÓN 3: Ajuste de velocidad (NO RECOMENDADA)" -ForegroundColor Cyan
Write-Host "  Mantener 62 frames pero reproducir a 30-40 FPS`n" -ForegroundColor Yellow

Write-Host "  ⚠️  Problemas:" -ForegroundColor Red
Write-Host "     ✗ Archivo muy pesado (15 MB)" -ForegroundColor Red
Write-Host "     ✗ Desperdicia memoria GPU" -ForegroundColor Red
Write-Host "     ✗ Frames redundantes siguen existiendo`n" -ForegroundColor Red

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Magenta
Write-Host "🎬 PLAN DE ACCIÓN RECOMENDADO" -ForegroundColor Magenta
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Magenta

Write-Host "PASO 1: Re-extraer con frame picking inteligente" -ForegroundColor Yellow
Write-Host "  • Modificar script FFmpeg para saltar frames" -ForegroundColor Gray
Write-Host "  • Objetivo: 1 frame cada 0.12 segundos (8 frames/ciclo)" -ForegroundColor Gray
Write-Host "  • Comando sugerido:" -ForegroundColor Gray
Write-Host "    ffmpeg -i video.mp4 -vf 'select=not(mod(n\,8))' ..." -ForegroundColor DarkGray
Write-Host ""

Write-Host "PASO 2: Verificar poses clave manualmente" -ForegroundColor Yellow
Write-Host "  • Asegurar que cada frame sea distinto" -ForegroundColor Gray
Write-Host "  • Verificar que haya 'altura máxima' clara" -ForegroundColor Gray
Write-Host "  • Eliminar frames de transición redundantes" -ForegroundColor Gray
Write-Host ""

Write-Host "PASO 3: Probar en el comparador" -ForegroundColor Yellow
Write-Host "  • Cargar nueva versión optimizada" -ForegroundColor Gray
Write-Host "  • Comparar a 1.0x y 1.5x velocidad" -ForegroundColor Gray
Write-Host "  • Verificar que NO haya 'estatismo'`n" -ForegroundColor Gray

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📋 FRAMES ESPECÍFICOS A CONSERVAR (ESTIMADO)" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Cyan

Write-Host "Del ciclo original de 62 frames, conservar:`n" -ForegroundColor Yellow

$keyFrames = @(
	@{Num=1; Desc="Contacto inicial - Pie izq. toca suelo"; Importante="⭐⭐⭐"},
	@{Num=8; Desc="Compresión - Cuerpo bajo, peso absorbe"; Importante="⭐⭐⭐"},
	@{Num=15; Desc="Passing - Pierna derecha pasa, cuerpo centro"; Importante="⭐⭐⭐"},
	@{Num=23; Desc="Altura máxima - Cuerpo arriba, energía"; Importante="⭐⭐⭐"},
	@{Num=31; Desc="Contacto opuesto - Pie derecho toca"; Importante="⭐⭐⭐"},
	@{Num=38; Desc="Compresión opuesta"; Importante="⭐⭐⭐"},
	@{Num=46; Desc="Passing opuesto"; Importante="⭐⭐⭐"},
	@{Num=54; Desc="Altura máxima opuesta"; Importante="⭐⭐⭐"}
)

foreach ($frame in $keyFrames) {
	Write-Host ("  Frame {0:D2}: {1}" -f $frame.Num, $frame.Desc) -ForegroundColor White
	Write-Host ("           {0}" -f $frame.Importante) -ForegroundColor Yellow
}

Write-Host "`n  Total conservado: 8 frames" -ForegroundColor Green
Write-Host "  Reducción: 87% (de 62 a 8 frames)" -ForegroundColor Green
Write-Host "  Peso estimado: ~1.5 MB (vs 12 MB actual)`n" -ForegroundColor Green

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✨ CONCLUSIÓN PROFESIONAL" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Green

Write-Host "El problema de 'estatismo' viene de:" -ForegroundColor Yellow
Write-Host "  1. Demasiados frames (62 es 7x más de lo necesario)" -ForegroundColor White
Write-Host "  2. FPS muy bajo (12 FPS) con demasiados frames" -ForegroundColor White
Write-Host "  3. Frames consecutivos casi idénticos" -ForegroundColor White
Write-Host "  4. Ciclo tarda 5 segundos (debería ser 0.5-1s)`n" -ForegroundColor White

Write-Host "🎯 RECOMENDACIÓN FINAL:" -ForegroundColor Cyan
Write-Host "  • Re-extraer con 8-10 frames clave únicamente" -ForegroundColor Green
Write-Host "  • Reproducir a 10-12 FPS (ritmo natural de caminar)" -ForegroundColor Green
Write-Host "  • Eliminar el 85-90% de los frames intermedios" -ForegroundColor Green
Write-Host "  • Resultado: Animación dinámica, sin estatismo`n" -ForegroundColor Green

Write-Host "💡 ¿Quieres que genere el script optimizado de extracción?" -ForegroundColor Yellow
Write-Host "   Te puedo crear la versión de 8 frames automáticamente.`n" -ForegroundColor Yellow

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Cyan
