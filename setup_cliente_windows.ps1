# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT DE CONFIGURACIÓN DEL CLIENTE — Windows 10/11
# ═══════════════════════════════════════════════════════════════════════════════
# Proyecto  : Comunicaciones III — Tema 3 — Laboratorio NAS con Samba
# Integrantes: Manuela Marín Rojo, Daniel Trujillo F, Santiago González
# Cliente   : Windows 10 / Windows 11
# Fecha     : Abril 2026
#
# DESCRIPCIÓN:
#   Este script de PowerShell configura un cliente Windows para acceder a los
#   recursos compartidos del servidor NAS DataCorp vía SMB/CIFS.
#   Windows soporta SMB de forma NATIVA (es el protocolo que inventó Microsoft),
#   así que no necesitamos instalar paquetes adicionales como en Linux.
#
# USO:
#   1. Abre PowerShell como Administrador:
#      - Clic derecho en el menú Inicio → "Terminal (Administrador)"
#      - O buscar "PowerShell" → clic derecho → "Ejecutar como administrador"
#   2. Si es la primera vez, habilitar ejecución de scripts:
#      Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#   3. Ejecutar:
#      .\setup_cliente_windows.ps1
#
# ANTES DE EJECUTAR:
#   Reemplaza <IP_SERVIDOR> en la variable $IP_SERVIDOR (línea ~40) por la IP
#   real del servidor Ubuntu.
# ═══════════════════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURACIÓN — MODIFICAR ANTES DE EJECUTAR
# ─────────────────────────────────────────────────────────────────────────────
# IMPORTANTE: Cambia esta IP por la IP real de tu servidor Ubuntu 24.04
$IP_SERVIDOR = "10.253.45.194"

# ─────────────────────────────────────────────────────────────────────────────
# VERIFICACIONES INICIALES
# ─────────────────────────────────────────────────────────────────────────────

# Por qué: Verificamos que el usuario haya reemplazado el placeholder
if ($IP_SERVIDOR -eq "10.253.45.194") {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║  ERROR: Debes configurar la IP del servidor.              ║" -ForegroundColor Red
    Write-Host "║                                                           ║" -ForegroundColor Red
    Write-Host '║  Abre este script y cambia la línea:                      ║' -ForegroundColor Red
    Write-Host '║    $IP_SERVIDOR = "<IP_SERVIDOR>"                         ║' -ForegroundColor Red
    Write-Host "║  Por la IP real del servidor Ubuntu, por ejemplo:         ║" -ForegroundColor Red
    Write-Host '║    $IP_SERVIDOR = "192.168.1.100"                         ║' -ForegroundColor Red
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    exit 1
}

# Por qué: Verificamos que estamos ejecutando como Administrador.
# Algunas operaciones (mapear unidades persistentes, modificar hosts) lo requieren.
$esAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $esAdmin) {
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║  ADVERTENCIA: No estás ejecutando como Administrador.     ║" -ForegroundColor Yellow
    Write-Host "║  Algunas operaciones pueden fallar.                       ║" -ForegroundColor Yellow
    Write-Host "║  Recomendado: clic derecho → Ejecutar como administrador  ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   CONFIGURACION DEL CLIENTE NAS — DataCorp" -ForegroundColor Cyan
Write-Host "   Windows → Servidor: $IP_SERVIDOR" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# PASO 1: VERIFICAR QUE SMB ESTÁ HABILITADO EN WINDOWS
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Windows tiene SMB habilitado por defecto, pero es posible que alguien
# lo haya deshabilitado (especialmente SMB1 por seguridad). Verificamos que
# SMB2 y SMB3 estén activos, que son los que usa nuestro servidor.
Write-Host "[1/6] Verificando que SMB esta habilitado en Windows..." -ForegroundColor White

# Por qué: Get-SmbClientConfiguration muestra la configuración del cliente SMB
try {
    $smbConfig = Get-SmbClientConfiguration -ErrorAction Stop

    # Verificar SMB2 (incluye SMB3, van juntos en Windows)
    if ($smbConfig.EnableSecuritySignature -ne $null) {
        Write-Host "    [OK] Cliente SMB de Windows esta activo." -ForegroundColor Green
    }

    # Mostrar información de la configuración SMB
    Write-Host "    Cifrado requerido por el cliente: $($smbConfig.RequireSecuritySignature)" -ForegroundColor Gray
    Write-Host "    Cifrado habilitado: $($smbConfig.EnableSecuritySignature)" -ForegroundColor Gray
}
catch {
    Write-Host "    [!] No se pudo verificar la configuracion SMB." -ForegroundColor Yellow
    Write-Host "    Windows 10/11 tiene SMB habilitado por defecto, continuando..." -ForegroundColor Yellow
}

# Por qué: Verificamos que SMB1 esté DESHABILITADO (por seguridad)
# SMB1 es inseguro (WannaCry). Nuestro servidor exige mínimo SMB2.
try {
    $smb1 = Get-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -ErrorAction Stop
    if ($smb1.State -eq "Enabled") {
        Write-Host "    [ADVERTENCIA] SMB1 esta HABILITADO. Es inseguro." -ForegroundColor Yellow
        Write-Host "    Recomendacion: Deshabilitar SMB1 con:" -ForegroundColor Yellow
        Write-Host "      Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol" -ForegroundColor Yellow
    }
    else {
        Write-Host "    [OK] SMB1 esta deshabilitado (correcto, es inseguro)." -ForegroundColor Green
    }
}
catch {
    Write-Host "    [!] No se pudo verificar el estado de SMB1." -ForegroundColor Yellow
}

Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# PASO 2: VERIFICAR CONECTIVIDAD CON EL SERVIDOR
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Antes de intentar acceder a los shares, verificamos que hay
# conexión de red con el servidor y que el puerto SMB (445) está abierto.
Write-Host "[2/6] Verificando conectividad con el servidor ($IP_SERVIDOR)..." -ForegroundColor White

# Por qué: Test-Connection es el equivalente a "ping" en PowerShell.
Write-Host "  -> Probando ping..."
$ping = Test-Connection -ComputerName $IP_SERVIDOR -Count 3 -Quiet -ErrorAction SilentlyContinue
if ($ping) {
    Write-Host "    [OK] El servidor $IP_SERVIDOR responde al ping." -ForegroundColor Green
}
else {
    Write-Host "    [X] El servidor $IP_SERVIDOR NO responde al ping." -ForegroundColor Red
    Write-Host "    Posibles causas:" -ForegroundColor Yellow
    Write-Host "      - El servidor esta apagado" -ForegroundColor Yellow
    Write-Host "      - No estan en la misma red" -ForegroundColor Yellow
    Write-Host "      - El firewall del servidor bloquea ICMP" -ForegroundColor Yellow
}

# Por qué: Test-NetConnection verifica que el puerto 445 (SMB) está abierto.
# Si el ping funciona pero el puerto está cerrado, Samba no está corriendo
# o el firewall lo bloquea.
Write-Host "  -> Probando puerto 445 (SMB)..."
$portTest = Test-NetConnection -ComputerName $IP_SERVIDOR -Port 445 -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
if ($portTest.TcpTestSucceeded) {
    Write-Host "    [OK] Puerto 445 (SMB) esta abierto en $IP_SERVIDOR." -ForegroundColor Green
}
else {
    Write-Host "    [X] Puerto 445 (SMB) NO esta accesible en $IP_SERVIDOR." -ForegroundColor Red
    Write-Host "    En el servidor, verifica:" -ForegroundColor Yellow
    Write-Host "      sudo systemctl status smbd" -ForegroundColor Yellow
    Write-Host "      sudo ufw allow samba" -ForegroundColor Yellow
}

Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# PASO 3: LISTAR SHARES DISPONIBLES EN EL SERVIDOR
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Antes de mapear unidades, verificamos qué shares están disponibles.
# "net view" es el comando de Windows para listar shares SMB de un servidor.
Write-Host "[3/6] Listando shares disponibles en el servidor..." -ForegroundColor White

try {
    $shares = net view "\\$IP_SERVIDOR" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    [OK] Shares detectados:" -ForegroundColor Green
        Write-Host $shares -ForegroundColor Gray
    }
    else {
        Write-Host "    [!] No se pudieron listar shares anonimamente." -ForegroundColor Yellow
        Write-Host "    Esto es normal si 'map to guest = bad user' esta activo." -ForegroundColor Yellow
        Write-Host "    Los shares se veran al conectarse con usuario/contrasena." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "    [!] Error al listar shares: $_" -ForegroundColor Yellow
}

Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# PASO 4: MAPEAR UNIDADES DE RED
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: En Windows, las carpetas de red se "mapean" como letras de unidad
# (como D:, E:, etc.). Esto es equivalente a "mount" en Linux.
# Usamos "net use" que es el comando clásico de Windows para mapear unidades.
#
# Letras asignadas:
#   P: = publico
#   C: no se puede (es el disco del sistema)
#   K: = contabilidad
#   S: = sistemas
#   V: = privado
#   A: = admin
Write-Host "[4/6] Preparando mapeo de unidades de red..." -ForegroundColor White
Write-Host ""

# Primero, eliminar mapeos anteriores si existen (para evitar conflictos)
Write-Host "  -> Limpiando mapeos anteriores de DataCorp..." -ForegroundColor Gray
$letras = @("P:", "K:", "S:", "V:", "A:")
foreach ($letra in $letras) {
    net use $letra /delete 2>$null | Out-Null
}
Write-Host "    [OK] Mapeos anteriores limpiados." -ForegroundColor Green
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# MAPEO COMO INVITADO (P: = publico)
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "  ┌───────────────────────────────────────────────────────┐" -ForegroundColor Cyan
Write-Host "  │  MAPEO: P: = \\$IP_SERVIDOR\publico (invitado)       │" -ForegroundColor Cyan
Write-Host "  └───────────────────────────────────────────────────────┘" -ForegroundColor Cyan

# Por qué: /user:guest sin contraseña para acceso público.
# "net use P: \\servidor\share" mapea la unidad.
try {
    net use P: "\\$IP_SERVIDOR\publico" /user:guest "" 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "    [OK] P: mapeado exitosamente a \\$IP_SERVIDOR\publico" -ForegroundColor Green
    }
    else {
        Write-Host "    [!] Error al mapear P: — Intentando sin credenciales..." -ForegroundColor Yellow
        net use P: "\\$IP_SERVIDOR\publico" "" /user:"" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [OK] P: mapeado exitosamente (sin credenciales)" -ForegroundColor Green
        }
        else {
            Write-Host "    [X] No se pudo mapear P: automaticamente." -ForegroundColor Red
            Write-Host "    Intenta manualmente: net use P: \\$IP_SERVIDOR\publico" -ForegroundColor Yellow
        }
    }
}
catch {
    Write-Host "    [X] Error: $_" -ForegroundColor Red
}

Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# MOSTRAR COMANDOS PARA MAPEO MANUAL CON DIFERENTES USUARIOS
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   COMANDOS DE MAPEO MANUAL POR USUARIO" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "Ejecuta estos comandos segun el usuario que quieras probar:" -ForegroundColor White
Write-Host "(Copia y pega en PowerShell o CMD)" -ForegroundColor Gray
Write-Host ""

# ── INVITADO ──
Write-Host "  ┌───────────────────────────────────────────────────────┐" -ForegroundColor White
Write-Host "  │  COMO INVITADO (solo /publico)                        │" -ForegroundColor White
Write-Host "  ├───────────────────────────────────────────────────────┤" -ForegroundColor White
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  net use P: \\$IP_SERVIDOR\publico /user:guest """"   │" -ForegroundColor Yellow
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Verificar:                                         │" -ForegroundColor Gray
Write-Host "  │  dir P:\                                              │" -ForegroundColor Yellow
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Probar que NO puede escribir:                      │" -ForegroundColor Gray
Write-Host "  │  echo test > P:\intruso.txt                           │" -ForegroundColor Yellow
Write-Host "  │  (Deberia dar: Acceso denegado)                       │" -ForegroundColor Gray
Write-Host "  └───────────────────────────────────────────────────────┘" -ForegroundColor White
Write-Host ""

# ── JUAN ──
Write-Host "  ┌───────────────────────────────────────────────────────┐" -ForegroundColor White
Write-Host "  │  COMO JUAN (contabilidad)                             │" -ForegroundColor White
Write-Host "  ├───────────────────────────────────────────────────────┤" -ForegroundColor White
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Contabilidad:                                      │" -ForegroundColor Gray
Write-Host "  │  net use K: \\$IP_SERVIDOR\contabilidad /user:dani Dani2026" -ForegroundColor Yellow
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Verificar y probar escritura:                      │" -ForegroundColor Gray
Write-Host "  │  dir K:\                                              │" -ForegroundColor Yellow
Write-Host "  │  echo Informe Q1 > K:\informe_dani.txt               │" -ForegroundColor Yellow
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # dani NO puede acceder a /privado:                  │" -ForegroundColor Gray
Write-Host "  │  net use V: \\$IP_SERVIDOR\privado /user:dani Dani2026" -ForegroundColor Yellow
Write-Host "  │  (Deberia dar: Error de sistema 5 / Acceso denegado)  │" -ForegroundColor Gray
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # NOTA: Cambiar contrasena en produccion             │" -ForegroundColor Gray
Write-Host "  └───────────────────────────────────────────────────────┘" -ForegroundColor White
Write-Host ""

# ── MARIA ──
Write-Host "  ┌───────────────────────────────────────────────────────┐" -ForegroundColor White
Write-Host "  │  COMO MARIA (sistemas)                                │" -ForegroundColor White
Write-Host "  ├───────────────────────────────────────────────────────┤" -ForegroundColor White
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Sistemas:                                          │" -ForegroundColor Gray
Write-Host "  │  net use S: \\$IP_SERVIDOR\sistemas /user:santi Santi2026" -ForegroundColor Yellow
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Verificar y probar escritura:                      │" -ForegroundColor Gray
Write-Host "  │  dir S:\                                              │" -ForegroundColor Yellow
Write-Host "  │  echo Reporte red > S:\reporte_santi.txt              │" -ForegroundColor Yellow
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # NOTA: Cambiar contrasena en produccion             │" -ForegroundColor Gray
Write-Host "  └───────────────────────────────────────────────────────┘" -ForegroundColor White
Write-Host ""

# ── ADMIN ──
Write-Host "  ┌───────────────────────────────────────────────────────┐" -ForegroundColor White
Write-Host "  │  COMO ADMIN (acceso total)                            │" -ForegroundColor White
Write-Host "  ├───────────────────────────────────────────────────────┤" -ForegroundColor White
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Privado:                                           │" -ForegroundColor Gray
Write-Host "  │  net use V: \\$IP_SERVIDOR\privado /user:admin Admin2026" -ForegroundColor Yellow
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Admin (share oculto, no aparece en 'net view'):    │" -ForegroundColor Gray
Write-Host "  │  net use A: \\$IP_SERVIDOR\admin /user:admin Admin2026" -ForegroundColor Yellow
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Contabilidad como admin:                           │" -ForegroundColor Gray
Write-Host "  │  net use K: \\$IP_SERVIDOR\contabilidad /user:admin Admin2026" -ForegroundColor Yellow
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Sistemas como admin:                               │" -ForegroundColor Gray
Write-Host "  │  net use S: \\$IP_SERVIDOR\sistemas /user:admin Admin2026" -ForegroundColor Yellow
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # NOTA: Cambiar contrasena en produccion             │" -ForegroundColor Gray
Write-Host "  └───────────────────────────────────────────────────────┘" -ForegroundColor White
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# PASO 5: CÓMO DESCONECTAR UNIDADES
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "[5/6] Como desconectar unidades de red..." -ForegroundColor White
Write-Host ""
Write-Host "  ┌───────────────────────────────────────────────────────┐" -ForegroundColor White
Write-Host "  │  DESCONECTAR UNIDADES DE RED                          │" -ForegroundColor White
Write-Host "  ├───────────────────────────────────────────────────────┤" -ForegroundColor White
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Desconectar una unidad especifica:                 │" -ForegroundColor Gray
Write-Host "  │  net use P: /delete                                   │" -ForegroundColor Yellow
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Desconectar TODAS las unidades de red:             │" -ForegroundColor Gray
Write-Host "  │  net use * /delete /yes                               │" -ForegroundColor Yellow
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Ver unidades mapeadas actualmente:                 │" -ForegroundColor Gray
Write-Host "  │  net use                                              │" -ForegroundColor Yellow
Write-Host "  └───────────────────────────────────────────────────────┘" -ForegroundColor White
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# PASO 6: MAPEO PERSISTENTE (sobrevive al reinicio)
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "[6/6] Mapeo persistente (opcional)..." -ForegroundColor White
Write-Host ""
Write-Host "  Para que las unidades se reconecten automaticamente" -ForegroundColor White
Write-Host "  cada vez que inicias sesion en Windows, agrega /persistent:yes:" -ForegroundColor White
Write-Host ""
Write-Host "  ┌───────────────────────────────────────────────────────┐" -ForegroundColor White
Write-Host "  │  MAPEO PERSISTENTE                                    │" -ForegroundColor White
Write-Host "  ├───────────────────────────────────────────────────────┤" -ForegroundColor White
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Publico (persistente):                             │" -ForegroundColor Gray
Write-Host "  │  net use P: \\$IP_SERVIDOR\publico /user:guest """" /persistent:yes" -ForegroundColor Yellow
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # Contabilidad (persistente, como dani):             │" -ForegroundColor Gray
Write-Host "  │  net use K: \\$IP_SERVIDOR\contabilidad /user:dani Dani2026 /persistent:yes" -ForegroundColor Yellow
Write-Host "  │                                                       │" -ForegroundColor White
Write-Host "  │  # NOTA: Windows guardara las credenciales en el      │" -ForegroundColor Gray
Write-Host "  │  # Administrador de credenciales de Windows.          │" -ForegroundColor Gray
Write-Host "  └───────────────────────────────────────────────────────┘" -ForegroundColor White
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# MÉTODO ALTERNATIVO: EXPLORADOR DE ARCHIVOS (GUI)
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   METODO ALTERNATIVO: Explorador de archivos (GUI)" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Si prefieres usar la interfaz grafica en vez de comandos:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Abre el Explorador de archivos (Win + E)" -ForegroundColor White
Write-Host "  2. En la barra de direcciones, escribe:" -ForegroundColor White
Write-Host "     \\$IP_SERVIDOR" -ForegroundColor Yellow
Write-Host "  3. Presiona Enter" -ForegroundColor White
Write-Host "  4. Windows te pedira usuario y contrasena" -ForegroundColor White
Write-Host "  5. Ingresa el usuario (ej: dani) y contrasena (ej: Dani2026)" -ForegroundColor White
Write-Host "  6. Veras las carpetas compartidas del servidor" -ForegroundColor White
Write-Host "  7. Puedes hacer clic derecho en una carpeta y seleccionar" -ForegroundColor White
Write-Host "     'Conectar a unidad de red' para mapearla permanentemente" -ForegroundColor White
Write-Host ""
Write-Host "  Para acceder a un share especifico directamente:" -ForegroundColor White
Write-Host "     \\$IP_SERVIDOR\publico       (sin contrasena)" -ForegroundColor Yellow
Write-Host "     \\$IP_SERVIDOR\contabilidad  (usuario: dani)" -ForegroundColor Yellow
Write-Host "     \\$IP_SERVIDOR\sistemas      (usuario: santi)" -ForegroundColor Yellow
Write-Host "     \\$IP_SERVIDOR\privado       (usuario: admin)" -ForegroundColor Yellow
Write-Host "     \\$IP_SERVIDOR\admin         (usuario: admin, share oculto)" -ForegroundColor Yellow
Write-Host ""

# ─────────────────────────────────────────────────────────────────────────────
# SOLUCIÓN DE PROBLEMAS COMUNES EN WINDOWS
# ─────────────────────────────────────────────────────────────────────────────
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   SOLUCION DE PROBLEMAS EN WINDOWS" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "  ERROR: 'No se puede acceder' o 'Error de red'" -ForegroundColor Yellow
Write-Host "    1. Verifica que el servidor este encendido y en la misma red" -ForegroundColor White
Write-Host "    2. Desactiva temporalmente el firewall de Windows:" -ForegroundColor White
Write-Host "       Panel de control → Firewall → Desactivar (temporalmente)" -ForegroundColor Gray
Write-Host "    3. Habilita descubrimiento de red:" -ForegroundColor White
Write-Host "       Panel de control → Centro de redes → Cambiar config. avanzada" -ForegroundColor Gray
Write-Host "       → Activar descubrimiento de red" -ForegroundColor Gray
Write-Host ""

Write-Host "  ERROR: 'Las credenciales no funcionan'" -ForegroundColor Yellow
Write-Host "    1. Windows puede cachear credenciales antiguas. Limpia con:" -ForegroundColor White
Write-Host "       net use * /delete /yes" -ForegroundColor Gray
Write-Host "    2. Limpia el cache de credenciales:" -ForegroundColor White
Write-Host "       rundll32.exe keymgr.dll, KRGuiMain" -ForegroundColor Gray
Write-Host "       (Elimina las entradas del servidor DataCorp)" -ForegroundColor Gray
Write-Host "    3. Intenta con el formato DOMINIO\usuario:" -ForegroundColor White
Write-Host "       net use K: \\$IP_SERVIDOR\contabilidad /user:DATACORP\dani Dani2026" -ForegroundColor Gray
Write-Host ""

Write-Host "  ERROR: 'Error de sistema 53 - No se encontro la ruta'" -ForegroundColor Yellow
Write-Host "    1. El servidor no esta accesible. Verifica con:" -ForegroundColor White
Write-Host "       ping $IP_SERVIDOR" -ForegroundColor Gray
Write-Host "       Test-NetConnection -ComputerName $IP_SERVIDOR -Port 445" -ForegroundColor Gray
Write-Host ""

Write-Host "  ERROR: 'Error de sistema 5 - Acceso denegado'" -ForegroundColor Yellow
Write-Host "    1. El usuario no tiene permiso para ese share (correcto!)" -ForegroundColor White
Write-Host "    2. Verifica que el usuario y contrasena son correctos" -ForegroundColor White
Write-Host ""

Write-Host "  PROBLEMA: No se negocia la version de SMB" -ForegroundColor Yellow
Write-Host "    1. Verificar version de SMB en uso (PowerShell como admin):" -ForegroundColor White
Write-Host '       Get-SmbConnection | Format-Table ServerName, Dialect' -ForegroundColor Gray
Write-Host "    2. Deberia mostrar Dialect = 3.x.x (SMB3)" -ForegroundColor White
Write-Host ""

# ═══════════════════════════════════════════════════════════════════════════════
# VERIFICACIÓN FINAL
# ═══════════════════════════════════════════════════════════════════════════════
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   VERIFICACION FINAL" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "--- Unidades de red mapeadas actualmente ---" -ForegroundColor White
net use 2>&1 | Write-Host

Write-Host ""
Write-Host "--- Verificar version de SMB negociada ---" -ForegroundColor White
Write-Host "  Despues de conectarte a un share, ejecuta:" -ForegroundColor Gray
Write-Host '  Get-SmbConnection | Format-Table ServerName, ShareName, Dialect' -ForegroundColor Yellow
Write-Host "  Deberia mostrar Dialect = 3.x.x (SMB 3.0 o superior)" -ForegroundColor Gray
Write-Host ""

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   CONFIGURACION DEL CLIENTE WINDOWS COMPLETADA" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Proximos pasos:" -ForegroundColor White
Write-Host "  1. Mapea los shares con los comandos mostrados arriba" -ForegroundColor White
Write-Host "  2. Prueba acceso con diferentes usuarios" -ForegroundColor White
Write-Host "  3. Verifica que los permisos funcionan segun la matriz" -ForegroundColor White
Write-Host ""
Write-Host "  Acceso rapido desde el Explorador de archivos:" -ForegroundColor White
Write-Host "    Win+R → \\$IP_SERVIDOR → Enter" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
