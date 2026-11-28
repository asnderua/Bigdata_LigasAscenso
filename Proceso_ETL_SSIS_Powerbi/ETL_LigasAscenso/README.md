#ETL de Ligas de Ascenso 

Este proyecto implementa el flujo de extracción, transformación y carga (ETL) para la plataforma de Inteligencia de Negocios y Análisis de Taquilla del Fútbol de Ascenso Peruano. El proceso extrae la información transaccional, la consolida en una base de datos intermedia (Staging), alimenta seis dimensiones y puebla dos tablas de hechos dentro de DW_LigasdeAscenso.

# Arquitectura y Estructura del Data Warehouse

Base de Datos Origen (OLTP): LigasdeAscenso

Base de Datos Intermedia (Staging): Staging_Ligas (dbo.stg_Partidos, dbo.stg_Boletos, dbo.stg_Asistencia)

Data Warehouse (OLAP): DW_LigasdeAscenso

Dimensiones: DimTiempo, DimTemporada, DimEstadio, DimCompeticion, DimTipoEntrada, DimClub

Tablas de Hechos:

FactVentas: Granularidad por Partido y Tipo de Entrada (filtra únicamente boletos con EstadoPago = 'Pagado').

FactAsistencia: Granularidad por Partido (registra asistencia física a estadios).

Vista Analítica: dbo.vw_KPI_PorPartido (consolida agregaciones monetarias y asistencia antes de la capa de visualización).

# Requisitos y Conexión

IDE: Visual Studio 2022 con la extensión SQL Server Integration Services Projects 2022+.

Motor BD: SQL Server Management Studio (SSMS) 2019 / 2022 / 2025 (Driver MSOLEDBSQL / OLE DB Provider).

Autenticación: Autenticación Integrada de Windows local (HP\Usuario / sesión activa). Cadenas de conexión OLE DB configuradas en los administradores: CM_Origen, CM_Staging y CM_DWNEW.

# Pasos para Ejecutar en tu PC

Instalación de Bases de Datos:
En caso de estar en una instancia nueva, ejecuta en SSMS los scripts de la carpeta SQL en el siguiente orden estricto:

SQL/01_Origen_LigasdeAscenso.sql

SQL/02_Staging_Ligas.sql

SQL/03_DW_ligasdeAscenso_new.sql

Configuración de Parámetros:
Abre la solución ETL_LigasAscenso.slnx en Visual Studio. Verifica en Project.params que los nombres de servidor apunten a tu instancia local ((local) o localhost) y que los nombres de las tres bases coincidan:

BaseOrigen = LigasdeAscenso

BaseStaging = Staging_Ligas

BaseDW = DW_LigasdeAscenso

#Ejecución del Paquete SSIS:
Abre y ejecuta Package.dtsx en modo depuración (F5). El paquete ejecutará en orden de precedencia:

Fase 1: Limpieza y preparación de las tablas de staging y de hechos (Preparar staging / Liberar staging).

Fase 2: Extracción transaccional y carga hacia Staging_Ligas (Extraer Partidos, Extraer Boletos, Extraer Asistencia).

Fase 3: Carga secuencial de las seis dimensiones en DW_LigasdeAscenso.

Fase 4: ExecSQL de carga final para FactVentas y FactAsistencia.

Validación de Resultados e Idempotencia:
Abre SSMS y ejecuta el script SQL_ETL/Verificar_ETL.sql. El script realiza una consulta UNION ALL para verificar la paridad entre las filas agregadas en staging y los hechos/dimensiones poblados en el DW. Puedes volver a ejecutar el paquete SSIS cuantas veces requieras para validar que los totales monetarios y de boletos se mantengan constantes.
