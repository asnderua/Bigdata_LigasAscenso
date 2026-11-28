 CREATE DATABASE Staging_Ligas;
GO

-- Paso 3: Seleccionar la base Staging
USE Staging_Ligas;
GO

-- Paso 4: Crear las tablas intermedias (si no existen)
IF OBJECT_ID(N'dbo.stg_Partidos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.stg_Partidos (
        IDPartidoOrigen INT NOT NULL PRIMARY KEY,
        IDTemporadaOrigen INT NOT NULL,
        AnioTemporada INT NOT NULL,
        FechaInicioTemporada DATE NOT NULL,
        FechaFinTemporada DATE NOT NULL,
        IDEtapaOrigen INT NOT NULL,
        IDCompeticionOrigen INT NOT NULL,
        NombreCompeticion VARCHAR(50) NOT NULL,
        Organizador VARCHAR(50) NOT NULL,
        NivelCompeticion VARCHAR(50) NOT NULL,
        NombreEtapa VARCHAR(50) NOT NULL,
        NivelEtapa INT NOT NULL,
        FactorPrecio DECIMAL(10,2) NOT NULL,
        IDEstadioOrigen INT NOT NULL,
        NombreEstadio VARCHAR(100) NOT NULL,
        DepartamentoEstadio VARCHAR(50) NOT NULL,
        ProvinciaEstadio VARCHAR(50) NOT NULL,
        DistritoEstadio VARCHAR(50) NOT NULL,
        RegionEstadio VARCHAR(50) NOT NULL,
        CategoriaEstadio VARCHAR(50) NOT NULL,
        MaxAforo INT NOT NULL,
        IDClubLocalOrigen INT NOT NULL,
        NombreClubLocal VARCHAR(100) NOT NULL,
        DepartamentoClubLocal VARCHAR(50) NOT NULL,
        ProvinciaClubLocal VARCHAR(50) NOT NULL,
        AnioFundacionLocal INT NULL,
        IDClubVisitaOrigen INT NOT NULL,
        NombreClubVisita VARCHAR(100) NOT NULL,
        DepartamentoClubVisita VARCHAR(50) NOT NULL,
        ProvinciaClubVisita VARCHAR(50) NOT NULL,
        AnioFundacionVisita INT NULL,
        FechaHoraPartido DATETIME2(0) NOT NULL,
        Jornada INT NULL,
        EstadoPartido VARCHAR(20) NOT NULL
    );
END;
GO
IF OBJECT_ID(N'dbo.stg_Boletos', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.stg_Boletos (
        IDBoletoOrigen INT NOT NULL PRIMARY KEY,
        IDPartidoOrigen INT NOT NULL,
        IDTipoEntradaOrigen INT NOT NULL,
        NombreTipoEntrada VARCHAR(50) NOT NULL,
        PrecioBase DECIMAL(10,2) NOT NULL,
        FechaVenta DATETIME2(0) NULL,
        CanalVenta VARCHAR(50) NOT NULL,
        MetodoPago VARCHAR(50) NOT NULL,
        EstadoPago VARCHAR(50) NOT NULL,
        PrecioPagado DECIMAL(10,2) NULL
    );
END;
GO
IF OBJECT_ID(N'dbo.stg_Asistencia', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.stg_Asistencia (
        IDPartidoOrigen INT NOT NULL PRIMARY KEY,
        AsistenciaRegistrada INT NULL,
        AforoEstadio INT NULL
    );
END;
GO

-- Paso 5: Verificar las tablas creadas
SELECT TABLE_NAME AS TablaStaging
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_TYPE = 'BASE TABLE'
  AND TABLE_NAME IN ('stg_Partidos', 'stg_Boletos', 'stg_Asistencia')
ORDER BY TABLE_NAME;
GO