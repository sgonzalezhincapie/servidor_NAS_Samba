#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT DE CONFIGURACIÓN DEL SERVIDOR NAS — DataCorp
# ═══════════════════════════════════════════════════════════════════════════════
# Proyecto  : Comunicaciones III — Tema 3 — Laboratorio NAS con Samba
# Integrantes: Manuela Marín Rojo, Daniel Trujillo F, Santiago González
# Servidor  : Ubuntu 24.04 LTS (Noble Numbat)
# Fecha     : Abril 2026
#
# DESCRIPCIÓN:
#   Este script configura desde cero un servidor NAS con Samba para la empresa
#   ficticia DataCorp. Crea la estructura de directorios, los grupos y usuarios,
#   aplica permisos POSIX y ACLs, e instala y arranca Samba.
#
# USO:
#   sudo bash setup_servidor.sh
#
# NOTA: Ejecutar como root (con sudo) en Ubuntu 24.04. El script se detiene
#       ante cualquier error gracias a "set -e".
# ═══════════════════════════════════════════════════════════════════════════════

# Detener el script inmediatamente si algún comando falla.
# Esto evita que un error pase desapercibido y se sigan ejecutando comandos
# sobre un estado incorrecto.
set -e

# ─────────────────────────────────────────────────────────────────────────────
# PASO 1: COMPROBACIÓN DE PRIVILEGIOS DE ROOT
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Samba, la creación de usuarios y la modificación de permisos
# requieren privilegios de superusuario. Si no somos root, no podemos continuar.
if [ "$(id -u)" -ne 0 ]; then
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║  ERROR: Este script debe ejecutarse como root (sudo).    ║"
    echo "║  Uso: sudo bash setup_servidor.sh                       ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "   CONFIGURACIÓN DEL SERVIDOR NAS — DataCorp"
echo "   Ubuntu 24.04 LTS + Samba"
echo "═══════════════════════════════════════════════════════════"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# PASO 2: ACTUALIZACIÓN DEL SISTEMA
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Antes de instalar paquetes nuevos, actualizamos la lista de paquetes
# disponibles (apt update). No hacemos "apt upgrade" porque puede fallar por
# problemas ajenos a Samba (ej: configuración de GRUB, paquetes de kernel
# retenidos) y no es necesario para nuestro laboratorio.
echo "[1/14] Actualizando lista de paquetes..."
apt update -y
echo "    ✓ Lista de paquetes actualizada."

# ─────────────────────────────────────────────────────────────────────────────
# PASO 3: INSTALACIÓN DE SAMBA Y HERRAMIENTAS
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Instalamos los paquetes necesarios:
#   - samba          : el servidor de archivos (implementa el protocolo SMB/CIFS)
#   - samba-common   : archivos de configuración compartidos (incluye smb.conf base)
#   - smbclient      : herramienta de línea de comandos para probar conexiones SMB
#   - acl            : herramientas para ACLs extendidas (setfacl, getfacl)
#   - attr           : herramientas para atributos extendidos en el sistema de archivos
echo "[2/14] Instalando Samba y herramientas..."
apt install -y samba samba-common smbclient acl attr
echo "    ✓ Samba y herramientas instaladas."

# ─────────────────────────────────────────────────────────────────────────────
# PASO 4: CREACIÓN DE LA ESTRUCTURA DE DIRECTORIOS
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Creamos la estructura de carpetas que simulará el sistema de archivos
# de la empresa DataCorp. /srv es el directorio estándar en Linux para datos
# servidos por el sistema (FTP, HTTP, Samba, etc.).
#
# Estructura:
# /srv/datacorp/
# ├── publico/               → Lectura para todos
# ├── departamentos/
# │   ├── contabilidad/      → Solo grupo contabilidad + administradores
# │   └── sistemas/          → Solo grupo sistemas + administradores
# ├── privado/               → Solo administradores
# └── admin/                 → Solo administradores
echo "[3/14] Creando estructura de directorios en /srv/datacorp/..."

# mkdir -p crea el directorio y todos los padres necesarios que no existan.
# Si ya existen, no da error.
mkdir -p /srv/datacorp/publico
mkdir -p /srv/datacorp/departamentos/contabilidad
mkdir -p /srv/datacorp/departamentos/sistemas
mkdir -p /srv/datacorp/privado
mkdir -p /srv/datacorp/admin

echo "    ✓ Directorios creados:"
echo "      /srv/datacorp/publico"
echo "      /srv/datacorp/departamentos/contabilidad"
echo "      /srv/datacorp/departamentos/sistemas"
echo "      /srv/datacorp/privado"
echo "      /srv/datacorp/admin"

# ─────────────────────────────────────────────────────────────────────────────
# PASO 5: CREACIÓN DE GRUPOS DEL SISTEMA
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: En Linux, los permisos se asignan a usuarios y a GRUPOS. Creamos
# grupos que representan los roles (RBAC = Role-Based Access Control):
#   - administradores : acceso total a todas las carpetas
#   - usuarios        : acceso a carpetas de departamento
#   - invitados       : solo lectura en /publico
#   - contabilidad    : grupo departamental para /departamentos/contabilidad
#   - sistemas        : grupo departamental para /departamentos/sistemas
#
# "groupadd" crea un nuevo grupo en /etc/group.
# "2>/dev/null || true" evita que el script falle si el grupo ya existe.
echo "[4/14] Creando grupos del sistema..."

groupadd administradores 2>/dev/null || echo "    (grupo 'administradores' ya existe)"
groupadd usuarios 2>/dev/null || echo "    (grupo 'usuarios' ya existe)"
groupadd invitados 2>/dev/null || echo "    (grupo 'invitados' ya existe)"
groupadd contabilidad 2>/dev/null || echo "    (grupo 'contabilidad' ya existe)"
groupadd sistemas 2>/dev/null || echo "    (grupo 'sistemas' ya existe)"

echo "    ✓ Grupos creados: administradores, usuarios, invitados, contabilidad, sistemas"

# ─────────────────────────────────────────────────────────────────────────────
# PASO 6: CREACIÓN DE USUARIOS DEL SISTEMA
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Samba requiere que cada usuario Samba exista primero como usuario
# del sistema Linux. Creamos usuarios con:
#   --no-create-home  : no crear directorio home (no lo necesitan, son usuarios de servicio)
#   --shell /usr/sbin/nologin : no pueden hacer login interactivo en el servidor
#     (esto es una medida de seguridad: solo pueden autenticarse vía Samba)
#
# Si el usuario ya existe, el "|| true" evita que el script falle.
echo "[5/14] Creando usuarios del sistema..."

# Por qué: "id admin" verifica si el usuario existe; solo lo creamos si no existe.
id admin &>/dev/null || useradd --no-create-home --shell /usr/sbin/nologin admin
echo "    Creado usuario: admin"

id Dani &>/dev/null || useradd --no-create-home --shell /usr/sbin/nologin Dani
echo "    Creado usuario: Dani"

id Santi &>/dev/null || useradd --no-create-home --shell /usr/sbin/nologin Santi
echo "    Creado usuario: Santi"

id invitado &>/dev/null || useradd --no-create-home --shell /usr/sbin/nologin invitado
echo "    Creado usuario: invitado"

echo "    ✓ Usuarios creados: admin, Dani, Santi, invitado"

# ─────────────────────────────────────────────────────────────────────────────
# PASO 7: ASIGNACIÓN DE USUARIOS A GRUPOS
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Cada usuario debe pertenecer a los grupos correctos para que los
# permisos funcionen. "usermod -aG" agrega al usuario a un grupo sin sacarlo
# de los demás (-a = append, -G = grupo suplementario).
echo "[6/14] Asignando usuarios a grupos..."

# admin → miembro de: administradores
# Por qué: admin es el superusuario del NAS, debe tener acceso a todo.
usermod -aG administradores admin
echo "    admin → administradores"

# Dani → miembro de: usuarios, contabilidad
# Por qué: Dani es un empleado del departamento de contabilidad.
usermod -aG usuarios Dani
usermod -aG contabilidad Dani
echo "    Dani → usuarios, contabilidad"

# Santi → miembro de: usuarios, sistemas
# Por qué: Santi es un empleado del departamento de sistemas.
usermod -aG usuarios Santi
usermod -aG sistemas Santi
echo "    Santi → usuarios, sistemas"

# invitado → miembro de: invitados
# Por qué: los invitados solo tienen acceso de lectura a /publico.
usermod -aG invitados invitado
echo "    invitado → invitados"

echo "    ✓ Asignaciones completas."

# ─────────────────────────────────────────────────────────────────────────────
# PASO 8: PERMISOS POSIX EN LOS DIRECTORIOS
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Los permisos POSIX (chmod/chown) son la primera capa de control de
# acceso. Aunque Samba tiene sus propias reglas, el sistema de archivos Linux
# SIEMPRE aplica sus permisos primero. Si Linux dice "no tienes permiso",
# Samba no puede hacer nada.
#
# Formato chmod: [propietario][grupo][otros]
#   r=4 (leer), w=2 (escribir), x=1 (ejecutar/entrar al directorio)
#   Ejemplo: 775 = rwxrwxr-x (propietario y grupo: todo; otros: leer+ejecutar)
echo "[7/14] Configurando permisos POSIX..."

# /srv/datacorp/ → root es dueño, el grupo administradores tiene acceso
# Por qué: El directorio raíz del NAS debe ser propiedad de root, y el grupo
# administradores debe poder acceder a todo el árbol.
chown root:administradores /srv/datacorp
chmod 755 /srv/datacorp

# /publico → todos pueden leer (otros: r+x), solo administradores escriben
# Por qué: 755 = rwxr-xr-x. El propietario (root) y grupo (administradores)
# pueden escribir; otros solo pueden leer y listar archivos.
chown root:administradores /srv/datacorp/publico
chmod 775 /srv/datacorp/publico
echo "    /publico → 775 (root:administradores)"

# /departamentos → acceso para el grupo usuarios
chown root:usuarios /srv/datacorp/departamentos
chmod 750 /srv/datacorp/departamentos
echo "    /departamentos → 750 (root:usuarios)"

# /departamentos/contabilidad → grupo contabilidad
# Por qué: 2770 = rwxrws--- (el "2" al inicio activa el bit SGID).
# SGID en directorio significa que los nuevos archivos creados aquí heredarán
# automáticamente el grupo del directorio (contabilidad), no el grupo del
# usuario que los crea. Esto es crucial para que todos los del departamento
# puedan acceder a los archivos de los demás.
chown root:contabilidad /srv/datacorp/departamentos/contabilidad
chmod 2770 /srv/datacorp/departamentos/contabilidad
echo "    /departamentos/contabilidad → 2770 (root:contabilidad, SGID)"

# /departamentos/sistemas → grupo sistemas
# Por qué: Misma lógica que contabilidad, pero para el departamento de sistemas.
chown root:sistemas /srv/datacorp/departamentos/sistemas
chmod 2770 /srv/datacorp/departamentos/sistemas
echo "    /departamentos/sistemas → 2770 (root:sistemas, SGID)"

# /privado → solo administradores
# Por qué: 770 = rwxrwx--- Solo root (propietario) y el grupo administradores
# pueden acceder. Nadie más.
chown root:administradores /srv/datacorp/privado
chmod 770 /srv/datacorp/privado
echo "    /privado → 770 (root:administradores)"

# /admin → solo administradores
# Por qué: Igual que /privado, restringido completamente a administradores.
chown root:administradores /srv/datacorp/admin
chmod 770 /srv/datacorp/admin
echo "    /admin → 770 (root:administradores)"

echo "    ✓ Permisos POSIX configurados."

# ─────────────────────────────────────────────────────────────────────────────
# PASO 9: VERIFICAR QUE EL SISTEMA DE ARCHIVOS SOPORTA ACLs
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Las ACLs (Access Control Lists) permiten permisos más granulares
# que los POSIX básicos (propietario/grupo/otros). La mayoría de los sistemas
# de archivos modernos (ext4, xfs) las soportan por defecto en Ubuntu 24.04.
# Verificamos que estén activas en la partición donde está /srv.
echo "[8/14] Verificando soporte de ACLs..."

# Por qué: "tune2fs -l" muestra las opciones del sistema de archivos.
# Si el sistema usa ext4, buscamos "acl" en las opciones de montaje.
# En Ubuntu 24.04 con ext4, las ACLs están habilitadas por defecto.
PARTICION=$(df /srv | tail -1 | awk '{print $1}')
echo "    Partición de /srv: $PARTICION"

# Intentamos verificar si es ext4 y si tiene soporte ACL
if command -v tune2fs &>/dev/null; then
    FS_OPTIONS=$(tune2fs -l "$PARTICION" 2>/dev/null | grep "Default mount options" || true)
    if echo "$FS_OPTIONS" | grep -q "acl"; then
        echo "    ✓ ACLs habilitadas por defecto en el sistema de archivos."
    else
        echo "    ⚠ No se detectó 'acl' en las opciones por defecto."
        echo "      En Ubuntu 24.04 con ext4, las ACLs funcionan igual (están en el kernel)."
        echo "      Si hay problemas, agrega 'acl' a las opciones de montaje en /etc/fstab."
    fi
else
    echo "    ℹ No se pudo verificar con tune2fs. Continuando (ext4 soporta ACL por defecto)."
fi

# ─────────────────────────────────────────────────────────────────────────────
# PASO 10: APLICACIÓN DE ACLs (CONTROL GRANULAR DE ACCESO)
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Los permisos POSIX básicos solo permiten asignar permisos a UN
# propietario y UN grupo. Con ACLs podemos dar permisos a MÚLTIPLES grupos
# en el mismo directorio. Esto es esencial para nuestro modelo RBAC.
#
# setfacl opciones más usadas:
#   -R        : aplicar recursivamente a todo el contenido
#   -m        : modificar (agregar/cambiar una regla)
#   -d        : establecer como default (los nuevos archivos heredan esta ACL)
#   g:grupo:rwx : dar permisos rwx al grupo especificado
echo "[9/14] Aplicando ACLs..."

# ── /publico ──
# Por qué: Todos pueden leer. Los administradores pueden escribir.
# Los usuarios e invitados solo pueden leer y listar (r-x).

# Primero limpiamos ACLs existentes para empezar limpio
setfacl -R -b /srv/datacorp/publico

# ACLs en /publico: administradores escriben, usuarios e invitados solo leen
setfacl -R -m g:administradores:rwx /srv/datacorp/publico
setfacl -R -m g:usuarios:r-x /srv/datacorp/publico
setfacl -R -m g:invitados:r-x /srv/datacorp/publico
# ACLs por defecto: los nuevos archivos creados aquí heredan estas reglas
setfacl -d -m g:administradores:rwx /srv/datacorp/publico
setfacl -d -m g:usuarios:r-x /srv/datacorp/publico
setfacl -d -m g:invitados:r-x /srv/datacorp/publico
echo "    /publico → ACLs: admin=rwx, usuarios=r-x, invitados=r-x"

# ── /departamentos/contabilidad ──
# Por qué: Los del grupo contabilidad y administradores pueden leer+escribir.
# Los demás usuarios no tienen acceso (lo controla Samba y POSIX).
setfacl -R -b /srv/datacorp/departamentos/contabilidad
setfacl -R -m g:administradores:rwx /srv/datacorp/departamentos/contabilidad
setfacl -R -m g:contabilidad:rwx /srv/datacorp/departamentos/contabilidad
setfacl -d -m g:administradores:rwx /srv/datacorp/departamentos/contabilidad
setfacl -d -m g:contabilidad:rwx /srv/datacorp/departamentos/contabilidad
echo "    /departamentos/contabilidad → ACLs: admin=rwx, contabilidad=rwx"

# ── /departamentos/sistemas ──
# Por qué: Los del grupo sistemas y administradores pueden leer+escribir.
setfacl -R -b /srv/datacorp/departamentos/sistemas
setfacl -R -m g:administradores:rwx /srv/datacorp/departamentos/sistemas
setfacl -R -m g:sistemas:rwx /srv/datacorp/departamentos/sistemas
setfacl -d -m g:administradores:rwx /srv/datacorp/departamentos/sistemas
setfacl -d -m g:sistemas:rwx /srv/datacorp/departamentos/sistemas
echo "    /departamentos/sistemas → ACLs: admin=rwx, sistemas=rwx"

# ── /privado ──
# Por qué: Solo administradores. ACLs refuerzan lo que ya dice chmod 770.
setfacl -R -b /srv/datacorp/privado
setfacl -R -m g:administradores:rwx /srv/datacorp/privado
setfacl -d -m g:administradores:rwx /srv/datacorp/privado
echo "    /privado → ACLs: admin=rwx"

# ── /admin ──
# Por qué: Solo administradores. Igual que /privado.
setfacl -R -b /srv/datacorp/admin
setfacl -R -m g:administradores:rwx /srv/datacorp/admin
setfacl -d -m g:administradores:rwx /srv/datacorp/admin
echo "    /admin → ACLs: admin=rwx"

echo "    ✓ ACLs aplicadas correctamente."

# ─────────────────────────────────────────────────────────────────────────────
# PASO 11: CREACIÓN DE USUARIOS EN SAMBA
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Samba mantiene su PROPIA base de datos de contraseñas, separada de
# la de Linux. Un usuario puede existir en Linux pero no en Samba (y viceversa,
# aunque no es recomendable). Debemos agregar cada usuario a Samba con
# smbpasswd -a (add).
#
# NOTA IMPORTANTE: Las contraseñas aquí son de ejemplo para un laboratorio.
# En un entorno real, NUNCA hardcodees contraseñas en scripts.
echo "[10/14] Creando usuarios en Samba..."

# Por qué: "(echo 'pass'; echo 'pass')" envía la contraseña dos veces
# (una para "New SMB password" y otra para "Retype new SMB password")
# sin necesidad de interacción manual.

# NOTA: Cambiar en producción
(echo "Admin2026"; echo "Admin2026") | smbpasswd -s -a admin
echo "    Usuario Samba creado: admin (contraseña: Admin2026)"

# NOTA: Cambiar en producción
(echo "Dani2026"; echo "Dani2026") | smbpasswd -s -a Dani
echo "    Usuario Samba creado: Dani (contraseña: Dani2026)"

# NOTA: Cambiar en producción
(echo "Santi2026"; echo "Santi2026") | smbpasswd -s -a Santi
echo "    Usuario Samba creado: Santi (contraseña: Santi2026)"

# NOTA: Cambiar en producción
(echo "Invitado2026"; echo "Invitado2026") | smbpasswd -s -a invitado
echo "    Usuario Samba creado: invitado (contraseña: Invitado2026)"

# Por qué: Habilitamos cada usuario para que pueda autenticarse en Samba.
smbpasswd -e admin
smbpasswd -e Dani
smbpasswd -e Santi
smbpasswd -e invitado

echo "    ✓ Usuarios Samba creados y habilitados."
echo ""
echo "    ┌──────────────────────────────────────────────┐"
echo "    │  CONTRASEÑAS DE EJEMPLO (CAMBIAR EN PROD.)   │"
echo "    ├──────────────┬───────────────────────────────┤"
echo "    │ admin        │ Admin2026                     │"
echo "    │ Dani         │ Dani2026                      │"
echo "    │ Santi        │ Santi2026                     │"
echo "    │ invitado     │ Invitado2026                  │"
echo "    └──────────────┴───────────────────────────────┘"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# PASO 12: INSTALAR ARCHIVO DE CONFIGURACIÓN smb.conf
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Hacemos una copia de respaldo del smb.conf original antes de
# reemplazarlo con el nuestro. Si algo sale mal, podemos restaurarlo.
echo "[11/14] Instalando archivo smb.conf..."

# Backup del archivo original
if [ -f /etc/samba/smb.conf ]; then
    cp /etc/samba/smb.conf /etc/samba/smb.conf.backup.$(date +%Y%m%d_%H%M%S)
    echo "    Backup creado: /etc/samba/smb.conf.backup.$(date +%Y%m%d_%H%M%S)"
fi

# Por qué: Verificamos si existe nuestro smb.conf personalizado en el mismo
# directorio que este script. Si no existe, advertimos al usuario.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/smb.conf" ]; then
    cp "$SCRIPT_DIR/smb.conf" /etc/samba/smb.conf
    echo "    ✓ smb.conf copiado desde $SCRIPT_DIR/smb.conf"
else
    echo "    ⚠ ADVERTENCIA: No se encontró smb.conf en $SCRIPT_DIR"
    echo "      Debes copiar manualmente el archivo smb.conf a /etc/samba/smb.conf"
    echo "      antes de iniciar Samba."
fi

# ─────────────────────────────────────────────────────────────────────────────
# PASO 13: HABILITAR Y ARRANCAR SERVICIOS DE SAMBA
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Samba usa dos servicios:
#   - smbd: el demonio principal que sirve archivos y gestiona autenticación SMB
#   - nmbd: el demonio de resolución de nombres NetBIOS (permite que los
#           clientes encuentren el servidor por nombre en la red local)
#
# "systemctl enable" hace que el servicio se inicie automáticamente al arrancar.
# "systemctl restart" inicia (o reinicia) el servicio ahora mismo.
echo "[12/14] Habilitando y arrancando servicios de Samba..."

# Por qué: enable = arrancar automáticamente en cada inicio del sistema
systemctl enable smbd
systemctl enable nmbd

# Por qué: restart = (re)iniciar ahora para aplicar la configuración
systemctl restart smbd
systemctl restart nmbd

echo "    ✓ smbd habilitado e iniciado."
echo "    ✓ nmbd habilitado e iniciado."

# ─────────────────────────────────────────────────────────────────────────────
# PASO 14: CONFIGURACIÓN DEL FIREWALL
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Ubuntu 24.04 puede tener UFW (Uncomplicated Firewall) activo.
# Si el firewall está bloqueando los puertos de Samba (445/TCP y 139/TCP),
# los clientes no podrán conectarse. "ufw allow samba" abre los puertos
# necesarios automáticamente.
echo "[13/14] Configurando firewall..."

# Por qué: Solo configuramos UFW si está instalado y activo
if command -v ufw &>/dev/null; then
    ufw allow samba
    echo "    ✓ Regla de firewall agregada: ufw allow samba"
    echo "    Puertos abiertos: 137/UDP, 138/UDP, 139/TCP, 445/TCP"
else
    echo "    ℹ UFW no está instalado o activo. Si usas otro firewall,"
    echo "      asegúrate de abrir los puertos: 137/UDP, 138/UDP, 139/TCP, 445/TCP"
fi

# ─────────────────────────────────────────────────────────────────────────────
# PASO 15: VERIFICACIÓN FINAL
# ─────────────────────────────────────────────────────────────────────────────
echo "[14/14] Ejecutando verificaciones finales..."
echo ""

# === VERIFICACIÓN ===

echo "─── Verificación 1: Estado de los servicios ───"
# Por qué: Comprobamos que smbd y nmbd están corriendo
systemctl is-active smbd && echo "    ✓ smbd está activo" || echo "    ✗ smbd NO está activo"
systemctl is-active nmbd && echo "    ✓ nmbd está activo" || echo "    ✗ nmbd NO está activo"
echo ""

echo "─── Verificación 2: testparm (validar smb.conf) ───"
# Por qué: testparm verifica la sintaxis del archivo smb.conf y muestra errores.
# Es la forma oficial de validar la configuración de Samba.
testparm -s 2>&1 | head -30
echo ""

echo "─── Verificación 3: Recursos compartidos visibles ───"
# Por qué: smbclient -L lista los shares disponibles en el servidor.
# -N = sin contraseña (conexión anónima, solo para ver la lista).
smbclient -L localhost -N 2>&1 || echo "    (Puede mostrar un error de autenticación, es normal con 'map to guest = bad user')"
echo ""

echo "─── Verificación 4: Estructura de directorios ───"
# Por qué: Verificamos que toda la estructura se creó correctamente
ls -la /srv/datacorp/
echo ""
ls -la /srv/datacorp/departamentos/
echo ""

echo "─── Verificación 5: ACLs aplicadas ───"
# Por qué: getfacl muestra las ACLs de cada directorio
echo "ACLs de /publico:"
getfacl /srv/datacorp/publico
echo ""
echo "ACLs de /departamentos/contabilidad:"
getfacl /srv/datacorp/departamentos/contabilidad
echo ""

echo "─── Verificación 6: Usuarios de Samba ───"
# Por qué: pdbedit -L lista todos los usuarios registrados en Samba
pdbedit -L
echo ""

echo "─── Verificación 7: Grupos y miembros ───"
# Por qué: Verificamos que los usuarios estén en los grupos correctos
echo "Grupo administradores:"
getent group administradores
echo "Grupo usuarios:"
getent group usuarios
echo "Grupo invitados:"
getent group invitados
echo "Grupo contabilidad:"
getent group contabilidad
echo "Grupo sistemas:"
getent group sistemas
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# RESUMEN FINAL
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "   CONFIGURACIÓN COMPLETADA EXITOSAMENTE"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "   Resumen de lo configurado:"
echo "   ─────────────────────────────────────────────────────"
echo "   ✓ Sistema actualizado"
echo "   ✓ Samba instalado ($(smbd --version))"
echo "   ✓ Estructura de directorios creada en /srv/datacorp/"
echo "   ✓ 5 grupos creados: administradores, usuarios, invitados,"
echo "     contabilidad, sistemas"
echo "   ✓ 4 usuarios creados: admin, Dani, Santi, invitado"
echo "   ✓ Permisos POSIX y ACLs configurados"
echo "   ✓ Usuarios registrados en Samba"
echo "   ✓ Servicios smbd y nmbd activos y habilitados"
echo "   ✓ Firewall configurado (si aplica)"
echo ""
echo "   NOTA: Recuerda configurar la IP fija con Netplan"
echo "   antes de que el cliente intente conectarse."
echo "   (Ver INSTRUCTIVO.md, PARTE A, Paso 1)"
echo ""
echo "   IP actual del servidor:"
ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1'
echo ""
echo "   Interfaz de red detectada:"
ip -4 route show default | awk '{print $5}'
echo ""
echo "═══════════════════════════════════════════════════════════"
