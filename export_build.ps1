# Script de exportación para PetJam
# Uso: .\export_build.ps1

$ErrorActionPreference = "Stop"

# Configuración
$GODOT_EXE = "C:\Program Files\Godot\Godot_v4.5.1-stable_win64.exe" # Ajusta la ruta
$PROJECT_PATH = $PSScriptRoot
$BUILD_DIR = Join-Path $PROJECT_PATH "builds"
$WINDOWS_BUILD = Join-Path $BUILD_DIR "windows"
$PRESET_NAME = "Windows Desktop"

Write-Host "🎮 Exportando PetJam..." -ForegroundColor Cyan

# Crear carpeta de builds si no existe
if (-not (Test-Path $BUILD_DIR)) {
	New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
}

if (-not (Test-Path $WINDOWS_BUILD)) {
	New-Item -ItemType Directory -Path $WINDOWS_BUILD | Out-Null
}

# Exportar para Windows
Write-Host "📦 Exportando para Windows..." -ForegroundColor Yellow
& $GODOT_EXE --headless --export-release $PRESET_NAME "$WINDOWS_BUILD\PetJam.exe"

if ($LASTEXITCODE -eq 0) {
	Write-Host "✅ Build completada exitosamente!" -ForegroundColor Green
	Write-Host "📁 Ubicación: $WINDOWS_BUILD\PetJam.exe" -ForegroundColor Cyan
	
	# Abrir carpeta
	Start-Process explorer.exe -ArgumentList $WINDOWS_BUILD
} else {
	Write-Host "❌ Error al exportar. Verifica la configuración del preset." -ForegroundColor Red
	exit 1
}
