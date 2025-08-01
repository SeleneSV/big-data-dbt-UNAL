#!/bin/bash

# ====================================================================================
# APOLLO 11 MISSION REPORTER
#
# Generación de logs, consolidación y creación de reportes.
# La estructura de directorios está organizada por función (reports, devices, backups),
# con una subcarpeta por cada ejecución.
#
# ESTRUCTURA DE SALIDA:
# ./reports/YYYYMMDD_HHMMSS/<reportes y consolidado>
# ./devices/YYYYMMDD_HHMMSS/<logs>
# ./backups/YYYYMMDD_HHMMSS/<logs archivados>
#
# Dependencias: csvkit, pandas, duckdb, dbt
# ====================================================================================

# --- CONFIGURACIÓN DE SEGURIDAD ---
set -e
set -o pipefail

# --- VERIFICACIÓN DE DEPENDENCIAS ---
if ! command -v csvsql &> /dev/null; then
    echo "Error: 'csvsql' no está instalado."
    exit 1
fi

# --- CONFIGURACIÓN GENERAL Y VARIABLES ---

# Directorio de trabajo
WORKING_DIR=$(pwd)

# ID único por ejecución
EXECUTION_ID=$(date "+%d%m%y%H%M%S")

# Estructura de directorios por ejecución
LOGS_DIR="${WORKING_DIR}/devices/${EXECUTION_ID}"
REPORTS_DIR="${WORKING_DIR}/reportes/${EXECUTION_ID}"
BACKUPS_DIR="${WORKING_DIR}/backups/${EXECUTION_ID}"
CONSOLIDATED_FILE="${REPORTS_DIR}/consolidated-${EXECUTION_ID}.csv"

# --- CARGAR CONFIGURACIONES DE MISIÓN ---
APOLO_CONFIG_FILE="$WORKING_DIR/apolo_11.config"
if [ -f "$APOLO_CONFIG_FILE" ]; then
    source "$APOLO_CONFIG_FILE"
    echo "Archivo de configuración '$APOLO_CONFIG_FILE' cargado."
else
    echo "Archivo de configuración no encontrado. Usando valores por defecto."
    MISION_NAMES=("ORBONE" "CLNM" "TMRS" "GALXONE" "UNKN")
    DEVICE_TYPES=("satellite" "spaceship" "space_vehicle")
    NUM_LOGS_RANGE=(1 5) # Rango de logs a generar [min, max]
fi

# CONSTANTES DE MISIÓN
STATUS_OPTIONS=(excellent good warning faulty killed unknown)
MIN_CODE=1
MAX_CODE=100
DELIMITER=";"
TOTAL_MISIONS=${#MISION_NAMES[@]}
TOTAL_DEVICES=${#DEVICE_TYPES[@]}
TOTAL_STATUS=${#STATUS_OPTIONS[@]}

# ============================
# FUNCIONES
# ============================

# --- Función para generar los logs de simulación ---
generate_logs() {
    echo "========================================================"
    echo " GENERACIÓN DE LOGS"
    echo "========================================================"
    echo "Directorio de logs para esta ejecución: $LOGS_DIR"

    local total_logs=$(($RANDOM % (${NUM_LOGS_RANGE[1]} - ${NUM_LOGS_RANGE[0]} + 1) + ${NUM_LOGS_RANGE[0]}))
    echo "Generando $total_logs logs de simulación..."

    for i in $(seq 1 $total_logs); do
        local apl=${MISION_NAMES[$(($RANDOM % $TOTAL_MISIONS))]}
        local device_type=${DEVICE_TYPES[$(($RANDOM % $TOTAL_DEVICES))]}
        local status=${STATUS_OPTIONS[$(($RANDOM % $TOTAL_STATUS))]}
        local random_num=$(($RANDOM % ($MAX_CODE - $MIN_CODE + 1) + $MIN_CODE))
        local codigo
        printf -v codigo "%04d" $random_num
        
        local output_name="${apl}-${codigo}.log"
        local current_date=$(date "+%d%m%y%H%M%S")
        local hash_data="${current_date}|${apl}|${device_type}|${status}"
        local hash=$(echo -n "$hash_data" | sha256sum | awk '{print $1}')

        if [[ "$apl" == "UNKN" ]]; then
            device_type="unknown"
            status="unknown"
            hash="unknown"
        fi

        local output_path="$LOGS_DIR/$output_name"
        echo "date${DELIMITER}mission${DELIMITER}device_type${DELIMITER}device_status${DELIMITER}hash" > "$output_path"
        echo "${current_date}${DELIMITER}${apl}${DELIMITER}${device_type}${DELIMITER}${status}${DELIMITER}${hash}" >> "$output_path"
    done
    echo " Generación de logs finalizada."
}

consolidate_logs() {
    echo "========================================================"
    echo " CONSOLIDACIÓN DE LOGS"
    echo "========================================================"
    
    echo "date${DELIMITER}mission${DELIMITER}device_type${DELIMITER}device_status${DELIMITER}hash" > "$CONSOLIDATED_FILE"

    find "$LOGS_DIR" -maxdepth 1 -type f -name "*.log" -print0 | xargs -0 -I {} tail -n +2 "{}" >> "$CONSOLIDATED_FILE"

    if [ $(wc -l < "$CONSOLIDATED_FILE") -gt 1 ]; then
        echo " Logs consolidados en: $CONSOLIDATED_FILE"
    else
        echo " No se encontraron datos en los logs. Abortando."
        rm "$CONSOLIDATED_FILE"
        exit 1
    fi
}

generate_reports() {
    echo "========================================================"
    echo " GENERACIÓN DE REPORTES"
    echo "========================================================"
    
    echo "Procesando archivo consolidado: $CONSOLIDATED_FILE"
    echo "Generando reportes en: $REPORTS_DIR"

    # 1. Análisis de Eventos
    local report_eventos="${REPORTS_DIR}/APLSTATS-EVENTOS-${EXECUTION_ID}.csv"
    echo "Generando reporte: Análisis de Eventos..."
    cat "$CONSOLIDATED_FILE" | csvsql -d "$DELIMITER" --query "
        SELECT mission, device_type, device_status, COUNT(*) AS event_count
        FROM stdin
        GROUP BY mission, device_type, device_status
        ORDER BY mission, device_type, event_count DESC
    " > "$report_eventos"

    # 2. Gestión de Desconexiones
    local report_desconexiones="${REPORTS_DIR}/APLSTATS-DESCONEXIONES-${EXECUTION_ID}.csv"
    echo "Generando reporte: Gestión de Desconexiones..."
    cat "$CONSOLIDATED_FILE" | csvsql -d "$DELIMITER" --query "
        SELECT mission, device_type, COUNT(*) AS unknown_count
        FROM stdin
        WHERE device_status = 'unknown'
        GROUP BY mission, device_type
        ORDER BY unknown_count DESC
    " > "$report_desconexiones"

    # 3. Misiones Inoperables
    local report_inoperables="${REPORTS_DIR}/APLSTATS-INOPERABLES-${EXECUTION_ID}.csv"
    echo "Generando reporte: Dispositivos Inoperables..."
    cat "$CONSOLIDATED_FILE" | csvsql -d "$DELIMITER" --query "
        SELECT mission, COUNT(*) AS inoperable_devices
        FROM stdin
        WHERE device_status = 'killed'
        GROUP BY mission
        ORDER BY inoperable_devices DESC
    " > "$report_inoperables"
    
    # 4. Cálculo de Porcentajes
    local report_porcentajes="${REPORTS_DIR}/APLSTATS-PORCENTAJES-${EXECUTION_ID}.csv"
    echo "Generando reporte: Cálculo de Porcentajes..."
    cat "$CONSOLIDATED_FILE" | csvsql -d "$DELIMITER" --query "
        SELECT
            mission,
            device_type,
            COUNT(*) AS data_points,
            ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM stdin), 2) AS percentage
        FROM stdin
        GROUP BY mission, device_type
        ORDER BY percentage DESC
    " > "$report_porcentajes"

    echo "Todos los reportes han sido generados."
}

# --- Función para limpiar y archivar los logs ---
cleanup() {
    echo "========================================================"
    echo " LIMPIEZA Y ARCHIVADO"
    echo "========================================================"
    
    local file_count=$(find "$LOGS_DIR" -maxdepth 1 -type f -name "*.log" 2>/dev/null | wc -l)

    if [ "$file_count" -gt 0 ]; then
        echo "Moviendo $file_count logs de '$LOGS_DIR' a '$BACKUPS_DIR'..."
        mv "$LOGS_DIR"/*.log "$BACKUPS_DIR/"
        # Eliminar el directorio de logs de la ejecución, que ahora está vacío
        rmdir "$LOGS_DIR"
        echo " Proceso de limpieza completado."
    else
        echo " No se encontraron logs para mover. No se requiere limpieza."
    fi
}

# ============================
# EJECUCIÓN PRINCIPAL
# ============================

main() {
    echo "========================================================"
    echo "INICIANDO PROCESO DE MISIÓN APOLO 11"
    echo "ID de Ejecución: ${EXECUTION_ID}"
    echo "========================================================"
    
    # Crear la estructura de directorios necesaria para esta ejecución
    mkdir -p "$LOGS_DIR" "$REPORTS_DIR" "$BACKUPS_DIR"
    echo "Estructura de directorios para la ejecución ${EXECUTION_ID} creada."
    
    # Ejecutar el flujo de trabajo
    generate_logs
    consolidate_logs
    generate_reports
    cleanup
    
    echo "========================================================"
    echo " MISIÓN COMPLETADA CON ÉXITO."
    echo "Los reportes finales se encuentran en: ${REPORTS_DIR}"
    echo "Los logs originales han sido archivados en: ${BACKUPS_DIR}"
    echo "========================================================"
}

# Iniciar la ejecución
main

db="$(pwd)/database/unal.db"

# Ejecutar el script Python que carga los datos
python app.py "$CONSOLIDATED_FILE" ";" $db "bronze.events"

cd $(pwd)/nasa

# Ejecutar dbt
dbt deps
dbt test
dbt seed
dbt run
dbt docs generate


