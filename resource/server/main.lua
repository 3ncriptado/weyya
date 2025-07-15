local ESX

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local commission = 0.3 -- 30% to delivery


MySQL.ready(function()
    MySQL.query([[CREATE TABLE IF NOT EXISTS wayya (
        id INT AUTO_INCREMENT PRIMARY KEY,
        record_type ENUM('business','order','delivery_job') NOT NULL,
        nombre VARCHAR(50) NULL,
        menu LONGTEXT NULL,
        dueno_id VARCHAR(60) NULL,
        ubicacion_negocio LONGTEXT NULL,
        user_id VARCHAR(60) NULL,
        items LONGTEXT NULL,
        total INT NULL,
        estado VARCHAR(20) NULL,
        negocio_id INT NULL,
        delivery_id VARCHAR(60) NULL,
        ubicacion_cliente LONGTEXT NULL,
        orden_id INT NULL,
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
    MySQL.query('SELECT id, nombre, menu FROM wayya WHERE record_type="business"', {}, function(res)
        cb(res)
    end)
end)

-- Get menu for a single business
ESX.RegisterServerCallback('way:getBusinessMenu', function(source, cb, id)
    MySQL.single('SELECT menu FROM wayya WHERE id = ? AND record_type="business"', { id }, function(row)
        if row and row.menu then
            local ok, data = pcall(json.decode, row.menu)
            if ok and data then
                cb(data)
            else
                cb({})
            end
        else
            cb({})
        end
    end)
end)

-- Orders belonging to the business owner requesting them
ESX.RegisterServerCallback('way:getBusinessOrders', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    MySQL.single('SELECT id FROM wayya WHERE dueno_id=? AND record_type="business"', {xPlayer.identifier}, function(bus)
        if not bus then return cb({}) end
        MySQL.query('SELECT id, total FROM wayya WHERE record_type="order" AND negocio_id=? AND estado IN ("pendiente","aceptado","enviado")', {bus.id}, function(res)
            cb(res or {})
        end)
    end)
end)

-- Orders available for delivery job
ESX.RegisterServerCallback('way:getAvailableOrders', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.job.name ~= 'delivery' then return cb({}) end
    MySQL.query('SELECT id, total FROM wayya WHERE record_type="order" AND estado="enviado" AND (delivery_id IS NULL OR delivery_id="")', {}, function(res)
        cb(res or {})
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
    MySQL.insert('INSERT INTO wayya (record_type, user_id, items, total, estado, negocio_id, ubicacion_cliente) VALUES ("order", ?, ?, ?, "pendiente", ?, ?)',
        {xPlayer.identifier, json.encode(items), total, negocio, json.encode(data.location)}, function(id)
            notify(src, 'Way Delivery', 'Pedido enviado al negocio')
            TriggerClientEvent('way:orderCreated', src, {id = id})
            TriggerClientEvent('way:newOrder', -1, {id = id, negocio = negocio}) -- notify business
        end)
end)

-- Business accepts order
RegisterNetEvent('way:acceptOrder', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    MySQL.single('SELECT negocio_id FROM wayya WHERE id=? AND record_type="order"', {id}, function(order)
        if not order then return end
        MySQL.single('SELECT id FROM wayya WHERE id=? AND dueno_id=? AND record_type="business"', {order.negocio_id, xPlayer.identifier}, function(b)
            if not b then
                notify(src, 'Way Delivery', 'No tienes permiso para esa orden')
                return
            end
            MySQL.update('UPDATE wayya SET estado="aceptado" WHERE id=? AND record_type="order"', {id})
            TriggerClientEvent('way:orderAccepted', -1, id)
        end)
    end)
end)

-- Order ready for delivery
RegisterNetEvent('way:readyOrder', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    MySQL.single('SELECT negocio_id FROM wayya WHERE id=? AND record_type="order"', {id}, function(order)
        if not order then return end
        MySQL.single('SELECT id FROM wayya WHERE id=? AND dueno_id=? AND record_type="business"', {order.negocio_id, xPlayer.identifier}, function(b)
            if not b then
                notify(src, 'Way Delivery', 'No tienes permiso para esa orden')
                return
            end
            MySQL.update('UPDATE wayya SET estado="enviado" WHERE id=? AND record_type="order"', {id})
            TriggerClientEvent('way:orderReady', -1, id)
        end)
    end)
end)

-- Delivery takes order
RegisterNetEvent('way:takeOrder', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or xPlayer.job.name ~= 'delivery' then
        notify(src, 'Way Delivery', 'No eres repartidor')
        return
    end
    MySQL.update('UPDATE wayya SET delivery_id=?, estado="en_camino" WHERE id=? AND record_type="order" AND (delivery_id IS NULL OR delivery_id="")', {xPlayer.identifier, id}, function(rows)
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
    MySQL.single('SELECT total, negocio_id, delivery_id, user_id FROM wayya WHERE id=? AND record_type="order"', {id}, function(order)
        if not order then return end
        if order.user_id ~= xPlayer.identifier then
            notify(src, 'Way Delivery', 'No eres el dueño de la orden')
            return
        end
        if xPlayer.getMoney() < order.total then
            notify(src, 'Way Delivery', 'Fondos insuficientes')
            return
        end
        xPlayer.removeMoney(order.total)
        local businessShare = math.floor(order.total * (1.0 - commission))
        local deliveryShare = order.total - businessShare
        if order.negocio_id then
            local bus
            MySQL.single('SELECT dueno_id FROM wayya WHERE id=? AND record_type="business"', {order.negocio_id}, function(b)
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
        MySQL.update('UPDATE wayya SET estado="entregado" WHERE id=? AND record_type="order"', {id})
        notify(src, 'Way Delivery', 'Has pagado la orden #'..id)
    end)
end)

