# ETL de Ligas de Ascenso

Este proyecto carga seis dimensiones y dos tablas de hechos en `DW_LigasdeAscenso`. `FactVentas` contiene una fila por partido y tipo de entrada con ventas pagadas. `FactAsistencia` contiene una fila por partido y admite medidas nulas cuando todavía no hay registro. `dbo.vw_KPI_PorPartido` agrega las ventas antes de combinarlas con la asistencia.

## Ejecutar en tu PC

1. Abre `ETL_LigasAscenso.slnx` con Visual Studio y la extensión **SQL Server Integration Services Projects 2022+**. El proyecto apunta a SQL Server 2025 y usa el controlador OLE DB 18 de 64 bits (`MSOLEDBSQL)). [Extensión para Visual Studio](https://marketplace.visualstudio.com/items?itemName=SSIS.MicrosoftDataToolsIntegrationServices)
2. En `Project.params`, configura `ServidorOrigen` y `ServidorDWStaging` con los nombres de instancia que funcionan en SSMS. Los valores de base esperados son `BaseOrigen=LigasdeAscenso`, `BaseStaging=Staging_Ligas` y `BaseDW=DW_LigasdeAscenso`. Staging y DW deben compartir instancia. La conexión `CM_DWNEW` usa autenticación integrada de Windows y conserva la sesión entre las tareas de carga.
3. Ejecuta `Package.dtsx` completo. El paquete vuelve a llenar las tres tablas de staging, carga las seis dimensiones y ejecuta **Cargar FactVentas** y **Cargar FactAsistencia**. Las cargas del DW se confirman juntas al finalizar la segunda FACT.
4. En SSMS, ejecuta `SQL_ETL/Verificar_ETL.sql`. Con los datos originales de ejemplo se esperan 16 filas de ventas, 14 filas de asistencia, 16 boletos pagados, S/ 485,00 y 41 400 asistentes registrados. Repite el paquete para comprobar que los totales se mantengan.

## Instalar las bases en otra PC

En una instancia de prueba nueva, ejecuta los scripts de la carpeta `SQL` en orden: `01_Origen_LigasdeAscenso.sql`, `02_Staging_Ligas.sql` y `03_DW_ligasdeAscenso_new.sql`. Para una prueba con una instancia ya configurada, usa las tres bases existentes de este proyecto. El DW debe tener `dbo.FactVentas` y `dbo.FactAsistencia` antes de ejecutar el paquete. El motor debe admitir una intercalación de página de códigos 1252 en las columnas VARCHAR de origen y staging. Ejecuta Visual Studio con una cuenta autorizada a leer origen y staging, escribir staging y cargar el DW.

## SQL del ETL

Los archivos `Extraer_*.sql` reproducen las consultas de extracción. `SQL_ETL/Cargar_DW.sql` contiene la carga de ambas FACT y de las seis dimensiones desde staging en una sola transacción. Úsalo solo si necesitas probar manualmente la fase DW después de llenar staging. El archivo `SQL_ETL/Verificar_ETL.sql` solo consulta resultados. Los comandos normales de carga ya están dentro del paquete SSIS.
