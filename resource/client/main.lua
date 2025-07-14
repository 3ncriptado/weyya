RegisterNetEvent('way:orderCreated')
AddEventHandler('way:orderCreated', function(data)
    print('Order created: '..data.id)
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

