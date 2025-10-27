# Script para corregir la importación de spritesheets en Godot 4.5
# Problema: detect_3d/compress_to=1 y fix_alpha_border=true causan transparencia incorrecta
# Solución: Cambiar a detect_3d/compress_to=0 y fix_alpha_border=false

Write-Host "🔧 Corrigiendo archivos .import de spritesheets..." -ForegroundColor Cyan

$importFiles = Get-ChildItem -Path "art\assets\Spritesheets" -Filter "*.png.import" -Recurse

$count = 0
$fixed = 0

foreach ($file in $importFiles) {
	$count++
	$content = Get-Content $file.FullName -Raw
	
	$modified = $false
	
	# Cambiar detect_3d/compress_to de 1 a 0
	if ($content -match "detect_3d/compress_to=1") {
		$content = $content -replace "detect_3d/compress_to=1", "detect_3d/compress_to=0"
		$modified = $true
	}
	
	# Cambiar process/fix_alpha_border de true a false
	if ($content -match "process/fix_alpha_border=true") {
		$content = $content -replace "process/fix_alpha_border=true", "process/fix_alpha_border=false"
		$modified = $true
	}
	
	if ($modified) {
		Set-Content -Path $file.FullName -Value $content -NoNewline
		$fixed++
		Write-Host "  ✓ Fixed: $($file.Name)" -ForegroundColor Green
	}
}

Write-Host "`n📊 Resumen:" -ForegroundColor Yellow
Write-Host "  Total archivos .import encontrados: $count" -ForegroundColor White
Write-Host "  Archivos corregidos: $fixed" -ForegroundColor Green
Write-Host "`n⚠️  IMPORTANTE: Debes reabrir Godot para que los cambios surtan efecto." -ForegroundColor Yellow
Write-Host "  Godot reimportará las texturas con la nueva configuración." -ForegroundColor White
