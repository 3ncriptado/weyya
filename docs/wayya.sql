CREATE TABLE IF NOT EXISTS wayya (
    id INT AUTO_INCREMENT PRIMARY KEY,
    -- Tipo de registro: 'business', 'order' o 'delivery_job'
    record_type ENUM('business','order','delivery_job') NOT NULL,

    -- Datos del negocio
    nombre VARCHAR(50) NULL,
    menu LONGTEXT NULL,
    dueno_id VARCHAR(60) NULL,
    ubicacion_negocio LONGTEXT NULL,

    -- Datos de la orden
    user_id VARCHAR(60) NULL,
    items LONGTEXT NULL,
    total INT NULL,
    estado VARCHAR(20) NULL,
    negocio_id INT NULL,
    delivery_id VARCHAR(60) NULL,
    ubicacion_cliente LONGTEXT NULL,

    -- Datos de trabajos de delivery
    orden_id INT NULL,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
