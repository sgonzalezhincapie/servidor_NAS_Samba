# Servidor NAS con Samba

Servidor de archivos en red compartida (NAS) usando Samba sobre Linux. Permite que equipos Windows, Arch Linux y Ubuntu accedan a carpetas compartidas con permisos por usuario y grupo/VLAN.

---

## Inicio rápido

```bash
python3 configurar.py
```

Un menú te preguntará qué vas a configurar (servidor o cliente) y ejecutará el script correspondiente.

---

## Archivos del proyecto

| Archivo | Para quién |
|---|---|
| `configurar.py` | Punto de entrada único — ejecutar en cualquier equipo Linux |
| `setup_servidor.sh` | Ejecutar en el servidor Ubuntu Server 22.04+ |
| `setup_cliente_arch.sh` | Ejecutar en el equipo cliente con Arch Linux |
| `setup_cliente_ubuntu.sh` | Ejecutar en el equipo cliente con Ubuntu Desktop |
| `setup_cliente_windows.ps1` | Ejecutar en el equipo cliente con Windows 10/11 |
| `smb.conf` | Configuración de Samba (el setup del servidor la instala automáticamente) |
| `verificacion_permisos.sh` | Ejecutar en el servidor para verificar que los permisos están bien |

---

## Estructura del NAS

```
/srv/datacorp/
├── publico/              → Lectura para todos, escritura solo admin
├── departamentos/
│   ├── financiera/       → Solo grupo financiera + admin
│   ├── produccion/       → Solo grupo produccion + admin
│   ├── design/           → Solo grupo design + admin
│   └── rh/               → Solo grupo rh + admin
├── privado/              → Solo admin
└── admin/                → Solo admin (oculto en la red)
```

> Los grupos de departamento se configuran durante la instalación del servidor. Los anteriores son los valores por defecto.

---
Updated memory file plan.md
Validación del launcher en Python
La idea es sólida y tiene sentido. Acá mi análisis:

Por qué funciona bien:

Python 3 viene preinstalado en Ubuntu (server y desktop), Arch Linux, y Debian. No requiere instalación adicional.
Permite un único punto de entrada: python3 configurar.py → menú visual → ejecuta el script correcto.
En Windows, Python también puede estar instalado. Si no, el README indica que vayan directo al .ps1.
Arquitectura recomendada (y por qué):

El launcher Python solo enruta — no duplica los prompts. Los scripts de shell/PowerShell mantienen toda su lógica interactiva. El launcher simplemente hace:

￼
¿Qué vas a configurar?  [1] Servidor (Ubuntu Server)  [2] Cliente Linux - Arch Linux  [3] Cliente Linux - Ubuntu  [4] Cliente Windows → (muestra instrucciones del .ps1, lo ejecuta si Python está en Windows)→ Llama a: sudo bash setup_servidor.sh  (o el que corresponda)
Caveat importante: Si el launcher llama a los scripts, no puede capturar los prompts interactivos de bash a menos que los scripts corran directamente en la terminal del usuario. La solución es que el launcher use os.execvp o subprocess con stdin=None para que el script bash tome control de la terminal directamente — esto funciona perfectamente.

Lo que NO haría: Que el launcher duplique la lógica de preguntas. Los scripts bash son los que preguntan, el launcher solo decide cuál correr.

Acá el plan actualizado completo:

Plan: Reorganización y funcionalización del NAS (actualizado)
TL;DR: Reescribir el README como guía de despliegue, corregir bugs técnicos en scripts, hacer el servidor interactivo (grupos/usuarios/contraseñas configurables), crear setup_cliente_ubuntu.sh y un launcher configurar.py. Borrar archivos obsoletos al final.

Fase 1 — Servidor (bloqueante)
1. smb.conf — Un solo cambio:

Reemplazar interfaces = lo wlo1 por interfaces = lo <INTERFAZ_RED> (placeholder que setup_servidor.sh inyectará con sed antes de copiar a samba)
2. setup_servidor.sh — Los cambios más grandes:

Actualizar comentarios: Ubuntu 24.04 → Ubuntu Server 22.04.5 LTS (el código es 100% compatible con Samba 4.15.x)
Auto-detectar interfaz de red con ip -4 route show default | awk '{print $5}' e inyectarla en smb.conf con sed antes de copiar
Grupos interactivos: preguntar si se usan los grupos por defecto (Financiera, Produccion, Design, RH) o si quiere definir los propios → si cambia, preguntar cuántos y sus nombres → crearlos con groupadd
Contraseña de admin interactiva con read -sp y confirmación
Usuarios interactivos: preguntar si quiere agregar usuarios ahora → cuántos (aparte de admin e invitado) → para cada uno: nombre, contraseña (con confirmación), grupo del NAS al que pertenece
Los usuarios admin e invitado siempre se crean; los grupos de departamento y usuarios adicionales son configurables
invitado siempre pertenece al grupo de invitados (grupo de solo lectura en /publico)
Fase 2 — Clientes (paralelos)
3. setup_cliente_arch.sh — 3 correcciones:

Agregar gvfs gvfs-smb a la instalación con pacman
Corregir UID/GID: uid=$(id -u ${SUDO_USER:-$USER}),gid=$(id -g ${SUDO_USER:-$USER})
Agregar sección de instrucciones GUI al final: Thunar → barra de ubicación → smb://IP_SERVIDOR → pide usuario y contraseña → navega normalmente
4. setup_cliente_ubuntu.sh (nuevo) — Basado en el de Arch:

Instalar: cifs-utils smbclient gvfs-backends con apt
Misma lógica de verificación de conectividad, creación de puntos de montaje, y comandos de montaje
Instrucciones GUI: Nautilus → Ctrl+L → smb://IP_SERVIDOR → ingresar usuario/contraseña
5. setup_cliente_windows.ps1 — Solo actualizar comentarios de versión (el script es funcional)

Fase 3 — Launcher Python
6. configurar.py (nuevo) — Script Python 3 puro (sin dependencias externas):

Menú principal: [1] Configurar servidor  [2] Configurar cliente
Si cliente: [1] Arch Linux  [2] Ubuntu  [3] Windows
Para Windows: muestra las instrucciones del .ps1 (no lo puede ejecutar directamente salvo que Python esté en Windows — pero eso se documenta)
Para Linux server/clientes: usa os.execvp('sudo', ['sudo', 'bash', 'script.sh']) → el script toma control completo de la terminal con todos sus prompts interactivos
Detecta si el archivo del script existe antes de llamarlo; si no, muestra error claro
Compatible con Python 3.6+ (Ubuntu 22.04 trae 3.10, Arch trae lo más reciente)
Fase 4 — README
7. README.md — Reescritura completa, enfoque en despliegue:

Inicio rápido: python3 configurar.py → único comando para todo
Servidor (Ubuntu Server 22.04.5 LTS): pasos con el script, qué pregunta, cómo personalizar grupos y usuarios
Cliente Windows: cómo ejecutar el .ps1, cómo abrir el explorador → \\IP_SERVIDOR
Cliente Arch Linux: cómo ejecutar el script, cómo abrir Thunar → smb://IP
Cliente Ubuntu: cómo ejecutar el script, cómo abrir Nautilus → smb://IP
Gestión de usuarios posterior: comandos para agregar/cambiar/eliminar usuarios desde el servidor
Solución de problemas: firewall, permisos, interfaz incorrecta, SMB bloqueado
Fase 5 — Limpieza (solo cuando todo esté validado)
8. Eliminar: guion_manu.md, guion_dani.md, guion_santi.md, INSTRUCTIVO.md

## Despliegue del servidor — Ubuntu Server 22.04.5 LTS

### Requisitos
- Ubuntu Server 22.04.5 LTS instalado
- Acceso con `sudo`
- Conexión a Internet para instalar paquetes (solo durante la instalación)
- Todos los equipos cliente en la misma red local

### Pasos

**1. Copiar los archivos al servidor**

Desde otro equipo (o directamente en el servidor):
```bash
git clone <URL_DEL_REPOSITORIO>
cd servidor_NAS
```
O copia los archivos manualmente con USB / SCP.

**2. Ejecutar el script de configuración**

```bash
sudo bash setup_servidor.sh
```

El script te hará estas preguntas antes de cambiar nada:

- ¿Usar los grupos por defecto? → `Financiera, Produccion, Design, RH` (recomendado: S)
- Contraseña para el usuario `admin` (acceso total)
- Contraseña para el usuario `invitado` (solo lectura pública)
- ¿Agregar usuarios de departamento ahora? → nombre, contraseña y grupo de cada uno

Después de confirmar, el script instala Samba, crea carpetas, aplica permisos, configura el firewall y arranca el servicio.

**3. Anotar la IP del servidor**

Al finalizar el script verás la IP del servidor. Compártela con los equipos cliente.

Si necesitas verla de nuevo:
```bash
ip -4 addr show
```

**4. Verificar que todo está correcto**

```bash
sudo bash verificacion_permisos.sh
```

Todos los tests deben salir en verde (PASS).

### Administración de usuarios después de la instalación

**Agregar un usuario nuevo:**
```bash
sudo useradd --no-create-home --shell /usr/sbin/nologin NOMBRE
sudo usermod -aG usuarios NOMBRE
sudo usermod -aG GRUPO NOMBRE        # ej: financiera, design, rh, produccion
sudo smbpasswd -a NOMBRE             # te pide la contraseña
```

**Cambiar la contraseña de un usuario:**
```bash
sudo smbpasswd NOMBRE
```

**Ver todos los usuarios registrados:**
```bash
sudo pdbedit -L
```

**Reiniciar Samba después de cambios en smb.conf:**
```bash
sudo systemctl restart smbd nmbd
```

---

## Cliente Windows — Windows 10 / 11

### Acceso rápido (sin instalar nada)

Windows soporta SMB de forma nativa. No necesitas instalar ningún programa.

1. Abre el **Explorador de archivos** (Win+E)
2. En la barra de direcciones escribe:
   ```
   \IP_DEL_SERVIDOR
   ```
3. Presiona **Enter**
4. Windows pedirá usuario y contraseña → ingresa las credenciales de tu cuenta del NAS
5. Verás las carpetas compartidas disponibles para tu usuario

### Script de configuración (opcional)

El script hace verificaciones automáticas (SMB habilitado, firewall, conectividad) y aplica el fix para el error de invitado en Windows 10/11.

**Antes de ejecutar:** edita `setup_cliente_windows.ps1` y cambia `$IP_SERVIDOR` por la IP real del servidor.

```powershell
# 1. Abrir PowerShell como Administrador
# 2. Habilitar ejecución de scripts (solo la primera vez):
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
# 3. Ejecutar:
.\setup_cliente_windows.ps1
```

### Mapear unidades de red (acceso permanente)

Para que las carpetas aparezcan como unidades de disco en "Este Equipo":

```powershell
# Carpeta pública (usuario invitado)
net use P: \IP_SERVIDOR\publico /user:invitado PASS /persistent:yes

# Carpeta de departamento (reemplaza CARPETA, USUARIO y PASS)
net use D: \IP_SERVIDOR\CARPETA /user:USUARIO PASS /persistent:yes
```

O desde el Explorador: clic derecho en la carpeta → **Conectar a unidad de red**.

---

## Cliente Arch Linux

### Requisitos previos

Edita `setup_cliente_arch.sh` y cambia `IP_SERVIDOR` por la IP real del servidor.

### Instalación

```bash
sudo bash setup_cliente_arch.sh
# o desde el launcher:
python3 configurar.py
```

El script instala `cifs-utils`, `smbclient`, `gvfs` y `gvfs-smb`.

### Acceso desde Thunar (recomendado)

1. Abre **Thunar**
2. Presiona **Ctrl+L** para abrir la barra de ubicación
3. Escribe:
   ```
   smb://IP_DEL_SERVIDOR
   ```
4. Thunar pedirá usuario y contraseña
5. Navega las carpetas como si fueran locales

> Si no aparece la barra de ubicación: menú **Ver → Mostrar barra de ubicación**

### Acceso desde terminal (montaje manual)

```bash
# Crear punto de montaje
sudo mkdir -p /mnt/nas/publico

# Montar (reemplaza IP, USUARIO, PASS y CARPETA según corresponda)
sudo mount.cifs //IP_SERVIDOR/publico /mnt/nas/publico \
  -o username=invitado,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8

# Ver el contenido
ls /mnt/nas/publico

# Desmontar
sudo umount /mnt/nas/publico
```

---

## Cliente Ubuntu Desktop

### Requisitos previos

Edita `setup_cliente_ubuntu.sh` y cambia `IP_SERVIDOR` por la IP real del servidor.

### Instalación

```bash
sudo bash setup_cliente_ubuntu.sh
# o desde el launcher:
python3 configurar.py
```

El script instala `cifs-utils`, `smbclient` y `gvfs-backends`.

### Acceso desde Nautilus (recomendado)

**Método 1 — Barra de ubicación:**
1. Abre el **Gestor de archivos** (Nautilus)
2. Presiona **Ctrl+L**
3. Escribe:
   ```
   smb://IP_DEL_SERVIDOR
   ```
4. Ingresa usuario y contraseña

**Método 2 — Otras ubicaciones:**
1. En Nautilus, clic en **Otras ubicaciones** (barra lateral)
2. En la barra inferior **"Conectar al servidor"** escribe:
   ```
   smb://IP_DEL_SERVIDOR
   ```

### Acceso desde terminal (montaje manual)

Mismo proceso que Arch Linux, reemplazando `pacman` por `apt`:

```bash
sudo mkdir -p /mnt/nas/publico
sudo mount.cifs //IP_SERVIDOR/publico /mnt/nas/publico \
  -o username=invitado,vers=3.0,uid=$(id -u),gid=$(id -g),iocharset=utf8
```

---

## Solución de problemas

### No puedo conectarme al servidor

```bash
# Verificar que Samba está corriendo (en el servidor):
sudo systemctl status smbd

# Verificar que el firewall permite Samba (en el servidor):
sudo ufw allow samba
sudo ufw status

# Verificar conectividad desde el cliente:
ping IP_DEL_SERVIDOR

# Verificar que el puerto SMB está abierto:
# Linux:
nc -zv IP_DEL_SERVIDOR 445
# Windows (PowerShell):
Test-NetConnection -ComputerName IP_DEL_SERVIDOR -Port 445
```

### Error de permisos al intentar escribir

El usuario conectado no tiene permisos de escritura en esa carpeta. Verifica:
- El usuario pertenece al grupo correcto en el servidor
- Estás conectado con el usuario correcto (no con `invitado`)

```bash
# Ver grupos del usuario (en el servidor):
groups NOMBRE_USUARIO

# Ver permisos de la carpeta:
getfacl /srv/datacorp/departamentos/CARPETA
```

### Windows — Error 0xc05d0004 o "acceso de invitado bloqueado"

El script de Windows (`setup_cliente_windows.ps1`) aplica automáticamente el fix. Si el problema persiste, ejecuta en PowerShell como Administrador:

```powershell
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters" -Name "AllowInsecureGuestAuth" -Value 1 -Type DWord -Force
```

### Windows — Las credenciales no funcionan o no pide contraseña

Windows cachea credenciales. Limpia la caché:

```powershell
net use * /delete /yes
cmdkey /delete:IP_DEL_SERVIDOR
```

### Arch/Ubuntu — "mount error(13): Permission denied" al montar

- Verifica que el usuario y contraseña son correctos
- Verifica que el usuario tiene permiso en ese share:
  ```bash
  smbclient //IP_SERVIDOR/CARPETA -U USUARIO
  ```

### smb.conf tiene errores

```bash
# Validar la configuración (en el servidor):
sudo testparm -s
```
