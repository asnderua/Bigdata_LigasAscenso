# Databricks notebook source
# MAGIC %md
# MAGIC # Proyecto Ligas de Ascenso — Componente Big Data (PySpark / Databricks)
# MAGIC Pipeline Medallion (Bronze → Silver → Gold) sobre el dataset de partidos de Liga 2 y Copa Perú, tablas de KPI por área para el dashboard y 5 experimentos de rendimiento (EXP-02 a EXP-06).

# COMMAND ----------

# MAGIC %md
# MAGIC ## 1. Bronze — Ingesta del dataset crudo
# MAGIC Lectura del archivo `LigasdeAscenso_BD_completa_actualizada.csv` desde el Volumen y guardado como tabla Delta sin transformar.

# COMMAND ----------

# MAGIC %sql
# MAGIC create database if not exists proyectoT4

# COMMAND ----------

# MAGIC %fs head /Volumes/workspace/proyectot4/volument4/DirectorioT4/LigasdeAscenso_BD_completa_actualizada.csv

# COMMAND ----------

dfLigas = spark.read.csv("/Volumes/workspace/proyectot4/volument4/DirectorioT4/LigasdeAscenso_BD_completa_actualizada.csv", header=True, inferSchema=True, sep=",")

# COMMAND ----------

display(dfLigas)

# COMMAND ----------

dfLigas.write.mode("overwrite").saveAsTable("proyectoT4.ligas")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 2. EDA — Exploración inicial
# MAGIC Conteos de filas, valores nulos y revisión de formatos antes de limpiar.

# COMMAND ----------

df = spark.table("proyectoT4.ligas")

df.printSchema()
df.describe().display()

from pyspark.sql.functions import col, count, when
df.select([count(when(col(c).isNull(), c)).alias(c) for c in df.columns]).display()

df.select("Estadio").distinct().count()
df.select("Competicion").distinct().count()

# COMMAND ----------

# MAGIC %md
# MAGIC Los nulos de asistencia, aforo y goles corresponden a partidos que no se jugaron. Se revisa con el estado del partido:

# COMMAND ----------

df.groupBy("EstadoPartido").count().orderBy(col("count").desc()).display()

# COMMAND ----------

# MAGIC %md
# MAGIC ## 3. Silver — Limpieza del dataset
# MAGIC Se elimina cualquier partido repetido, se asegura el formato de fecha y se agregan columnas de apoyo: año, mes, día de la semana, si tiene asistencia registrada y los valores válidos para calcular la ocupación. Se guarda como `ligas_clean`.

# COMMAND ----------

from pyspark.sql.functions import col, when, to_timestamp, year, month, dayofweek

df = spark.table("proyectoT4.ligas")

df_clean = (df
    .dropDuplicates(["IDpartido"])
    .withColumn("FechaHora", to_timestamp(col("FechaHora")))
    .withColumn("Anio", year(col("FechaHora")))
    .withColumn("Mes", month(col("FechaHora")))
    .withColumn("orden_dia", ((dayofweek(col("FechaHora")) + 5) % 7) + 1)
    .withColumn("dia_semana",
        when(col("orden_dia") == 1, "Lunes")
        .when(col("orden_dia") == 2, "Martes")
        .when(col("orden_dia") == 3, "Miércoles")
        .when(col("orden_dia") == 4, "Jueves")
        .when(col("orden_dia") == 5, "Viernes")
        .when(col("orden_dia") == 6, "Sábado")
        .otherwise("Domingo"))
    .withColumn("tiene_asistencia", col("AsistenciaRegistrada").isNotNull())
    .withColumn("asist_valida", when(col("AsistenciaRegistrada").isNotNull() & (col("AforoEstadio") > 0), col("AsistenciaRegistrada")))
    .withColumn("aforo_valido", when(col("AsistenciaRegistrada").isNotNull() & (col("AforoEstadio") > 0), col("AforoEstadio")))
)

df_clean.write.mode("overwrite").saveAsTable("proyectoT4.ligas_clean")

df_clean.printSchema()
df_clean.filter(col("FechaHora").isNull()).count()
df_clean.count()

# COMMAND ----------

print(df_clean.filter(col("FechaHora").isNull()).count())

# COMMAND ----------

# MAGIC %md
# MAGIC ## 4. Gold — Tablas de KPI por área
# MAGIC Una tabla pequeña y lista para graficar por cada visualización del dashboard. Cada tabla se guarda en la base `proyectoT4`.

# COMMAND ----------

# MAGIC %md
# MAGIC ### 4.1 Resumen general (tarjetas)

# COMMAND ----------

from pyspark.sql.functions import col, when, count, sum as _sum, avg, round as _round, to_date, lit

df_clean = spark.table("proyectoT4.ligas_clean")

df_resumen = (df_clean
    .agg(
        _round(_sum("IngresosPagados"), 2).alias("ingresos_totales"),
        _sum("BoletosPagados").alias("boletos_pagados"),
        count(when(col("BoletosPagados") > 0, 1)).alias("partidos_con_venta"),
        _sum("AsistenciaRegistrada").alias("asistentes_registrados"),
        count(when(col("tiene_asistencia"), 1)).alias("partidos_con_asistencia"),
        _sum("asist_valida").alias("asistencia_valida"),
        _sum("aforo_valido").alias("aforo_valido")
    )
    .withColumn("precio_promedio", _round(col("ingresos_totales") / col("boletos_pagados"), 2))
    .withColumn("asistencia_promedio", _round(col("asistentes_registrados") / col("partidos_con_asistencia"), 2))
    .withColumn("ocupacion_pct", _round(100 * col("asistencia_valida") / col("aforo_valido"), 2))
)

df_resumen.write.mode("overwrite").saveAsTable("proyectoT4.gold_resumen")
df_resumen.display()

# COMMAND ----------

# MAGIC %md
# MAGIC ### 4.2 Administración y Finanzas

# COMMAND ----------

df_fin_temporada = (df_clean
    .groupBy("Temporada", "Competicion")
    .agg(_round(_sum("IngresosPagados"), 2).alias("ingresos"))
    .orderBy("Temporada", "Competicion")
)
df_fin_temporada.write.mode("overwrite").saveAsTable("proyectoT4.gold_ingresos_temporada")

# COMMAND ----------

total_ingresos = df_clean.agg(_sum("IngresosPagados")).first()[0]

df_fin_estadio = (df_clean
    .groupBy("Estadio")
    .agg(
        _round(_sum("IngresosPagados"), 2).alias("ingresos"),
        _sum("BoletosPagados").alias("boletos"),
        count(when(col("BoletosPagados") > 0, 1)).alias("partidos_con_venta")
    )
    .withColumn("precio_promedio", _round(when(col("boletos") > 0, col("ingresos") / col("boletos")), 2))
    .withColumn("pct_del_total", _round(100 * col("ingresos") / lit(total_ingresos), 1))
    .orderBy(col("ingresos").desc())
)
df_fin_estadio.write.mode("overwrite").saveAsTable("proyectoT4.gold_ingresos_estadio")

# COMMAND ----------

# MAGIC %md
# MAGIC ### 4.3 Marketing

# COMMAND ----------

df_boletos_temporada = (df_clean
    .groupBy("Temporada", "Competicion")
    .agg(_sum("BoletosPagados").alias("boletos"))
    .orderBy("Temporada", "Competicion")
)
df_boletos_temporada.write.mode("overwrite").saveAsTable("proyectoT4.gold_boletos_temporada")

# COMMAND ----------

df_boletos_mes = (df_clean
    .groupBy("Mes", "Competicion")
    .agg(_sum("BoletosPagados").alias("boletos"))
    .orderBy("Mes", "Competicion")
)
df_boletos_mes.write.mode("overwrite").saveAsTable("proyectoT4.gold_boletos_mes")

# COMMAND ----------

# MAGIC %md
# MAGIC ### 4.4 Logística e Infraestructura

# COMMAND ----------

df_asist_dia = (df_clean
    .groupBy("orden_dia", "dia_semana")
    .agg(
        _sum("AsistenciaRegistrada").alias("asistentes_total"),
        _round(avg("AsistenciaRegistrada"), 2).alias("asistencia_promedio"),
        count(when(col("tiene_asistencia"), 1)).alias("partidos_con_asistencia")
    )
    .orderBy("orden_dia")
)
df_asist_dia.write.mode("overwrite").saveAsTable("proyectoT4.gold_asistencia_dia")

# COMMAND ----------

df_asist_dia_mes = (df_clean
    .filter(col("tiene_asistencia"))
    .groupBy("orden_dia", "dia_semana", "Mes")
    .agg(_round(avg("AsistenciaRegistrada"), 0).alias("asistencia_promedio"))
    .orderBy("orden_dia", "Mes")
)
df_asist_dia_mes.write.mode("overwrite").saveAsTable("proyectoT4.gold_asistencia_dia_mes")

# COMMAND ----------

df_asist_estadio = (df_clean
    .filter(col("tiene_asistencia"))
    .groupBy("Estadio")
    .agg(
        _round(avg("AsistenciaRegistrada"), 0).alias("asistencia_promedio"),
        count("IDpartido").alias("partidos")
    )
    .orderBy(col("asistencia_promedio").desc())
)
df_asist_estadio.write.mode("overwrite").saveAsTable("proyectoT4.gold_asistencia_estadio")

# COMMAND ----------

df_top_fechas = (df_clean
    .filter(col("tiene_asistencia"))
    .groupBy(to_date(col("FechaHora")).alias("fecha"))
    .agg(
        _sum("AsistenciaRegistrada").alias("asistentes"),
        count("IDpartido").alias("partidos")
    )
    .orderBy(col("asistentes").desc())
    .limit(10)
)
df_top_fechas.write.mode("overwrite").saveAsTable("proyectoT4.gold_top_fechas")

# COMMAND ----------

# MAGIC %md
# MAGIC ### 4.5 Programación Deportiva
# MAGIC La meta de ocupación es 60 % (definida en la tabla de KPI del informe).

# COMMAND ----------

META_OCUPACION = 60

df_ocupacion_estadio = (df_clean
    .filter(col("aforo_valido") > 0)
    .groupBy("Estadio")
    .agg(
        _sum("asist_valida").alias("asistencia"),
        _sum("aforo_valido").alias("aforo"),
        _round(avg("asist_valida"), 0).alias("asistencia_promedio"),
        _round(_sum("IngresosPagados"), 2).alias("ingresos")
    )
    .withColumn("ocupacion_pct", _round(100 * col("asistencia") / col("aforo"), 2))
    .withColumn("estado_meta", when(col("ocupacion_pct") < META_OCUPACION, "Bajo la meta").otherwise("Cumple la meta"))
    .orderBy("ocupacion_pct")
)
df_ocupacion_estadio.write.mode("overwrite").saveAsTable("proyectoT4.gold_ocupacion_estadio")

# COMMAND ----------

df_ocupacion_temporada = (df_clean
    .filter(col("aforo_valido") > 0)
    .groupBy("Temporada", "Competicion")
    .agg(
        _sum("asist_valida").alias("asistencia"),
        _sum("aforo_valido").alias("aforo")
    )
    .withColumn("ocupacion_pct", _round(100 * col("asistencia") / col("aforo"), 2))
    .orderBy("Temporada", "Competicion")
)
df_ocupacion_temporada.write.mode("overwrite").saveAsTable("proyectoT4.gold_ocupacion_temporada")

# COMMAND ----------

# MAGIC %md
# MAGIC ## 5. Visualizaciones — Dashboard
# MAGIC Cada tabla se muestra con `display()`. Para graficar: clic en **+** junto a *Table* → **Visualization**, elegir el tipo y llenar los campos que se indican. Al final, **View → Add to dashboard** para armar el tablero.

# COMMAND ----------

# MAGIC %md
# MAGIC ### 5.1 Resumen general
# MAGIC **Tipo:** *Counter* (uno por KPI: `ingresos_totales`, `precio_promedio`, `boletos_pagados`, `asistencia_promedio`, `ocupacion_pct`).

# COMMAND ----------

spark.table("proyectoT4.gold_resumen").display()

# COMMAND ----------

# MAGIC %md
# MAGIC ### 5.2 Administración y Finanzas — ¿Cuánto se recaudó y qué sedes explican el total?
# MAGIC **Ingresos por temporada y competición.** Tipo: *Bar* · X: `Temporada` · Y: `ingresos` (SUM) · Agrupar por: `Competicion`.
# MAGIC *Decisión:* contrastar los cierres de cada temporada con los registros de los clubes.

# COMMAND ----------

spark.table("proyectoT4.gold_ingresos_temporada").display()

# COMMAND ----------

# MAGIC %md
# MAGIC **Ingresos por estadio.** Tipo: *Bar* horizontal · X: `ingresos` · Y: `Estadio` (ordenar por `ingresos` descendente, mostrar los 10 primeros).
# MAGIC *Decisión:* priorizar la revisión de taquilla y comparar sedes para programar encuentros.

# COMMAND ----------

spark.table("proyectoT4.gold_ingresos_estadio").display()

# COMMAND ----------

# MAGIC %md
# MAGIC ### 5.3 Marketing — ¿Dónde conviene revisar la venta y el precio efectivo?
# MAGIC **Boletos por temporada y competición.** Tipo: *Bar* · X: `Temporada` · Y: `boletos` (SUM) · Agrupar por: `Competicion`.
# MAGIC *Decisión:* detectar temporadas de menor venta donde convenga probar una campaña.

# COMMAND ----------

spark.table("proyectoT4.gold_boletos_temporada").display()

# COMMAND ----------

# MAGIC %md
# MAGIC **Boletos por mes del año.** Tipo: *Bar* · X: `Mes` · Y: `boletos` (SUM) · Agrupar por: `Competicion`.
# MAGIC *Decisión:* elegir los meses de menor venta para lanzar promociones.

# COMMAND ----------

spark.table("proyectoT4.gold_boletos_mes").display()

# COMMAND ----------

# MAGIC %md
# MAGIC **Precio promedio vs boletos por estadio.** Tipo: *Scatter* · X: `boletos` · Y: `precio_promedio` · Color: `Estadio` · Tamaño: `ingresos`.
# MAGIC *Decisión:* comparar precios con Finanzas y elegir dónde probar una promoción.

# COMMAND ----------

spark.table("proyectoT4.gold_ingresos_estadio").filter("boletos > 0").display()

# COMMAND ----------

# MAGIC %md
# MAGIC ### 5.4 Logística e Infraestructura — ¿Cuánta gente suele asistir y qué fechas requieren refuerzos?
# MAGIC **Asistencia por día de la semana.** Tipo: *Bar* · X: `dia_semana` (ordenar por `orden_dia`) · Y: `asistentes_total` (total) o `asistencia_promedio` (por partido).
# MAGIC *Decisión:* ubicar los días que requieren refuerzo de personal, accesos y servicios.

# COMMAND ----------

spark.table("proyectoT4.gold_asistencia_dia").display()

# COMMAND ----------

# MAGIC %md
# MAGIC **Asistencia por día y mes.** Tipo: *Heatmap* · X: `Mes` · Y: `dia_semana` · Color: `asistencia_promedio`.
# MAGIC *Decisión:* ubicar los picos de asistencia a lo largo del año.

# COMMAND ----------

spark.table("proyectoT4.gold_asistencia_dia_mes").display()

# COMMAND ----------

# MAGIC %md
# MAGIC **Asistencia promedio por estadio.** Tipo: *Bar* horizontal · X: `asistencia_promedio` · Y: `Estadio`.
# MAGIC *Decisión:* estimar cuántos accesos y cuánto personal requiere cada sede.

# COMMAND ----------

spark.table("proyectoT4.gold_asistencia_estadio").display()

# COMMAND ----------

# MAGIC %md
# MAGIC **Fechas con mayor asistencia.** Se deja como tabla.
# MAGIC *Decisión:* ubicar las fechas que requieren refuerzos de personal, accesos y servicios.

# COMMAND ----------

spark.table("proyectoT4.gold_top_fechas").display()

# COMMAND ----------

# MAGIC %md
# MAGIC ### 5.5 Programación Deportiva — ¿Qué estadios se acercan a su capacidad?
# MAGIC **Ocupación por estadio.** Tipo: *Bar* horizontal · X: `ocupacion_pct` · Y: `Estadio` · Color: `estado_meta`.
# MAGIC *Decisión:* identificar estadios bajo la meta o cerca de su capacidad y revisar sedes y horarios.

# COMMAND ----------

spark.table("proyectoT4.gold_ocupacion_estadio").display()

# COMMAND ----------

# MAGIC %md
# MAGIC **Ocupación por temporada y competición.** Tipo: *Line* · X: `Temporada` · Y: `ocupacion_pct` · Agrupar por: `Competicion`.
# MAGIC *Decisión:* ver si el uso del aforo mejora o cae frente a la meta.

# COMMAND ----------

spark.table("proyectoT4.gold_ocupacion_temporada").display()

# COMMAND ----------

# MAGIC %md
# MAGIC ## 6. Experimentos de rendimiento (EXP-02 a EXP-06)
# MAGIC Medición de tiempo antes y después de cada cambio. El dataset es pequeño (3,014 partidos), por lo que las diferencias en segundos serán pequeñas; se comparan las tendencias.

# COMMAND ----------

# MAGIC %md
# MAGIC ### 6.1 EXP-02 — Volumen de datos (x1 vs x5)

# COMMAND ----------

import time
from pyspark.sql.functions import col, sum as _sum

def calcular_kpi_estadio(df):
    return (df
        .groupBy("Estadio")
        .agg(
            _sum("IngresosPagados").alias("ingresos"),
            _sum("BoletosPagados").alias("boletos"),
            _sum("asist_valida").alias("asistencia"),
            _sum("aforo_valido").alias("aforo")
        )
    )

df_clean = spark.table("proyectoT4.ligas_clean")

inicio = time.time()
calcular_kpi_estadio(df_clean).count()
fin = time.time()
t_vol_x1 = fin - inicio
print(f"Volumen x1 ({df_clean.count()} filas): {t_vol_x1:.2f} segundos")

# COMMAND ----------

df_x5 = df_clean
for i in range(1, 5):
    df_x5 = df_x5.unionByName(df_clean.withColumn("IDpartido", col("IDpartido") + i * 100000))

df_x5.write.mode("overwrite").saveAsTable("proyectoT4.ligas_clean_x5")
print(f"Volumen x5: {df_x5.count()} filas")

# COMMAND ----------

inicio = time.time()
calcular_kpi_estadio(df_x5).count()
fin = time.time()
t_vol_x5 = fin - inicio
print(f"Volumen x5 ({df_x5.count()} filas): {t_vol_x5:.2f} segundos")

# COMMAND ----------

display(spark.createDataFrame([("x1", t_vol_x1), ("x5", t_vol_x5)], ["condicion", "tiempo_segundos"]))

# COMMAND ----------

# MAGIC %md
# MAGIC ### 6.2 EXP-03 — Uso de cache (.cache())
# MAGIC Si tu entorno es *serverless* y `.cache()` marca error, documenta esa limitación en el informe y compara solo con la medición sin cache.

# COMMAND ----------

import time
from pyspark.sql.functions import col

df_jugados = df_clean.filter(col("EstadoPartido") == "Finalizado")

inicio = time.time()
for repeticion in range(3):
    calcular_kpi_estadio(df_jugados).count()
fin = time.time()
t_sin_cache = fin - inicio
print(f"SIN cache, 3 repeticiones: {t_sin_cache:.2f} segundos")

# COMMAND ----------

df_jugados_cache = df_clean.filter(col("EstadoPartido") == "Finalizado").cache()
df_jugados_cache.count()  # esto fuerza a que se guarde en memoria ahora, no despues

inicio = time.time()
for repeticion in range(3):
    calcular_kpi_estadio(df_jugados_cache).count()
fin = time.time()
t_con_cache = fin - inicio
print(f"CON cache, 3 repeticiones: {t_con_cache:.2f} segundos")

df_jugados_cache.unpersist()

# COMMAND ----------

display(spark.createDataFrame([("Sin cache", t_sin_cache), ("Con cache", t_con_cache)], ["condicion", "tiempo_segundos"]))

# COMMAND ----------

# MAGIC %md
# MAGIC ### 6.3 EXP-04 — Window sin partición (x1 vs x5 partidos)

# COMMAND ----------

import time
from pyspark.sql import Window
from pyspark.sql.functions import ntile, col

def medir_window(df, nombre):
    inicio = time.time()

    w_asistencia = Window.orderBy(col("AsistenciaRegistrada").desc())

    df_cuartiles = (df
        .filter(col("tiene_asistencia"))
        .withColumn("cuartil_asistencia", ntile(4).over(w_asistencia))
    )
    df_cuartiles.count()

    fin = time.time()
    tiempo = fin - inicio
    print(f"{nombre}: {tiempo:.2f} segundos")
    return tiempo

df_x5 = spark.table("proyectoT4.ligas_clean_x5")

t_window_x1 = medir_window(df_clean, "Window sin particion, volumen x1")
t_window_x5 = medir_window(df_x5, "Window sin particion, volumen x5")

# COMMAND ----------

display(spark.createDataFrame([("x1 (2,746 partidos con asistencia)", t_window_x1), ("x5 (13,730 partidos con asistencia)", t_window_x5)], ["condicion", "tiempo_segundos"]))

# COMMAND ----------

# MAGIC %md
# MAGIC ### 6.4 EXP-05 — Formato de almacenamiento (CSV vs Delta)

# COMMAND ----------

import time

inicio = time.time()
df_csv = spark.read.csv("/Volumes/workspace/proyectot4/volument4/DirectorioT4/LigasdeAscenso_BD_completa_actualizada.csv", header=True, inferSchema=True, sep=",")
conteo_csv = df_csv.count()
fin = time.time()
t_csv = fin - inicio
print(f"Lectura CSV crudo: {t_csv:.2f} segundos ({conteo_csv} filas)")

# COMMAND ----------

inicio = time.time()
df_delta = spark.table("proyectoT4.ligas_clean")
conteo_delta = df_delta.count()
fin = time.time()
t_delta = fin - inicio
print(f"Lectura tabla Delta: {t_delta:.2f} segundos ({conteo_delta} filas)")

# COMMAND ----------

display(spark.createDataFrame([("CSV crudo", t_csv), ("Tabla Delta", t_delta)], ["condicion", "tiempo_segundos"]))

# COMMAND ----------

# MAGIC %md
# MAGIC ### 6.5 EXP-06 — Número de particiones (por defecto vs 2)

# COMMAND ----------

from pyspark.sql.functions import spark_partition_id

df_x5 = spark.table("proyectoT4.ligas_clean_x5")
particiones_default = df_x5.select(spark_partition_id()).distinct().count()
print(f"Particiones por defecto: {particiones_default}")

# COMMAND ----------

import time
from pyspark.sql.functions import spark_partition_id

def calcular_kpi_tiempo(df, nombre):
    inicio = time.time()
    calcular_kpi_estadio(df).count()
    fin = time.time()
    tiempo = fin - inicio
    particiones = df.select(spark_partition_id()).distinct().count()
    print(f"{nombre} ({particiones} particiones): {tiempo:.2f} segundos")
    return tiempo

t_part_default = calcular_kpi_tiempo(df_x5, "Particiones por defecto")

# COMMAND ----------

df_x5_pocas_particiones = df_x5.repartition(2)
t_part_2 = calcular_kpi_tiempo(df_x5_pocas_particiones, "Forzado a 2 particiones")

# COMMAND ----------

display(spark.createDataFrame([("Particiones por defecto", t_part_default), ("2 particiones (forzado)", t_part_2)], ["condicion", "tiempo_segundos"]))

# COMMAND ----------

# MAGIC %md
# MAGIC ## 7. Verificación final
# MAGIC Consultas de control sobre las tablas Gold. Los valores esperados son: ingresos S/ 101,345.00 · boletos pagados 2,552 · precio promedio S/ 39.71 · asistencia promedio 7,199.16 · ocupación 61.83 %.

# COMMAND ----------

spark.table("proyectoT4.gold_resumen").display()

# COMMAND ----------

spark.table("proyectoT4.gold_ocupacion_estadio").groupBy("estado_meta").count().orderBy(col("count").desc()).display()
