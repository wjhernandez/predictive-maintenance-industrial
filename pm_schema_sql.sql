-- ============================================================
-- PROYECTO: Mantenimiento Predictivo Industrial
-- Dataset: AI4I 2020 (UCI ML Repository)
-- Autora: Wendy J. Hernández
-- Descripción: Modelo estrella de datos para dashboard Power BI
-- ============================================================


-- ============================================================
-- DIMENSIONES
-- ============================================================

-- Dimensión: Tipo de Producto
CREATE TABLE dim_product_type (
    type_id     SERIAL PRIMARY KEY,
    type_code   CHAR(1) NOT NULL UNIQUE,         -- 'H', 'M', 'L'
    type_name   VARCHAR(20) NOT NULL,             -- 'High', 'Medium', 'Low'
    quality_pct NUMERIC(5,2),                     -- proporción en el dataset
    tool_wear_rate_min INT                        -- incremento de desgaste por ciclo (min)
);

INSERT INTO dim_product_type (type_code, type_name, quality_pct, tool_wear_rate_min)
VALUES
    ('H', 'High Quality',   50.0, 5),
    ('M', 'Medium Quality', 30.0, 4),
    ('L', 'Low Quality',    20.0, 2);


-- Dimensión: Modo de Falla
CREATE TABLE dim_failure_mode (
    failure_mode_id  SERIAL PRIMARY KEY,
    mode_code        VARCHAR(5) NOT NULL UNIQUE,
    mode_name        VARCHAR(50) NOT NULL,
    description      TEXT,
    trigger_condition TEXT
);

INSERT INTO dim_failure_mode (mode_code, mode_name, description, trigger_condition)
VALUES
    ('TWF', 'Tool Wear Failure',
     'Falla por desgaste acumulado de herramienta',
     'Tool wear entre 200-240 min con probabilidad 50%'),
    ('HDF', 'Heat Dissipation Failure',
     'Falla por disipación insuficiente de calor',
     'Delta_T < 8.6 K Y velocidad rotacional < 1380 rpm'),
    ('PWF', 'Power Failure',
     'Falla por potencia fuera de rango operacional',
     'Potencia mecánica < 3500 W o > 9000 W'),
    ('OSF', 'Overstrain Failure',
     'Falla por sobresfuerzo acumulado',
     'Tool_wear × Torque > umbral específico por tipo de producto'),
    ('RNF', 'Random Failure',
     'Falla aleatoria independiente del proceso',
     'Probabilidad aleatoria 0.1% por ciclo');


-- ============================================================
-- TABLA DE HECHOS PRINCIPAL
-- ============================================================

CREATE TABLE fact_process_readings (
    reading_id              SERIAL PRIMARY KEY,
    uid                     INT NOT NULL,
    product_id              VARCHAR(10) NOT NULL,
    type_id                 INT REFERENCES dim_product_type(type_id),

    -- Variables de proceso (sensores)
    air_temp_k              NUMERIC(6,2) NOT NULL,
    process_temp_k          NUMERIC(6,2) NOT NULL,
    rotational_speed_rpm    INT NOT NULL,
    torque_nm               NUMERIC(6,2) NOT NULL,
    tool_wear_min           INT NOT NULL,

    -- Variables derivadas (Feature Engineering)
    delta_t_k               NUMERIC(6,2),    -- Temp_proceso - Temp_aire
    power_w                 NUMERIC(10,2),   -- Torque × ω (Watts)
    overstrain_index        NUMERIC(10,2),   -- Torque × Tool_wear

    -- Estado real (ground truth)
    machine_failure         SMALLINT NOT NULL DEFAULT 0,
    failure_twf             SMALLINT NOT NULL DEFAULT 0,
    failure_hdf             SMALLINT NOT NULL DEFAULT 0,
    failure_pwf             SMALLINT NOT NULL DEFAULT 0,
    failure_osf             SMALLINT NOT NULL DEFAULT 0,
    failure_rnf             SMALLINT NOT NULL DEFAULT 0,

    -- Predicción del modelo ML
    pred_failure            SMALLINT,
    pred_probability        NUMERIC(6,4),
    model_version           VARCHAR(20) DEFAULT 'v1.0_XGBoost',

    -- Metadatos
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- ============================================================
-- TABLA DE HECHOS: KPIs DE CONFIABILIDAD
-- ============================================================

CREATE TABLE fact_reliability_kpis (
    kpi_id              SERIAL PRIMARY KEY,
    type_id             INT REFERENCES dim_product_type(type_id),
    calc_date           DATE NOT NULL DEFAULT CURRENT_DATE,

    -- Indicadores TPM estándar
    total_records       INT NOT NULL,
    total_failures      INT NOT NULL,
    failure_rate_pct    NUMERIC(6,3) NOT NULL,
    mtbf_minutes        NUMERIC(10,2),            -- Mean Time Between Failures
    mtbf_hours          NUMERIC(8,2),
    availability_pct    NUMERIC(6,3),             -- Disponibilidad operacional

    -- Indicadores de predicción
    true_positives      INT,      -- Fallas correctamente detectadas
    false_negatives     INT,      -- Fallas NO detectadas (crítico)
    false_positives     INT,      -- Alarmas falsas
    recall_score        NUMERIC(6,4),
    precision_score     NUMERIC(6,4)
);


-- ============================================================
-- TABLA DE RESUMEN DE MODELOS
-- ============================================================

CREATE TABLE fact_model_performance (
    model_id            SERIAL PRIMARY KEY,
    model_name          VARCHAR(50) NOT NULL,
    model_version       VARCHAR(20),
    training_date       DATE,

    -- Métricas globales
    roc_auc             NUMERIC(6,4),
    pr_auc              NUMERIC(6,4),

    -- Métricas por clase (clase falla = 1)
    recall_failure      NUMERIC(6,4),
    precision_failure   NUMERIC(6,4),
    f1_failure          NUMERIC(6,4),
    accuracy            NUMERIC(6,4),

    -- Configuración
    smote_applied       BOOLEAN,
    n_estimators        INT,
    training_samples    INT,
    test_samples        INT,
    notes               TEXT
);


-- ============================================================
-- VISTAS ANALÍTICAS PARA POWER BI
-- ============================================================

-- Vista: Resumen operacional por tipo de producto
CREATE OR REPLACE VIEW vw_operational_summary AS
SELECT
    pt.type_code,
    pt.type_name,
    COUNT(r.reading_id)                                             AS total_readings,
    SUM(r.machine_failure)                                          AS total_failures,
    ROUND(SUM(r.machine_failure) * 100.0 / COUNT(*), 2)            AS failure_rate_pct,
    ROUND(COUNT(*) * 1.0 / NULLIF(SUM(r.machine_failure), 0), 1)   AS mtbf_readings,
    ROUND(COUNT(*) * 1.0 / NULLIF(SUM(r.machine_failure), 0) / 60, 2) AS mtbf_hours,
    ROUND(AVG(r.torque_nm), 2)                                      AS avg_torque_nm,
    ROUND(AVG(r.tool_wear_min), 1)                                  AS avg_tool_wear_min,
    ROUND(AVG(r.power_w), 1)                                        AS avg_power_w,
    ROUND(AVG(r.delta_t_k), 2)                                      AS avg_delta_t_k,
    SUM(r.failure_hdf)                                              AS failures_hdf,
    SUM(r.failure_twf)                                              AS failures_twf,
    SUM(r.failure_pwf)                                              AS failures_pwf,
    SUM(r.failure_osf)                                              AS failures_osf,
    SUM(r.failure_rnf)                                              AS failures_rnf
FROM fact_process_readings r
JOIN dim_product_type pt ON r.type_id = pt.type_id
GROUP BY pt.type_code, pt.type_name
ORDER BY failure_rate_pct DESC;


-- Vista: Alertas activas (predicción de falla con alta probabilidad)
CREATE OR REPLACE VIEW vw_active_alerts AS
SELECT
    r.uid,
    r.product_id,
    pt.type_code,
    r.torque_nm,
    r.tool_wear_min,
    r.rotational_speed_rpm,
    r.delta_t_k,
    r.power_w,
    r.overstrain_index,
    r.pred_probability,
    r.machine_failure                           AS actual_failure,
    CASE
        WHEN r.pred_probability >= 0.8 THEN 'CRITICO'
        WHEN r.pred_probability >= 0.5 THEN 'ADVERTENCIA'
        WHEN r.pred_probability >= 0.3 THEN 'MONITOREO'
        ELSE 'NORMAL'
    END                                         AS alert_level,
    r.model_version
FROM fact_process_readings r
JOIN dim_product_type pt ON r.type_id = pt.type_id
WHERE r.pred_probability >= 0.3
ORDER BY r.pred_probability DESC;


-- Vista: Distribución de modos de falla
CREATE OR REPLACE VIEW vw_failure_mode_distribution AS
SELECT
    fm.mode_code,
    fm.mode_name,
    fm.description,
    COUNT(DISTINCT CASE
        WHEN fm.mode_code = 'TWF' AND r.failure_twf = 1 THEN r.uid
        WHEN fm.mode_code = 'HDF' AND r.failure_hdf = 1 THEN r.uid
        WHEN fm.mode_code = 'PWF' AND r.failure_pwf = 1 THEN r.uid
        WHEN fm.mode_code = 'OSF' AND r.failure_osf = 1 THEN r.uid
        WHEN fm.mode_code = 'RNF' AND r.failure_rnf = 1 THEN r.uid
    END)                                        AS failure_count,
    ROUND(
        COUNT(DISTINCT CASE
            WHEN fm.mode_code = 'TWF' AND r.failure_twf = 1 THEN r.uid
            WHEN fm.mode_code = 'HDF' AND r.failure_hdf = 1 THEN r.uid
            WHEN fm.mode_code = 'PWF' AND r.failure_pwf = 1 THEN r.uid
            WHEN fm.mode_code = 'OSF' AND r.failure_osf = 1 THEN r.uid
            WHEN fm.mode_code = 'RNF' AND r.failure_rnf = 1 THEN r.uid
        END) * 100.0 / NULLIF(SUM(r.machine_failure) OVER (), 0),
    1)                                          AS pct_of_total_failures
FROM dim_failure_mode fm
CROSS JOIN fact_process_readings r
GROUP BY fm.mode_code, fm.mode_name, fm.description
ORDER BY failure_count DESC;


-- ============================================================
-- ÍNDICES PARA OPTIMIZACIÓN DE CONSULTAS
-- ============================================================

CREATE INDEX idx_fact_type_id      ON fact_process_readings(type_id);
CREATE INDEX idx_fact_machine_fail ON fact_process_readings(machine_failure);
CREATE INDEX idx_fact_pred_prob    ON fact_process_readings(pred_probability DESC);
CREATE INDEX idx_fact_tool_wear    ON fact_process_readings(tool_wear_min);
CREATE INDEX idx_fact_uid          ON fact_process_readings(uid);


-- ============================================================
-- CARGA INICIAL DESDE CSV (ejecutar después de exportar Python)
-- ============================================================

/*
COPY fact_process_readings (
    uid, product_id, type_id,
    air_temp_k, process_temp_k, rotational_speed_rpm, torque_nm, tool_wear_min,
    delta_t_k, power_w, overstrain_index,
    machine_failure, failure_twf, failure_hdf, failure_pwf, failure_osf, failure_rnf,
    pred_failure, pred_probability
)
FROM '/ruta/pm_fact_table.csv'
DELIMITER ','
CSV HEADER;
*/

-- ============================================================
-- CONSULTAS DE VALIDACIÓN Y ANÁLISIS EXPLORATORIO EN SQL
-- ============================================================

-- 1. Conteo general por tipo de producto y estado
SELECT
    pt.type_name,
    SUM(CASE WHEN r.machine_failure = 0 THEN 1 ELSE 0 END) AS normal_ops,
    SUM(r.machine_failure)                                   AS failures,
    ROUND(SUM(r.machine_failure) * 100.0 / COUNT(*), 2)     AS failure_rate_pct
FROM fact_process_readings r
JOIN dim_product_type pt ON r.type_id = pt.type_id
GROUP BY pt.type_name
ORDER BY failure_rate_pct DESC;


-- 2. Estadísticas descriptivas de variables de proceso por clase
SELECT
    machine_failure,
    ROUND(AVG(air_temp_k), 2)           AS avg_air_temp,
    ROUND(AVG(process_temp_k), 2)       AS avg_proc_temp,
    ROUND(AVG(delta_t_k), 2)            AS avg_delta_t,
    ROUND(AVG(rotational_speed_rpm), 0) AS avg_rpm,
    ROUND(AVG(torque_nm), 2)            AS avg_torque,
    ROUND(AVG(tool_wear_min), 1)        AS avg_tool_wear,
    ROUND(AVG(power_w), 1)              AS avg_power,
    ROUND(AVG(overstrain_index), 1)     AS avg_overstrain
FROM fact_process_readings
GROUP BY machine_failure;


-- 3. Detección de registros en zona de riesgo (criterio físico HDF)
SELECT COUNT(*) AS registros_riesgo_hdf
FROM fact_process_readings
WHERE delta_t_k < 8.6
  AND rotational_speed_rpm < 1380
  AND machine_failure = 0;   -- Operación en zona de riesgo aún sin falla


-- 4. Top 10 registros con mayor probabilidad de falla predicha
SELECT
    uid, product_id,
    torque_nm, tool_wear_min, power_w,
    pred_probability,
    machine_failure AS falla_real
FROM fact_process_readings
ORDER BY pred_probability DESC
LIMIT 10;


-- 5. Matriz de confusión desde SQL
SELECT
    machine_failure  AS real,
    pred_failure     AS predicho,
    COUNT(*)         AS conteo,
    CASE
        WHEN machine_failure = 1 AND pred_failure = 1 THEN 'Verdadero Positivo'
        WHEN machine_failure = 0 AND pred_failure = 0 THEN 'Verdadero Negativo'
        WHEN machine_failure = 0 AND pred_failure = 1 THEN 'Falso Positivo (alarma falsa)'
        WHEN machine_failure = 1 AND pred_failure = 0 THEN 'Falso Negativo (falla no detectada)'
    END AS categoria
FROM fact_process_readings
WHERE pred_failure IS NOT NULL
GROUP BY machine_failure, pred_failure
ORDER BY machine_failure DESC, pred_failure DESC;
