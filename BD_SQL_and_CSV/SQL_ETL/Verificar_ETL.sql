USE [DW_LigasdeAscenso];
GO

-- Con los datos de prueba originales, los resultados son 16 y 14.
SELECT 'FactVentas' AS Tabla, COUNT_BIG(*) AS Filas, 16 AS Esperadas
FROM dbo.FactVentas
UNION ALL
SELECT 'FactAsistencia', COUNT_BIG(*), 14
FROM dbo.FactAsistencia;

-- Esperados: 14 partidos, 11 con asistencia, 16 boletos pagados,
-- S/ 485.00 de ingresos y 41400 asistentes.
SELECT COUNT_BIG(*) AS Partidos,
       COUNT_BIG(AsistenciaRegistrada) AS PartidosConAsistencia,
       SUM(BoletosVendidos) AS BoletosVendidos,
       SUM(IngresosTaquilla) AS IngresosTaquilla,
       SUM(CONVERT(bigint, AsistenciaRegistrada)) AS AsistenciaRegistrada
FROM dbo.vw_KPI_PorPartido;

-- Debe devolver cero filas. La PK de asistencia impide duplicados por partido.
SELECT IDPartido
FROM dbo.FactVentas
EXCEPT
SELECT IDPartido
FROM dbo.FactAsistencia;

SELECT * FROM dbo.vw_KPI_PorPartido ORDER BY IDPartido;
