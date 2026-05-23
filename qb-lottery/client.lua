local hud = ""
local myTickets = {}
local jackpot = 0
local drawTime = 0

local function DrawText(text)
    SetTextFont(0)
    SetTextScale(0.6, 0.6)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, 0.12)
end

CreateThread(function()
    while true do
        Wait(0)
        if hud ~= "" then
            DrawText(hud)
        end
    end
end)

-- 打开 lottery 界面（F5 键 166）
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, 166) then
            SetNuiFocus(true, true)
            SendNUIMessage({
                action = "open",
                tickets = myTickets,  
                jackpot = jackpot
            })
        end
    end
end)

RegisterNetEvent("qb-lottery:client:Hud", function(text)
    hud = text
end)

RegisterNetEvent("qb-lottery:client:Jackpot", function(amount)
    jackpot = amount
end)


RegisterNetEvent("qb-lottery:client:Sync", function(list)
    myTickets = list
    SendNUIMessage({
        action = "tickets",
        tickets = list
    })
end)

RegisterNetEvent("qb-lottery:client:ClearTickets", function()
    myTickets = {}
    SendNUIMessage({action="tickets",tickets={}})
end)

RegisterNetEvent("qb-lottery:client:DrawTime", function(time)
    SendNUIMessage({
        action = "time",
        time = time
    })
end)

-- 购买
RegisterNUICallback("buy", function(data, cb)
    TriggerServerEvent("qb-lottery:server:Buy", data.number, data.type)
    cb("ok")
end)

-- 机选
RegisterNUICallback("random", function(_, cb)
    TriggerServerEvent("qb-lottery:server:Random")
    cb("ok")
end)

-- 关闭界面
RegisterNUICallback("close", function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({action="close"})
    cb("ok")
end)