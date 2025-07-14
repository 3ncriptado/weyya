local ESX

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local commission = 0.3 -- 30% to delivery

local pendingOrders = {}

MySQL.ready(function()
    MySQL.query([[CREATE TABLE IF NOT EXISTS way_business (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nombre VARCHAR(50),
        menu LONGTEXT,
        dueno_id VARCHAR(60)
    )]])

    MySQL.query([[CREATE TABLE IF NOT EXISTS way_orders (
        id INT AUTO_INCREMENT PRIMARY KEY,
        user_id VARCHAR(60),
        items LONGTEXT,
        total INT,
        estado VARCHAR(20),
        negocio_id INT,
        delivery_id VARCHAR(60),
        ubicacion_cliente LONGTEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )]])

    MySQL.query([[CREATE TABLE IF NOT EXISTS way_delivery_jobs (
        id INT AUTO_INCREMENT PRIMARY KEY,
        delivery_id VARCHAR(60),
        estado VARCHAR(20),
        orden_id INT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )]])
end)

-- Helper to send phone notifications
local function notify(src, title, msg)
    TriggerClientEvent('lb-phone:notify', src, {
        title = title,
        message = msg,
        icon = 'fas fa-hamburger',
        duration = 5000
    })
end

-- Client requests list of businesses
ESX.RegisterServerCallback('way:getBusinesses', function(source, cb)
    MySQL.query('SELECT id, nombre, menu FROM way_business', {}, function(res)
        cb(res)
    end)
end)

-- Client creates an order
RegisterNetEvent('way:createOrder', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    local negocio = data.negocio
    local items = data.items
    local total = data.total
    MySQL.insert('INSERT INTO way_orders (user_id, items, total, estado, negocio_id, ubicacion_cliente) VALUES (?, ?, ?, "pendiente", ?, ?)',
        {xPlayer.identifier, json.encode(items), total, negocio, json.encode(data.location)}, function(id)
            notify(src, 'Way Delivery', 'Pedido enviado al negocio')
            TriggerClientEvent('way:orderCreated', src, {id = id})
            TriggerClientEvent('way:newOrder', -1, {id = id, negocio = negocio}) -- notify business
        end)
end)

-- Business accepts order
RegisterNetEvent('way:acceptOrder', function(id)
    MySQL.update('UPDATE way_orders SET estado="aceptado" WHERE id=?', {id})
    TriggerClientEvent('way:orderAccepted', -1, id)
end)

-- Order ready for delivery
RegisterNetEvent('way:readyOrder', function(id)
    MySQL.update('UPDATE way_orders SET estado="enviado" WHERE id=?', {id})
    TriggerClientEvent('way:orderReady', -1, id)
end)

-- Delivery takes order
RegisterNetEvent('way:takeOrder', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    MySQL.update('UPDATE way_orders SET delivery_id=?, estado="en_camino" WHERE id=? AND (delivery_id IS NULL OR delivery_id="")', {xPlayer.identifier, id}, function(rows)
        if rows and rows > 0 then
            notify(src, 'Way Delivery', 'Has tomado la orden #'..id)
            TriggerClientEvent('way:orderTaken', -1, id)
        else
            notify(src, 'Way Delivery', 'La orden ya fue tomada')
        end
    end)
end)

-- Customer pays and completes order
RegisterNetEvent('way:payOrder', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    MySQL.single('SELECT total, negocio_id, delivery_id FROM way_orders WHERE id=?', {id}, function(order)
        if not order then return end
        if xPlayer.getMoney() < order.total then
            notify(src, 'Way Delivery', 'Fondos insuficientes')
            return
        end
        xPlayer.removeMoney(order.total)
        local businessShare = math.floor(order.total * (1.0 - commission))
        local deliveryShare = order.total - businessShare
        if order.negocio_id then
            local bus
            MySQL.single('SELECT dueno_id FROM way_business WHERE id=?', {order.negocio_id}, function(b)
                bus = b
                if bus and bus.dueno_id then
                    local owner = ESX.GetPlayerFromIdentifier(bus.dueno_id)
                    if owner then owner.addMoney(businessShare) end
                end
            end)
        end
        if order.delivery_id then
            local del = ESX.GetPlayerFromIdentifier(order.delivery_id)
            if del then del.addMoney(deliveryShare) end
        end
        MySQL.update('UPDATE way_orders SET estado="entregado" WHERE id=?', {id})
        notify(src, 'Way Delivery', 'Has pagado la orden #'..id)
    end)
end)

