# **Documentación Técnica: Sistema de Reportes de Misión Apolo-11**

El sistema **Apolo-11** es una plataforma de procesamiento de datos diseñada para simular, ingestar, transformar y analizar logs de misiones espaciales. Construido sobre **Linux** y **Bash**, el sistema integra  **Python**, **DuckDB** y **dbt** para ofrecer una solución de análisis de datos completa, automatizada y escalable.

El objetivo principal es procesar logs generados en tiempo de ejecución, consolidarlos, cargarlos en una base de datos analítica y transformarlos en reportes para el control de la misión.

## Arquitectura y Flujo de Trabajo

El sistema sigue un flujo  orquestado que combina scripting con herramientas de ingeniería de datos, siguiendo el patrón de la **Arquitectura Medallion**.


## Componentes del Sistema

### Estructura de Directorios

Cada ejecución crea un conjunto de directorios con un identificador único (`EXECUTION_ID`) para garantizar la trazabilidad y evitar la sobreescritura de datos.

```
.
├── apolo_11.sh             # Script orquestador principal
├── app.py                  # Script de ingesta de datos a DuckDB
├── apolo_11.config         # Archivo de configuración
├── requirements.txt        # Dependencias de Python
├── database/
│   └── unal.db             # Archivo de la base de datos DuckDB
├── nasa/                   # Directorio del proyecto dbt
│   ├── dbt_project.yml
│   ├── models/
│   │   └── ...
│   └── ...
├── devices/
│   └── <EXECUTION_ID>/     # Logs crudos generados por la simulación
├── reportes/
│   └── <EXECUTION_ID>/     # Reportes CSV y archivo consolidado
└── backups/
    └── <EXECUTION_ID>/     # Logs crudos archivados después del procesamiento
```

## Prerrequisitos e Instalación

### Configuración del Entorno

1.  **Clonar el repositorio**
    ```bash
    git clone https://github.com/SeleneSV/big-data-dbt-UNAL.git
    cd big-data-dbt-UNAL
    ```

2.  **Crear y activar un entorno virtual de Python**
    ```bash
    python3 -m venv venv
    source venv/bin/activate
    ```

3.  **Instalar dependencias de Python**
    
    ```bash
    pip install -r requirements.txt
    ```

4.  **Instalar DuckDB CLI**
    
    ```bash
    curl -s https://install.duckdb.org | sh
    # Añadir al PATH según las instrucciones del instalador
    export PATH="/home/$(whoami)/.duckdb/cli/latest:$PATH"
    ```

### Configuración del Proyecto

- **Crear archivo de configuración `apolo_11.config`**:

  Para personalizar los nombres de las misiones, tipos de dispositivos o la cantidad de logs, cree un archivo `apolo_11.config` en la raíz del proyecto.

  ```bash
  # Ejemplo de apolo_11.config
    MISION_NAMES=("ORBONE" "CLNM" "TMRS" "GALXONE" "UNKN") # Nombres de las misiones
    DEVICE_TYPES=("satellite" "spaceship" "space_vehicle")
    NUM_LOGS_RANGE=(1 5)
  ```

## Uso

Para ejecutar ejecute el script principal desde la raíz del proyecto:

```bash
bash apolo_11.sh
```


## Notas Adicionales y Configuración Crítica

### Configuración de la Conexión de `dbt`

Para que `dbt` pueda interactuar con la base de datos DuckDB (`database/unal.db`), es fundamental configurar correctamente el perfil de conexión.

Esta configuración se realiza en el archivo `profiles.yml`. Este archivo le indica a `dbt` la ruta al archivo de la base de datos.

Para obtener una guía detallada y paso a paso sobre cómo crear y configurar este archivo para que apunte correctamente a la base de datos de este proyecto, consulte el documento de referencia: `__TRABAJO FINAL #4__`.
