RegisterNetEvent('way:orderCreated')
AddEventHandler('way:orderCreated', function(data)
    print('Order created: ' .. data.id)
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
    end)
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

RegisterNUICallback('readyOrder', function(data, cb)
    TriggerServerEvent('way:readyOrder', data.id)
    cb({})
end)

RegisterNUICallback('getAvailableOrders', function(data, cb)
    ESX.TriggerServerCallback('way:getAvailableOrders', function(res)
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

