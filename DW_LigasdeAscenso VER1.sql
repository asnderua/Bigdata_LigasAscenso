CREATE DATABASE DW_LigasAscenso;
GO

USE DW_LigasAscenso;
GO

-- 1. Capa de Staging (Tabla intermedia para recibir los datos planos o en bruto)
IF OBJECT_ID('dbo.stg_ligas_ascenso', 'U') IS NOT NULL DROP TABLE dbo.stg_ligas_ascenso;
CREATE TABLE dbo.stg_ligas_ascenso (
    Fecha DATE NULL,
    ID_PartidoOrigen INT NULL,
    NombreCompeticion VARCHAR(50) NULL,
    NombreEtapa VARCHAR(50) NULL,
    NivelCompeticion VARCHAR(30) NULL,
    EquipoLocal VARCHAR(100) NULL,
    EquipoVisitante VARCHAR(100) NULL,
    EstadoPartido VARCHAR(30) NULL,
    NombreEstadio VARCHAR(100) NULL,
    CategoriaEstadio VARCHAR(20) NULL,
    MaxAforo INT NULL,
    NombreZona VARCHAR(50) NULL,
    CanalVenta VARCHAR(30) NULL,
    MetodoPago VARCHAR(30) NULL,
    Departamento VARCHAR(50) NULL,
    Provincia VARCHAR(50) NULL,
    Distrito VARCHAR(50) NULL,
    Region VARCHAR(20) NULL,
    CantidadBoletosVendidos INT NULL,
    MontoIngresoTotal DECIMAL(12, 2) NULL,
    PrecioPromedioBoletos DECIMAL(10, 2) NULL
);
GO

-- 2. Dimensión Tiempo
IF OBJECT_ID('dbo.Dim_Tiempo', 'U') IS NOT NULL DROP TABLE dbo.Dim_Tiempo;
CREATE TABLE dbo.Dim_Tiempo (
    ID_Tiempo INT NOT NULL,
    Fecha DATE NOT NULL,
    Anio INT NOT NULL,
    Mes INT NOT NULL,
    NombreMes VARCHAR(20) NOT NULL,
    Dia INT NOT NULL,
    DiaSemana VARCHAR(20) NOT NULL,
    Hora INT NOT NULL,
    RangoHorario VARCHAR(20) NOT NULL,
    CONSTRAINT PK_Dim_Tiempo PRIMARY KEY CLUSTERED (ID_Tiempo)
);

-- 3. Dimensión Partido
IF OBJECT_ID('dbo.Dim_Partido', 'U') IS NOT NULL DROP TABLE dbo.Dim_Partido;
CREATE TABLE dbo.Dim_Partido (
    ID_Partido INT IDENTITY(1,1) NOT NULL,
    NombreCompeticion VARCHAR(50) NOT NULL, 
    NombreEtapa VARCHAR(50) NOT NULL,        
    NivelCompeticion VARCHAR(30) NOT NULL,   
    EquipoLocal VARCHAR(100) NOT NULL,
    EquipoVisitante VARCHAR(100) NOT NULL,
    EstadoPartido VARCHAR(30) NOT NULL,      
    CONSTRAINT PK_Dim_Partido PRIMARY KEY CLUSTERED (ID_Partido)
);

-- 4. Dimensión Estadio
IF OBJECT_ID('dbo.Dim_Estadio', 'U') IS NOT NULL DROP TABLE dbo.Dim_Estadio;
CREATE TABLE dbo.Dim_Estadio (
    ID_Estadio INT IDENTITY(1,1) NOT NULL,
    NombreEstadio VARCHAR(100) NOT NULL,
    CategoriaEstadio VARCHAR(20) NOT NULL,   
    MaxAforo INT NOT NULL,
    CONSTRAINT PK_Dim_Estadio PRIMARY KEY CLUSTERED (ID_Estadio)
);

-- 5. Dimensión Tipo Entrada
IF OBJECT_ID('dbo.Dim_TipoEntrada', 'U') IS NOT NULL DROP TABLE dbo.Dim_TipoEntrada;
CREATE TABLE dbo.Dim_TipoEntrada (
    ID_TipoEntrada INT IDENTITY(1,1) NOT NULL,
    NombreZona VARCHAR(50) NOT NULL,         
    CanalVenta VARCHAR(30) NOT NULL,         
    MetodoPago VARCHAR(30) NOT NULL,         
    CONSTRAINT PK_Dim_TipoEntrada PRIMARY KEY CLUSTERED (ID_TipoEntrada)
);

-- 6. Dimensión Ubicación
IF OBJECT_ID('dbo.Dim_Ubicacion', 'U') IS NOT NULL DROP TABLE dbo.Dim_Ubicacion;
CREATE TABLE dbo.Dim_Ubicacion (
    ID_Ubicacion INT IDENTITY(1,1) NOT NULL,
    Departamento VARCHAR(50) NOT NULL,
    Provincia VARCHAR(50) NOT NULL,
    Distrito VARCHAR(50) NOT NULL,
    Region VARCHAR(20) NOT NULL,             
    CONSTRAINT PK_Dim_Ubicacion PRIMARY KEY CLUSTERED (ID_Ubicacion)
);
GO

-- 7. Tabla de Hechos (Fact Table)
IF OBJECT_ID('dbo.Fact_VentasTaquilla', 'U') IS NOT NULL DROP TABLE dbo.Fact_VentasTaquilla;
CREATE TABLE dbo.Fact_VentasTaquilla (
    ID_Tiempo INT NOT NULL,
    ID_Partido INT NOT NULL,
    ID_Estadio INT NOT NULL,
    ID_TipoEntrada INT NOT NULL,
    ID_Ubicacion INT NOT NULL,
    
    CantidadBoletosVendidos INT NOT NULL,
    MontoIngresoTotal DECIMAL(12, 2) NOT NULL,
    PrecioPromedioBoletos DECIMAL(10, 2) NOT NULL,

    CONSTRAINT FK_Fact_Tiempo FOREIGN KEY (ID_Tiempo) 
        REFERENCES dbo.Dim_Tiempo (ID_Tiempo),
    CONSTRAINT FK_Fact_Partido FOREIGN KEY (ID_Partido) 
        REFERENCES dbo.Dim_Partido (ID_Partido),
    CONSTRAINT FK_Fact_Estadio FOREIGN KEY (ID_Estadio) 
        REFERENCES dbo.Dim_Estadio (ID_Estadio),
    CONSTRAINT FK_Fact_TipoEntrada FOREIGN KEY (ID_TipoEntrada) 
        REFERENCES dbo.Dim_TipoEntrada (ID_TipoEntrada),
    CONSTRAINT FK_Fact_Ubicacion FOREIGN KEY (ID_Ubicacion) 
        REFERENCES dbo.Dim_Ubicacion (ID_Ubicacion)
);
GO