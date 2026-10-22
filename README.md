1. Crear la Base de Datos Origen:
Ejecuta el script SQL correspondiente para generar y poblar la base de datos transaccional inicial.

2. Crear el Data Warehouse:
Ejecuta el script DDL para generar la base de datos de destino (DW_LigasAscenso), incluyendo sus tablas y esquema.

4. Configurar Usuarios:
Crea y asigna los permisos necesarios a los usuarios de base de datos para asegurar el acceso tanto al origen como al DW.

5. Configurar Visual Studio (SSIS):
Abre el proyecto de Integration Services y actualiza los administradores de conexiones (Origen y Destino) para que apunten a tus bases de datos locales.

6. Cargar la Capa Staging:
Configura el flujo de datos para extraer la información, agruparla y cargarla en la tabla temporal de prueba (stg_ligas_ascenso).




