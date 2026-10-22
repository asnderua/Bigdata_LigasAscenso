1. Crear la Base de Datos Origen:
Ejecuta el script SQL correspondiente para generar y poblar la base de datos transaccional inicial.

2. Crear el Data Warehouse:
Ejecuta el script DDL para generar la base de datos de destino (DW_LigasAscenso), incluyendo sus tablas y esquema.

3. Configurar Usuarios:
Crea y asigna los permisos necesarios a los usuarios de base de datos para asegurar el acceso tanto al origen como al DW.

4. Configurar Visual Studio (SSIS):
Abre el proyecto de Integration Services y actualiza los administradores de conexiones (Origen y Destino) para que apunten a tus bases de datos locales.

5. Preparar Limpieza de Datos:
Configura la tarea Ejecutar SQL al inicio del Flujo de Control para limpiar las tablas antes de cada ejecución, evitando así registros duplicados.

6. Cargar la Capa Staging:
Configura el flujo de datos para extraer la información, agruparla y cargarla en la tabla temporal de prueba (stg_ligas_ascenso).

7. Alimentar las Dimensiones:
Una vez cargada la capa staging, configura y ejecuta las 5 tareas de flujo de datos que alimentarán el modelo: DIM_Tiempo, DIM_Partido, DIM_Ubicacion, DIM_Estadio y DIM_TipodeEntrada.

8. Cargar la Tabla de Hechos:
Configura la tarea final que toma los datos preparados en staging, los cruza con las dimensiones y carga la información consolidada en el DW.

9. Ejecutar Paquetes y Documentar:
Inicia la ejecución del paquete SSIS completo. Revisa la pestaña de progreso y registra las capturas/evidencias para validar que la carga fue exitosa.
