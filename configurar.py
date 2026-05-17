#!/usr/bin/env python3
# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURAR.PY — Punto de entrada unico para el servidor NAS
# ═══════════════════════════════════════════════════════════════════════════════
# Python 3.6+ | Sin dependencias externas
#
# USO:
#   python3 configurar.py
#
# DESCRIPCION:
#   Menu interactivo que detecta el sistema operativo y ejecuta el script
#   correspondiente (servidor o cliente). Todos los scripts se encuentran
#   en el mismo directorio que este archivo.
# ═══════════════════════════════════════════════════════════════════════════════

import os
import sys
import subprocess
import platform

# ─────────────────────────────────────────────────────────────────────────────
# Utilidades de salida
# ─────────────────────────────────────────────────────────────────────────────
def limpiar():
    os.system("clear" if os.name != "nt" else "cls")

def titulo(texto):
    linea = "=" * 60
    print(f"\n{linea}")
    print(f"  {texto}")
    print(f"{linea}\n")

def opcion(numero, texto, descripcion=""):
    if descripcion:
        print(f"  [{numero}] {texto}")
        print(f"       {descripcion}")
    else:
        print(f"  [{numero}] {texto}")

def pedir_opcion(maximo, prompt="  Tu eleccion: "):
    while True:
        try:
            valor = input(prompt).strip()
            n = int(valor)
            if 1 <= n <= maximo:
                return n
            print(f"  Ingresa un numero entre 1 y {maximo}.")
        except (ValueError, KeyboardInterrupt):
            print("\n  Operacion cancelada.")
            sys.exit(0)

# ─────────────────────────────────────────────────────────────────────────────
# Directorio base (donde esta este script)
# ─────────────────────────────────────────────────────────────────────────────
DIRECTORIO_BASE = os.path.dirname(os.path.abspath(__file__))

def ruta(nombre_script):
    return os.path.join(DIRECTORIO_BASE, nombre_script)

def verificar_script(nombre_script):
    """Verifica que el script existe antes de ejecutarlo."""
    path = ruta(nombre_script)
    if not os.path.isfile(path):
        print(f"\n  ERROR: No se encontro el archivo '{nombre_script}'")
        print(f"  Asegurate de que el archivo este en: {DIRECTORIO_BASE}")
        input("\n  Presiona Enter para volver al menu...")
        return False
    return True

# ─────────────────────────────────────────────────────────────────────────────
# Ejecutar script bash (toma control completo del terminal)
# ─────────────────────────────────────────────────────────────────────────────
def ejecutar_bash(script, args=None, necesita_sudo=True):
    """Reemplaza el proceso actual con el script bash dado."""
    if not verificar_script(script):
        return

    path = ruta(script)
    print(f"\n  Iniciando {script}...\n")

    if necesita_sudo and os.geteuid() != 0:
        # Relanzar con sudo, pasando el control completo al script
        cmd = ["sudo", "bash", path] + (args or [])
    else:
        cmd = ["bash", path] + (args or [])

    # os.execvp reemplaza el proceso actual: el script toma el terminal directamente
    os.execvp(cmd[0], cmd)

def ejecutar_python_como_raiz(script):
    """Relanza este script con sudo si no somos root (Linux)."""
    if os.geteuid() != 0:
        print(f"  Se requieren permisos de administrador para ejecutar '{script}'.")
        print(f"  Ejecutando con sudo...\n")
        os.execvp("sudo", ["sudo", "bash", ruta(script)])

# ─────────────────────────────────────────────────────────────────────────────
# Instrucciones para Windows (no se puede llamar directamente al .ps1)
# ─────────────────────────────────────────────────────────────────────────────
def instrucciones_windows():
    limpiar()
    titulo("CLIENTE WINDOWS — Instrucciones")
    print("  El script de Windows es un archivo PowerShell (.ps1).")
    print("  Copia el archivo setup_cliente_windows.ps1 a tu equipo Windows")
    print("  y sigue estos pasos:\n")
    print("  PASO 1 — Editar la IP del servidor")
    print("    Abre el archivo setup_cliente_windows.ps1 con el Bloc de notas.")
    print("    Cambia la linea:  $IP_SERVIDOR = \"192.168.1.55\"")
    print("    Por la IP real del servidor NAS.\n")
    print("  PASO 2 — Abrir PowerShell como Administrador")
    print("    Clic derecho en el menu Inicio -> Terminal (Administrador)")
    print("    O buscar PowerShell -> clic derecho -> Ejecutar como administrador\n")
    print("  PASO 3 — Habilitar ejecucion de scripts (solo la primera vez)")
    print("    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser\n")
    print("  PASO 4 — Ejecutar el script")
    print("    .\\setup_cliente_windows.ps1\n")
    print("  ACCESO RAPIDO SIN SCRIPT:")
    print("    Abre el Explorador de archivos (Win+E)")
    print("    En la barra de direcciones escribe:  \\\\IP_DEL_SERVIDOR")
    print("    Presiona Enter e ingresa tu usuario y contrasena.\n")
    input("  Presiona Enter para volver al menu...")

# ─────────────────────────────────────────────────────────────────────────────
# Menus
# ─────────────────────────────────────────────────────────────────────────────
def menu_cliente():
    limpiar()
    titulo("CONFIGURAR CLIENTE NAS")
    opcion(1, "Arch Linux",   "Instala paquetes y muestra como acceder desde Thunar")
    opcion(2, "Ubuntu",       "Instala paquetes y muestra como acceder desde Nautilus")
    opcion(3, "Windows",      "Muestra instrucciones para ejecutar el script PowerShell")
    opcion(4, "Volver")
    print()

    sel = pedir_opcion(4)
    if sel == 1:
        ejecutar_bash("setup_cliente_arch.sh")
    elif sel == 2:
        ejecutar_bash("setup_cliente_ubuntu.sh")
    elif sel == 3:
        instrucciones_windows()
        menu_cliente()
    # sel == 4: volver (no hace nada, retorna al menu principal)

def menu_principal():
    es_windows = platform.system() == "Windows"

    while True:
        limpiar()
        titulo("CONFIGURADOR DEL SERVIDOR NAS")
        print("  Que vas a configurar?\n")
        opcion(1, "Servidor NAS",    "Instala y configura Samba en Ubuntu Server 22.04+")
        opcion(2, "Cliente",          "Configura acceso al NAS desde este equipo")
        opcion(3, "Salir")
        print()

        if es_windows:
            print("  NOTA: Estas en Windows. Para configurar el servidor o un cliente Linux,")
            print("  copia los archivos .sh al equipo correspondiente y ejecutalos desde ahi.\n")

        sel = pedir_opcion(3)

        if sel == 1:
            if es_windows:
                print("\n  El servidor se configura en Ubuntu Server, no en Windows.")
                print("  Copia setup_servidor.sh al servidor y ejecuta: sudo bash setup_servidor.sh")
                input("\n  Presiona Enter para continuar...")
            else:
                ejecutar_bash("setup_servidor.sh")

        elif sel == 2:
            if es_windows:
                instrucciones_windows()
            else:
                menu_cliente()

        elif sel == 3:
            print("\n  Hasta luego.\n")
            sys.exit(0)

# ─────────────────────────────────────────────────────────────────────────────
# Entrada principal
# ─────────────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    try:
        menu_principal()
    except KeyboardInterrupt:
        print("\n\n  Operacion cancelada.\n")
        sys.exit(0)
