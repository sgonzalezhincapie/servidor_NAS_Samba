# Laboratorio NAS con Samba — DataCorp

**Comunicaciones III — Tema 3**  
**Integrantes:** Manuela Marín Rojo, Daniel Trujillo F, Santiago González  
**Fecha de entrega:** Viernes 17 de abril de 2026

---

## Descripción

Este repositorio contiene un laboratorio práctico y académico de cómo funciona un servidor NAS (Network Attached Storage) y cómo se configura utilizando Samba sobre Linux. Implementa un modelo RBAC (Control de Acceso Basado en Roles) para la empresa ficticia **DataCorp**.

## Entorno

| Rol | Sistema Operativo | Función |
|-----|-------------------|---------|
| **Servidor** | Ubuntu 24.04 LTS | Servidor de archivos Samba |
| **Cliente** | Arch Linux | Accede a los recursos compartidos |

## Archivos del repositorio

| Archivo | Descripción |
|---------|-------------|
| `setup_servidor.sh` | Script de configuración completa del servidor Ubuntu (usuarios, grupos, permisos, ACLs, Samba) |
| `smb.conf` | Archivo de configuración de Samba (`/etc/samba/smb.conf`) con todos los shares |
| `setup_cliente_arch.sh` | Script de configuración del cliente Arch Linux (paquetes, montaje de shares) |
| `INSTRUCTIVO.md` | Guía paso a paso para montar todo el laboratorio desde cero |
| `verificacion_permisos.sh` | Script de pruebas automáticas que valida los permisos en el servidor |

## Inicio rápido

### En el servidor (Ubuntu 24.04):
```bash
# 1. Configurar IP fija con Netplan (ver INSTRUCTIVO.md, Parte A, Paso 1)
# 2. Editar smb.conf y reemplazar <INTERFAZ_RED> por tu interfaz real
# 3. Ejecutar el script del servidor:
sudo bash setup_servidor.sh
# 4. Verificar permisos:
sudo bash verificacion_permisos.sh
```

### En el cliente (Arch Linux):
```bash
# 1. Editar setup_cliente_arch.sh y reemplazar <IP_SERVIDOR>
# 2. Ejecutar el script del cliente:
sudo bash setup_cliente_arch.sh
```

## Estructura del NAS

```
/srv/datacorp/
├── publico/               → Lectura para todos, escritura solo administradores
├── departamentos/
│   ├── contabilidad/      → R+W para grupo contabilidad + administradores
│   └── sistemas/          → R+W para grupo sistemas + administradores
├── privado/               → Solo administradores
└── admin/                 → Solo administradores (oculto)
```

## Usuarios de prueba

| Usuario | Contraseña | Grupos | Acceso |
|---------|-----------|--------|--------|
| admin | Admin2026 | administradores | Total |
| juan | Juan2026 | usuarios, contabilidad | publico (R), contabilidad (R+W) |
| maria | Maria2026 | usuarios, sistemas | publico (R), sistemas (R+W) |
| invitado | Invitado2026 | invitados | publico (R) |

> **NOTA:** Contraseñas de ejemplo. Cambiar en producción.
