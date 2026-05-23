ESX = exports['es_extended']:getSharedObject()

local Config = {
	Price = 500,             -- 每注彩票价格（500元）
	StartJackpot = 10000,    -- 初始奖池金额（10000元）
	AddJackpot = 5000,       -- 未中奖时每期追加金额（+5000）
	DrawInterval = 20,       -- 每期开奖间隔时间（20秒）
	MaxTickets = 5,          -- 每人最多购买几注（5注）
	RandomWinChance = 10,    -- 机选中奖概率（100=必中）
	ManualWinMultiplier = 2, -- 手动购买中奖奖金倍数（×2）
	NoBuyTime = 10,          -- 开奖前多少秒禁止购买（10秒锁盘）
}

local tickets = {}
local playerTickets = {}
local canBuy = true
local jackpot = Config.StartJackpot
local currentWinNumber = nil
local playerGotWin = {}

MySQL.ready(function()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS lottery_jackpot (
            id INT PRIMARY KEY DEFAULT 1,
            jackpot INT NOT NULL DEFAULT 10000
        )
    ]], {}, function()
        MySQL.Async.fetchScalar("SELECT jackpot FROM lottery_jackpot WHERE id = 1", {}, function(val)
            if val then
                jackpot = val
                print("[乐透日志] 读取数据库奖池成功: " .. jackpot)
            else
                MySQL.Async.execute("INSERT INTO lottery_jackpot (id, jackpot) VALUES (1, ?)", {Config.StartJackpot})
                jackpot = Config.StartJackpot
                print("[乐透日志] 创建初始奖池成功: " .. jackpot)
            end
            TriggerClientEvent('qb-lottery:client:Jackpot', -1, jackpot)
            print("[乐透日志] 系统初始化成功，当前奖池：" .. jackpot)
        end)
    end)
end)

local function SaveJackpot()
    MySQL.Async.execute("UPDATE lottery_jackpot SET jackpot = ? WHERE id = 1", {jackpot})
end

local function GetPlayerName(src)
    local xPlayer = ESX.GetPlayerFromId(src)
    if xPlayer then
        return xPlayer.getName()
    end
    return "未知玩家"
end

local function Hud(msg)
    TriggerClientEvent('qb-lottery:client:Hud', -1, msg)
    TriggerClientEvent('qb-lottery:client:Jackpot', -1, jackpot)
end

RegisterNetEvent('qb-lottery:server:Buy', function(num, type)
    local src = source
    local pName = GetPlayerName(src)
    local xPlayer = ESX.GetPlayerFromId(src)

    if not canBuy then
        TriggerClientEvent('esx:showNotification', src, '~r~最后10秒禁止购买')
        return
    end

    if not xPlayer then return end

    num = tostring(num)
    if not num:match("^%d%d%d%d$") then
        TriggerClientEvent('esx:showNotification', src, '~r~必须4位数字')
        return
    end

    playerTickets[src] = playerTickets[src] or {}
    if #playerTickets[src] >= Config.MaxTickets then
        TriggerClientEvent('esx:showNotification', src, '~r~最多5注')
        return
    end

    if xPlayer.getMoney() < Config.Price then
        TriggerClientEvent('esx:showNotification', src, '~r~现金不足')
        return
    end

    xPlayer.removeMoney(Config.Price)
    table.insert(playerTickets[src], { number = num, type = type or 'manual' })
    tickets[num] = tickets[num] or {}
    table.insert(tickets[num], { id = src, type = type or 'manual' })

    local ticketNumbers = {}
    for _, v in ipairs(playerTickets[src]) do
        table.insert(ticketNumbers, v.number)
    end
    TriggerClientEvent("qb-lottery:client:Sync", src, ticketNumbers)

    print("[乐透日志] 玩家【" .. pName .. "】手动购买号码：" .. num)
    TriggerClientEvent('esx:showNotification', src, '~g~购买成功：'..num)
end)

RegisterNetEvent('qb-lottery:server:Random', function()
    local src = source
    local pName = GetPlayerName(src)
    local xPlayer = ESX.GetPlayerFromId(src)

    if not canBuy then
        TriggerClientEvent('esx:showNotification', src, '~r~最后10秒禁止购买')
        return
    end

    if not xPlayer then return end

    playerTickets[src] = playerTickets[src] or {}
    if #playerTickets[src] >= Config.MaxTickets then
        TriggerClientEvent('esx:showNotification', src, '~r~最多5注')
        return
    end

    if xPlayer.getMoney() < Config.Price then
        TriggerClientEvent('esx:showNotification', src, '~r~现金不足')
        return
    end

    xPlayer.removeMoney(Config.Price)

    local function getUniqueNum()
        local used = {}
        for _,v in pairs(playerTickets[src]) do
            used[v.number] = true
        end
        local num
        repeat
            num = string.format("%04d", math.random(0,9999))
        until not used[num]
        return num
    end

    local randomNum
    if not playerGotWin[src] and math.random(1,100) <= Config.RandomWinChance then
        randomNum = currentWinNumber
        playerGotWin[src] = true
    else
        randomNum = getUniqueNum()
    end

    table.insert(playerTickets[src], { number = randomNum, type = 'random' })
    tickets[randomNum] = tickets[randomNum] or {}
    table.insert(tickets[randomNum], { id = src, type = 'random' })

    local ticketNumbers = {}
    for _, v in ipairs(playerTickets[src]) do
        table.insert(ticketNumbers, v.number)
    end
    TriggerClientEvent("qb-lottery:client:Sync", src, ticketNumbers)

    print("[乐透日志] 玩家【" .. pName .. "】机选购买号码：" .. randomNum)
    TriggerClientEvent('esx:showNotification', src, '~g~机选成功：'..randomNum)
end)

CreateThread(function()
    print("[乐透日志] 乐透开奖循环已启动")
    while true do
        currentWinNumber = string.format("%04d", math.random(0, 9999))
        canBuy = true
        playerGotWin = {}
        Hud("")
        print("[乐透日志] 本期开奖号码：" .. currentWinNumber)

        for i = Config.DrawInterval, 1, -1 do
            TriggerClientEvent("qb-lottery:client:DrawTime", -1, i)
            if i <= Config.NoBuyTime then
                canBuy = false
                Hud("~b~大乐透即将开奖~w~ | ~y~倒计时："..i.."秒~w~ | ~g~奖池：$"..jackpot.."~w~")
            end
            Wait(1000)
        end

        local winnerList = tickets[currentWinNumber] or {}
        Hud("~o~开奖中...~w~")
        Wait(2000)

        if #winnerList > 0 then
            local baseReward = math.floor(jackpot / #winnerList)
            local announce = {}
            print("[乐透日志] 本期中奖人数：" .. #winnerList .. " 人，单人基础奖金：" .. baseReward)

            for _, w in pairs(winnerList) do
                local xPlayer = ESX.GetPlayerFromId(w.id)
                local pName = GetPlayerName(w.id)
                if xPlayer then
                    local reward = w.type == 'manual' and baseReward * Config.ManualWinMultiplier or baseReward
                    local typeText = w.type == 'manual' and "手动翻倍" or "机选"
                    
                    xPlayer.addMoney(reward)
                    table.insert(announce, "~g~恭喜 "..pName.."~w~ | "..typeText.." | 中奖号码："..currentWinNumber.." | ~y~奖金$"..reward.."~w~")
                    print("[乐透日志] 【中奖】玩家【" .. pName .. "】命中号码 " .. currentWinNumber .. "，获得奖金：" .. reward)
                end
            end

            Hud("~r~【中奖公告】~w~ " .. table.concat(announce, " | "))
            jackpot = Config.StartJackpot
            SaveJackpot()
        else
            jackpot = jackpot + Config.AddJackpot
            Hud("~b~本期开奖号码："..currentWinNumber.."~w~ | ~r~无人中奖~w~ | ~g~奖池累加至$"..jackpot.."~w~")
            print("[乐透日志] 本期无人中奖，最新奖池：" .. jackpot)
            SaveJackpot()
        end

        Wait(3000)
        Hud("")
        table.wipe(tickets)
        table.wipe(playerTickets)
        TriggerClientEvent("qb-lottery:client:ClearTickets", -1)
        Wait(1000)
    end
end)

AddEventHandler("playerDropped", function()
    playerTickets[source] = nil
    playerGotWin[source] = nil
end)

AddEventHandler("onResourceStop", function(resName)
    if resName == GetCurrentResourceName() then
        SaveJackpot()
        print("[乐透日志] 乐透系统已关闭，奖池已保存")
    end
end)