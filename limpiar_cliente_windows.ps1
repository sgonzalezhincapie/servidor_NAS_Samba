# ===============================================================================
# SCRIPT DE LIMPIEZA DEL CLIENTE NAS — Windows 10 / 11
# ===============================================================================
#
# USO:
#   Ejecutar en PowerShell como Administrador:
#   .\limpiar_cliente_windows.ps1
#
# DESCRIPCION:
#   Revierte la configuracion de cliente NAS en Windows:
#   elimina unidades de red mapeadas, credenciales cacheadas
#   y la modificacion en el registro para acceso de invitado.
#
# REQUISITO: PowerShell como Administrador
# ===============================================================================

#Requires -RunAsAdministrator

$HOST_NAS = Read-Host "  IP o nombre del servidor NAS (ej: 192.168.1.55)"

Write-Host ""
Write-Host "  Este script eliminara:" -ForegroundColor Yellow
Write-Host "    - Todas las unidades de red mapeadas"
Write-Host "    - Credenciales cacheadas del servidor NAS"
Write-Host "    - La clave de registro AllowInsecureGuestAuth"
Write-Host ""
$confirmacion = Read-Host "  Continuar? [s/N]"
if ($confirmacion -notmatch "^[sS]$") {
    Write-Host "  Operacion cancelada." -ForegroundColor Gray
    exit 0
}
Write-Host ""

# ─── PASO 1: ELIMINAR UNIDADES DE RED MAPEADAS ───────────────────────────────
Write-Host "[1/3] Eliminando unidades de red mapeadas..." -ForegroundColor Cyan
Write-Host ""

$mapeadas = net use 2>&1
if ($mapeadas -match "\\\\") {
    net use * /delete /yes 2>&1 | Out-Null
    Write-Host "  OK  Unidades de red eliminadas." -ForegroundColor Green
} else {
    Write-Host "  --  No hay unidades de red mapeadas." -ForegroundColor Yellow
}
Write-Host ""

# ─── PASO 2: LIMPIAR CREDENCIALES CACHEADAS ──────────────────────────────────
Write-Host "[2/3] Limpiando credenciales cacheadas del NAS..." -ForegroundColor Cyan
Write-Host ""

# Eliminar credenciales especificas del servidor NAS
if ($HOST_NAS -ne "") {
    $resultado = cmdkey /delete:$HOST_NAS 2>&1
    if ($resultado -match "eliminada|deleted") {
        Write-Host "  OK  Credenciales de $HOST_NAS eliminadas." -ForegroundColor Green
    } else {
        Write-Host "  --  No habia credenciales guardadas para $HOST_NAS." -ForegroundColor Yellow
    }
}

# Intentar limpiar variantes comunes
foreach ($sufijo in @("", ":445", ":139")) {
    cmdkey /delete:"$HOST_NAS$sufijo" 2>&1 | Out-Null
}
Write-Host ""

# ─── PASO 3: REVERTIR REGISTRO (AllowInsecureGuestAuth) ──────────────────────
Write-Host "[3/3] Revirtiendo configuracion del registro..." -ForegroundColor Cyan
Write-Host ""

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
$regKey  = "AllowInsecureGuestAuth"

try {
    $valorActual = Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction SilentlyContinue
    if ($valorActual -ne $null) {
        Set-ItemProperty -Path $regPath -Name $regKey -Value 0 -Type DWord -Force
        Write-Host "  OK  $regKey revertido a 0 (valor predeterminado seguro)." -ForegroundColor Green
    } else {
        Write-Host "  --  $regKey no estaba configurado, omitiendo." -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ERR No se pudo modificar el registro: $_" -ForegroundColor Red
}
Write-Host ""

# ─── RESUMEN ─────────────────────────────────────────────────────────────────
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  LIMPIEZA COMPLETADA" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Tu equipo ya no tiene configuracion de cliente NAS."
Write-Host "  Para volver a configurar el acceso:"
Write-Host "    .\setup_cliente_windows.ps1"
Write-Host ""
