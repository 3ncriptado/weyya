RegisterNetEvent('way:orderCreated')
AddEventHandler('way:orderCreated', function(data)
    print('Order created: ' .. data.id)
end)
-- Order event handlers ------------------------------------------------------

-- When a new order is created notify the player and refresh the UI
RegisterNetEvent('way:newOrder')
AddEventHandler('way:newOrder', function(data)
    -- Show phone notification
    TriggerEvent('lb-phone:notify', {
        title = 'Way Delivery',
        message = 'Nueva orden #' .. tostring(data.id),
        icon = 'fas fa-hamburger',
        duration = 5000
    })

    -- Update business orders list if UI is open
    SendNUIMessage('refreshBusinessOrders')
end)

RegisterNetEvent('way:orderAccepted')
AddEventHandler('way:orderAccepted', function(id)
    TriggerEvent('lb-phone:notify', {
        title = 'Way Delivery',
        message = 'Orden #' .. id .. ' aceptada',
        icon = 'fas fa-hamburger',
        duration = 5000
    })
    SendNUIMessage('refreshBusinessOrders')
end)

RegisterNetEvent('way:orderReady')
AddEventHandler('way:orderReady', function(id)
    TriggerEvent('lb-phone:notify', {
        title = 'Way Delivery',
        message = 'Orden #' .. id .. ' lista para delivery',
        icon = 'fas fa-hamburger',
        duration = 5000
    })
    SendNUIMessage('refreshBusinessOrders')
    SendNUIMessage('refreshDeliveryOrders')
end)

RegisterNetEvent('way:orderTaken')
AddEventHandler('way:orderTaken', function(id)
    TriggerEvent('lb-phone:notify', {
        title = 'Way Delivery',
        message = 'Orden #' .. id .. ' recogida',
        icon = 'fas fa-hamburger',
        duration = 5000
    })
    SendNUIMessage('refreshBusinessOrders')
    SendNUIMessage('refreshDeliveryOrders')
end)


-- Send messages to UI
local function openUI()
    SetNuiFocus(true, true)
    SendNUIMessage('open')
end

local function closeUI()
    SetNuiFocus(false, false)
    SendNUIMessage('close')
end

-- lb-phone integration for opening/closing the app
RegisterNetEvent('lb-phone:appOpened')
AddEventHandler('lb-phone:appOpened', function(app)
    if app == 'way' then
        openUI()
    end
end)

RegisterNetEvent('lb-phone:appClosed')
AddEventHandler('lb-phone:appClosed', function(app)
    if app == 'way' then
        closeUI()
    end
end)

-- simple placeholder to integrate with lb-phone
CreateThread(function()
    TriggerEvent('lb-phone:addCustomApp', {
        identifier = 'way',
        name = 'Way Delivery',
        description = 'Pide comida a domicilio',
        ui = 'resource/ui/index.html'
    })
end)

-- NUI callbacks -----------------------------------------------------------
RegisterNUICallback('getBusinesses', function(data, cb)
    ESX.TriggerServerCallback('way:getBusinesses', function(res)
        cb(res)
    end, data.categoria)
end)

RegisterNUICallback('getBusinessMenu', function(data, cb)
    ESX.TriggerServerCallback('way:getBusinessMenu', cb, data.id)
end)

RegisterNUICallback('createOrder', function(data, cb)
    TriggerServerEvent('way:createOrder', data)
    cb({})
end)

RegisterNUICallback('getBusinessOrders', function(data, cb)
    ESX.TriggerServerCallback('way:getBusinessOrders', function(res)
        cb(res)
    end)
end)

RegisterNUICallback('acceptOrder', function(data, cb)
    TriggerServerEvent('way:acceptOrder', data.id)
    cb({})
end)

RegisterNUICallback('rejectOrder', function(data, cb)
    TriggerServerEvent('way:rejectOrder', data.id)
    cb({})
end)

RegisterNUICallback('readyOrder', function(data, cb)
    TriggerServerEvent('way:readyOrder', data.id)
    cb({})
end)

RegisterNUICallback('getAvailableOrders', function(data, cb)
    ESX.TriggerServerCallback('way:getAvailableOrders', function(res)
        cb(res)
    end)
end)

RegisterNUICallback('getMyOrders', function(data, cb)
    ESX.TriggerServerCallback('way:getMyOrders', function(res)
        cb(res)
    end)
end)

RegisterNUICallback('takeOrder', function(data, cb)
    TriggerServerEvent('way:takeOrder', data.id)
    cb({})
end)

RegisterNUICallback('payOrder', function(data, cb)
    TriggerServerEvent('way:payOrder', data.id)
    cb({})
end)

RegisterNUICallback('getOwnerBusiness', function(data, cb)
    ESX.TriggerServerCallback('way:getOwnerBusiness', function(res)
        cb(res)
    end)
end)

RegisterNUICallback('registerBusiness', function(data, cb)
    data.location = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('way:registerBusiness', data)
    cb({})
end)

RegisterNUICallback('updateMenuItem', function(data, cb)
    TriggerServerEvent('way:updateMenuItem', data)
    cb({})
end)

RegisterNUICallback('deleteMenuItem', function(data, cb)
    TriggerServerEvent('way:deleteMenuItem', data)
    cb({})
end)

-- Returns player's current coordinates to the UI
RegisterNUICallback('getPlayerCoords', function(data, cb)
    local coords = GetEntityCoords(PlayerPedId())
    cb({ x = coords.x, y = coords.y, z = coords.z })
end)

-- Receive business and client locations when taking an order
RegisterNetEvent('way:orderLocations')
AddEventHandler('way:orderLocations', function(data)
    if data and data.business then
        SetNewWaypoint(data.business.x + 0.0, data.business.y + 0.0)
        ESX.ShowNotification('Dirígete al negocio para recoger el pedido')
    end
    -- store for optional use by other scripts
    CurrentDeliveryLocations = data
end)
