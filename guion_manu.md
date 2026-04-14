# Guion de Exposición — Manuela (Servidor Ubuntu)

**Rol:** Administradora del servidor NAS  
**Equipo:** Ubuntu 24.04 LTS  
**Duración estimada:** ~8-10 minutos

---

## BLOQUE 1 — Introducción al proyecto (lo que estamos haciendo)

> **[Mostrar en pantalla: el escritorio de Ubuntu con la terminal abierta]**

**Decir:**

> Buenas, yo soy Manuela y voy a mostrar la parte del **servidor**. Nuestro proyecto es montar un **NAS**, que básicamente es un servidor de archivos en red. Piensen en un cuarto de archivos digital: tiene carpetas públicas, carpetas privadas por departamento, y cada persona solo puede acceder a lo que le corresponde según su rol.
>
> Para hacer esto usamos **Samba**, que es un software libre que permite compartir archivos entre Linux y Windows usando el protocolo **SMB**. SMB es el protocolo estándar para compartir archivos en red — lo inventó Microsoft, pero gracias a Samba funciona en cualquier sistema operativo.
>
> Lo que vamos a demostrar hoy es un entorno real: mi computador es el servidor con Ubuntu, el de Santiago es un cliente con Arch Linux, y el de Daniel es un cliente con Windows. Los tres están en la misma red.

---

## BLOQUE 2 — Ejecutar el script del servidor

> **[Mostrar en pantalla: la terminal]**

**Decir:**

> El servidor se configura con un solo script que automatiza todo. Lo ejecuto con `sudo` porque necesito permisos de administrador para crear usuarios, instalar paquetes y configurar permisos.

**Ejecutar:** *(si ya está configurado, solo mostrarlo; si no, ejecutar)*

```bash
sudo bash setup_servidor.sh
```

> El script hace 14 pasos automáticamente. Les explico los más importantes:
>
> 1. **Instala Samba** — el software que convierte este computador en un servidor de archivos.
> 2. **Crea la estructura de carpetas** en `/srv/datacorp/` — ahí viven los archivos compartidos: `publico`, `contabilidad`, `sistemas`, `privado` y `admin`.
> 3. **Crea los grupos** — esto es importante, porque usamos un modelo llamado **RBAC** (Control de Acceso Basado en Roles). En vez de dar permisos usuario por usuario, los agrupamos en roles: administradores, usuarios, invitados, contabilidad, sistemas.
> 4. **Crea los usuarios** — `admin`, `dani`, `santi` e `invitado`. Cada uno con su contraseña de Samba.
> 5. **Aplica los permisos** — y acá es donde se pone interesante, porque usamos TRES capas de seguridad.

---

## BLOQUE 3 — Las tres capas de seguridad

**Decir:**

> Nuestro NAS tiene **tres capas de seguridad** que trabajan juntas. Las tres deben decir "sí" para que un usuario pueda acceder. Si cualquiera dice "no", el acceso se deniega.
>
> - **Capa 1: Permisos POSIX** — son los permisos básicos de Linux, los que se ven con `ls -la`. Definen un dueño, un grupo, y qué puede hacer "el resto del mundo". Se configuran con `chmod` y `chown`.
> - **Capa 2: ACLs** — las Listas de Control de Acceso. Esto es lo que nos permite dar permisos a MÚLTIPLES grupos en la misma carpeta. Con `chmod` solo puedes poner un grupo; con ACLs puedes decir "administradores tienen todo, usuarios solo lectura, invitados solo lectura".
> - **Capa 3: Directivas de Samba** — en el archivo `smb.conf` definimos quién puede conectarse a cada recurso compartido con `valid users` y quién puede escribir con `write list`.
>
> Las tres trabajan como filtros en serie: primero Linux verifica los permisos del disco, luego las ACLs, y luego Samba verifica sus propias reglas.

---

## BLOQUE 4 — Mostrar getfacl (las ACLs)

> **[Mostrar en pantalla: la terminal]**

**Decir:**

> Ahora les muestro cómo se ven las ACLs en la práctica. El comando `getfacl` muestra los permisos extendidos de una carpeta.

**Ejecutar:**

```bash
sudo getfacl /srv/datacorp/publico
```

**Decir (señalando la salida):**

> Miren la salida:
> - `owner: root` — el dueño es root.
> - `group: administradores` — el grupo principal es administradores.
> - `group:administradores:rwx` — los administradores pueden leer, escribir y entrar.
> - `group:usuarios:r-x` — los usuarios pueden leer y entrar, pero **NO escribir**. La `w` no aparece.
> - `group:invitados:r-x` — los invitados igual, solo lectura.
>
> Esto es lo que **no se puede hacer con un simple `chmod`** — ahí solo se puede asignar UN grupo. Acá tenemos tres grupos, cada uno con permisos diferentes, en la misma carpeta.

**Ejecutar:**

```bash
sudo getfacl /srv/datacorp/departamentos/contabilidad
```

**Decir:**

> Acá en contabilidad vemos `group:contabilidad:rwx` y `group:administradores:rwx` — solo estos dos grupos pueden leer y escribir. Si `santi` (que está en el grupo `sistemas`) intenta entrar acá, le va a decir que no tiene permiso.

---

## BLOQUE 5 — Verificar usuarios y grupos

> **[Mostrar en pantalla: la terminal]**

**Ejecutar:**

```bash
sudo pdbedit -L
```

**Decir:**

> `pdbedit -L` lista los usuarios registrados en Samba. Vemos los cuatro: admin, dani, santi e invitado. Recuerden que Samba tiene su **propia base de datos de contraseñas**, separada de la de Linux. Un usuario tiene que existir en ambas partes.

**Ejecutar:**

```bash
groups admin && groups dani && groups santi && groups invitado
```

**Decir:**

> Acá vemos a qué grupos pertenece cada usuario:
> - `admin` → administradores (acceso total)
> - `dani` → usuarios + contabilidad (puede entrar a contabilidad)
> - `santi` → usuarios + sistemas (puede entrar a sistemas)
> - `invitado` → invitados (solo lectura en publico)
>
> Cuando un empleado nuevo llega, por ejemplo, al departamento de contabilidad, solo tengo que hacer `sudo usermod -aG contabilidad nuevo_empleado` y automáticamente hereda todos los permisos. Eso es RBAC.

---

## BLOQUE 6 — Mostrar que Samba está corriendo

**Ejecutar:**

```bash
sudo systemctl status smbd --no-pager
```

**Decir:**

> Samba tiene dos servicios: `smbd`, que es el que comparte archivos y maneja la autenticación (puerto 445), y `nmbd`, que resuelve nombres en la red. Los dos están activos y habilitados para arrancar con el sistema.

**Ejecutar:**

```bash
smbclient -L localhost -U admin
```

*(Poner contraseña: Admin2026)*

**Decir:**

> Con `smbclient -L` listo los recursos compartidos que tiene el servidor. Vemos `publico`, `contabilidad`, `sistemas` y `privado`. Noten que `admin` **no aparece** — eso es porque en el `smb.conf` le pusimos `browseable = no`, es un share oculto al que solo se puede acceder si sabés la ruta exacta.
>
> Ahora le paso la palabra a Santiago, que va a mostrar cómo se conecta desde Arch Linux.

---

## BLOQUE 7 — Demostración en vivo (si hay tiempo)

> **[Cuando Santi y Dani estén conectados]**

**Ejecutar:**

```bash
sudo smbstatus
```

**Decir:**

> Con `smbstatus` puedo ver en tiempo real quién está conectado al servidor: qué usuario, desde qué IP, y a qué carpeta está accediendo. Ahí se ve que Santiago está conectado desde Arch y Daniel desde Windows.

---

## TIPS PARA LA GRABACIÓN

- Cuando ejecutes un comando, esperá un segundo antes de hablar para que se vea la salida.
- Si algo ya está configurado (porque ya corriste el script antes), mostrá los resultados directamente sin volver a ejecutar el script completo.
- Podés usar `clear` entre bloques para que la pantalla no se sature.
- Si te preguntan algo, los conceptos clave son: **NAS, Samba, RBAC, tres capas de seguridad, ACLs**.
