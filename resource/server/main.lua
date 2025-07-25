local ESX

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local commission = 0.3 -- 30% to delivery


MySQL.ready(function()
    MySQL.query([[CREATE TABLE IF NOT EXISTS wayya (
        id INT AUTO_INCREMENT PRIMARY KEY,
        record_type ENUM('business','order','delivery_job') NOT NULL,
        nombre VARCHAR(50) NULL,
        categoria VARCHAR(50) NULL,
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
ESX.RegisterServerCallback('way:getBusinesses', function(source, cb, categoria)
    local query = 'SELECT id, nombre, categoria FROM wayya WHERE record_type="business"'
    local params = {}
    if categoria and categoria ~= '' then
        query = query .. ' AND categoria=?'
        params = {categoria}
    end
    MySQL.query(query, params, function(res)
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

ESX.RegisterServerCallback('way:getMyOrders', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb({}) end
    MySQL.query('SELECT id, total, estado FROM wayya WHERE record_type="order" AND user_id=? ORDER BY created_at DESC', {xPlayer.identifier}, function(res)
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
    MySQL.single('SELECT negocio_id, estado FROM wayya WHERE id=? AND record_type="order"', {id}, function(order)
        if not order then return end
        MySQL.single('SELECT id FROM wayya WHERE id=? AND dueno_id=? AND record_type="business"', {order.negocio_id, xPlayer.identifier}, function(b)
            if not b then
                notify(src, 'Way Delivery', 'No tienes permiso para esa orden')
                return
            end
            if order.estado ~= 'pendiente' then
                notify(src, 'Way Delivery', 'Estado de la orden inv\195\161lido')
                return
            end
            MySQL.update('UPDATE wayya SET estado="aceptado" WHERE id=? AND record_type="order"', {id})
            TriggerClientEvent('way:orderAccepted', -1, id)
        end)
    end)
end)

-- Business rejects order
RegisterNetEvent('way:rejectOrder', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    MySQL.single('SELECT negocio_id, user_id FROM wayya WHERE id=? AND record_type="order"', {id}, function(order)
        if not order then return end
        MySQL.single('SELECT id FROM wayya WHERE id=? AND dueno_id=? AND record_type="business"', {order.negocio_id, xPlayer.identifier}, function(b)
            if not b then
                notify(src, 'Way Delivery', 'No tienes permiso para esa orden')
                return
            end
            MySQL.update('UPDATE wayya SET estado="rechazado" WHERE id=? AND record_type="order"', {id})
            local customer = ESX.GetPlayerFromIdentifier(order.user_id)
            if customer then
                notify(customer.source, 'Way Delivery', 'Tu pedido #'..id..' fue rechazado')
            end
        end)
    end)
end)

-- Order ready for delivery
RegisterNetEvent('way:readyOrder', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    MySQL.single('SELECT negocio_id, estado FROM wayya WHERE id=? AND record_type="order"', {id}, function(order)
        if not order then return end
        MySQL.single('SELECT id FROM wayya WHERE id=? AND dueno_id=? AND record_type="business"', {order.negocio_id, xPlayer.identifier}, function(b)
            if not b then
                notify(src, 'Way Delivery', 'No tienes permiso para esa orden')
                return
            end
            if order.estado ~= 'aceptado' then
                notify(src, 'Way Delivery', 'La orden no est\195\161 aceptada')
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

    MySQL.single('SELECT estado, delivery_id FROM wayya WHERE id=? AND record_type="order"', {id}, function(order)
        if not order then return end
        if order.estado ~= 'enviado' then
            notify(src, 'Way Delivery', 'La orden no está disponible')
            return
        end
        if order.delivery_id and order.delivery_id ~= '' then
            notify(src, 'Way Delivery', 'La orden ya fue tomada')
            return
        end

        MySQL.update('UPDATE wayya SET delivery_id=?, estado="en_camino" WHERE id=? AND record_type="order"', {xPlayer.identifier, id}, function(rows)
            if rows and rows > 0 then
                -- Obtener ubicaciones del negocio y del cliente
                MySQL.single('SELECT negocio_id, ubicacion_cliente FROM wayya WHERE id=? AND record_type="order"', {id}, function(order)
                    if order then
                        MySQL.single('SELECT ubicacion_negocio FROM wayya WHERE id=? AND record_type="business"', {order.negocio_id}, function(bus)
                            local businessLoc, clientLoc
                            if bus and bus.ubicacion_negocio then
                                local ok, data = pcall(json.decode, bus.ubicacion_negocio)
                                if ok then businessLoc = data end
                            end
                            if order.ubicacion_cliente then
                                local ok, data = pcall(json.decode, order.ubicacion_cliente)
                                if ok then clientLoc = data end
                            end
                            TriggerClientEvent('way:orderLocations', src, {business = businessLoc, client = clientLoc})
                        end)
                    end
                end)

                notify(src, 'Way Delivery', 'Has tomado la orden #'..id)
                TriggerClientEvent('way:orderTaken', -1, id)
            else
                notify(src, 'Way Delivery', 'La orden ya fue tomada')
            end
        end)
    end)
end)


-- Customer pays and completes order
RegisterNetEvent('way:payOrder', function(id)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer then return end
    MySQL.single('SELECT total, negocio_id, delivery_id, user_id, estado FROM wayya WHERE id=? AND record_type="order"', {id}, function(order)
        if not order then return end
        if order.user_id ~= xPlayer.identifier then
            notify(src, 'Way Delivery', 'No eres el dueño de la orden')
            return
        end
        if order.estado ~= 'en_camino' then
            notify(src, 'Way Delivery', 'La orden no está en camino')
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

-- =====================================================================
-- Business management

-- Fetch business owned by the requesting player
ESX.RegisterServerCallback('way:getOwnerBusiness', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return cb(nil) end
    MySQL.single('SELECT id, nombre, menu, ubicacion_negocio FROM wayya WHERE dueno_id=? AND record_type="business"', {xPlayer.identifier}, function(b)
        if not b then return cb(nil) end
        local menu = {}
        if b.menu then
            local ok, data = pcall(json.decode, b.menu)
            if ok and data then menu = data end
        end
        cb({ id = b.id, nombre = b.nombre, menu = menu, ubicacion = b.ubicacion_negocio })
    end)
end)

-- Create new business for the player
RegisterNetEvent('way:registerBusiness', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not data or not data.name then return end
    MySQL.single('SELECT id FROM wayya WHERE dueno_id=? AND record_type="business"', {xPlayer.identifier}, function(b)
        if b then
            notify(src, 'Way Delivery', 'Ya tienes un negocio registrado')
            return
        end
        MySQL.insert('INSERT INTO wayya (record_type, nombre, menu, dueno_id, ubicacion_negocio) VALUES ("business", ?, ?, ?, ?)',
            {data.name, json.encode(data.menu or {}), xPlayer.identifier, json.encode(data.location)},
            function(id)
                notify(src, 'Way Delivery', 'Negocio registrado #'..id)
            end)
    end)
end)

-- Add or update a menu item
RegisterNetEvent('way:updateMenuItem', function(item)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not item then return end
    MySQL.single('SELECT id, menu FROM wayya WHERE dueno_id=? AND record_type="business"', {xPlayer.identifier}, function(b)
        if not b then return end
        local menu = {}
        if b.menu then
            local ok, data = pcall(json.decode, b.menu)
            if ok and data then menu = data end
        end
        local found = false
        for i,v in ipairs(menu) do
            if tostring(v.id) == tostring(item.id) then
                menu[i] = item
                found = true
                break
            end
        end
        if not found then table.insert(menu, item) end
        MySQL.update('UPDATE wayya SET menu=? WHERE id=?', {json.encode(menu), b.id})
    end)
end)

-- Delete a menu item
RegisterNetEvent('way:deleteMenuItem', function(data)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    if not xPlayer or not data or not data.id then return end
    MySQL.single('SELECT id, menu FROM wayya WHERE dueno_id=? AND record_type="business"', {xPlayer.identifier}, function(b)
        if not b then return end
        local menu = {}
        if b.menu then
            local ok, arr = pcall(json.decode, b.menu)
            if ok and arr then menu = arr end
        end
        for i,v in ipairs(menu) do
            if tostring(v.id) == tostring(data.id) then
                table.remove(menu, i)
                break
            end
        end
        MySQL.update('UPDATE wayya SET menu=? WHERE id=?', {json.encode(menu), b.id})
    end)
end)

