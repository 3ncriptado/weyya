# Way Delivery

Este repositorio contiene la especificacion del proyecto en espanol para una aplicacion de reparto de comida integrada con lb-phone para FiveM.

Crear un recurso para FiveM (ESX) compatible con lb-phone que implemente una app de delivery de comida llamada "Way Delivery", con las siguientes características técnicas:

1. Estructura de la App:
   - La app debe agregarse a lb-phone como una Custom App con interfaz UI (`ui = "resource/ui/index.html"`).
   - El sistema debe contar con 3 interfaces distintas según el tipo de usuario:
     a) Cliente (jugador que pide comida)
     b) Negocio (restaurante)
     c) Repartidor (trabajo de delivery)

2. Funcionalidad para el Cliente:
   - Puede ver una lista de negocios disponibles (por categoría o tipo de comida).
   - Puede ver el menú del negocio, seleccionar productos y agregarlos a un carrito.
   - Al confirmar el pedido, se realiza una solicitud al negocio.
   - Se genera una orden en espera de confirmación por parte del negocio.
   - Al momento de recibir el pedido físicamente en el juego, el usuario abre la app y presiona “Pagar”.
   - El sistema descuenta el dinero del jugador:
     - Una parte va al negocio (según precio de artículos).
     - Otra parte va al delivery (porcentaje configurado, ej. 30%).

3. Funcionalidad para el Negocio:
   - Tiene acceso a una vista administrativa (modo dueño de negocio).
   - Recibe notificaciones de pedidos pendientes.
   - Puede aceptar o rechazar pedidos.
   - Al aceptar un pedido, queda en “preparación”.
   - Cuando el pedido esté listo, puede presionar “Enviar a delivery”.
   - El pedido queda disponible para que un delivery lo recoja.

4. Funcionalidad para el Delivery:
   - Puede ver una lista de pedidos disponibles para recoger.
   - Al aceptar un pedido, se le muestra la ubicación del negocio.
   - Luego de recoger, se le indica la ubicación del cliente.
   - Al entregar, el cliente debe confirmar y pagar desde la app.
   - Al confirmarse el pago, se le entrega la comisión al delivery automáticamente.

5. Backend / Servidor:
   - Debe manejar la lógica de pedidos (creación, estado, asignación).
   - Tablas MySQL:
     - `way_orders`: id, user_id, items, total, estado (pendiente, aceptado, enviado, entregado), negocio_id, delivery_id, ubicación_cliente, timestamps.
     - `way_business`: id, nombre, menú, dueño_id
     - `way_delivery_jobs`: id, delivery_id, estado, orden_id, timestamps

6. Consideraciones:
   - Sistema de notificaciones interno (UI del LB Phone).
   - Validación de fondos al momento de pagar.
   - Configuración de porcentajes de comisión para delivery/negocio.
   - Control de acceso por tipo de usuario (clientes, dueños de negocio, deliverys).
   - Estética adaptada al estilo LB Phone (modo oscuro, colores tailwind, responsivo).

Objetivo: un sistema funcional e inmersivo de pedidos y entregas que funcione completamente dentro del teléfono del jugador con lógica de negocios, logística y economía integrada, sin uso de comandos externos o interacción fuera del teléfono.
