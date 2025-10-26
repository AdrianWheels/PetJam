# =====================================================
# Script de Extracción OPTIMIZADA - Frame Picking Inteligente
# Extrae solo KEY POSES para animación dinámica
# =====================================================

param(
	[string]$InputVideo = "art/assets/Animaciones/Hero/Walk/hero_walk_01.mp4",
	[int]$KeyFramesCount = 8,  # Número de poses clave por ciclo
	[string]$OutputName = "hero_walk_optimized"
)

Write-Host "`n╔═══════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  🎨 EXTRACCIÓN OPTIMIZADA - KEY POSES ONLY       ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════╝`n" -ForegroundColor Green

# Verificar FFmpeg
$ffmpegPath = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not $ffmpegPath) {
	Write-Host "❌ FFmpeg no encontrado" -ForegroundColor Red
	exit 1
}

# Verificar video
if (-not (Test-Path $InputVideo)) {
	Write-Host "❌ Video no encontrado: $InputVideo" -ForegroundColor Red
	exit 1
}

Write-Host "📹 Video: $InputVideo" -ForegroundColor Cyan
Write-Host "🎯 Objetivo: $KeyFramesCount frames clave`n" -ForegroundColor Cyan

# Obtener info del video
$videoInfo = ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets,r_frame_rate,width,height,duration -of csv=p=0 $InputVideo
$videoInfoParts = $videoInfo -split ","
$totalFrames = [int]$videoInfoParts[0]

# Parsear frame rate (puede venir como fracción "30/1" o "29.97")
$frameRateRaw = $videoInfoParts[1]
if ($frameRateRaw -match "(\d+)/(\d+)") {
	$frameRate = [double]$matches[1] / [double]$matches[2]
} else {
	$frameRate = [double]$frameRateRaw
}

$width = [int]$videoInfoParts[2]
$height = [int]$videoInfoParts[3]

Write-Host "📊 Información del video:" -ForegroundColor Yellow
Write-Host "  Total frames: $totalFrames" -ForegroundColor Gray
Write-Host "  Frame rate: $([math]::Round($frameRate, 2)) fps" -ForegroundColor Gray
Write-Host "  Resolución: ${width}x${height}`n" -ForegroundColor Gray

# Calcular intervalo de frames a extraer
$frameInterval = [math]::Floor($totalFrames / $KeyFramesCount)

Write-Host "🎯 Estrategia de extracción:" -ForegroundColor Cyan
Write-Host "  Método: Frame Picking (cada $frameInterval frames)" -ForegroundColor Gray
Write-Host "  Frames objetivo: $KeyFramesCount poses clave`n" -ForegroundColor Gray

# Crear directorios
$outputDir = "art/assets/Spritesheets/optimized"
$tempDir = "$outputDir/temp_$OutputName"
New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

Write-Host "🔧 Extrayendo frames clave...`n" -ForegroundColor Yellow

# Estrategia: Usar select filter de FFmpeg para elegir frames específicos
# select='not(mod(n,$frameInterval))' - Selecciona cada N frame
$selectFilter = "select='not(mod(n\,$frameInterval))',colorkey=0x000000:0.1:0.2"

ffmpeg -i $InputVideo -vf $selectFilter -vsync vfr "$tempDir/frame_%03d.png" -y 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
	Write-Host "❌ Error en extracción" -ForegroundColor Red
	exit 1
}

# Contar frames extraídos
$extractedFrames = (Get-ChildItem "$tempDir/frame_*.png").Count

Write-Host "✅ Frames extraídos: $extractedFrames" -ForegroundColor Green

# Limitar a exactamente KeyFramesCount frames
if ($extractedFrames -gt $KeyFramesCount) {
	Write-Host "⚙️  Ajustando a $KeyFramesCount frames..." -ForegroundColor Yellow
	$framesToKeep = Get-ChildItem "$tempDir/frame_*.png" | Select-Object -First $KeyFramesCount
	$framesToRemove = Get-ChildItem "$tempDir/frame_*.png" | Select-Object -Skip $KeyFramesCount
	$framesToRemove | Remove-Item
	$extractedFrames = $KeyFramesCount
}

# Renumerar frames consecutivamente
Write-Host "🔄 Renumerando frames..." -ForegroundColor Yellow
$frames = Get-ChildItem "$tempDir/frame_*.png" | Sort-Object Name
$counter = 1
foreach ($frame in $frames) {
	$newName = "key_frame_{0:D3}.png" -f $counter
	Rename-Item $frame.FullName $newName
	$counter++
}

# Duplicar primer frame al final para loop perfecto
$firstFrame = Get-ChildItem "$tempDir/key_frame_001.png"
$lastFrameNum = $extractedFrames + 1
$lastFrameName = "key_frame_{0:D3}.png" -f $lastFrameNum
Copy-Item $firstFrame.FullName "$tempDir/$lastFrameName"

Write-Host "✅ Loop cerrado: primer frame duplicado al final" -ForegroundColor Green

$finalFrameCount = $extractedFrames + 1

# Crear spritesheet
Write-Host "`n📐 Generando spritesheet optimizado..." -ForegroundColor Cyan

$spritesheetOutput = "$outputDir/${OutputName}_${finalFrameCount}frames.png"

# Intentar usar ImageMagick primero
$magickPath = Get-Command magick -ErrorAction SilentlyContinue

if ($magickPath) {
	magick convert "$tempDir/key_frame_*.png" +append "$spritesheetOutput" 2>&1 | Out-Null
} else {
	# Fallback a FFmpeg
	$tileLayout = "${finalFrameCount}x1"
	ffmpeg -i "$tempDir/key_frame_%03d.png" -filter_complex "tile=$tileLayout" "$spritesheetOutput" -y 2>&1 | Out-Null
}

if (Test-Path $spritesheetOutput) {
	$fileSize = [math]::Round((Get-Item $spritesheetOutput).Length / 1KB, 2)
	Write-Host "✅ Spritesheet creado: $fileSize KB" -ForegroundColor Green
	Write-Host "   → $spritesheetOutput`n" -ForegroundColor DarkGray
} else {
	Write-Host "❌ Error creando spritesheet" -ForegroundColor Red
	exit 1
}

# Comparación con versión anterior
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 COMPARACIÓN: ANTES vs DESPUÉS" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Cyan

$originalFile = "art/assets/Spritesheets/Hero/hero_walk_01_12fps.png"
if (Test-Path $originalFile) {
	$originalSize = [math]::Round((Get-Item $originalFile).Length / 1KB, 2)
	$reduction = [math]::Round((1 - ($fileSize / $originalSize)) * 100, 1)
	
	Write-Host "ANTES (12 FPS, 62 frames):" -ForegroundColor Red
	Write-Host "  Tamaño: $originalSize KB" -ForegroundColor Gray
	Write-Host "  Frames: 62" -ForegroundColor Gray
	Write-Host "  Duración ciclo: ~5.2 segundos" -ForegroundColor Gray
	Write-Host "  Problema: Demasiado lento, estatismo`n" -ForegroundColor Gray
	
	Write-Host "DESPUÉS (Optimizado, $finalFrameCount frames):" -ForegroundColor Green
	Write-Host "  Tamaño: $fileSize KB" -ForegroundColor Gray
	Write-Host "  Frames: $finalFrameCount" -ForegroundColor Gray
	Write-Host "  Duración ciclo @ 10 FPS: ~$([math]::Round($finalFrameCount / 10.0, 1)) segundos" -ForegroundColor Gray
	Write-Host "  Duración ciclo @ 12 FPS: ~$([math]::Round($finalFrameCount / 12.0, 1)) segundos" -ForegroundColor Gray
	Write-Host "`n  ✅ Reducción de tamaño: $reduction%" -ForegroundColor Green
	Write-Host "  ✅ Reducción de frames: $([math]::Round((1 - ($finalFrameCount / 62.0)) * 100, 1))%" -ForegroundColor Green
	Write-Host "  ✅ Animación más dinámica y enérgica`n" -ForegroundColor Green
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✨ SIGUIENTE PASO" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Green

Write-Host "🎮 Probar en el comparador:" -ForegroundColor Yellow
Write-Host "  1. Abre Godot" -ForegroundColor Gray
Write-Host "  2. Importa el nuevo spritesheet:" -ForegroundColor Gray
Write-Host "     $spritesheetOutput" -ForegroundColor DarkGray
Write-Host "  3. Crea AnimatedSprite2D con $finalFrameCount hframes" -ForegroundColor Gray
Write-Host "  4. Configura a 10-12 FPS" -ForegroundColor Gray
Write-Host "  5. Compara con la versión de 62 frames`n" -ForegroundColor Gray

Write-Host "💡 Esperado:" -ForegroundColor Cyan
Write-Host "  ✓ Movimiento más enérgico" -ForegroundColor Green
Write-Host "  ✓ Sin sensación de estatismo" -ForegroundColor Green
Write-Host "  ✓ Ciclo rápido y dinámico" -ForegroundColor Green
Write-Host "  ✓ Archivo mucho más liviano`n" -ForegroundColor Green

Write-Host "🗑️  ¿Borrar frames temporales? (Y/N): " -ForegroundColor Yellow -NoNewline
$response = Read-Host
if ($response -eq "Y" -or $response -eq "y") {
	Remove-Item -Path $tempDir -Recurse -Force
	Write-Host "✅ Frames temporales eliminados`n" -ForegroundColor Green
} else {
	Write-Host "💾 Frames temporales conservados en: $tempDir`n" -ForegroundColor Cyan
}

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Cyan
