# HoundForge — BloodHound CE para Windows

<p align="center">
  <img src="assets/banner.svg" alt="HoundForge — BloodHound CE sobre WSL2" width="100%">
</p>

<p align="center">
  <strong>Instala BloodHound CE en Windows con un solo clic.</strong><br>
  Docker Engine funciona dentro de Linux: Docker Desktop no es necesario.
</p>

<p align="center">
  <a href="README.md">English</a> ·
  <a href="#inicio-rápido">Inicio rápido</a> ·
  <a href="#seguridad-predeterminada">Seguridad</a> ·
  <a href="#solución-de-problemas">Solución de problemas</a>
</p>

## ¿Por qué este proyecto?

**HoundForge** envuelve el CLI oficial de BloodHound en una instalación segura
y orientada a Windows. Es un instalador de BloodHound para Windows 10 y Windows
11 que utiliza WSL2 en lugar de Docker Desktop. El CLI simplifica la administración de contenedores,
pero una estación Windows todavía necesita WSL2, una distribución compatible,
Docker, Compose, puertos seguros y un mecanismo repetible de arranque. Este
proyecto automatiza todo ese proceso sin requerir Docker Desktop.

Está pensado para profesionales de seguridad que necesitan un entorno local y
reproducible de BloodHound CE durante revisiones autorizadas de Active Directory.

## Características

- Detecta Kali, Ubuntu o Debian sobre WSL2.
- Instala Docker Engine y Docker Compose dentro de WSL.
- Descarga la versión más reciente del `bloodhound-cli` oficial.
- Reutiliza instalaciones existentes sin borrar datos ni cambiar credenciales.
- Limita BloodHound, Neo4j Browser y Bolt a `127.0.0.1`.
- No publica PostgreSQL hacia Windows.
- Crea controles amigables de inicio, estado, credenciales y detención.
- Protege la configuración que contiene credenciales con permisos `0600`.
- Admite entornos WSL AMD64 y ARM64.

## Inicio rápido

### Un clic

1. Descarga o clona este repositorio.
2. Haz doble clic en `Install-HoundForge.cmd`.
3. Espera que se abra `http://127.0.0.1:8080/ui/login`.
4. Ejecuta `BloodHound-CE\03-Credentials.cmd` desde el escritorio para ver las
   credenciales generadas localmente.

### PowerShell

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\Install-BloodHoundCE.ps1 -OpenBrowser
```

Seleccionar una distribución concreta:

```powershell
.\Install-BloodHoundCE.ps1 -Distro kali-linux -OpenBrowser
```

Instalar WSL y Ubuntu cuando todavía no existen:

```powershell
# Ejecutar desde PowerShell como administrador
.\Install-BloodHoundCE.ps1 -InstallWslIfMissing
```

Windows puede solicitar un reinicio o la inicialización inicial de Ubuntu. En
ese caso, vuelve a ejecutar el instalador después de completar ese paso.

## Controles del escritorio

La carpeta `BloodHound-CE` contiene:

| Archivo | Función |
|---|---|
| `01-Start.cmd` | Inicia Docker y BloodHound y abre la interfaz. |
| `02-Status.cmd` | Muestra la salud de los contenedores y prueba la interfaz. |
| `03-Credentials.cmd` | Muestra las credenciales solamente en el equipo local. |
| `04-Stop.cmd` | Detiene los contenedores sin eliminar datos. |
| `README.txt` | Referencia local resumida. |

## Parámetros

| Parámetro | Función |
|---|---|
| `-Distro <nombre>` | Selecciona una distribución WSL. |
| `-InstallWslIfMissing` | Instala WSL y Ubuntu cuando no existen. |
| `-DesktopFolderName <nombre>` | Cambia el nombre de la carpeta de controles. |
| `-NoDesktopControls` | No crea los controles del escritorio. |
| `-NoStart` | Instala y deja los contenedores detenidos. |
| `-OpenBrowser` | Abre la interfaz después de validarla. |

## Seguridad predeterminada

El instalador comprueba que Docker no publique contenedores en todas las
interfaces del host. La configuración esperada es:

| Servicio | Publicación |
|---|---|
| Interfaz de BloodHound | `127.0.0.1:8080` |
| Neo4j Browser | `127.0.0.1:7474` |
| Neo4j Bolt | `127.0.0.1:7687` |
| PostgreSQL | Sin publicar |

El proceso interno de BloodHound escucha en `0.0.0.0:8080` **dentro del
contenedor** para que Docker pueda comunicarse con él. El mapeo visible desde
Windows continúa limitado a localhost.

No expongas estos servicios a una red corporativa o VPN sin diseñar controles
de acceso y TLS adecuados.

## Reejecución y conservación de datos

Al volver a ejecutar el instalador:

- se actualizan los paquetes necesarios;
- se renueva el binario oficial de BloodHound CLI;
- se reutilizan la configuración Compose y los volúmenes existentes;
- se conservan datos importados, usuarios y credenciales.

El instalador no desinstala contenedores ni elimina volúmenes.

## Requisitos

- Windows 10 u 11.
- WSL2 con Kali, Ubuntu o Debian.
- PowerShell 5.1 o superior.
- Acceso a Internet desde WSL.
- Al menos 8 GB de RAM recomendados.
- Aproximadamente 10 GB de espacio libre.

## Solución de problemas

### La distribución utiliza WSL1

```powershell
wsl --set-version "kali-linux" 2
```

Sustituye `kali-linux` por el nombre mostrado en `wsl --list --verbose`.

### La interfaz todavía no responde

Ejecuta `02-Status.cmd` o revisa los registros desde WSL:

```bash
bloodhound-cli running
bloodhound-cli logs
```

### Consultar credenciales sin el acceso del escritorio

Dentro de la distribución WSL seleccionada:

```bash
jq '.default_admin' ~/.config/bloodhound/bloodhound.config.json
```

Trata la salida como un secreto y cambia la contraseña inicial después del
primer inicio de sesión.

## Uso legal y ético

Utiliza BloodHound únicamente en entornos propios o para los que tengas una
autorización explícita. Notifica al equipo de seguridad antes de recolectar o
importar datos del directorio. Este proyecto no concede autorización ni está
afiliado a SpecterOps.

BloodHound es mantenido por SpecterOps. Este proyecto solamente automatiza el
despliegue local de los contenedores y del CLI oficiales.

## Licencia

El instalador y la documentación se distribuyen bajo la [licencia MIT](LICENSE).
El software de terceros conserva sus licencias respectivas.
