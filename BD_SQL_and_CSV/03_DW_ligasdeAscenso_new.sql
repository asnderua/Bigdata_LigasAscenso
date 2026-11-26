
CREATE DATABASE DW_LigasdeAscenso 
GO
USE DW_LigasdeAscenso
GO

-- 1. DIMENSIONES (compatibles con el script DW anterior)
IF OBJECT_ID(N'dbo.DimTiempo', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimTiempo (
        IDTiempo INT NOT NULL PRIMARY KEY,  -- YYYYMMDD
        Fecha DATE NOT NULL UNIQUE,
        Anio SMALLINT NOT NULL,
        Mes TINYINT NOT NULL,
        NombreMes NVARCHAR(20) NOT NULL,
        Dia TINYINT NOT NULL,
        DiaSemana TINYINT NOT NULL,
        NombreDiaSemana NVARCHAR(20) NOT NULL,
        EsFinDeSemana BIT NOT NULL,
        CONSTRAINT CK_DimTiempo_Mes CHECK (Mes BETWEEN 1 AND 12),
        CONSTRAINT CK_DimTiempo_Dia CHECK (Dia BETWEEN 1 AND 31),
        CONSTRAINT CK_DimTiempo_DiaSemana CHECK (DiaSemana BETWEEN 1 AND 7)
    );
END;
GO
IF OBJECT_ID(N'dbo.DimTemporada', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimTemporada (
        IDTemporada INT NOT NULL PRIMARY KEY,
        Anio INT NOT NULL,
        FechaInicio DATE NOT NULL,
        FechaFinal DATE NOT NULL,
        CONSTRAINT CK_DimTemporada_Fechas CHECK (FechaFinal >= FechaInicio)
    );
END;
GO
IF OBJECT_ID(N'dbo.DimEstadio', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimEstadio (
        IDEstadio INT NOT NULL PRIMARY KEY,
        NombreEstadio VARCHAR(100) NOT NULL,
        Departamento VARCHAR(50) NOT NULL,
        Provincia VARCHAR(50) NOT NULL,
        Distrito VARCHAR(50) NOT NULL,
        Region VARCHAR(50) NOT NULL,
        Categoria VARCHAR(50) NOT NULL,
        MaxAforo INT NOT NULL,
        CONSTRAINT CK_DimEstadio_Aforo CHECK (MaxAforo > 0)
    );
END;
GO
IF OBJECT_ID(N'dbo.DimCompeticion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimCompeticion (
        IDEtapa INT NOT NULL PRIMARY KEY,
        IDCompeticionOrigen INT NOT NULL,
        NombreCompeticion VARCHAR(50) NOT NULL,
        Organizador VARCHAR(50) NOT NULL,
        NivelCompeticion VARCHAR(50) NOT NULL,
        NombreEtapa VARCHAR(50) NOT NULL,
        NivelEtapa INT NOT NULL,
        FactorPrecio DECIMAL(10,2) NOT NULL,
        CONSTRAINT CK_DimCompeticion_Factor CHECK (FactorPrecio >= 0)
    );
END;
GO
IF OBJECT_ID(N'dbo.DimTipoEntrada', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimTipoEntrada (
        IDTipoEntrada INT NOT NULL PRIMARY KEY,
        NombreTE VARCHAR(50) NOT NULL,
        PrecioBase DECIMAL(10,2) NOT NULL,
        CONSTRAINT CK_DimTipoEntrada_Precio CHECK (PrecioBase >= 0)
    );
END;
GO
IF OBJECT_ID(N'dbo.DimClub', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimClub (
        IDClub INT NOT NULL PRIMARY KEY,
        NombreClub VARCHAR(100) NOT NULL,
        Departamento VARCHAR(50) NOT NULL,
        Provincia VARCHAR(50) NOT NULL,
        AnioFundacion INT NULL
    );
END;
GO

-- Granularidad de ventas: partido y tipo de entrada con pagos confirmados.
CREATE TABLE dbo.FactVentas (
    IDPartido INT NOT NULL,
    IDTipoEntrada INT NOT NULL,
    IDTiempoPartido INT NOT NULL,
    IDTemporada INT NOT NULL,
    IDEstadio INT NOT NULL,
    IDEtapa INT NOT NULL,
    IDClubLocal INT NOT NULL,
    IDClubVisita INT NOT NULL,
    BoletosVendidos INT NOT NULL,
    IngresosTaquilla DECIMAL(18,2) NOT NULL,
    PrecioPromedioEntrada AS
        CONVERT(decimal(18,2), IngresosTaquilla / NULLIF(BoletosVendidos, 0)) PERSISTED,
    CONSTRAINT PK_FactVentas PRIMARY KEY (IDPartido, IDTipoEntrada),
    CONSTRAINT FK_FV_TipoEntrada FOREIGN KEY (IDTipoEntrada) REFERENCES dbo.DimTipoEntrada(IDTipoEntrada),
    CONSTRAINT FK_FV_Tiempo FOREIGN KEY (IDTiempoPartido) REFERENCES dbo.DimTiempo(IDTiempo),
    CONSTRAINT FK_FV_Temporada FOREIGN KEY (IDTemporada) REFERENCES dbo.DimTemporada(IDTemporada),
    CONSTRAINT FK_FV_Estadio FOREIGN KEY (IDEstadio) REFERENCES dbo.DimEstadio(IDEstadio),
    CONSTRAINT FK_FV_Competicion FOREIGN KEY (IDEtapa) REFERENCES dbo.DimCompeticion(IDEtapa),
    CONSTRAINT FK_FV_ClubLocal FOREIGN KEY (IDClubLocal) REFERENCES dbo.DimClub(IDClub),
    CONSTRAINT FK_FV_ClubVisita FOREIGN KEY (IDClubVisita) REFERENCES dbo.DimClub(IDClub),
    CONSTRAINT CK_FV_Medidas CHECK (BoletosVendidos > 0 AND IngresosTaquilla >= 0)
);
GO

-- Granularidad de asistencia: un partido. Los nulos indican medidas sin registro.
CREATE TABLE dbo.FactAsistencia (
    IDPartido INT NOT NULL,
    IDTiempoPartido INT NOT NULL,
    IDTemporada INT NOT NULL,
    IDEstadio INT NOT NULL,
    IDEtapa INT NOT NULL,
    IDClubLocal INT NOT NULL,
    IDClubVisita INT NOT NULL,
    EstadoPartido VARCHAR(20) NOT NULL,
    AsistenciaRegistrada INT NULL,
    AforoEstadio INT NULL,
    PorcentajeOcupacion AS CONVERT(decimal(7,2), 
    (CONVERT(decimal(18,4), AsistenciaRegistrada) * 100.0) / NULLIF(AforoEstadio, 0)) PERSISTED,
    CONSTRAINT PK_FactAsistencia PRIMARY KEY (IDPartido),
    CONSTRAINT FK_FA_Tiempo FOREIGN KEY (IDTiempoPartido) REFERENCES dbo.DimTiempo(IDTiempo),
    CONSTRAINT FK_FA_Temporada FOREIGN KEY (IDTemporada) REFERENCES dbo.DimTemporada(IDTemporada),
    CONSTRAINT FK_FA_Estadio FOREIGN KEY (IDEstadio) REFERENCES dbo.DimEstadio(IDEstadio),
    CONSTRAINT FK_FA_Competicion FOREIGN KEY (IDEtapa) REFERENCES dbo.DimCompeticion(IDEtapa),
    CONSTRAINT FK_FA_ClubLocal FOREIGN KEY (IDClubLocal) REFERENCES dbo.DimClub(IDClub),
    CONSTRAINT FK_FA_ClubVisita FOREIGN KEY (IDClubVisita) REFERENCES dbo.DimClub(IDClub),
    CONSTRAINT CK_FA_Medidas CHECK (
        (AsistenciaRegistrada IS NULL OR AsistenciaRegistrada >= 0)
        AND (AforoEstadio IS NULL OR AforoEstadio >= 0)
        AND (AsistenciaRegistrada IS NULL OR AforoEstadio IS NULL OR AsistenciaRegistrada <= AforoEstadio)
    )
);
GO

-- Se agregan las ventas por partido antes de combinarlas con asistencia.
CREATE OR ALTER VIEW dbo.vw_KPI_PorPartido AS
WITH VentasPorPartido AS (
    SELECT IDPartido, SUM(CONVERT(bigint, BoletosVendidos)) AS BoletosVendidos,
           SUM(IngresosTaquilla) AS IngresosTaquilla
    FROM dbo.FactVentas
    GROUP BY IDPartido
)
SELECT a.IDPartido, a.IDTiempoPartido, a.IDTemporada, a.IDEstadio, a.IDEtapa,
       a.IDClubLocal, a.IDClubVisita, a.EstadoPartido,
       COALESCE(v.BoletosVendidos, CONVERT(bigint, 0)) AS BoletosVendidos,
       COALESCE(v.IngresosTaquilla, CONVERT(decimal(38,2), 0)) AS IngresosTaquilla,
       a.AsistenciaRegistrada, a.AforoEstadio,
       CONVERT(decimal(18,2), v.IngresosTaquilla / NULLIF(v.BoletosVendidos, 0)) AS PrecioPromedioEntrada,
       a.PorcentajeOcupacion
FROM dbo.FactAsistencia AS a
LEFT JOIN VentasPorPartido AS v ON v.IDPartido = a.IDPartido;
GO
