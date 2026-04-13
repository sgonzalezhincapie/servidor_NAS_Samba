#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT DE VERIFICACIÓN DE PERMISOS — DataCorp
# ═══════════════════════════════════════════════════════════════════════════════
# Proyecto  : Comunicaciones III — Tema 3 — Laboratorio NAS con Samba
# Integrantes: Manuela Marín Rojo, Daniel Trujillo F, Santiago González
# Ejecutar en: Servidor Ubuntu 24.04
# Fecha     : Abril 2026
#
# DESCRIPCIÓN:
#   Este script prueba automáticamente que los permisos del NAS DataCorp
#   están configurados correctamente. Para cada combinación usuario/carpeta,
#   intenta crear un archivo de prueba y verifica si el resultado coincide
#   con la matriz de permisos esperada.
#
# USO:
#   sudo bash verificacion_permisos.sh
#
# NOTA: Debe ejecutarse como root en el SERVIDOR (no en el cliente).
#       Las pruebas se hacen a nivel de sistema de archivos (POSIX + ACL),
#       no a través de Samba directamente.
# ═══════════════════════════════════════════════════════════════════════════════

set -u  # Error si se usa una variable no definida (pero sin set -e para capturar fallos)

# ─────────────────────────────────────────────────────────────────────────────
# VERIFICACIÓN DE PRIVILEGIOS
# ─────────────────────────────────────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Este script debe ejecutarse como root (sudo)."
    echo "Uso: sudo bash verificacion_permisos.sh"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# COLORES PARA LA SALIDA
# ─────────────────────────────────────────────────────────────────────────────
# Por qué: Los colores ANSI hacen que sea más fácil distinguir PASS de FAIL
# en la salida del terminal.
VERDE='\033[0;32m'
ROJO='\033[0;31m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
NEGRITA='\033[1m'
RESET='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# CONTADORES
# ─────────────────────────────────────────────────────────────────────────────
TOTAL=0
PASS=0
FAIL=0

# ─────────────────────────────────────────────────────────────────────────────
# DIRECTORIOS A PROBAR
# ─────────────────────────────────────────────────────────────────────────────
DIR_PUBLICO="/srv/datacorp/publico"
DIR_CONTABILIDAD="/srv/datacorp/departamentos/contabilidad"
DIR_SISTEMAS="/srv/datacorp/departamentos/sistemas"
DIR_PRIVADO="/srv/datacorp/privado"
DIR_ADMIN="/srv/datacorp/admin"

# ─────────────────────────────────────────────────────────────────────────────
# FUNCIONES DE PRUEBA
# ─────────────────────────────────────────────────────────────────────────────

# Función: test_write
# Prueba si un usuario puede crear un archivo en un directorio
# Parámetros:
#   $1 = nombre del usuario
#   $2 = ruta del directorio
#   $3 = "should_pass" si esperamos que SÍ pueda escribir
#         "should_fail" si esperamos que NO pueda escribir
test_write() {
    local USUARIO="$1"
    local DIRECTORIO="$2"
    local EXPECTATIVA="$3"
    local NOMBRE_DIR
    NOMBRE_DIR=$(basename "$DIRECTORIO")
    local ARCHIVO_PRUEBA="$DIRECTORIO/.test_permisos_${USUARIO}_$$"

    TOTAL=$((TOTAL + 1))

    # Por qué: "su -s /bin/bash -c" ejecuta un comando COMO el usuario
    # especificado. -s /bin/bash fuerza el shell (porque nuestros usuarios
    # tienen /usr/sbin/nologin como shell por defecto).
    if su -s /bin/bash -c "touch '$ARCHIVO_PRUEBA' 2>/dev/null && rm -f '$ARCHIVO_PRUEBA'" "$USUARIO" 2>/dev/null; then
        # El usuario PUDO escribir
        if [ "$EXPECTATIVA" = "should_pass" ]; then
            echo -e "  ${VERDE}[PASS]${RESET} ${USUARIO} puede escribir en /${NOMBRE_DIR} ${VERDE}✓${RESET}"
            PASS=$((PASS + 1))
        else
            echo -e "  ${ROJO}[FAIL]${RESET} ${USUARIO} pudo escribir en /${NOMBRE_DIR} ${ROJO}✗ (¡NO debería poder!)${RESET}"
            FAIL=$((FAIL + 1))
        fi
    else
        # El usuario NO pudo escribir
        if [ "$EXPECTATIVA" = "should_fail" ]; then
            echo -e "  ${VERDE}[PASS]${RESET} ${USUARIO} NO puede escribir en /${NOMBRE_DIR} ${VERDE}✓${RESET} (correcto: acceso denegado)"
            PASS=$((PASS + 1))
        else
            echo -e "  ${ROJO}[FAIL]${RESET} ${USUARIO} NO puede escribir en /${NOMBRE_DIR} ${ROJO}✗ (¡DEBERÍA poder!)${RESET}"
            FAIL=$((FAIL + 1))
        fi
    fi

    # Limpiar archivo de prueba si quedó
    rm -f "$ARCHIVO_PRUEBA" 2>/dev/null
}

# Función: test_read
# Prueba si un usuario puede listar el contenido de un directorio
# Parámetros:
#   $1 = nombre del usuario
#   $2 = ruta del directorio
#   $3 = "should_pass" o "should_fail"
test_read() {
    local USUARIO="$1"
    local DIRECTORIO="$2"
    local EXPECTATIVA="$3"
    local NOMBRE_DIR
    NOMBRE_DIR=$(basename "$DIRECTORIO")

    TOTAL=$((TOTAL + 1))

    # Por qué: "ls" intenta listar el directorio. Si no tiene permiso de
    # lectura (r) o acceso (x), fallará.
    if su -s /bin/bash -c "ls '$DIRECTORIO' >/dev/null 2>&1" "$USUARIO" 2>/dev/null; then
        # El usuario PUDO leer
        if [ "$EXPECTATIVA" = "should_pass" ]; then
            echo -e "  ${VERDE}[PASS]${RESET} ${USUARIO} puede leer en /${NOMBRE_DIR} ${VERDE}✓${RESET}"
            PASS=$((PASS + 1))
        else
            echo -e "  ${ROJO}[FAIL]${RESET} ${USUARIO} pudo leer en /${NOMBRE_DIR} ${ROJO}✗ (¡NO debería poder!)${RESET}"
            FAIL=$((FAIL + 1))
        fi
    else
        # El usuario NO pudo leer
        if [ "$EXPECTATIVA" = "should_fail" ]; then
            echo -e "  ${VERDE}[PASS]${RESET} ${USUARIO} NO puede leer en /${NOMBRE_DIR} ${VERDE}✓${RESET} (correcto: acceso denegado)"
            PASS=$((PASS + 1))
        else
            echo -e "  ${ROJO}[FAIL]${RESET} ${USUARIO} NO puede leer en /${NOMBRE_DIR} ${ROJO}✗ (¡DEBERÍA poder!)${RESET}"
            FAIL=$((FAIL + 1))
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# EJECUCIÓN DE PRUEBAS
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${NEGRITA}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${NEGRITA}   VERIFICACIÓN DE PERMISOS — NAS DataCorp${RESET}"
echo -e "${NEGRITA}═══════════════════════════════════════════════════════════${RESET}"
echo ""
echo "  Matriz de permisos esperada:"
echo "  ┌─────────────────────┬───────────────┬──────────┬───────────┐"
echo "  │ Carpeta             │ administradores│ usuarios │ invitados │"
echo "  ├─────────────────────┼───────────────┼──────────┼───────────┤"
echo "  │ /publico            │     R+W       │    R     │     R     │"
echo "  │ /contabilidad       │     R+W       │   R+W*   │ Sin acceso│"
echo "  │ /sistemas           │     R+W       │   R+W*   │ Sin acceso│"
echo "  │ /privado            │     R+W       │ Sin acceso│Sin acceso│"
echo "  │ /admin              │     R+W       │ Sin acceso│Sin acceso│"
echo "  └─────────────────────┴───────────────┴──────────┴───────────┘"
echo "  (* solo usuarios del grupo de ese departamento)"
echo ""

# ─── Verificar que los usuarios existen ───
echo -e "${AZUL}── Verificación previa: usuarios y grupos ──${RESET}"
for USER in admin juan maria invitado; do
    if id "$USER" &>/dev/null; then
        echo -e "  ${VERDE}✓${RESET} Usuario '$USER' existe: $(groups $USER 2>/dev/null)"
    else
        echo -e "  ${ROJO}✗${RESET} Usuario '$USER' NO existe. Ejecuta setup_servidor.sh primero."
        exit 1
    fi
done
echo ""

# ─── Verificar que los directorios existen ───
for DIR in "$DIR_PUBLICO" "$DIR_CONTABILIDAD" "$DIR_SISTEMAS" "$DIR_PRIVADO" "$DIR_ADMIN"; do
    if [ ! -d "$DIR" ]; then
        echo -e "  ${ROJO}✗${RESET} Directorio '$DIR' NO existe. Ejecuta setup_servidor.sh primero."
        exit 1
    fi
done
echo -e "  ${VERDE}✓${RESET} Todos los directorios existen."
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# PRUEBAS DE ADMIN (administradores)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${AZUL}── Pruebas para: admin (grupo: administradores) ──${RESET}"
echo "   admin debe tener acceso R+W a TODAS las carpetas."
echo ""
test_read  "admin" "$DIR_PUBLICO"       "should_pass"
test_write "admin" "$DIR_PUBLICO"       "should_pass"
test_read  "admin" "$DIR_CONTABILIDAD"  "should_pass"
test_write "admin" "$DIR_CONTABILIDAD"  "should_pass"
test_read  "admin" "$DIR_SISTEMAS"      "should_pass"
test_write "admin" "$DIR_SISTEMAS"      "should_pass"
test_read  "admin" "$DIR_PRIVADO"       "should_pass"
test_write "admin" "$DIR_PRIVADO"       "should_pass"
test_read  "admin" "$DIR_ADMIN"         "should_pass"
test_write "admin" "$DIR_ADMIN"         "should_pass"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# PRUEBAS DE JUAN (usuarios + contabilidad)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${AZUL}── Pruebas para: juan (grupos: usuarios, contabilidad) ──${RESET}"
echo "   juan puede: leer /publico, R+W en /contabilidad."
echo "   juan NO puede: escribir en /publico, acceder a /sistemas, /privado, /admin."
echo ""
test_read  "juan" "$DIR_PUBLICO"        "should_pass"
test_write "juan" "$DIR_PUBLICO"        "should_fail"
test_read  "juan" "$DIR_CONTABILIDAD"   "should_pass"
test_write "juan" "$DIR_CONTABILIDAD"   "should_pass"
test_read  "juan" "$DIR_SISTEMAS"       "should_fail"
test_write "juan" "$DIR_SISTEMAS"       "should_fail"
test_read  "juan" "$DIR_PRIVADO"        "should_fail"
test_write "juan" "$DIR_PRIVADO"        "should_fail"
test_read  "juan" "$DIR_ADMIN"          "should_fail"
test_write "juan" "$DIR_ADMIN"          "should_fail"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# PRUEBAS DE MARIA (usuarios + sistemas)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${AZUL}── Pruebas para: maria (grupos: usuarios, sistemas) ──${RESET}"
echo "   maria puede: leer /publico, R+W en /sistemas."
echo "   maria NO puede: escribir en /publico, acceder a /contabilidad, /privado, /admin."
echo ""
test_read  "maria" "$DIR_PUBLICO"       "should_pass"
test_write "maria" "$DIR_PUBLICO"       "should_fail"
test_read  "maria" "$DIR_CONTABILIDAD"  "should_fail"
test_write "maria" "$DIR_CONTABILIDAD"  "should_fail"
test_read  "maria" "$DIR_SISTEMAS"      "should_pass"
test_write "maria" "$DIR_SISTEMAS"      "should_pass"
test_read  "maria" "$DIR_PRIVADO"       "should_fail"
test_write "maria" "$DIR_PRIVADO"       "should_fail"
test_read  "maria" "$DIR_ADMIN"         "should_fail"
test_write "maria" "$DIR_ADMIN"         "should_fail"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# PRUEBAS DE INVITADO (invitados)
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${AZUL}── Pruebas para: invitado (grupo: invitados) ──${RESET}"
echo "   invitado puede: leer /publico."
echo "   invitado NO puede: escribir en ningún lado, acceder a nada excepto /publico."
echo ""
test_read  "invitado" "$DIR_PUBLICO"       "should_pass"
test_write "invitado" "$DIR_PUBLICO"       "should_fail"
test_read  "invitado" "$DIR_CONTABILIDAD"  "should_fail"
test_write "invitado" "$DIR_CONTABILIDAD"  "should_fail"
test_read  "invitado" "$DIR_SISTEMAS"      "should_fail"
test_write "invitado" "$DIR_SISTEMAS"      "should_fail"
test_read  "invitado" "$DIR_PRIVADO"       "should_fail"
test_write "invitado" "$DIR_PRIVADO"       "should_fail"
test_read  "invitado" "$DIR_ADMIN"         "should_fail"
test_write "invitado" "$DIR_ADMIN"         "should_fail"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════════════════════════════════════════
echo -e "${NEGRITA}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${NEGRITA}   RESUMEN DE VERIFICACIÓN${RESET}"
echo -e "${NEGRITA}═══════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "   Total de pruebas: ${NEGRITA}${TOTAL}${RESET}"
echo -e "   ${VERDE}Pruebas exitosas (PASS): ${PASS}${RESET}"
echo -e "   ${ROJO}Pruebas fallidas (FAIL): ${FAIL}${RESET}"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "   ${VERDE}${NEGRITA}═══════════════════════════════════════════════${RESET}"
    echo -e "   ${VERDE}${NEGRITA}   ✓ TODAS LAS PRUEBAS PASARON CORRECTAMENTE${RESET}"
    echo -e "   ${VERDE}${NEGRITA}   Los permisos están configurados según la${RESET}"
    echo -e "   ${VERDE}${NEGRITA}   matriz RBAC de DataCorp.${RESET}"
    echo -e "   ${VERDE}${NEGRITA}═══════════════════════════════════════════════${RESET}"
else
    echo -e "   ${ROJO}${NEGRITA}═══════════════════════════════════════════════${RESET}"
    echo -e "   ${ROJO}${NEGRITA}   ✗ HAY PRUEBAS FALLIDAS${RESET}"
    echo -e "   ${ROJO}${NEGRITA}   Revisa los permisos POSIX y ACLs con:${RESET}"
    echo -e "   ${ROJO}${NEGRITA}     ls -la /srv/datacorp/               ${RESET}"
    echo -e "   ${ROJO}${NEGRITA}     getfacl /srv/datacorp/<directorio>  ${RESET}"
    echo -e "   ${ROJO}${NEGRITA}     groups <usuario>                    ${RESET}"
    echo -e "   ${ROJO}${NEGRITA}═══════════════════════════════════════════════${RESET}"
fi
echo ""

# Código de salida: 0 si todo pasó, 1 si hay fallos
exit $FAIL
