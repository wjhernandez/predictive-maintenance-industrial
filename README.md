# Mantenimiento Predictivo en Planta Industrial
### Clasificación de Fallas de Equipos mediante Machine Learning — AI4I 2020 Dataset

**Autora:** Wendy J. Hernández  
**Perfil:** Ingeniería Química · Especialización Ambiental · Data Analytics  
**Stack:** Python · SQL (PostgreSQL) · Power BI  
**Dataset:** [AI4I 2020 Predictive Maintenance — UCI ML Repository](https://archive.ics.uci.edu/dataset/601/ai4i+2020+predictive+maintenance+dataset)

---

## Contexto de Negocio

En industrias de proceso continuo como papel, pulpa, química, alimentos, entre otros, los equipos rotativos representan activos críticos cuya falla no planificada genera paros de producción, costos de mantenimiento correctivo hasta 5 veces superiores al preventivo, y riesgos operacionales. Bajo la filosofía **TPM (Total Productive Maintenance)**, el pilar de Mantenimiento Planificado busca transitar del mantenimiento reactivo al predictivo mediante análisis de datos de sensores en tiempo real.

**Pregunta de negocio:**
> ¿Es posible predecir la falla de un equipo industrial con base en variables de proceso medibles en tiempo real, y clasificar el tipo de falla para orientar la acción de mantenimiento?

---

## Dataset

El AI4I 2020 Predictive Maintenance Dataset es un conjunto de datos sintético que replica condiciones reales de planta industrial, publicado por Matzka (2020) en UCI ML Repository.

| Variable | Descripción | Unidad |
|---|---|---|
| Air temperature | Temperatura del aire (walk aleatorio ~300 K) | K |
| Process temperature | Temperatura de proceso (T_aire + 10 K) | K |
| Rotational speed | Velocidad rotacional del equipo | rpm |
| Torque | Torque aplicado (media 40 Nm) | Nm |
| Tool wear | Desgaste acumulado de herramienta | min |
| Machine failure | **TARGET**: 1=falla, 0=normal | binario |
| TWF/HDF/PWF/OSF/RNF | Modos de falla individuales | binario |

**Características:**
- 10,000 registros · 14 variables · Desbalance 96.6% normal / 3.4% falla
- Licencia: Creative Commons Attribution 4.0 (CC BY 4.0)

---

## Metodología

```
Carga de datos (UCI API)
    ↓
EDA — Distribuciones, correlaciones, análisis por modo de falla
    ↓
Feature Engineering — Delta_T, Potencia mecánica, Overstrain index
    ↓
Preprocesamiento — Escalado, SMOTE (solo en train)
    ↓
Modelado — Regresión Logística, Random Forest, XGBoost
    ↓
Evaluación — PR-AUC, Recall (métrica primaria), Matrices de confusión
    ↓
Interpretabilidad — SHAP values (importancia por variable)
    ↓
KPIs — MTBF, Disponibilidad operacional por tipo de producto
    ↓
Exportación CSV → Power BI Dashboard
```

### Decisiones de diseño

- **Métrica primaria: Recall** — el costo de una falla no detectada (falso negativo) en planta es órdenes de magnitud mayor que el costo de una inspección innecesaria
- **SMOTE aplicado únicamente en train** para evitar data leakage
- **Variables derivadas con fundamento físico:** P = T × ω (potencia mecánica), ΔT = T_proceso − T_aire, Índice sobresfuerzo = Torque × Desgaste
- **SHAP para interpretabilidad**: el equipo de mantenimiento necesita saber *por qué* el modelo predice una falla, no solo *que* la predice

---

## Estructura del Repositorio

```
predictive-maintenance-industrial/
├── notebook/
│   └── predictive_maintenance_industrial.ipynb   # Análisis completo
├── sql/
│   └── pm_schema_sql.sql                         # Modelo estrella de datos
├── data/
│   └── (descargar desde UCI o Kaggle — ver instrucciones)
├── exports/
│   ├── pm_fact_table.csv                         # Tabla de hechos principal
│   ├── pm_kpis_confiabilidad.csv                 # KPIs por tipo producto
│   └── pm_model_comparison.csv                   # Comparación de modelos
├── figures/
│   ├── fig1_balance_clases.png
│   ├── fig2_distribuciones.png
│   ├── fig3_correlacion.png
│   ├── fig4_analisis_tipo.png
│   ├── fig5_roc_pr_curves.png
│   ├── fig6_confusion_matrices.png
│   ├── fig7_shap_importance.png
│   └── fig8_kpis_confiabilidad.png
└── README.md
```

---

## Cómo ejecutar

**1. Clonar el repositorio**
```bash
git clone https://github.com/wjhernandez/predictive-maintenance-industrial.git
cd predictive-maintenance-industrial
```

**2. Instalar dependencias**
```bash
pip install pandas numpy matplotlib seaborn scikit-learn imbalanced-learn xgboost shap ucimlrepo
```

**3. Ejecutar el notebook**
```bash
jupyter notebook notebook/predictive_maintenance_industrial.ipynb
```

El dataset se descarga automáticamente desde UCI ML Repository mediante la librería `ucimlrepo` (requiere conexión a internet).

**4. Configurar base de datos (opcional)**
```bash
psql -U usuario -d nombre_db -f sql/pm_schema_sql.sql
```

**5. Conectar Power BI**
- Importar los archivos CSV desde `exports/` o conectar directamente a PostgreSQL mediante las vistas analíticas incluidas en el schema.

---

## Arquitectura Power BI

El dashboard está diseñado como modelo estrella con las siguientes páginas:

- **Resumen Ejecutivo:** KPIs globales, disponibilidad por tipo, distribución de fallas
- **Análisis de Proceso:** Variables de sensor en tendencia temporal, zonas de riesgo
- **Modo de Falla:** Distribución por TWF/HDF/PWF/OSF/RNF, condiciones disparadoras
- **Predicción ML:** Probabilidades predichas, alertas activas, matriz de confusión

---

## Relevancia Industrial

Este análisis es aplicable directamente a:

- **Industria papelera/pulpa:** Monitoreo de refinadores, bombas, compresores de aire.
- **Manufactura de consumo:** Líneas de producción continua.
- **Agroindustria:** Equipos de procesamiento en ingenios azucareros, plantas de aceite.
- **Química industrial:** Torres de destilación, reactores, intercambiadores de calor.

---

## Referencias

- Matzka, S. (2020). *Explainable Artificial Intelligence for Predictive Maintenance Applications*. UCI ML Repository. https://doi.org/10.24432/C5HS5C
- Chawla, N.V. et al. (2002). SMOTE: Synthetic Minority Over-sampling Technique. *Journal of Artificial Intelligence Research*, 16, 321–357.
- Lundberg, S.M. & Lee, S.I. (2017). A Unified Approach to Interpreting Model Predictions. *NeurIPS*.
- Mobley, R.K. (2002). *An Introduction to Predictive Maintenance* (2nd ed.). Butterworth-Heinemann.
- Géron, A. (2022). *Hands-On Machine Learning with Scikit-Learn, Keras & TensorFlow* (3rd ed.). O'Reilly.

---

*Proyecto desarrollado como parte del portafolio de Data Analytics con enfoque en manufactura industrial y sostenibilidad.*
