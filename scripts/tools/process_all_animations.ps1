# =====================================================
# Procesamiento Batch de TODAS las Animaciones
# PetJam - Godot 4.5 Jam Project
# =====================================================
# Procesa todos los MP4 encontrados en art/assets/Animaciones

param(
	[int[]]$FPSVariants = @(10, 12),  # Por defecto solo 10 y 12 FPS (balance calidad/tamaño)
	[switch]$DryRun = $false,  # Si es true, solo muestra lo que haría sin procesar
	[string]$Filter = "*"  # Filtro de archivos (ej: "*walk*", "*hero*")
)

Write-Host "🎬 Procesamiento Batch de Animaciones - PetJam" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Buscar todos los MP4
$mp4Files = Get-ChildItem -Path "art/assets/Animaciones" -Filter "*.mp4" -Recurse | Where-Object { $_.Name -like $Filter }

Write-Host "`n📹 Encontrados $($mp4Files.Count) videos MP4" -ForegroundColor Green

if ($mp4Files.Count -eq 0) {
	Write-Host "❌ No se encontraron videos con el filtro: $Filter" -ForegroundColor Red
	exit 1
}

Write-Host "`n📋 Lista de videos a procesar:" -ForegroundColor Yellow
foreach ($file in $mp4Files) {
	$category = $file.Directory.Parent.Name  # Hero o Enemies
	$type = $file.Directory.Name  # Walk, Attack, Death
	Write-Host "  ✓ [$category/$type] $($file.Name)" -ForegroundColor Gray
}

Write-Host "`n⚙️  Configuración:" -ForegroundColor Cyan
Write-Host "  FPS variantes: $($FPSVariants -join ', ')" -ForegroundColor Gray
Write-Host "  Remover fondo negro: SÍ" -ForegroundColor Gray
Write-Host "  Loop cerrado: SÍ (primer frame duplicado al final)" -ForegroundColor Gray

if ($DryRun) {
	Write-Host "`n⚠️  MODO DRY RUN - No se procesarán archivos" -ForegroundColor Yellow
	exit 0
}

Write-Host "`n🚀 Iniciando procesamiento..." -ForegroundColor Green
Write-Host "   (Esto puede tomar varios minutos)" -ForegroundColor Gray

$totalProcessed = 0
$totalFailed = 0

foreach ($file in $mp4Files) {
	$relativePath = $file.FullName.Replace((Get-Location).Path + "\", "")
	Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
	Write-Host "📹 Procesando: $($file.Name)" -ForegroundColor Cyan
	Write-Host "   Ubicación: $relativePath" -ForegroundColor DarkGray
	
	# Ejecutar script de extracción
	$params = @{
		InputVideo = $relativePath
		FPSVariants = $FPSVariants
	}
	
	try {
		& ".\scripts\tools\extract_animation_frames.ps1" @params
		
		if ($LASTEXITCODE -eq 0) {
			$totalProcessed++
			Write-Host "✅ Completado: $($file.Name)" -ForegroundColor Green
		} else {
			$totalFailed++
			Write-Host "⚠️  Error procesando: $($file.Name)" -ForegroundColor Yellow
		}
	} catch {
		$totalFailed++
		Write-Host "❌ Error fatal: $($file.Name)" -ForegroundColor Red
		Write-Host "   $($_.Exception.Message)" -ForegroundColor Red
	}
}

Write-Host "`n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "✨ Procesamiento batch completado!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host "`n📊 Estadísticas:" -ForegroundColor Cyan
Write-Host "  Videos procesados: $totalProcessed / $($mp4Files.Count)" -ForegroundColor Gray
if ($totalFailed -gt 0) {
	Write-Host "  Errores: $totalFailed" -ForegroundColor Yellow
}

Write-Host "`n📁 Spritesheets generados en:" -ForegroundColor Cyan
Write-Host "  → art/assets/Spritesheets/Hero/" -ForegroundColor Gray
Write-Host "  → art/assets/Spritesheets/Enemies/" -ForegroundColor Gray

Write-Host "`n💡 Siguiente paso:" -ForegroundColor Yellow
Write-Host "  1. Abre Godot y ejecuta la escena:" -ForegroundColor Gray
Write-Host "     scenes/sandboxes/AnimationTestComparison.tscn" -ForegroundColor Gray
Write-Host "  2. O presiona F5 en el juego para abrir el comparador" -ForegroundColor Gray
Write-Host "  3. Compara las variantes de FPS y elige la mejor" -ForegroundColor Gray

# Mostrar tamaño total generado
$totalSize = (Get-ChildItem -Path "art/assets/Spritesheets" -Recurse -File | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)
Write-Host "`n💾 Espacio usado: $totalSizeMB MB" -ForegroundColor Cyan
