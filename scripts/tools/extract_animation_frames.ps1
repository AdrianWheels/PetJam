# =====================================================
# Script de Extracción de Frames de MP4 → Spritesheets
# PetJam - Godot 4.5 Jam Project
# =====================================================
# Extrae frames de MP4 con fondo negro removido
# Genera múltiples versiones con diferentes FPS
# Respeta loops (primer y último frame iguales)

param(
	[string]$InputVideo,
	[string]$OutputDir = "art/assets/Spritesheets/temp_frames",
	[int[]]$FPSVariants = @(8, 10, 12, 15),
	[switch]$RemoveBackground = $true,
	[switch]$CreateSpritesheet = $true
)

# Verificar FFmpeg instalado
$ffmpegPath = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (-not $ffmpegPath) {
	Write-Host "❌ FFmpeg no encontrado. Instalando..." -ForegroundColor Red
	Write-Host "Ejecuta: winget install Gyan.FFmpeg" -ForegroundColor Yellow
	exit 1
}

Write-Host "🎬 Extractor de Animaciones PetJam" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan

# Si no se especifica video, usar hero_walk_01 por defecto
if (-not $InputVideo) {
	$InputVideo = "art/assets/Animaciones/Hero/Walk/hero_walk_01.mp4"
}

# Verificar que existe el video
if (-not (Test-Path $InputVideo)) {
	Write-Host "❌ Video no encontrado: $InputVideo" -ForegroundColor Red
	exit 1
}

$videoName = [System.IO.Path]::GetFileNameWithoutExtension($InputVideo)
Write-Host "📹 Procesando: $videoName" -ForegroundColor Green

# Detectar si es Hero o Enemy basándose en la ruta
$baseOutputDir = "art/assets/Spritesheets"
$tempDir = "$baseOutputDir/temp_frames/$videoName"

if ($InputVideo -like "*Hero*") {
	$spritesheetDir = "$baseOutputDir/Hero"
} elseif ($InputVideo -like "*Enemies*") {
	$spritesheetDir = "$baseOutputDir/Enemies"
} else {
	$spritesheetDir = "$baseOutputDir/Other"
}

New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
New-Item -ItemType Directory -Force -Path $spritesheetDir | Out-Null

# Obtener información del video
Write-Host "`n📊 Analizando video..." -ForegroundColor Yellow
$videoInfo = ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets,r_frame_rate,width,height -of csv=p=0 $InputVideo
$videoInfoParts = $videoInfo -split ","
$totalFrames = [int]$videoInfoParts[0]
$width = [int]$videoInfoParts[1]
$frameRateRaw = $videoInfoParts[2]
$height = [int]$videoInfoParts[3]

# Parsear frame rate (puede venir como fracción "24/1" o decimal "24.0")
if ($frameRateRaw -match "(\d+)/(\d+)") {
	$frameRate = [math]::Round([double]$matches[1] / [double]$matches[2], 2)
} else {
	$frameRate = [math]::Round([double]$frameRateRaw, 2)
}

Write-Host "  Frames totales: $totalFrames" -ForegroundColor Gray
Write-Host "  Frame rate original: $frameRate fps" -ForegroundColor Gray
Write-Host "  Resolución: ${width}x${height}" -ForegroundColor Gray

# Procesar cada variante de FPS
foreach ($fps in $FPSVariants) {
	Write-Host "`n🎨 Generando variante a $fps FPS..." -ForegroundColor Cyan
	
	$variantDir = "$tempDir/fps_$fps"
	New-Item -ItemType Directory -Force -Path $variantDir | Out-Null
	
	# Filtro de video: extraer frames + remover fondo negro
	$vfilter = "fps=$fps"
	
	if ($RemoveBackground) {
		# Chromakey para remover negro + hacer transparente
		# fuzz controla tolerancia (0.1 = 10% tolerancia al negro puro)
		$vfilter += ",colorkey=0x000000:0.1:0.2"
	}
	
	Write-Host "  Extrayendo frames..." -ForegroundColor Gray
	
	# Extraer frames
	ffmpeg -i $InputVideo -vf $vfilter "$variantDir/frame_%04d.png" -y 2>&1 | Out-Null
	
	if ($LASTEXITCODE -ne 0) {
		Write-Host "  ⚠️  Error extrayendo frames a $fps FPS" -ForegroundColor Yellow
		continue
	}
	
	# Contar frames extraídos
	$extractedFrames = (Get-ChildItem "$variantDir/frame_*.png").Count
	Write-Host "  ✅ Extraídos $extractedFrames frames" -ForegroundColor Green
	
	# Verificar si el loop está cerrado (primer y último frame similares)
	# Si no lo está, duplicar el primer frame al final
	$firstFrame = "$variantDir/frame_0001.png"
	$lastFrameNum = "{0:D4}" -f $extractedFrames
	$lastFrame = "$variantDir/frame_$lastFrameNum.png"
	
	if ($extractedFrames -gt 1) {
		Write-Host "  🔄 Verificando loop (primer = último frame)..." -ForegroundColor Gray
		
		# Copiar primer frame como último para asegurar loop perfecto
		$newLastFrameNum = "{0:D4}" -f ($extractedFrames + 1)
		Copy-Item $firstFrame "$variantDir/frame_$newLastFrameNum.png"
		Write-Host "  ✅ Loop cerrado: duplicado primer frame al final" -ForegroundColor Green
		$extractedFrames++
	}
	
	# Crear spritesheet horizontal
	if ($CreateSpritesheet) {
		Write-Host "  📐 Generando spritesheet..." -ForegroundColor Gray
		
		$spritesheetOutput = "$spritesheetDir/${videoName}_${fps}fps.png"
		
		# Usar ImageMagick si está disponible (mejor calidad)
		$magickPath = Get-Command magick -ErrorAction SilentlyContinue
		
		if ($magickPath) {
			# ImageMagick: montaje horizontal con transparencia
			magick convert "$variantDir/frame_*.png" +append "$spritesheetOutput" 2>&1 | Out-Null
		} else {
			# FFmpeg fallback: tile horizontal
			$tileLayout = "${extractedFrames}x1"
			ffmpeg -i "$variantDir/frame_%04d.png" -filter_complex "tile=$tileLayout" "$spritesheetOutput" -y 2>&1 | Out-Null
		}
		
		if (Test-Path $spritesheetOutput) {
			$fileSize = [math]::Round((Get-Item $spritesheetOutput).Length / 1KB, 2)
			Write-Host "  ✅ Spritesheet creado: $fileSize KB" -ForegroundColor Green
			Write-Host "     → $spritesheetOutput" -ForegroundColor DarkGray
			Write-Host "     → Frames: $extractedFrames | Dimensión estimada: $($width * $extractedFrames)x$height" -ForegroundColor DarkGray
		} else {
			Write-Host "  ⚠️  Error creando spritesheet" -ForegroundColor Yellow
		}
	}
}

Write-Host "`n✨ Proceso completado!" -ForegroundColor Green
Write-Host "📁 Spritesheets generados en: $spritesheetDir" -ForegroundColor Cyan
Write-Host "`n💡 Importa los PNG en Godot y configura AnimatedSprite2D:" -ForegroundColor Yellow
Write-Host "   1. Selecciona la textura del spritesheet" -ForegroundColor Gray
Write-Host "   2. En Inspector → Animation → Hframes = <número de frames>" -ForegroundColor Gray
Write-Host "   3. Ajusta FPS en AnimationPlayer según la variante que prefieras" -ForegroundColor Gray

Write-Host "`n🎮 Variantes generadas:" -ForegroundColor Cyan
foreach ($fps in $FPSVariants) {
	$file = "$spritesheetDir/${videoName}_${fps}fps.png"
	if (Test-Path $file) {
		Write-Host "   ✓ $fps FPS → ${videoName}_${fps}fps.png" -ForegroundColor Green
	}
}
