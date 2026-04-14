#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT DE CONFIGURACIÓN DEL CLIENTE — Arch Linux
# ═══════════════════════════════════════════════════════════════════════════════
# Proyecto  : Comunicaciones III — Tema 3 — Laboratorio NAS con Samba
# Integrantes: Manuela Marín Rojo, Daniel Trujillo F, Santiago González
# Cliente   : Arch Linux (rolling release)
# Fecha     : Abril 2026
#
# DESCRIPCIÓN:
#   Este script configura un cliente Arch Linux para acceder a los recursos
#   compartidos del servidor NAS DataCorp vía Samba/CIFS.
#
# USO:
#   sudo bash setup_cliente_arch.sh
#
# ANTES DE EJECUTAR:
#   Reemplaza <IP_SERVIDOR> por la IP real del servidor Ubuntu.
#   Para encontrarla, en el servidor ejecuta: ip -4 addr show | grep inet
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# ─────────────────────────────────────────────────────────────────────────────
# VARIABLE DE CONFIGURACIÓN — MODIFICAR ANTES DE EJECUTAR
# ─────────────────────────────────────────────────────────────────────────────
# IMPORTANTE: Cambia esta IP por la IP real de tu servidor Ubuntu 24.04
IP_SERVIDOR="10.253.45.194"
#IP_SERVIDOR="<IP_SERVIDOR>"

# ─────────────────────────────────────────────────────────────────────────────
# PASO 0: COMPROBACIONES INICIALES
# ─────────────────────────────────────────────────────────────────────────────

# Por qué: Necesitamos ser root para instalar paquetes y montar sistemas de archivos
if [ "$(id -u)" -ne 0 ]; then
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║  ERROR: Este script debe ejecutarse como root (sudo).    ║"
    echo "║  Uso: sudo bash setup_cliente_arch.sh                   ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    exit 1
fi

# Por qué: Verificamos que el usuario haya reemplazado el placeholder
if [ "$IP_SERVIDOR" = "10.253.45.194" ]; then
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║  ERROR: Debes configurar la IP del servidor.             ║"
    echo "║                                                          ║"
    echo "║  Abre este script y cambia la línea:                     ║"
    echo '║    IP_SERVIDOR="<IP_SERVIDOR>"                           ║'
    echo "║  Por la IP real del servidor Ubuntu, por ejemplo:        ║"
    echo '║    IP_SERVIDOR="192.168.1.100"                           ║'
    echo "╚═══════════════════════════════════════════════════════════╝"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "   CONFIGURACIÓN DEL CLIENTE NAS — DataCorp"
echo "   Arch Linux → Servidor: $IP_SERVIDOR"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# PASO 1: INSTALACIÓN DE PAQUETES NECESARIOS
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: En Arch Linux necesitamos estos paquetes para acceder a shares SMB:
#   - cifs-utils : proporciona mount.cifs, que permite montar shares SMB como
#                  si fueran directorios locales
#   - smbclient  : herramienta de línea de comandos para explorar y probar
#                  conexiones a servidores SMB (como un "explorador de archivos
#                  en terminal")
#
# "--needed" evita reinstalar paquetes que ya están instalados.
# "--noconfirm" responde automáticamente "sí" a las preguntas.
echo "[1/5] Instalando paquetes necesarios..."
pacman -S --needed --noconfirm cifs-utils smbclient
echo "    ✓ cifs-utils instalado (proporciona mount.cifs)"
echo "    ✓ smbclient instalado (herramienta de prueba)"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# PASO 2: VERIFICACIÓN DE CONECTIVIDAD CON EL SERVIDOR
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Antes de intentar montar shares, verificamos que:
#   a) Hay conexión de red con el servidor (ping)
#   b) Samba está respondiendo en el servidor (smbclient -L)
echo "[2/5] Verificando conectividad con el servidor ($IP_SERVIDOR)..."

# Por qué: ping -c 3 envía 3 paquetes y espera respuesta.
# Si no hay respuesta, el servidor está apagado, sin red, o hay un firewall.
echo "  → Probando ping..."
if ping -c 3 -W 2 "$IP_SERVIDOR" &>/dev/null; then
    echo "    ✓ El servidor $IP_SERVIDOR responde al ping."
else
    echo "    ✗ El servidor $IP_SERVIDOR NO responde al ping."
    echo "      Posibles causas:"
    echo "      - El servidor está apagado"
    echo "      - No están en la misma red"
    echo "      - El firewall del servidor bloquea ICMP"
    echo "      Puedes continuar, pero los montajes probablemente fallarán."
fi

# Por qué: smbclient -L lista los shares del servidor. -N = sin contraseña.
# Esto verifica que Samba está corriendo y accesible en el puerto 445.
echo "  → Probando conexión SMB..."
if smbclient -L "//$IP_SERVIDOR" -N 2>/dev/null | grep -q "Disk"; then
    echo "    ✓ Samba en $IP_SERVIDOR está accesible. Shares detectados:"
    smbclient -L "//$IP_SERVIDOR" -N 2>/dev/null | grep "Disk" | sed 's/^/      /'
else
    echo "    ⚠ No se pudieron listar los shares de $IP_SERVIDOR"
    echo "      Esto puede ser normal si 'map to guest = bad user' está activo."
    echo "      Intenta con usuario: smbclient -L //$IP_SERVIDOR -U admin"
fi
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# PASO 3: CREACIÓN DE PUNTOS DE MONTAJE
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: En Linux, para acceder a un recurso de red como si fuera un
# directorio local, necesitas un "punto de montaje": una carpeta vacía donde
# se "proyecta" el contenido del share remoto.
#
# /mnt es el directorio estándar para montajes temporales.
# Creamos un subdirectorio para cada share de DataCorp.
echo "[3/5] Creando puntos de montaje en /mnt/datacorp/..."

mkdir -p /mnt/datacorp/publico
mkdir -p /mnt/datacorp/contabilidad
mkdir -p /mnt/datacorp/sistemas
mkdir -p /mnt/datacorp/privado
mkdir -p /mnt/datacorp/admin

echo "    ✓ Puntos de montaje creados:"
echo "      /mnt/datacorp/publico"
echo "      /mnt/datacorp/contabilidad"
echo "      /mnt/datacorp/sistemas"
echo "      /mnt/datacorp/privado"
echo "      /mnt/datacorp/admin"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# PASO 4: VERIFICAR VERSIÓN DE SMB NEGOCIADA
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Es importante saber qué versión de SMB se está usando en la
# comunicación. SMB3 es más seguro y rápido que SMB2.
# Ubuntu 24.04 con Samba 4.x soporta SMB2 y SMB3.
# Arch Linux con cifs-utils también soporta ambos.
echo "[4/5] Verificando versión de SMB..."

# Por qué: smbclient --max-protocol nos permite verificar qué versiones soporta
echo "  Versiones de SMB soportadas por el cliente:"
echo "    $(smbclient --version)"
echo ""
echo "  NOTA sobre compatibilidad Ubuntu 24.04 ↔ Arch Linux:"
echo "    - Ubuntu 24.04 usa Samba 4.19+ con SMB2/SMB3 por defecto"
echo "    - Arch Linux usa cifs-utils que soporta SMB2/SMB3"
echo "    - La versión se negocia automáticamente (generalmente SMB3)"
echo "    - Nuestro smb.conf fuerza min protocol = SMB2 por seguridad"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# PASO 5: MONTAJE DE RECURSOS COMPARTIDOS
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: mount.cifs monta un share SMB/CIFS como un directorio local.
# Equivale a "conectar una unidad de red" en Windows.
#
# Opciones de montaje explicadas:
#   vers=3.0      : Forzar el uso de SMB versión 3.0 (seguro y compatible)
#   uid=1000      : El usuario local que "posee" los archivos montados
#                   (1000 suele ser el primer usuario creado en Linux)
#   gid=1000      : El grupo local para los archivos montados
#   iocharset=utf8: Codificación de caracteres para nombres de archivo con
#                   acentos, ñ, etc.
#   file_mode=0664: Permisos de archivos montados (rw-rw-r--)
#   dir_mode=0775 : Permisos de directorios montados (rwxrwxr-x)
echo "[5/5] Montando recursos compartidos..."
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "   COMANDOS DE MONTAJE MANUAL"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "A continuación se muestran los comandos para montar cada"
echo "share como diferentes usuarios. Cópialos y ejecútalos"
echo "según el perfil que quieras probar."
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# MONTAJE COMO INVITADO (sin contraseña)
# ─────────────────────────────────────────────────────────────────────────────
echo "┌───────────────────────────────────────────────────────┐"
echo "│  MONTAJE COMO INVITADO (solo /publico)               │"
echo "├───────────────────────────────────────────────────────┤"
echo "│                                                       │"
echo "│  # Montar /publico como invitado (sin contraseña):    │"
echo "│  mount.cifs //$IP_SERVIDOR/publico /mnt/datacorp/publico \\"
echo "│    -o guest,vers=3.0,uid=1000,gid=1000,iocharset=utf8│"
echo "│                                                       │"
echo "│  # Verificar:                                         │"
echo "│  ls -la /mnt/datacorp/publico                         │"
echo "│                                                       │"
echo "│  # Probar que NO puede escribir:                      │"
echo "│  touch /mnt/datacorp/publico/test_invitado.txt        │"
echo "│  (Debería dar: Permission denied)                     │"
echo "└───────────────────────────────────────────────────────┘"
echo ""

# Montaje automático de /publico como invitado
echo "  → Montando /publico como invitado..."
mount.cifs "//$IP_SERVIDOR/publico" /mnt/datacorp/publico \
    -o guest,vers=3.0,uid=1000,gid=1000,iocharset=utf8 2>/dev/null \
    && echo "    ✓ /publico montado exitosamente." \
    || echo "    ✗ Error al montar /publico. Verifica la IP y que Samba esté corriendo."

# ─────────────────────────────────────────────────────────────────────────────
# MONTAJE COMO DANI (departamento de contabilidad)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "┌───────────────────────────────────────────────────────┐"
echo "│  MONTAJE COMO DANI (contabilidad)                     │"
echo "├───────────────────────────────────────────────────────┤"
echo "│                                                       │"
echo "│  # Montar /contabilidad como Dani:                    │"
echo "│  mount.cifs //$IP_SERVIDOR/contabilidad \\             │"
echo "│    /mnt/datacorp/contabilidad \\                       │"
echo "│    -o username=Dani,password=Dani2026,\\               │"
echo "│       vers=3.0,uid=1000,gid=1000,iocharset=utf8      │"
echo "│                                                       │"
echo "│  # Verificar:                                         │"
echo "│  ls -la /mnt/datacorp/contabilidad                    │"
echo "│                                                       │"
echo "│  # Probar escritura (debería funcionar):              │"
echo "│  echo 'Prueba de Dani' > \\                           │"
echo "│    /mnt/datacorp/contabilidad/archivo_dani.txt        │"
echo "│                                                       │"
echo "│  # NOTA: Cambiar contraseña en producción             │"
echo "└───────────────────────────────────────────────────────┘"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# MONTAJE COMO SANTI (departamento de sistemas)
# ─────────────────────────────────────────────────────────────────────────────
echo "┌───────────────────────────────────────────────────────┐"
echo "│  MONTAJE COMO SANTI (sistemas)                        │"
echo "├───────────────────────────────────────────────────────┤"
echo "│                                                       │"
echo "│  # Montar /sistemas como Santi:                       │"
echo "│  mount.cifs //$IP_SERVIDOR/sistemas \\                 │"
echo "│    /mnt/datacorp/sistemas \\                           │"
echo "│    -o username=Santi,password=Santi2026,\\             │"
echo "│       vers=3.0,uid=1000,gid=1000,iocharset=utf8      │"
echo "│                                                       │"
echo "│  # Verificar:                                         │"
echo "│  ls -la /mnt/datacorp/sistemas                        │"
echo "│                                                       │"
echo "│  # Probar escritura (debería funcionar):              │"
echo "│  echo 'Prueba de Santi' > \\                          │"
echo "│    /mnt/datacorp/sistemas/archivo_santi.txt           │"
echo "│                                                       │"
echo "│  # NOTA: Cambiar contraseña en producción             │"
echo "└───────────────────────────────────────────────────────┘"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# MONTAJE COMO ADMIN (acceso total)
# ─────────────────────────────────────────────────────────────────────────────
echo "┌───────────────────────────────────────────────────────┐"
echo "│  MONTAJE COMO ADMIN (acceso total)                    │"
echo "├───────────────────────────────────────────────────────┤"
echo "│                                                       │"
echo "│  # Montar /privado como admin:                        │"
echo "│  mount.cifs //$IP_SERVIDOR/privado \\                  │"
echo "│    /mnt/datacorp/privado \\                            │"
echo "│    -o username=admin,password=Admin2026,\\             │"
echo "│       vers=3.0,uid=1000,gid=1000,iocharset=utf8      │"
echo "│                                                       │"
echo "│  # Montar /admin como admin (share oculto):           │"
echo "│  mount.cifs //$IP_SERVIDOR/admin \\                    │"
echo "│    /mnt/datacorp/admin \\                              │"
echo "│    -o username=admin,password=Admin2026,\\             │"
echo "│       vers=3.0,uid=1000,gid=1000,iocharset=utf8      │"
echo "│                                                       │"
echo "│  # NOTA: Cambiar contraseña en producción             │"
echo "└───────────────────────────────────────────────────────┘"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# CÓMO DESMONTAR
# ─────────────────────────────────────────────────────────────────────────────
echo "┌───────────────────────────────────────────────────────┐"
echo "│  DESMONTAR RECURSOS                                   │"
echo "├───────────────────────────────────────────────────────┤"
echo "│                                                       │"
echo "│  # Desmontar un share específico:                     │"
echo "│  umount /mnt/datacorp/publico                         │"
echo "│                                                       │"
echo "│  # Si da error 'busy', usar desmontaje perezoso:     │"
echo "│  umount -l /mnt/datacorp/publico                      │"
echo "│                                                       │"
echo "│  # Desmontar todos los shares de DataCorp:            │"
echo "│  umount /mnt/datacorp/publico 2>/dev/null             │"
echo "│  umount /mnt/datacorp/contabilidad 2>/dev/null        │"
echo "│  umount /mnt/datacorp/sistemas 2>/dev/null            │"
echo "│  umount /mnt/datacorp/privado 2>/dev/null             │"
echo "│  umount /mnt/datacorp/admin 2>/dev/null               │"
echo "└───────────────────────────────────────────────────────┘"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# SECCIÓN OPCIONAL: MONTAJE PERMANENTE CON /etc/fstab
# ═══════════════════════════════════════════════════════════════════════════════
echo "═══════════════════════════════════════════════════════════"
echo "   MONTAJE PERMANENTE (OPCIONAL) — /etc/fstab"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Si quieres que los shares se monten automáticamente cada"
echo "vez que el cliente se enciende, sigue estos pasos:"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Paso 1: Crear archivo de credenciales
# ─────────────────────────────────────────────────────────────────────────────
echo "┌───────────────────────────────────────────────────────┐"
echo "│  PASO 1: Crear archivo de credenciales                │"
echo "├───────────────────────────────────────────────────────┤"
echo "│                                                       │"
echo "│  # Por qué: Guardar la contraseña en /etc/fstab es    │"
echo "│  # inseguro porque cualquiera puede leerlo. Usamos    │"
echo "│  # un archivo separado con permisos restrictivos.     │"
echo "│                                                       │"
echo "│  # Crear directorio para credenciales:                │"
echo "│  sudo mkdir -p /etc/samba                             │"
echo "│                                                       │"
echo "│  # Crear archivo para Dani:                           │"
echo "│  sudo tee /etc/samba/credentials_dani > /dev/null <<EOF│"
echo "│  username=Dani                                        │"
echo "│  password=Dani2026                                    │"
echo "│  domain=DATACORP                                      │"
echo "│  EOF                                                  │"
echo "│                                                       │"
echo "│  # Proteger el archivo (solo root puede leerlo):      │"
echo "│  sudo chmod 600 /etc/samba/credentials_dani           │"
echo "│                                                       │"
echo "│  # Para otros usuarios, crear archivos similares:     │"
echo "│  # /etc/samba/credentials_santi                       │"
echo "│  # /etc/samba/credentials_admin                       │"
echo "└───────────────────────────────────────────────────────┘"
echo ""

# Por qué: Creamos el archivo de credenciales de ejemplo automáticamente
echo "  → Creando archivo de credenciales de ejemplo para Dani..."
mkdir -p /etc/samba

# NOTA: Cambiar en producción
cat > /etc/samba/credentials_dani <<EOF
username=dani
password=Dani2026
domain=DATACORP
EOF

# Por qué: chmod 600 = solo root puede leer y escribir este archivo.
# Esto evita que otros usuarios del sistema vean la contraseña.
chmod 600 /etc/samba/credentials_dani
echo "    ✓ /etc/samba/credentials_dani creado (permisos: 600)"

# Crear también para santi y admin
cat > /etc/samba/credentials_santi <<EOF
username=santi
password=Santi2026
domain=DATACORP
EOF
chmod 600 /etc/samba/credentials_santi
echo "    ✓ /etc/samba/credentials_santi creado"

cat > /etc/samba/credentials_admin <<EOF
username=admin
password=Admin2026
domain=DATACORP
EOF
chmod 600 /etc/samba/credentials_admin
echo "    ✓ /etc/samba/credentials_admin creado"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Paso 2: Agregar entradas a /etc/fstab
# ─────────────────────────────────────────────────────────────────────────────
echo "┌───────────────────────────────────────────────────────┐"
echo "│  PASO 2: Agregar a /etc/fstab                         │"
echo "├───────────────────────────────────────────────────────┤"
echo "│                                                       │"
echo "│  Agrega estas líneas al final de /etc/fstab:          │"
echo "│  (sudo nano /etc/fstab)                               │"
echo "│                                                       │"
echo "│  # DataCorp NAS - Montajes automáticos                │"
echo "│  //$IP_SERVIDOR/publico  /mnt/datacorp/publico  cifs  guest,vers=3.0,uid=1000,gid=1000,iocharset=utf8,_netdev,nofail  0  0"
echo "│  //$IP_SERVIDOR/contabilidad  /mnt/datacorp/contabilidad  cifs  credentials=/etc/samba/credentials_dani,vers=3.0,uid=1000,gid=1000,iocharset=utf8,_netdev,nofail  0  0"
echo "│                                                       │"
echo "│  OPCIONES IMPORTANTES:                                │"
echo "│  _netdev = esperar a que la red esté disponible       │"
echo "│  nofail  = no fallar si el servidor no responde       │"
echo "│            (evita que el cliente no arranque)          │"
echo "│  credentials= ruta al archivo con usuario/contraseña  │"
echo "└───────────────────────────────────────────────────────┘"
echo ""

# Por qué: NO agregamos automáticamente a fstab porque es irreversible.
# El usuario debe verificar y agregar manualmente.
echo "  ⚠ NOTA: NO se ha modificado /etc/fstab automáticamente."
echo "    Revisa las líneas de arriba y agrégalas manualmente."
echo "    Después, prueba con: sudo mount -a"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# VERIFICACIÓN FINAL
# ═══════════════════════════════════════════════════════════════════════════════

echo "═══════════════════════════════════════════════════════════"
echo "   VERIFICACIÓN FINAL"
echo "═══════════════════════════════════════════════════════════"
echo ""

echo "─── Paquetes instalados ───"
pacman -Q cifs-utils smbclient 2>/dev/null || echo "  ⚠ Algún paquete falta"
echo ""

echo "─── Puntos de montaje creados ───"
ls -la /mnt/datacorp/
echo ""

echo "─── Shares montados actualmente ───"
mount | grep cifs || echo "  (ningún share montado actualmente)"
echo ""

echo "─── Verificar versión de SMB en uso ───"
echo "  Para ver qué versión de SMB se negoció, después de montar ejecuta:"
echo "  cat /proc/fs/cifs/DebugData | grep -i dialect"
echo "  Deberías ver algo como: Dialect: 0x0300 (= SMB 3.0)"
echo ""

echo "═══════════════════════════════════════════════════════════"
echo "   CONFIGURACIÓN DEL CLIENTE COMPLETADA"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "  Próximos pasos:"
echo "  1. Monta los shares con los comandos mostrados arriba"
echo "  2. Prueba acceso con diferentes usuarios"
echo "  3. Verifica que los permisos funcionan según la matriz"
echo ""
echo "  Para probar rápidamente con smbclient (sin montar):"
echo "    smbclient //$IP_SERVIDOR/publico -N"
echo "    smbclient //$IP_SERVIDOR/contabilidad -U dani"
echo "    smbclient //$IP_SERVIDOR/sistemas -U santi"
echo "    smbclient //$IP_SERVIDOR/privado -U admin"
echo "═══════════════════════════════════════════════════════════"
