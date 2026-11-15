--[[
  Pirate Hub - Fluent UI (Update 4: Worlds 4 + 5 Edition)
  Built from the game dump (Net remotes + Controllers).
  English-only labels on purpose (avoids executor encoding problems).
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser       = game:GetService("VirtualUser")
local Workspace         = game:GetService("Workspace")
local HttpService       = game:GetService("HttpService")
local RunService        = game:GetService("RunService")
local CoreGui           = game:GetService("CoreGui")
local LocalPlayer       = Players.LocalPlayer

-- Preserve executor thread capability (Plugin/CoreGui access) after calling game ModuleScripts
local setId = setthreadidentity or setidentity or (syn and syn.set_thread_identity)
local function elevate()
    if setId then pcall(setId, 8) end
end
elevate()

-- Clean up any older Pirate Hub window / toggle button so re-executing never stacks duplicate UIs
local uiRoots = { CoreGui }
if type(gethui) == "function" then
    local okHui, hui = pcall(gethui)
    if okHui and typeof(hui) == "Instance" then
        table.insert(uiRoots, hui)
    end
end
for _, root in ipairs(uiRoots) do
    pcall(function()
        for _, gui in ipairs(root:GetChildren()) do
            if gui:IsA("ScreenGui") then
                if gui.Name == "_PirateHubToggleGui" then
                    gui:Destroy()
                elseif gui.Name == "ScreenGui" then
                    for _, d in ipairs(gui:GetDescendants()) do
                        if d:IsA("TextLabel") and d.Text == "Pirate Hub" then
                            gui:Destroy()
                            break
                        end
                    end
                end
            end
        end
    end)
end

---------------------------------------------------------------- Net & Shared Modules
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net    = require(Shared:WaitForChild("Lib"):WaitForChild("Net"))
elevate()

local WorldMap, SeedCfg, EvoCfg, ArmorCfg, TrainCfg, RaidCfg, EnemyCfg, NumFmt
pcall(function() WorldMap = require(Shared.Lib.WorldMap) end)
pcall(function() SeedCfg  = require(Shared.Configs.SeedConfig) end)
pcall(function() EvoCfg   = require(Shared.Configs.EvolutionConfig) end)
pcall(function() ArmorCfg = require(Shared.Configs.HakiArmorConfig) end)
pcall(function() TrainCfg = require(Shared.Configs.TrainingConfig) end)
pcall(function() RaidCfg  = require(Shared.Configs.RaidBossConfig) end)
pcall(function() EnemyCfg = require(Shared.Configs.EnemyConfig) end)
pcall(function() NumFmt   = require(Shared.Lib.NumberFormatter) end)
pcall(function()
    local GameCfg = require(Shared.Configs.GameConfig)
    if type(GameCfg) == "table" and type(GameCfg.StageFarm) == "table" then
        -- Add +0.8s buffer so client FarmRespawn never fires before server 30s FarmCleared cooldown expires
        GameCfg.StageFarm.RespawnDelay = 30.8
    end
end)
elevate()

local function fire(name, ...)
    local a = { ... }
    local ok, err = pcall(function() Net:FireServer(name, table.unpack(a)) end)
    elevate()
    return ok, err
end

local function invoke(name, ...)
    local a = { ... }
    local ok, res = pcall(function() return Net:InvokeServer(name, table.unpack(a)) end)
    elevate()
    return ok, res
end

local function hrpOf()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
end

---------------------------------------------------------------- UI
local Fluent
for attempt = 1, 3 do
    local okF, resF = pcall(function()
        return loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
    end)
    elevate()
    if okF and type(resF) == "table" then
        Fluent = resF
        break
    end
    task.wait(0.5)
end
if not Fluent then
    warn("[Pirate Hub] Failed to load Fluent UI library")
    return
end

local Window = Fluent:CreateWindow({
    Title       = "Pirate Hub",
    SubTitle    = "Update 4 (Worlds 1-5)",
    TabWidth    = 140,
    Size        = UDim2.fromOffset(600, 480),
    Acrylic     = false,
    Theme       = "Dark",
    MinimizeKey = Enum.KeyCode.RightControl,
})

pcall(function()
    if Fluent.GUI and Fluent.GUI:IsA("ScreenGui") then
        Fluent.GUI.DisplayOrder = 999999
        Fluent.GUI.ResetOnSpawn = false
        Fluent.GUI.IgnoreGuiInset = true
        Fluent.GUI.Enabled = true
    end
end)

-- Keep window inside viewport and provide a draggable floating toggle button so UI is never lost
local uiUnloaded = false
local toggleGui = nil
local function setupUiGuard()
    elevate()
    local parentRoot = CoreGui
    local okHui, hui = pcall(function() return type(gethui) == "function" and gethui() or nil end)
    if okHui and typeof(hui) == "Instance" and not hui:IsA("ScreenGui") and hui.Name ~= "RobloxGui" then
        parentRoot = hui
    end
    pcall(function()
        if Fluent.GUI and Fluent.GUI:IsA("ScreenGui") and Fluent.GUI.Parent ~= parentRoot then
            Fluent.GUI.Parent = parentRoot
        end
    end)

    local function buildToggleGui()
        if toggleGui then pcall(function() toggleGui:Destroy() end) end
        toggleGui = Instance.new("ScreenGui")
        toggleGui.Name = "_PirateHubToggleGui"
        toggleGui.DisplayOrder = 999999
        toggleGui.ResetOnSpawn = false
        toggleGui.IgnoreGuiInset = true
        toggleGui.Parent = parentRoot

        local btn = Instance.new("TextButton")
        btn.Name = "TogglePirateHub"
        btn.Size = UDim2.fromOffset(110, 32)
        btn.Position = UDim2.new(0, 16, 0.5, -16)
        btn.BackgroundColor3 = Color3.fromRGB(28, 30, 38)
        btn.BorderSizePixel = 0
        btn.Text = "Pirate Hub"
        btn.TextColor3 = Color3.fromRGB(240, 240, 245)
        btn.TextSize = 14
        btn.Font = Enum.Font.GothamBold
        btn.Active = true
        btn.Draggable = true
        btn.Parent = toggleGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = btn

        local stroke = Instance.new("UIStroke")
        stroke.Color = Color3.fromRGB(90, 165, 255)
        stroke.Thickness = 1.5
        stroke.Parent = btn

        btn.MouseButton1Click:Connect(function()
            elevate()
            if uiUnloaded then return end
            pcall(function()
                if Fluent.GUI and Fluent.GUI:IsA("ScreenGui") then
                    Fluent.GUI.Enabled = true
                end
                if type(Window.Minimize) == "function" then
                    Window:Minimize()
                elseif Window.Root and Window.Root:IsA("GuiObject") then
                    Window.Root.Visible = not Window.Root.Visible
                end
                local cam = Workspace.CurrentCamera
                local root = Window and Window.Root
                if cam and root and root:IsA("GuiObject") and root.Visible then
                    local vp = cam.ViewportSize
                    local pos = root.AbsolutePosition
                    local sz = root.AbsoluteSize
                    if pos.X > vp.X - 40 or pos.Y > vp.Y - 40 or pos.X + sz.X < 40 or pos.Y + sz.Y < 40 then
                        root.Position = UDim2.fromOffset(math.max(20, (vp.X - sz.X) * 0.5), math.max(20, (vp.Y - sz.Y) * 0.5))
                    end
                end
            end)
        end)
    end
    buildToggleGui()

    task.spawn(function()
        while not uiUnloaded do
            task.wait(1)
            elevate()
            pcall(function()
                if not toggleGui or not toggleGui.Parent then
                    buildToggleGui()
                end
                if Fluent.GUI and Fluent.GUI:IsA("ScreenGui") then
                    if Fluent.GUI.Parent == nil then Fluent.GUI.Parent = parentRoot end
                    if not Fluent.GUI.Enabled then Fluent.GUI.Enabled = true end
                    if Fluent.GUI.DisplayOrder < 999999 then Fluent.GUI.DisplayOrder = 999999 end
                end
                local cam = Workspace.CurrentCamera
                local root = Window and Window.Root
                if cam and root and root:IsA("GuiObject") and root.Visible then
                    local vp = cam.ViewportSize
                    if vp.X > 100 and vp.Y > 100 then
                        local pos = root.AbsolutePosition
                        local sz = root.AbsoluteSize
                        if pos.X > vp.X - 40 or pos.Y > vp.Y - 40 or pos.X + sz.X < 40 or pos.Y + sz.Y < 40 then
                            root.Position = UDim2.fromOffset(math.max(20, (vp.X - sz.X) * 0.5), math.max(20, (vp.Y - sz.Y) * 0.5))
                        end
                    end
                end
            end)
        end
    end)
end
pcall(setupUiGuard)

local Tabs = {
    Main     = Window:AddTab({ Title = "Main",        Icon = "swords" }),
    Training = Window:AddTab({ Title = "Training",    Icon = "dumbbell" }),
    Farm     = Window:AddTab({ Title = "Farm Stage",  Icon = "target" }),
    Seeds    = Window:AddTab({ Title = "Seeds/Drops", Icon = "sprout" }),
    Garden   = Window:AddTab({ Title = "Garden",      Icon = "flower" }),
    Boss     = Window:AddTab({ Title = "World Boss",  Icon = "skull" }),
    Summon   = Window:AddTab({ Title = "Summon",      Icon = "sparkles" }),
    Rewards  = Window:AddTab({ Title = "Rewards",     Icon = "gift" }),
    Upgrade  = Window:AddTab({ Title = "Upgrade",     Icon = "trending-up" }),
    Travel   = Window:AddTab({ Title = "Travel",      Icon = "map" }),
    Misc     = Window:AddTab({ Title = "Misc",        Icon = "settings" }),
}

local function notify(t, c)
    elevate()
    pcall(function() Fluent:Notify({ Title = t, Content = c or "", Duration = 3 }) end)
end

local function safeSection(name, fn)
    elevate()
    local ok, err = pcall(fn)
    elevate()
    if not ok then
        warn("[Pirate Hub] Section error (" .. tostring(name) .. "): " .. tostring(err))
        notify("Init Error: " .. tostring(name), tostring(err))
    end
end

local flags = {
    click       = false,
    trainbest   = false,
    rebirth     = false,
    equipbest   = false,
    endrun      = false,
    insta       = false,
    instahp     = true,
    autoscroll  = true,
    seed        = false,
    garden      = false,
    boss        = false,
    summon      = false,
    walker      = false,
    farmlock    = false,
    claim       = false,
    adminmeteor = true,
    upgrade     = false,
    afk         = true,
    fov         = 70,
}
local bossActive      = false -- true while going to or fighting a World Boss
local seedPickupCF    = nil   -- temporary CFrame override while AutoSeed is picking up a seed
local seedPickupUntil = 0
local seedBank        = true  -- auto EndRun to bank seeds when RunSeeds >= RunSeedCap or BagFull
local isBankingSeeds  = false -- true while EndRun is warping player back to bank seeds
local lastBankAt      = 0
local clickRate       = 0.15

local function isSeedBagFull()
    local cap = tonumber(LocalPlayer:GetAttribute("RunSeedCap")) or 0
    local cur = tonumber(LocalPlayer:GetAttribute("RunSeeds")) or 0
    return cap > 0 and cur >= cap
end

local function triggerSeedBank()
    if isBankingSeeds or (os.clock() - lastBankAt) < 2.5 then return false end
    local runStage = tonumber(LocalPlayer:GetAttribute("RunStage")) or 0
    local runSeeds = tonumber(LocalPlayer:GetAttribute("RunSeeds")) or 0
    if runStage <= 0 and runSeeds <= 0 then return false end

    isBankingSeeds = true
    lastBankAt = os.clock()
    seedPickupCF = nil
    seedPickupUntil = 0

    pcall(function()
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end)

    fire("EndRun")
    local t0 = os.clock()
    while os.clock() - t0 < 3.5 do
        local rs = tonumber(LocalPlayer:GetAttribute("RunStage")) or 0
        local sd = tonumber(LocalPlayer:GetAttribute("RunSeeds")) or 0
        if rs == 0 and sd == 0 then
            break
        end
        task.wait(0.15)
    end
    task.wait(0.35)
    isBankingSeeds = false
    return true
end

local function loop(flag, delayFn, fn)
    task.spawn(function()
        elevate()
        while flags[flag] do
            elevate()
            pcall(fn)
            elevate()
            task.wait(delayFn())
        end
    end)
end

-- Shared Seed Rarities (W1 1-50, W2 51-74, W3 75-98, W4 99-122, W5 123-146)
local Rarities = { "Common", "Uncommon", "Rare", "Epic", "Elemental", "Beast", "Ancient", "Mythical", "Divine" }
local Cutoffs  = { 8, 16, 23, 30, 36, 41, 45, 48, 50 }
local function rarityOf(id)
    if SeedCfg and type(SeedCfg.Get) == "function" then
        local ok, info = pcall(SeedCfg.Get, id)
        elevate()
        if ok and info and info.Rarity then return info.Rarity end
    end
    if id > 50 then
        local idx = (id - 51) % 24
        return Rarities[math.clamp(math.floor(idx / 3) + 1, 1, 8)]
    end
    for i, c in ipairs(Cutoffs) do if id <= c then return Rarities[i] end end
    return "Divine"
end

---------------------------------------------------------------- EQUIP BEST HELPERS
local function getOwnedFruits()
    local owned = { [1] = true }
    local rawCsv = LocalPlayer:GetAttribute("OwnedEvolutions")
    if type(rawCsv) == "string" and rawCsv ~= "" then
        for s in string.gmatch(rawCsv, "[^,]+") do
            local n = tonumber(s)
            if n then owned[n] = true end
        end
    end
    local rawJson = LocalPlayer:GetAttribute("EvolutionCounts")
    if type(rawJson) == "string" and rawJson ~= "" then
        local ok, dec = pcall(function() return HttpService:JSONDecode(rawJson) end)
        if ok and type(dec) == "table" then
            for k, v in pairs(dec) do
                local idx, cnt = tonumber(k), tonumber(v)
                if idx and cnt and cnt > 0 then owned[idx] = true end
            end
        end
    end
    return owned
end

local function equipBestFruit()
    if not EvoCfg then return false, "No EvolutionConfig" end
    local owned = getOwnedFruits()
    local reached = EvoCfg.ReachedWorld and EvoCfg.ReachedWorld(
        LocalPlayer:GetAttribute("World2Unlocked") == true,
        LocalPlayer:GetAttribute("World3Unlocked") == true,
        LocalPlayer:GetAttribute("World4Unlocked") == true,
        LocalPlayer:GetAttribute("World5Unlocked") == true
    ) or (tonumber(LocalPlayer:GetAttribute("World")) or 1)
    elevate()

    local bestIdx, bestDmg = nil, -1
    for idx in pairs(owned) do
        local d = (EvoCfg.DamageFor and EvoCfg.DamageFor(idx, reached)) or (EvoCfg.Get and EvoCfg.Get(idx) and EvoCfg.Get(idx).Damage) or 0
        if d > bestDmg then
            bestDmg = d
            bestIdx = idx
        end
    end
    elevate()
    local cur = tonumber(LocalPlayer:GetAttribute("EvolutionIndex")) or 1
    if bestIdx and bestIdx ~= cur then
        invoke("EquipEvolution", bestIdx)
        return true, ("Equipped Fruit #%d"):format(bestIdx)
    end
    return false, "Already on best fruit"
end

local function equipBestArmor()
    local raw = LocalPlayer:GetAttribute("HakiArmorCounts")
    if type(raw) ~= "string" or raw == "" then return false, "No Haki Armors owned" end
    local ok, dec = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(dec) ~= "table" then return false, "Decode failed" end

    local bestId, bestDef = nil, -1
    for id, cnt in pairs(dec) do
        if (tonumber(cnt) or 0) >= 1 then
            local info = ArmorCfg and ArmorCfg.Get and ArmorCfg.Get(tostring(id))
            local def = (info and tonumber(info.Defense)) or 0
            if def > bestDef then
                bestDef = def
                bestId = tostring(id)
            end
        end
    end
    elevate()
    local cur = tostring(LocalPlayer:GetAttribute("EquippedHakiArmor") or "")
    if bestId and bestId ~= cur then
        invoke("EquipHakiArmor", bestId)
        return true, ("Equipped Armor %s"):format(bestId)
    end
    return false, "Already on best armor"
end

local function equipBestAll()
    local r1, m1 = equipBestFruit()
    local r2, m2 = equipBestArmor()
    local okS = invoke("EquipBestSummons")
    return r1 or r2 or okS, ("%s | %s | Summons updated"):format(tostring(m1), tostring(m2))
end

---------------------------------------------------------------- INSTA KILL AT <= HP% (DEFAULT 80%)
local instaHpPct       = 80
local instaLoopRunning = false
local inInstaKillCall  = false
local cachedECtrl      = nil
local cachedEnemyMap   = nil
local cachedKillQueue  = nil
local mainInstaToggle  = nil
local farmInstaToggle  = nil
local syncingInsta     = false

local function ensureInstaHook()
    if cachedECtrl and cachedEnemyMap and cachedECtrl._pirateInstaHooked then
        return cachedECtrl, cachedEnemyMap
    end
    pcall(function()
        if not cachedECtrl then
            cachedECtrl = require(Shared.Client.Controllers.EnemyController)
        end
        local gup = (debug and debug.getupvalues) or getupvalues
        if cachedECtrl and type(gup) == "function" then
            if not cachedEnemyMap then
                for _, fnName in ipairs({ "GetActiveWaveHealth", "SlayActiveWave" }) do
                    local fn = cachedECtrl[fnName]
                    if type(fn) == "function" then
                        local ok, ups = pcall(gup, fn)
                        if ok and type(ups) == "table" then
                            for _, uv in pairs(ups) do
                                if type(uv) == "table" then
                                    cachedEnemyMap = uv
                                    break
                                end
                            end
                        end
                    end
                    if cachedEnemyMap then break end
                end
            end
            if type(cachedECtrl.GetActiveStageState) == "function" then
                local ok, ups = pcall(gup, cachedECtrl.GetActiveStageState)
                if ok and type(ups) == "table" then
                    for _, uv in pairs(ups) do
                        if type(uv) == "table" and type(uv.Farm) == "table" and type(uv.Farm.Config) == "table" then
                            uv.Farm.Config.RespawnDelay = 30.8
                        end
                    end
                end
            end
        end
        if cachedECtrl and type(cachedECtrl.ApplyDamage) == "function" then
            if not cachedECtrl._origApplyDamage then
                cachedECtrl._origApplyDamage = cachedECtrl.ApplyDamage
            end
            local origDmg = cachedECtrl._origApplyDamage
            if not cachedKillQueue and type(gup) == "function" then
                local ok, ups = pcall(gup, origDmg)
                if ok and type(ups) == "table" then
                    for _, uv in pairs(ups) do
                        if type(uv) == "function" then
                            local ok2, kups = pcall(gup, uv)
                            if ok2 and type(kups) == "table" then
                                for _, kuv in pairs(kups) do
                                    if type(kuv) == "table" and type(kuv.flush) == "function" and type(kuv.pending) == "table" then
                                        cachedKillQueue = kuv
                                        break
                                    end
                                end
                            end
                        end
                        if cachedKillQueue then break end
                    end
                end
            end
            cachedECtrl.ApplyDamage = function(target, amount, ...)
                local res = origDmg(target, amount, ...)
                if flags.instahp and not inInstaKillCall and cachedEnemyMap then
                    local entry = cachedEnemyMap[target]
                    if type(entry) == "table" and entry.alive and entry.attackable
                        and type(entry.hp) == "number" and type(entry.maxHp) == "number"
                        and entry.maxHp > 0 and entry.hp > 0 then
                        if (entry.hp / entry.maxHp) <= (instaHpPct / 100) + 1e-6 then
                            inInstaKillCall = true
                            pcall(origDmg, target, math.ceil(entry.hp) + 10)
                            if cachedKillQueue and type(cachedKillQueue.flush) == "function" and type(cachedKillQueue.pending) == "table" and next(cachedKillQueue.pending) ~= nil then
                                pcall(cachedKillQueue.flush)
                            end
                            inInstaKillCall = false
                        end
                    end
                end
                return res
            end
            cachedECtrl._pirateInstaHooked = true
        end
    end)
    elevate()
    return cachedECtrl, cachedEnemyMap
end

local function startInstaHpLoop()
    if instaLoopRunning then return end
    instaLoopRunning = true
    task.spawn(function()
        task.wait(0.1)
        elevate()
        while flags.instahp do
            elevate()
            pcall(function()
                local ECtrl, enemyMap = ensureInstaHook()
                if ECtrl and ECtrl._origApplyDamage and enemyMap then
                    local threshold = (instaHpPct / 100) + 1e-6
                    local toKill = {}
                    for model, entry in pairs(enemyMap) do
                        if type(entry) == "table" and entry.alive and entry.attackable
                            and type(entry.hp) == "number" and type(entry.maxHp) == "number"
                            and entry.maxHp > 0 and entry.hp > 0
                            and (entry.hp / entry.maxHp) <= threshold then
                            table.insert(toKill, { model = model, hp = entry.hp })
                        end
                    end
                    if #toKill > 0 then
                        inInstaKillCall = true
                        for _, item in ipairs(toKill) do
                            pcall(ECtrl._origApplyDamage, item.model, math.ceil(item.hp) + 10)
                        end
                        if cachedKillQueue and type(cachedKillQueue.flush) == "function" and type(cachedKillQueue.pending) == "table" and next(cachedKillQueue.pending) ~= nil then
                            pcall(cachedKillQueue.flush)
                        end
                        inInstaKillCall = false
                    end
                end
            end)
            elevate()
            task.wait(0.08)
        end
        instaLoopRunning = false
    end)
end

local function setInstaHpState(v)
    flags.instahp = v
    if v then startInstaHpLoop() end
    if not syncingInsta then
        syncingInsta = true
        pcall(function()
            if mainInstaToggle and mainInstaToggle.Value ~= v then mainInstaToggle:SetValue(v) end
            if farmInstaToggle and farmInstaToggle.Value ~= v then farmInstaToggle:SetValue(v) end
        end)
        elevate()
        syncingInsta = false
    end
end

---------------------------------------------------------------- TRAINING HELPERS (W1-W5, DUMMIES #1-#10)
local selectedTrainIdx = 0 -- 0 = Auto Best Unlocked, 1..10 = specific Training Dummy
local trainLoopRunning = false
local mainTrainToggle  = nil
local tabTrainToggle   = nil
local syncingTrain     = false
local mainTrainInfo    = nil
local tabTrainInfo     = nil

local function setTrainStatus(t)
    elevate()
    pcall(function() if mainTrainInfo then mainTrainInfo:SetDesc(t) end end)
    pcall(function() if tabTrainInfo then tabTrainInfo:SetDesc(t) end end)
end

local function formatTrainMult(m)
    local n = tonumber(m) or 1
    if NumFmt and type(NumFmt.Format) == "function" and n >= 1000 then
        local ok, s = pcall(NumFmt.Format, n)
        elevate()
        if ok and type(s) == "string" then return "x" .. s end
    end
    if n % 1 == 0 then return ("x%d"):format(n) end
    return ("x%.1f"):format(n):gsub("%.0$", "")
end

local function describeTrainer(idx, world)
    local w = world or tonumber(LocalPlayer:GetAttribute("World")) or 1
    local reb = tonumber(LocalPlayer:GetAttribute("Rebirths")) or 0
    local dummy = TrainCfg and TrainCfg.GetDummy and TrainCfg.GetDummy(idx, w)
    local mult = (TrainCfg and TrainCfg.EffectiveMultiplier and TrainCfg.EffectiveMultiplier(LocalPlayer, idx, w))
        or (dummy and dummy.Multiplier) or idx
    local unlocked = (TrainCfg and TrainCfg.IsUnlocked and TrainCfg.IsUnlocked(LocalPlayer, idx, w, reb)) or (idx == 1)
    local passKey = TrainCfg and TrainCfg.GetPassKeyFor and TrainCfg.GetPassKeyFor(idx, w)
    local reqReb = (dummy and tonumber(dummy.RebirthsRequired)) or 0
    local island = (dummy and dummy.Island) or nil
    elevate()
    local reqStr = passKey and ("Pass: " .. tostring(passKey)) or (reqReb > 0 and (tostring(reqReb) .. " Reb") or "Free")
    local nameStr = island and ("#" .. idx .. " " .. tostring(island)) or ("Training #" .. idx)
    return {
        idx      = idx,
        world    = w,
        mult     = mult,
        multStr  = formatTrainMult(mult),
        unlocked = unlocked == true,
        reqStr   = reqStr,
        nameStr  = nameStr,
    }
end

local function findBestTrainer()
    if not TrainCfg then return 1, 1, 1 end
    local world    = tonumber(LocalPlayer:GetAttribute("World")) or 1
    local rebirths = tonumber(LocalPlayer:GetAttribute("Rebirths")) or 0
    local bestIdx, bestMult = 1, -1
    for i = 1, (TrainCfg.Count or 10) do
        local unlocked = TrainCfg.IsUnlocked and TrainCfg.IsUnlocked(LocalPlayer, i, world, rebirths)
        if unlocked then
            local m = (TrainCfg.EffectiveMultiplier and TrainCfg.EffectiveMultiplier(LocalPlayer, i, world)) or i
            if m > bestMult then
                bestMult = m
                bestIdx  = i
            end
        end
    end
    elevate()
    return bestIdx, bestMult, world
end

local function resolveTargetTrainer()
    local world = tonumber(LocalPlayer:GetAttribute("World")) or 1
    if selectedTrainIdx >= 1 and selectedTrainIdx <= 10 then
        local info = describeTrainer(selectedTrainIdx, world)
        return info.idx, info.mult, world, info
    end
    local idx, mult, w = findBestTrainer()
    local info = describeTrainer(idx, w)
    return idx, mult, w, info
end

local function getTrainerCFrame(idx)
    if not TrainCfg or type(TrainCfg.GetZone) ~= "function" then return nil end
    local okZ, zone = pcall(TrainCfg.GetZone, idx)
    local okF, fig  = pcall(function() return TrainCfg.GetFigure and TrainCfg.GetFigure(idx) end)
    elevate()
    if not (okZ and zone and zone:IsA("BasePart")) then return nil end
    local floorY = zone.Position.Y - (zone.Size.Y * 0.5) + 3.2
    local pos = Vector3.new(zone.Position.X, floorY, zone.Position.Z)
    if okF and fig and fig:IsA("Model") then
        local okP, piv = pcall(function() return fig:GetPivot().Position end)
        if okP and typeof(piv) == "Vector3" then
            local lookAt = Vector3.new(piv.X, floorY, piv.Z)
            if (lookAt - pos).Magnitude > 0.5 then
                return CFrame.lookAt(pos, lookAt)
            end
        end
    end
    return CFrame.new(pos)
end

local function teleportToTrainerOnce(idx)
    local hrp = hrpOf()
    if not hrp then return false, "Character not ready" end
    local runStage = tonumber(LocalPlayer:GetAttribute("RunStage")) or 0
    if runStage > 0 then
        fire("EndRun")
        task.wait(0.5)
        hrp = hrpOf()
        if not hrp then return false, "Character not ready" end
    end
    local targetIdx = idx
    if not targetIdx or targetIdx <= 0 then
        targetIdx = resolveTargetTrainer()
    end
    local cf = getTrainerCFrame(targetIdx)
    if not cf then
        return false, "Training zone #" .. tostring(targetIdx) .. " not found in Workspace"
    end
    hrp.CFrame = cf
    local info = describeTrainer(targetIdx)
    local msg = ("Teleported -> %s (%s | %s)%s"):format(
        info.nameStr, info.multStr, info.reqStr, info.unlocked and "" or " [LOCKED]"
    )
    setTrainStatus(msg)
    return true, msg
end

local function startTrainLoop()
    if trainLoopRunning then return end
    trainLoopRunning = true
    task.spawn(function()
        elevate()
        local CS, autoTrainSig, manualSig
        pcall(function()
            CS = require(Shared.Client.ClientSignals)
            autoTrainSig = CS:Get("AutoTrainToggle")
            manualSig    = CS:Get("ManualAttack")
            if autoTrainSig then autoTrainSig:Fire(true) end
        end)
        elevate()
        while flags.trainbest do
            elevate()
            local hrp = hrpOf()
            local inRaid   = LocalPlayer:GetAttribute("InRaid") == true
            local runStage = tonumber(LocalPlayer:GetAttribute("RunStage")) or 0
            if inRaid or bossActive or flags.walker then
                setTrainStatus("Paused (in boss or stage farm active)")
            elseif seedPickupCF and os.clock() < seedPickupUntil then
                -- Yield position lock while AutoSeed collects a dropped seed
            elseif hrp and TrainCfg and type(TrainCfg.GetZone) == "function" then
                if runStage > 0 then
                    fire("EndRun")
                    task.wait(0.6)
                end
                local idx, _, w, info = resolveTargetTrainer()
                local cf = idx and getTrainerCFrame(idx)
                if cf then
                    if (hrp.Position - cf.Position).Magnitude > 4.5 then
                        hrp.CFrame = cf
                    end
                    local modeTag = (selectedTrainIdx == 0) and "Auto Best" or ("Selected #" .. tostring(selectedTrainIdx))
                    setTrainStatus(("World %d | %s -> %s (%s)%s"):format(
                        w or 1, modeTag, info.nameStr, info.multStr, info.unlocked and "" or " [LOCKED]"
                    ))
                    if manualSig then pcall(function() manualSig:Fire() end); elevate() end
                    fire("AttackTick", true)
                else
                    setTrainStatus("Waiting for TrainingDummies zone in Workspace...")
                end
            end
            task.wait(0.25)
        end
        if autoTrainSig then pcall(function() autoTrainSig:Fire(false) end); elevate() end
        trainLoopRunning = false
    end)
end

local function setTrainState(v)
    flags.trainbest = v
    if v then
        startTrainLoop()
    else
        setTrainStatus("idle")
    end
    if not syncingTrain then
        syncingTrain = true
        pcall(function()
            if mainTrainToggle and mainTrainToggle.Value ~= v then mainTrainToggle:SetValue(v) end
            if tabTrainToggle and tabTrainToggle.Value ~= v then tabTrainToggle:SetValue(v) end
        end)
        elevate()
        syncingTrain = false
    end
end

---------------------------------------------------------------- 1. MAIN TAB
safeSection("Main", function()
    Tabs.Main:AddToggle("AutoClick", { Title = "Auto Attack (AttackTick)", Default = false, Callback = function(v)
        flags.click = v
        if v then loop("click", function() return clickRate end, function() fire("AttackTick", true) end) end
    end })
    Tabs.Main:AddSlider("ClickRate", { Title = "Attack delay (sec)", Min = 0.05, Max = 1, Default = 0.15, Rounding = 2,
        Callback = function(v) clickRate = v end })

    mainTrainInfo = Tabs.Main:AddParagraph({ Title = "Trainer status", Content = "idle" })

    mainTrainToggle = Tabs.Main:AddToggle("AutoTrainBest", { Title = "Auto Train (Uses Training Tab selection)", Default = false, Callback = function(v)
        setTrainState(v)
    end })

    Tabs.Main:AddToggle("AutoRebirth", { Title = "Auto Rebirth", Default = false, Callback = function(v)
        flags.rebirth = v
        if v then loop("rebirth", function() return 2 end, function() invoke("TryRebirth") end) end
    end })

    Tabs.Main:AddToggle("AutoEquipBest", { Title = "Auto Equip Best (Fruit + Haki + Summons)", Default = false, Callback = function(v)
        flags.equipbest = v
        if v then loop("equipbest", function() return 5 end, equipBestAll) end
    end })

    Tabs.Main:AddButton({ Title = "Equip Best All Now (Fruit + Haki + Summons)", Callback = function()
        local _, msg = equipBestAll()
        notify("Equip Best", msg)
    end })

    Tabs.Main:AddToggle("AutoEndRun", { Title = "Auto End Run (EndRun)", Default = false, Callback = function(v)
        flags.endrun = v
        if v then loop("endrun", function() return 30 end, function() fire("EndRun") end) end
    end })

    mainInstaToggle = Tabs.Main:AddToggle("InstaKillHP", {
        Title = "Insta Kill Mob at <= 80% HP (Instant Death)",
        Default = true,
        Callback = function(v) setInstaHpState(v) end,
    })
    Tabs.Main:AddSlider("InstaKillHPPct", {
        Title = "Insta Kill HP Threshold (%)",
        Min = 1,
        Max = 100,
        Default = 80,
        Rounding = 0,
        Callback = function(v) instaHpPct = v end,
    })

    local instaDelay = 12
    Tabs.Main:AddSlider("InstaDelay", { Title = "Insta Kill after fight seconds (min 12)", Min = 12, Max = 60, Default = 12, Rounding = 0,
        Callback = function(v) instaDelay = v end })
    Tabs.Main:AddToggle("InstaKill", { Title = "Auto Insta Kill (owned charges)", Default = false, Callback = function(v)
        flags.insta = v
        if not v then return end
        task.spawn(function()
            elevate()
            local lastStage, fightStart = nil, os.clock()
            while flags.insta do
                local stage   = tonumber(LocalPlayer:GetAttribute("RunStage")) or 0
                local charges = tonumber(LocalPlayer:GetAttribute("InstaKillCharges")) or 0
                if stage ~= lastStage then lastStage, fightStart = stage, os.clock() end
                if charges > 0 and stage >= 2 and os.clock() - fightStart >= instaDelay then
                    fire("InstaKillUse")
                    fightStart = os.clock()
                    task.wait(3)
                end
                task.wait(0.5)
            end
        end)
    end })
end)

---------------------------------------------------------------- 1B. TRAINING TAB
safeSection("Training", function()
    tabTrainInfo = Tabs.Training:AddParagraph({ Title = "Training Status", Content = "idle" })
    local listInfo = Tabs.Training:AddParagraph({ Title = "Current World Training Dummies", Content = "Loading..." })

    local function refreshTrainingList()
        elevate()
        local w = tonumber(LocalPlayer:GetAttribute("World")) or 1
        local reb = tonumber(LocalPlayer:GetAttribute("Rebirths")) or 0
        local lines = { ("World %d | Your Rebirths: %d"):format(w, reb) }
        for i = 1, 10 do
            local d = describeTrainer(i, w)
            local stateTag = d.unlocked and "[UNLOCKED]" or ("[LOCKED - " .. d.reqStr .. "]")
            table.insert(lines, ("%s -> %s %s"):format(d.nameStr, d.multStr, stateTag))
        end
        elevate()
        pcall(function() listInfo:SetDesc(table.concat(lines, "\n")) end)
    end

    local trainChoices = {
        "Auto Best Unlocked",
        "Training #1 (Starter / 0 Reb)",
        "Training #2 (Rebirth Tier 1)",
        "Training #3 (Rebirth Tier 2)",
        "Training #4 (Rebirth Tier 3)",
        "Training #5 (Rebirth Tier 4)",
        "Training #6 (VIP Gamepass)",
        "Training #7 (Rebirth Tier 5)",
        "Training #8 (Rebirth Tier 6)",
        "Training #9 (Gamepass Tier 1)",
        "Training #10 (Gamepass Tier 2)",
    }

    local trainDD = Tabs.Training:AddDropdown("TrainingTargetSelect", {
        Title   = "Select Training Dummy to Stay At",
        Values  = trainChoices,
        Default = "Auto Best Unlocked",
    })
    trainDD:OnChanged(function(v)
        local n = tonumber(tostring(v):match("#(%d+)"))
        selectedTrainIdx = n or 0
        refreshTrainingList()
        if flags.trainbest then
            task.spawn(function()
                elevate()
                teleportToTrainerOnce(selectedTrainIdx)
            end)
        end
    end)

    tabTrainToggle = Tabs.Training:AddToggle("AutoTrainSelected", {
        Title   = "Auto Teleport & Stay at Selected Training",
        Default = false,
        Callback = function(v)
            setTrainState(v)
        end,
    })

    Tabs.Training:AddButton({
        Title = "Teleport to Selected Training Now (Once)",
        Description = "Warps directly to the selected Training Dummy without locking",
        Callback = function()
            task.spawn(function()
                elevate()
                local _, msg = teleportToTrainerOnce(selectedTrainIdx)
                notify("Training", msg)
            end)
        end,
    })

    Tabs.Training:AddButton({
        Title = "Refresh Training Multipliers & Unlock Status",
        Callback = function()
            refreshTrainingList()
            notify("Training", "Refreshed current World training list")
        end,
    })

    for i = 1, 10 do
        local idx = i
        Tabs.Training:AddButton({
            Title = ("Warp to Training #%d"):format(idx),
            Callback = function()
                task.spawn(function()
                    elevate()
                    selectedTrainIdx = idx
                    pcall(function() trainDD:SetValue(trainChoices[idx + 1]) end)
                    elevate()
                    local _, msg = teleportToTrainerOnce(idx)
                    notify("Training #" .. idx, msg)
                end)
            end,
        })
    end

    task.spawn(function()
        task.wait(0.3)
        refreshTrainingList()
        LocalPlayer:GetAttributeChangedSignal("World"):Connect(refreshTrainingList)
        LocalPlayer:GetAttributeChangedSignal("Rebirths"):Connect(refreshTrainingList)
    end)
end)

---------------------------------------------------------------- 2. FARM STAGE TAB
safeSection("Farm Stage", function()
    local farmWorld, farmStage, farmPer = 1, 1, 24

    local function bestOf(w)
        return tonumber(LocalPlayer:GetAttribute("BestStage" .. w)) or tonumber(LocalPlayer:GetAttribute("BestStage")) or 0
    end

    local farmInfo = Tabs.Farm:AddParagraph({ Title = "Farm status", Content = "-" })
    local function farmSet(t)
        elevate()
        pcall(function() farmInfo:SetDesc(t) end)
    end

    local fw = Tabs.Farm:AddDropdown("FarmWorld", { Title = "World", Values = { "1", "2", "3", "4", "5" }, Default = 1 })
    fw:OnChanged(function(v) farmWorld = tonumber(v) or 1 end)
    Tabs.Farm:AddSlider("FarmStage", { Title = "Stage (1-24)", Min = 1, Max = farmPer, Default = 1, Rounding = 0,
        Callback = function(v) farmStage = v end })

    local function stageCenter(s)
        local pos
        pcall(function()
            local w  = tonumber(LocalPlayer:GetAttribute("World")) or 1
            local st = EnemyCfg and EnemyCfg.GetStage and EnemyCfg.GetStage(s, w)
            if not st then return end
            local fn = (WorldMap and WorldMap.FindFunctionals and WorldMap.FindFunctionals())
                    or Workspace:FindFirstChild("__FUNCTIONALS")
            local stages = fn and fn:FindFirstChild("Stages")
            local biome  = stages and stages:FindFirstChild(st.Biome)
            local stModel = biome and biome:FindFirstChild("Stage" .. tostring(st.StageNumber))
            local spawns = stModel and stModel:FindFirstChild("EnemySpawns")
            if spawns then
                local sum, n = Vector3.zero, 0
                for _, p in ipairs(spawns:GetChildren()) do
                    local bp = p:IsA("BasePart") and p or p:FindFirstChildWhichIsA("BasePart", true)
                    if bp then sum += bp.Position; n += 1 end
                end
                if n > 0 then pos = sum / n end
            end
        end)
        elevate()
        return pos or Vector3.new(345, 4.3, -845.5 - 129 * (s - 1))
    end

    local hitboxOn    = true
    local hitboxSize  = 35
    local origSizes   = setmetatable({}, { __mode = "k" })
    local farmPosMode = "Above"
    local farmPosDist = 7
    local autoSkills  = true
    local farmLoop    = false

    local pmDD = Tabs.Farm:AddDropdown("FarmPosMode", { Title = "Position relative to mob", Values = { "Above", "Below", "Behind" }, Default = "Above" })
    pmDD:OnChanged(function(v) farmPosMode = v end)

    Tabs.Farm:AddSlider("FarmPosDist", { Title = "Distance from mob (studs)", Min = 3, Max = 18, Default = 7, Rounding = 0,
        Callback = function(v) farmPosDist = v end })

    Tabs.Farm:AddToggle("AutoSkills", { Title = "Auto Use All Skills (Special / Utility / Haki)", Default = true,
        Callback = function(v) autoSkills = v end })

    Tabs.Farm:AddToggle("FarmLoopEndRun", { Title = "Loop Farm (Auto EndRun at target stage)", Default = false,
        Callback = function(v) farmLoop = v end })

    farmInstaToggle = Tabs.Farm:AddToggle("FarmInstaKillHP", {
        Title = "Insta Kill Mob at <= 80% HP (Instant Death)",
        Default = true,
        Callback = function(v) setInstaHpState(v) end,
    })

    Tabs.Farm:AddToggle("HitboxToggle", { Title = "Expand Enemy Hitbox + Bring Mobs", Default = true, Callback = function(v)
        hitboxOn = v
        if not v then
            local le = Workspace:FindFirstChild("_LocalEnemies")
            if le then
                for _, m in ipairs(le:GetChildren()) do
                    local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
                    if root and origSizes[root] then
                        pcall(function()
                            root.Size = origSizes[root]
                            root.Transparency = 1
                        end)
                    end
                end
            end
        end
    end })

    Tabs.Farm:AddSlider("HitboxSize", { Title = "Hitbox Size (studs)", Min = 10, Max = 80, Default = 35, Rounding = 0,
        Callback = function(v) hitboxSize = v end })

    local function applyHitbox(hrp)
        if not hitboxOn or not hrp then return end
        local le = Workspace:FindFirstChild("_LocalEnemies")
        if not le then return end
        local sz = Vector3.new(hitboxSize, hitboxSize, hitboxSize)
        for _, m in ipairs(le:GetChildren()) do
            pcall(function()
                local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
                if root then
                    if not origSizes[root] then origSizes[root] = root.Size end
                    if root.Size ~= sz then
                        root.Size = sz
                        root.Transparency = 0.75
                        root.CanCollide = false
                    end
                end
            end)
        end
    end

    Tabs.Farm:AddToggle("StageWalker", { Title = "Auto farm to target stage (FREE, stage by stage + attack)", Default = false, Callback = function(v)
        flags.walker = v
        if not v then farmSet("off"); return end
        task.spawn(function()
            elevate()
            local sig, ECtrl, CS, skillSigs
            pcall(function()
                CS = require(Shared.Client.ClientSignals)
                sig = { toggle = CS:Get("AutoClickToggle"), manual = CS:Get("ManualAttack") }
                skillSigs = {
                    special = CS:Get("SpecialActivate"),
                    utility = CS:Get("UtilityActivate"),
                    haki    = CS:Get("HakiActivate"),
                }
                sig.toggle:Fire(true)
            end)
            pcall(function()
                ECtrl = require(Shared.Client.Controllers.EnemyController)
            end)
            elevate()

            local lastSkill = 0
            local clearStage = -1
            local lockedTargetCF = nil
            local lockedStage = nil
            local wasInBoss = false
            local bossReturnAt = nil
            local endRunAfterBossDone = false
            local noEnemySince = nil
            local lastSpawnNudge = 0

            local noclipConn
            pcall(function()
                noclipConn = RunService.Heartbeat:Connect(function()
                    pcall(function()
                        if isBankingSeeds then
                            local c = LocalPlayer.Character
                            local hum = c and c:FindFirstChildOfClass("Humanoid")
                            if hum and hum.PlatformStand then hum.PlatformStand = false end
                            return
                        end
                        local activeSeedCF = (seedPickupCF and os.clock() < seedPickupUntil) and seedPickupCF or nil
                        local desiredCF = activeSeedCF or lockedTargetCF
                        if not flags.walker or not desiredCF then return end
                        local c = LocalPlayer.Character
                        if not c then return end
                        local hrp = c:FindFirstChild("HumanoidRootPart")
                        local hum = c:FindFirstChildOfClass("Humanoid")
                        if hum and (farmPosMode == "Above" or farmPosMode == "Below") and not activeSeedCF then
                            hum.PlatformStand = true
                        elseif hum then
                            hum.PlatformStand = false
                        end
                        if hrp then
                            hrp.CFrame = desiredCF
                            hrp.AssemblyLinearVelocity = Vector3.zero
                            hrp.AssemblyAngularVelocity = Vector3.zero
                        end
                        if farmPosMode == "Below" and not activeSeedCF then
                            for _, part in ipairs(c:GetDescendants()) do
                                if part:IsA("BasePart") and part.CanCollide then
                                    part.CanCollide = false
                                end
                            end
                        end
                    end)
                end)
            end)

            local conn
            if CS then
                pcall(function()
                    conn = CS:Get("StageClearedLocal").Event:Connect(function(stIdx)
                        clearStage = math.max(clearStage, tonumber(stIdx) or 0)
                    end)
                end)
                elevate()
            end

            while flags.walker do
                elevate()
                local okTick, errTick = pcall(function()
                local hrp = (LocalPlayer.Character or {}).FindFirstChild and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                local inRaid   = LocalPlayer:GetAttribute("InRaid") == true
                local bossBusy = bossActive
                local curW = tonumber(LocalPlayer:GetAttribute("World")) or 1
                local attrRun = tonumber(LocalPlayer:GetAttribute("RunStage")) or 0
                if attrRun == 0 and clearStage > 0 then clearStage = 0 end
                local run = math.max(attrRun, clearStage)

                local stState
                if ECtrl and type(ECtrl.GetActiveStageState) == "function" then
                    pcall(function() stState = ECtrl.GetActiveStageState() end)
                    elevate()
                end
                if stState and tonumber(stState.stageIndex) then
                    if stState.spawned and (tonumber(stState.remaining) or 1) <= 0 and (tonumber(stState.alive) or 1) <= 0 then
                        run = math.max(run, stState.stageIndex)
                    else
                        run = math.max(run, stState.stageIndex - 1)
                    end
                end

                if inRaid or bossBusy then
                    wasInBoss = true
                    bossReturnAt = nil
                    endRunAfterBossDone = false
                    noEnemySince = nil
                    lockedTargetCF = nil
                    farmSet("Paused (boss)")
                elseif isBankingSeeds then
                    noEnemySince = nil
                    lockedTargetCF = nil
                    farmSet("Seed bag full -> Returning home to bank seeds...")
                elseif seedBank and isSeedBagFull() then
                    noEnemySince = nil
                    lockedTargetCF = nil
                    farmSet("Seed bag full -> Returning home to bank seeds...")
                    triggerSeedBank()
                elseif curW ~= farmWorld then
                    noEnemySince = nil
                    lockedTargetCF = nil
                    farmSet(("You are in world %d, target world %d (use Travel > Set World)"):format(curW, farmWorld))
                elseif farmLoop and run >= farmStage then
                    lockedTargetCF = nil
                    lockedStage = nil
                    noEnemySince = nil
                    if seedPickupCF and os.clock() < seedPickupUntil then
                        farmSet("Picking up drops before loop EndRun...")
                        task.wait(0.2)
                    else
                        farmSet(("Target stage %d cleared -> Looping (EndRun)..."):format(farmStage))
                        pcall(function()
                            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                            if hum then hum.PlatformStand = false end
                        end)
                        fire("EndRun")
                        local tLoop = os.clock()
                        while flags.walker and os.clock() - tLoop < 3.0 do
                            if (tonumber(LocalPlayer:GetAttribute("RunStage")) or 0) == 0 then
                                break
                            end
                            task.wait(0.15)
                        end
                        clearStage = 0
                        task.wait(0.35)
                    end
                elseif hrp then
                    local s = (run < farmStage) and (run + 1) or farmStage
                    local center = stageCenter(s)

                    if wasInBoss then
                        wasInBoss = false
                        bossReturnAt = os.clock()
                        endRunAfterBossDone = false
                        lockedTargetCF = nil
                        lockedStage = nil
                        noEnemySince = os.clock()
                        if ECtrl and ECtrl.Farm and type(ECtrl.Farm.start) == "function" and run >= farmStage and ECtrl.Farm.stage ~= run then
                            pcall(function() ECtrl.Farm.start(run) end)
                            elevate()
                        end
                    end

                    local enemyPos
                    if ECtrl and type(ECtrl.GetNearestAttackable) == "function" then
                        pcall(function()
                            local e = ECtrl.GetNearestAttackable(center)
                            if e then
                                enemyPos = e:GetPivot().Position
                            end
                        end)
                        elevate()
                    end
                    if not enemyPos then
                        local le = Workspace:FindFirstChild("_LocalEnemies")
                        if le then
                            local bestD = 90
                            for _, m in ipairs(le:GetChildren()) do
                                local okP, piv = pcall(function() return m:GetPivot().Position end)
                                if okP and piv then
                                    local d = (piv - center).Magnitude
                                    if d < bestD then bestD = d; enemyPos = piv end
                                end
                            end
                        end
                    end

                    if enemyPos then
                        noEnemySince = nil
                        bossReturnAt = nil
                        endRunAfterBossDone = false
                    else
                        noEnemySince = noEnemySince or os.clock()
                        if bossReturnAt and not endRunAfterBossDone and os.clock() - bossReturnAt >= 2.0 then
                            endRunAfterBossDone = true
                            bossReturnAt = nil
                            lockedTargetCF = nil
                            lockedStage = nil
                            farmSet("No mobs after boss -> EndRun 1x to reset...")
                            pcall(function()
                                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                                if hum then hum.PlatformStand = false end
                            end)
                            fire("EndRun")
                            local tEnd = os.clock()
                            while flags.walker and os.clock() - tEnd < 3.0 do
                                if (tonumber(LocalPlayer:GetAttribute("RunStage")) or 0) == 0 then
                                    break
                                end
                                task.wait(0.15)
                            end
                            clearStage = 0
                            task.wait(0.4)
                        elseif (os.clock() - noEnemySince >= 1.2 or (stState and not stState.spawned)) and os.clock() - lastSpawnNudge >= 5.0 then
                            lastSpawnNudge = os.clock()
                            lockedTargetCF = nil
                            lockedStage = nil
                            if ECtrl and ECtrl.Farm and type(ECtrl.Farm.start) == "function" and run >= farmStage and ECtrl.Farm.stage ~= run then
                                pcall(function() ECtrl.Farm.start(run) end)
                                elevate()
                            end
                            if stState and not stState.spawned then
                                hrp.CFrame = CFrame.new(center.X, center.Y + 3, center.Z + 45)
                                task.wait(0.18)
                                if flags.walker and LocalPlayer:GetAttribute("InRaid") ~= true and not bossActive then
                                    local h2 = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                                    if h2 then
                                        h2.CFrame = CFrame.new(center.X, center.Y + 3, center.Z - 5)
                                        task.wait(0.18)
                                    end
                                end
                            end
                        end
                    end

                    local anchor = enemyPos and Vector3.new(enemyPos.X, center.Y, enemyPos.Z) or center
                    local offset = (farmPosMode == "Above" and Vector3.new(0, farmPosDist, 0))
                                or (farmPosMode == "Below" and Vector3.new(0, -farmPosDist, 0))
                                or Vector3.new(0, 3, farmPosDist)
                    local target = anchor + offset

                    if not lockedTargetCF or lockedStage ~= s or (lockedTargetCF.Position - target).Magnitude > 1.5 then
                        lockedStage = s
                        if farmPosMode == "Above" or farmPosMode == "Below" then
                            lockedTargetCF = CFrame.new(target)
                        else
                            lockedTargetCF = CFrame.lookAt(target, Vector3.new(anchor.X, target.Y, anchor.Z - 1))
                        end
                    end

                    farmSet(("World %d | RunStage %d | fighting stage %d | target %d | mode: %s"):format(
                        curW, run, s, farmStage, farmPosMode))

                    applyHitbox(hrp)
                    if sig then pcall(function() sig.manual:Fire() end); elevate() end
                    fire("AttackTick", true)

                    if autoSkills and enemyPos and skillSigs and os.clock() - lastSkill > 0.8 then
                        lastSkill = os.clock()
                        pcall(function() skillSigs.special:Fire() end)
                        pcall(function() skillSigs.utility:Fire() end)
                        pcall(function() skillSigs.haki:Fire() end)
                        elevate()
                    end
                end
                end)
                elevate()
                if not okTick then
                    warn("[Pirate Hub] StageWalker tick error: " .. tostring(errTick))
                end
                task.wait(0.15)
            end
            if noclipConn then pcall(function() noclipConn:Disconnect() end) end
            pcall(function()
                local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
                if hum then hum.PlatformStand = false end
            end)
            if conn then pcall(function() conn:Disconnect() end) end
            if sig and not flags.click then pcall(function() sig.toggle:Fire(false) end); elevate() end
        end)
    end })

    local allowPaid = false
    Tabs.Farm:AddToggle("AllowPaid", { Title = "Allow PAID teleport (costs Wins each time)", Default = false,
        Callback = function(v) allowPaid = v end })

    local function goFarm()
        if not allowPaid then return false, "paid teleport disabled" end
        local best = bestOf(farmWorld)
        if farmStage > best then return false, "stage locked (best " .. best .. ")" end
        local curW = tonumber(LocalPlayer:GetAttribute("World")) or 1
        if curW ~= farmWorld then
            invoke("SetWorld", farmWorld)
            task.wait(1.5)
        end
        local ok, res = invoke("TeleportToStage", farmStage)
        return ok and type(res) == "table" and res.ok == true, res
    end

    Tabs.Farm:AddButton({ Title = "Teleport to stage once (paid)", Callback = function()
        local ok, why = goFarm()
        notify("Farm", ok and ("Stage " .. farmStage .. " world " .. farmWorld) or ("Not teleported: " .. tostring(why)))
    end })

    Tabs.Farm:AddToggle("FarmLock", { Title = "Watch farm stage (paid re-teleport max 1 per 60s)", Default = false, Callback = function(v)
        flags.farmlock = v
        if not v then farmSet("off"); return end
        task.spawn(function()
            elevate()
            local lastTry = -1e9
            while flags.farmlock do
                local inRaid   = LocalPlayer:GetAttribute("InRaid") == true
                local bossBusy = bossActive
                local curW = tonumber(LocalPlayer:GetAttribute("World")) or 1
                local run  = tonumber(LocalPlayer:GetAttribute("RunStage")) or 0
                local best = bestOf(farmWorld)
                if inRaid or bossBusy then
                    farmSet("Paused (boss)")
                else
                    local onTarget = (curW == farmWorld) and (run == farmStage or run == farmStage - 1)
                    farmSet(("Target world %d stage %d | now world %d RunStage %d | best %d | %s"):format(
                        farmWorld, farmStage, curW, run, best, allowPaid and "paid teleport ON" or "free mode"))
                    if not onTarget and allowPaid and os.clock() - lastTry > 60 then
                        lastTry = os.clock()
                        goFarm()
                    end
                end
                task.wait(0.5)
            end
        end)
    end })
end)

---------------------------------------------------------------- 3. SEEDS & BOSS SCROLL DROPS TAB
safeSection("Seeds/Drops", function()
    local seedWant     = { Common = true, Uncommon = true, Rare = true, Epic = true, Elemental = true, Beast = true, Ancient = true, Mythical = true, Divine = true }
    local seedTP       = true
    local seedRange    = 12
    local drops        = {}
    local stageLootPos = {}
    local scrollTokens = {}

    local function trackDrop(m)
        pcall(function()
            if m and m:IsA("Model") then
                if m.Name:sub(1, 9) == "SeedDrop_" then
                    drops[m] = true
                elseif m.Name:sub(1, 11) == "ScrollDrop_" then
                    local tok = m.Name:sub(12)
                    if tok ~= "" then scrollTokens[tok] = m end
                end
            end
        end)
    end

    -- Build all UI elements FIRST before spawning background listeners
    Tabs.Seeds:AddToggle("AutoScroll", { Title = "Auto Collect Boss Chest Scrolls (PickupScroll)", Default = true, Callback = function(v)
        flags.autoscroll = v
        if v then
            loop("autoscroll", function() return 0.35 end, function()
                local sf = Workspace:FindFirstChild("_ScrollDrops")
                if sf then
                    for _, m in ipairs(sf:GetChildren()) do
                        if m:IsA("Model") and m.Name:sub(1, 11) == "ScrollDrop_" then
                            local tok = m.Name:sub(12)
                            if tok ~= "" then scrollTokens[tok] = m end
                        end
                    end
                end
                for tok, ref in pairs(scrollTokens) do
                    if not flags.autoscroll then break end
                    local ok, res = invoke("PickupScroll", tok)
                    if ok and type(res) == "table" then
                        if res.ok or res.reason == "Expired" or res.reason == "Invalid" then
                            scrollTokens[tok] = nil
                            if typeof(ref) == "Instance" and ref.Parent then pcall(function() ref:Destroy() end) end
                        end
                    else
                        scrollTokens[tok] = nil
                    end
                end
            end)
        end
    end })

    local seedDD = Tabs.Seeds:AddDropdown("SeedRarity", {
        Title   = "Seed Rarities to collect",
        Values  = { "Common", "Uncommon", "Rare", "Epic", "Elemental", "Beast", "Ancient", "Mythical", "Divine" },
        Multi   = true,
        Default = { "Common", "Uncommon", "Rare", "Epic", "Elemental", "Beast", "Ancient", "Mythical", "Divine" },
    })
    seedDD:OnChanged(function(v) seedWant = v end)

    Tabs.Seeds:AddToggle("SeedTP", { Title = "Teleport to far seeds, then return", Default = true,
        Callback = function(v) seedTP = v end })
    Tabs.Seeds:AddSlider("SeedRange", { Title = "Pickup range (studs)", Min = 5, Max = 14, Default = 12, Rounding = 0,
        Callback = function(v) seedRange = v end })
    Tabs.Seeds:AddToggle("SeedBank", { Title = "Auto bank when bag full (EndRun)", Default = true,
        Callback = function(v) seedBank = v end })

    local function dropPos(m, token)
        if token and typeof(stageLootPos[token]) == "Vector3" then
            return stageLootPos[token]
        end
        -- Wait until the 0.75s parabola arc finishes (ProximityPrompt enabled or CrystalPivot exists) so we don't teleport 36 studs into the air
        local pp = m:FindFirstChildWhichIsA("ProximityPrompt", true)
        local cp = m:FindFirstChild("CrystalPivot")
        if pp and not pp.Enabled and not cp then
            return nil
        end
        local p = m:FindFirstChild("Body", true) or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
        return p and p.Position
    end

    Tabs.Seeds:AddToggle("AutoSeed", { Title = "Auto Collect Seeds", Default = false, Callback = function(v)
        flags.seed = v
        if not v then
            seedPickupCF = nil
            seedPickupUntil = 0
            return
        end
        loop("seed", function() return 0.12 end, function()
            if LocalPlayer:GetAttribute("InRaid") == true or bossActive or isBankingSeeds then return end
            if seedBank and isSeedBagFull() then
                triggerSeedBank()
                return
            end
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local sdFolder = Workspace:FindFirstChild("_SeedDrops")
            if sdFolder then
                for _, m in ipairs(sdFolder:GetChildren()) do
                    if m:IsA("Model") and m.Name:sub(1, 9) == "SeedDrop_" then
                        drops[m] = true
                    end
                end
            end

            local savedOriginCF = (not flags.walker) and hrp.CFrame or nil
            local didTeleport = false

            for m in pairs(drops) do
                if not flags.seed then break end
                if not m.Parent then
                    drops[m] = nil
                else
                    local id    = tonumber(m:GetAttribute("SeedId"))
                    local token = m:GetAttribute("Token")
                    local pos   = dropPos(m, token)
                    if id and token and pos and seedWant[rarityOf(id)] then
                        local near = (hrp.Position - pos).Magnitude <= seedRange
                        if not near and seedTP then
                            local tpCF = CFrame.new(pos + Vector3.new(0, 2.5, 0))
                            seedPickupCF = tpCF
                            seedPickupUntil = os.clock() + 0.8
                            hrp.CFrame = tpCF
                            didTeleport = true
                            task.wait(0.14)
                            near = true
                        end
                        if near then
                            local ok, res = invoke("PickupSeed", token)
                            if ok and type(res) == "table" and res.reason == "TooFar" and seedTP then
                                local tpCF = CFrame.new(pos + Vector3.new(0, 2.5, 0))
                                seedPickupCF = tpCF
                                seedPickupUntil = os.clock() + 0.8
                                hrp.CFrame = tpCF
                                task.wait(0.16)
                                ok, res = invoke("PickupSeed", token)
                            end
                            if ok and type(res) == "table" then
                                if res.ok then
                                    drops[m] = nil
                                    stageLootPos[token] = nil
                                    pcall(function() m:Destroy() end)
                                elseif res.reason == "Expired" or res.reason == "Invalid" then
                                    drops[m] = nil
                                    stageLootPos[token] = nil
                                elseif res.reason == "BagFull" and seedBank then
                                    triggerSeedBank()
                                    break
                                end
                            end
                        end
                    end
                end
            end

            seedPickupCF = nil
            seedPickupUntil = 0
            if didTeleport and savedOriginCF and not flags.walker and hrp.Parent then
                hrp.CFrame = savedOriginCF
            end
        end)
    end })

    -- Register drop & scroll hooks in a background thread so UI creation is never interrupted
    task.spawn(function()
        elevate()
        for _, d in ipairs(Workspace:GetDescendants()) do trackDrop(d) end
        Workspace.DescendantAdded:Connect(function(d) task.defer(trackDrop, d) end)
        pcall(function()
            Net:OnClient("StageLoot", function(payload)
                if type(payload) ~= "table" or type(payload.drops) ~= "table" then return end
                for _, item in ipairs(payload.drops) do
                    if type(item) == "table" and type(item.token) == "string" and typeof(item.position) == "Vector3" then
                        stageLootPos[item.token] = item.position
                    end
                end
            end)
        end)
        pcall(function()
            Net:OnClient("ScrollDrop", function(payload)
                if type(payload) ~= "table" or type(payload.tokens) ~= "table" then return end
                for _, tok in ipairs(payload.tokens) do
                    local s = tostring(tok or "")
                    if s ~= "" then
                        scrollTokens[s] = true
                        if flags.autoscroll then
                            task.spawn(function()
                                elevate()
                                task.wait(0.15)
                                local ok, res = invoke("PickupScroll", s)
                                if ok and type(res) == "table" and (res.ok or res.reason == "Expired" or res.reason == "Invalid") then
                                    scrollTokens[s] = nil
                                end
                            end)
                        end
                    end
                end
            end)
        end)
        elevate()
    end)
end)

---------------------------------------------------------------- 4. GARDEN (GREENHOUSE) TAB
safeSection("Garden", function()
    local gardenMode  = "Fruit"
    local gardenQty   = 10
    local gardenRar   = { Common = true, Uncommon = true, Rare = true, Epic = true, Elemental = true }
    local gardenInfo  = Tabs.Garden:AddParagraph({ Title = "Garden status", Content = "idle" })
    local function gardenSet(t)
        elevate()
        pcall(function() gardenInfo:SetDesc(t) end)
    end

    local gmDD = Tabs.Garden:AddDropdown("GardenMode", {
        Title   = "Grow Type (Fruit or Haki)",
        Values  = { "Fruit", "Haki (Armor)" },
        Default = "Fruit",
    })
    gmDD:OnChanged(function(v)
        gardenMode = (v == "Haki (Armor)") and "Armor" or "Fruit"
    end)

    local grDD = Tabs.Garden:AddDropdown("GardenRarities", {
        Title   = "Seed Rarities to use",
        Values  = { "Common", "Uncommon", "Rare", "Epic", "Elemental", "Beast", "Ancient", "Mythical", "Divine" },
        Multi   = true,
        Default = { "Common", "Uncommon", "Rare", "Epic", "Elemental" },
    })
    grDD:OnChanged(function(v) gardenRar = v end)

    Tabs.Garden:AddSlider("GardenQty", {
        Title    = "Seeds per grow (min 4, max 10)",
        Min      = 4,
        Max      = 10,
        Default  = 10,
        Rounding = 0,
        Callback = function(v) gardenQty = v end,
    })

    local function buildGardenSlots()
        local raw = LocalPlayer:GetAttribute("SeedsJson")
        if type(raw) ~= "string" or raw == "" then return nil, "No seeds in bag" end
        local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if not ok or type(decoded) ~= "table" then return nil, "Failed to read SeedsJson" end

        local curW = tonumber(LocalPlayer:GetAttribute("World")) or 1
        local seedW = (SeedCfg and SeedCfg.SeedWorldFor and SeedCfg.SeedWorldFor(curW)) or curW
        elevate()

        local list = {}
        for k, v in pairs(decoded) do
            local sid = tonumber(k)
            local cnt = math.floor(tonumber(v) or 0)
            if sid and cnt > 0 then
                local info = SeedCfg and SeedCfg.Get and SeedCfg.Get(sid)
                local w = (SeedCfg and SeedCfg.WorldOf and SeedCfg.WorldOf(sid)) or (info and info.World) or 1
                local rar = (info and info.Rarity) or rarityOf(sid)
                if w == seedW and gardenRar[rar] then
                    table.insert(list, { id = sid, count = cnt, val = (info and info.GrowValue) or sid, name = (info and info.Name) or ("Seed " .. sid) })
                end
            end
        end
        elevate()

        table.sort(list, function(a, b) return a.val < b.val end)

        local slots, total = {}, 0
        for _, item in ipairs(list) do
            if #slots >= 4 or total >= gardenQty then break end
            local take = math.min(item.count, gardenQty - total)
            if take > 0 then
                table.insert(slots, { seedId = item.id, count = take })
                total = total + take
            end
        end

        if total < 4 then
            return nil, ("Not enough matching seeds in World %d (have %d / need >= 4)"):format(seedW, total)
        end
        return slots, ("Using %d seeds across %d slot(s)"):format(total, #slots)
    end

    local function doGardenGrow()
        local slots, msg = buildGardenSlots()
        if not slots then
            gardenSet(msg)
            return false, msg
        end
        gardenSet(msg .. " -> Growing " .. gardenMode .. "...")
        local ok, res = invoke("GreenhouseGrow", slots, gardenMode, false)
        if ok and type(res) == "table" and res.ok then
            local got = (res.kind == "Armor") and ("Haki Armor: " .. tostring(res.armorId)) or ("Fruit #" .. tostring(res.fruitIndex))
            gardenSet("Success! Got " .. got .. " (" .. tostring(res.rarity or "") .. ")")
            return true, got
        else
            local reason = (type(res) == "table" and res.reason) or tostring(res)
            gardenSet("Grow failed: " .. tostring(reason))
            return false, reason
        end
    end

    Tabs.Garden:AddButton({ Title = "Grow Once Now", Callback = function()
        local _, info = doGardenGrow()
        notify("Garden", tostring(info))
    end })

    Tabs.Garden:AddToggle("AutoGarden", { Title = "Auto Grow Garden (loop)", Default = false, Callback = function(v)
        flags.garden = v
        if not v then gardenSet("idle"); return end
        loop("garden", function() return 2.5 end, doGardenGrow)
    end })
end)

---------------------------------------------------------------- 5. WORLD BOSS TAB
safeSection("World Boss", function()
    local bossValues  = { "Kaydo", "Mofia", "GrandLady" }
    local bossDefault = { "Kaydo", "Mofia", "GrandLady" }
    pcall(function()
        local BR = require(Shared.Configs.BossRotation)
        elevate()
        if type(BR) == "table" and type(BR.Order) == "table" then
            -- Clean any non-numeric keys in BR.Order and copy string names into separate tables
            for k in pairs(BR.Order) do
                if type(k) ~= "number" then BR.Order[k] = nil end
            end
            local cleanVal, cleanDef = {}, {}
            for _, b in ipairs(BR.Order) do
                if type(b) == "string" then
                    table.insert(cleanVal, b)
                    table.insert(cleanDef, b)
                end
            end
            if #cleanVal > 0 then
                bossValues  = cleanVal
                bossDefault = cleanDef
            end
        end
    end)
    elevate()

    local bossWant = {}
    for _, b in ipairs(bossValues) do bossWant[b] = true end
    local bossStand  = 6
    local bossSkills = true

    Tabs.Boss:AddSlider("BossStand", { Title = "Stand distance from boss (studs)", Min = 0, Max = 20, Default = 6, Rounding = 0,
        Callback = function(v) bossStand = v end })
    Tabs.Boss:AddToggle("BossSkills", { Title = "Auto Use All Skills on Boss (Special / Utility / Haki)", Default = true,
        Callback = function(v) bossSkills = v end })
    local bossStatus = Tabs.Boss:AddParagraph({ Title = "Status", Content = "idle" })
    local function setStatus(t)
        elevate()
        pcall(function() bossStatus:SetDesc(t) end)
    end
    local function bossTimeStr()
        local st = tostring(Workspace:GetAttribute("RaidState") or "Closed")
        local now = Workspace:GetServerTimeNow()
        if st == "Open" then
            local cur = tostring(Workspace:GetAttribute("RaidBossId") or "?")
            local endAt = tonumber(Workspace:GetAttribute("RaidPhaseEnd")) or 0
            local rem = math.max(0, math.ceil(endAt - now))
            return ("OPEN: %s (%02d:%02d left)"):format(cur, math.floor(rem / 60), rem % 60)
        else
            local nxt = tostring(Workspace:GetAttribute("RaidNextBossId") or "?")
            local openAt = tonumber(Workspace:GetAttribute("RaidNextOpenAt")) or tonumber(Workspace:GetAttribute("RaidPhaseEnd")) or 0
            local rem = math.max(0, math.ceil(openAt - now))
            return ("Next: %s in %02d:%02d (%ds)"):format(nxt, math.floor(rem / 60), rem % 60, rem)
        end
    end
    task.spawn(function()
        while task.wait(1) do
            if not flags.boss then
                setStatus("Idle | " .. bossTimeStr())
            end
        end
    end)

    local bossDD = Tabs.Boss:AddDropdown("BossSel", {
        Title   = "Bosses to fight",
        Multi   = true,
        Values  = bossValues,
        Default = bossDefault,
    })
    bossDD:OnChanged(function(v) bossWant = v end)

    Tabs.Boss:AddToggle("AutoBoss", { Title = "Auto World Boss (teleport, fight, return to farm)", Default = false, Callback = function(v)
        flags.boss = v
        if not v then bossActive = false; setStatus("idle"); return end
        task.spawn(function()
            elevate()
            local returnCF, entered, tries, lastTry, outSince = nil, false, 0, 0, nil
            local lastFarmCF, doneKey, raidEndedKey = nil, nil, nil
            local attackLoop = false
            local CFlags, DeathFx, raidEndConn
            pcall(function() CFlags = require(Shared.Client.CombatFlags) end)
            pcall(function() DeathFx = require(Shared.Client.RaidBossDeathFx) end)
            pcall(function()
                local CS = require(Shared.Client.ClientSignals)
                raidEndConn = CS:Get("RaidEnded").Event:Connect(function()
                    elevate()
                    raidEndedKey = tostring(Workspace:GetAttribute("RaidPhaseEnd"))
                    if flags.boss and LocalPlayer:GetAttribute("InRaid") == true then
                        fire("RaidRevealDone")
                        fire("RaidLeave")
                        if DeathFx and DeathFx.cancel then pcall(DeathFx.cancel) end
                        elevate()
                    end
                end)
            end)
            elevate()

            local function isBossDead(state, bossId, phaseKey, inRaidNow)
                if state ~= "Open" then return true end
                if raidEndedKey ~= nil and raidEndedKey == phaseKey then return true end
                local exitEnd = tonumber(Workspace:GetAttribute("RaidExitEnd")) or 0
                if exitEnd > Workspace:GetServerTimeNow() then return true end
                if inRaidNow and type(bossId) == "string" and bossId ~= "" then
                    local hpFrac = tonumber(Workspace:GetAttribute("Raid" .. bossId .. "HpFrac"))
                    if hpFrac ~= nil and hpFrac <= 0 then return true end
                end
                return false
            end

            while flags.boss do
                elevate()
                local okBoss, errBoss = pcall(function()
                local hrp, hum = hrpOf()
                local state    = Workspace:GetAttribute("RaidState")
                local bossId   = Workspace:GetAttribute("RaidBossId")
                local phaseKey = tostring(Workspace:GetAttribute("RaidPhaseEnd"))
                local inRaid   = LocalPlayer:GetAttribute("InRaid") == true
                local downed   = (LocalPlayer:GetAttribute("Downed") == true) or (CFlags and CFlags.Downed == true)
                local dead     = (not hum) or hum.Health <= 0 or downed
                local bossDead = isBossDead(state, bossId, phaseKey, inRaid)

                if (inRaid or entered) and bossDead then
                    fire("RaidRevealDone")
                    fire("RaidLeave")
                    if DeathFx and DeathFx.cancel then pcall(DeathFx.cancel) end
                    elevate()
                    doneKey = phaseKey
                    entered, outSince, tries, lastTry = false, nil, 0, 0
                    setStatus("Boss defeated -> Left room immediately, back to farm")
                    local back = returnCF or lastFarmCF
                    if hrp and back then hrp.CFrame = back end
                    local waitLeave = os.clock()
                    while flags.boss and LocalPlayer:GetAttribute("InRaid") == true and os.clock() - waitLeave < 1.2 do
                        task.wait(0.1)
                        fire("RaidLeave")
                    end
                    local nhrp = hrpOf()
                    if nhrp and back then nhrp.CFrame = back end
                    returnCF = nil
                    bossActive = false
                elseif inRaid and dead then
                    fire("RaidRevealDone")
                    fire("RaidLeave")
                    entered, outSince, tries, lastTry = false, nil, 0, 0
                    bossActive = true
                    setStatus("Died in boss -> Re-entering boss room immediately...")
                    local waitOut = os.clock()
                    while flags.boss and (LocalPlayer:GetAttribute("InRaid") == true or LocalPlayer:GetAttribute("Downed") == true) and os.clock() - waitOut < 1.5 do
                        task.wait(0.1)
                        fire("RaidLeave")
                    end
                    if CFlags then CFlags.Downed = false end
                    local nhrp, nhum = hrpOf()
                    if nhrp and nhum and nhum.Health > 0 and not isBossDead(Workspace:GetAttribute("RaidState"), bossId, phaseKey, false) and bossWant[bossId] then
                        local zone = RaidCfg and RaidCfg.PortalNow and RaidCfg.PortalNow()
                        elevate()
                        if zone then
                            nhrp.CFrame = zone * CFrame.new(0, 3, 0)
                            fire("RaidEnter")
                            lastTry = os.clock()
                            tries = 1
                        end
                    end
                elseif hrp and hum and not dead then
                    if inRaid then
                        bossActive = true
                        if not returnCF then returnCF = lastFarmCF end
                        entered, outSince = true, nil
                        setStatus("Fighting boss: " .. tostring(bossId))
                        local bossPos = Workspace:GetAttribute("Raid" .. tostring(bossId) .. "Pos")
                        if bossId == "Mofia" and Workspace:GetAttribute("RaidRozAlive") == true then
                            local rozPos = Workspace:GetAttribute("RaidRozPos")
                            if typeof(rozPos) == "Vector3" then bossPos = rozPos end
                        end
                        if typeof(bossPos) ~= "Vector3" then
                            local cfg = RaidCfg and RaidCfg.ArenaFor and RaidCfg.ArenaFor(bossId)
                            elevate()
                            bossPos = cfg and cfg.Center or nil
                        end
                        if bossPos then
                            local target = bossPos + Vector3.new(0, 3, bossStand)
                            if (hrp.Position - target).Magnitude > bossStand + 8 then
                                hrp.CFrame = CFrame.lookAt(target, bossPos)
                            end
                        end
                        if not attackLoop then
                            attackLoop = true
                            task.spawn(function()
                                elevate()
                                local sig, skillSigs
                                local lastBossSkill = 0
                                pcall(function()
                                    local CS = require(Shared.Client.ClientSignals)
                                    sig = { toggle = CS:Get("AutoClickToggle"), manual = CS:Get("ManualAttack") }
                                    skillSigs = {
                                        special = CS:Get("SpecialActivate"),
                                        utility = CS:Get("UtilityActivate"),
                                        haki    = CS:Get("HakiActivate"),
                                    }
                                    sig.toggle:Fire(true)
                                end)
                                elevate()
                                while flags.boss and LocalPlayer:GetAttribute("InRaid") == true and LocalPlayer:GetAttribute("Downed") ~= true and not isBossDead(Workspace:GetAttribute("RaidState"), Workspace:GetAttribute("RaidBossId"), tostring(Workspace:GetAttribute("RaidPhaseEnd")), true) do
                                    if sig then pcall(function() sig.manual:Fire() end); elevate() end
                                    fire("AttackTick", true)
                                    if bossSkills and skillSigs and os.clock() - lastBossSkill > 0.8 then
                                        lastBossSkill = os.clock()
                                        pcall(function() skillSigs.special:Fire() end)
                                        pcall(function() skillSigs.utility:Fire() end)
                                        pcall(function() skillSigs.haki:Fire() end)
                                        elevate()
                                    end
                                    task.wait(math.max(clickRate, 0.1))
                                end
                                if sig and not flags.click then pcall(function() sig.toggle:Fire(false) end); elevate() end
                                attackLoop = false
                            end)
                        end
                    elseif state == "Open" and not bossDead and bossWant[bossId] and not entered and doneKey ~= phaseKey then
                        bossActive = true
                        local zone = RaidCfg and RaidCfg.PortalNow and RaidCfg.PortalNow()
                        elevate()
                        if zone then
                            returnCF = returnCF or lastFarmCF or hrp.CFrame
                            hrp.CFrame = zone * CFrame.new(0, 3, 0)
                            if os.clock() - lastTry > 0.4 then
                                lastTry = os.clock(); tries = tries + 1
                                fire("RaidEnter")
                            end
                            setStatus("Teleport to portal: " .. tostring(bossId) .. " (try " .. tries .. ")")
                            if tries >= 30 then
                                hrp.CFrame = returnCF; returnCF, tries = nil, 0
                                entered = true
                                doneKey = phaseKey
                                bossActive = false
                                setStatus("Could not enter boss, back to farm")
                            end
                        end
                    else
                        if entered and (bossDead or not bossWant[bossId] or inRaid == false) then
                            outSince = outSince or os.clock()
                            if os.clock() - outSince > 0.3 then
                                local back = returnCF or lastFarmCF
                                if back then hrp.CFrame = back end
                                doneKey = phaseKey
                                returnCF, tries, entered, outSince = nil, 0, false, nil
                                bossActive = false
                                setStatus("Back to farm, waiting for next boss")
                            end
                        elseif state ~= "Open" or bossDead then
                            entered, tries = false, 0
                            bossActive = false
                            setStatus("Waiting | " .. bossTimeStr())
                        end
                        if not entered and not bossActive then lastFarmCF = hrp.CFrame end
                    end
                else
                    if not inRaid and entered then
                        entered, outSince, tries, lastTry = false, nil, 0, 0
                        if bossDead or not bossWant[bossId] then
                            bossActive, returnCF = false, nil
                        end
                    end
                end
                end)
                elevate()
                if not okBoss then
                    warn("[Pirate Hub] AutoBoss tick error: " .. tostring(errBoss))
                end
                task.wait(0.15)
            end
            if raidEndConn then pcall(function() raidEndConn:Disconnect() end) end
        end)
    end })
end)

safeSection("Summon", function()
    local SummonCfg
    pcall(function() SummonCfg = require(Shared.Configs.SummonConfig) end)
    elevate()

    local summonStatus = Tabs.Summon:AddParagraph({ Title = "Summon Status", Content = "idle" })
    local totalRolls = 0
    local lastGot = "none"

    local function updateSummonStatus(msg)
        local scrolls = tonumber(LocalPlayer:GetAttribute("Scrolls")) or 0
        pcall(function()
            summonStatus:SetDesc(("Scrolls: %d | Rolls: %d | Last: %s | %s"):format(scrolls, totalRolls, lastGot, msg or "idle"))
        end)
    end
    updateSummonStatus("idle")

    local summonMode = "Auto (x10 if >=10 else x1)"
    Tabs.Summon:AddDropdown("SummonMode", {
        Title = "Summon Mode",
        Values = { "Auto (x10 if >=10 else x1)", "x10 Only", "x1 Only" },
        Default = "Auto (x10 if >=10 else x1)",
        Callback = function(v) summonMode = v end
    })

    local stopGrade = "None"
    Tabs.Summon:AddDropdown("SummonStopGrade", {
        Title = "Stop Auto Summon on Grade",
        Values = { "None", "A", "S", "SS", "SSS", "RAID", "EXCLUSIVE" },
        Default = "None",
        Callback = function(v) stopGrade = v end
    })

    local autoEquipSummons = false
    Tabs.Summon:AddToggle("SummonEquipBest", {
        Title = "Auto Equip Best Summons",
        Default = false,
        Callback = function(v) autoEquipSummons = v end
    })

    local summonDelay = 0.4
    Tabs.Summon:AddSlider("SummonDelay", {
        Title = "Summon Delay (s)",
        Default = 0.4, Min = 0.2, Max = 3.0, Rounding = 1,
        Callback = function(v) summonDelay = v end
    })

    local function doSummonOnce(count)
        local ok, res = invoke("Summon", count)
        if ok and type(res) == "table" and res.ok and type(res.results) == "table" then
            totalRolls = totalRolls + #res.results
            local summary = {}
            local hitStop = false
            local stopIdx = (stopGrade ~= "None" and SummonCfg and SummonCfg.GradeIndex) and SummonCfg.GradeIndex(stopGrade) or nil
            elevate()
            for _, item in ipairs(res.results) do
                local g = tostring(item.g or "?")
                local id = tostring(item.id or item.name or "?")
                table.insert(summary, id .. "[" .. g .. "]")
                if stopIdx and SummonCfg and SummonCfg.GradeIndex then
                    if SummonCfg.GradeIndex(g) >= stopIdx then
                        hitStop = true
                    end
                end
            end
            elevate()
            lastGot = table.concat(summary, ", ")
            if #lastGot > 60 then lastGot = lastGot:sub(1, 57) .. "..." end
            if autoEquipSummons then
                invoke("EquipBestSummons")
            end
            updateSummonStatus(hitStop and ("Stopped on grade >= " .. stopGrade) or "ok")
            return true, hitStop, nil
        end
        local reason = (type(res) == "table" and res.reason) or "failed"
        updateSummonStatus("Failed: " .. tostring(reason))
        return false, false, reason
    end

    local autoSummonToggle
    autoSummonToggle = Tabs.Summon:AddToggle("AutoSummon", {
        Title = "Auto Summon",
        Default = false,
        Callback = function(v)
            flags.summon = v
            if not v then updateSummonStatus("off"); return end
            task.spawn(function()
                elevate()
                while flags.summon do
                    local scrolls = tonumber(LocalPlayer:GetAttribute("Scrolls")) or 0
                    local multiCount = (SummonCfg and SummonCfg.MultiCount) or 10
                    local count = 1
                    if summonMode == "x10 Only" then
                        if scrolls < multiCount then
                            updateSummonStatus("Waiting for " .. multiCount .. " Scrolls...")
                            task.wait(1)
                            continue
                        end
                        count = multiCount
                    elseif summonMode == "x1 Only" then
                        if scrolls < 1 then
                            updateSummonStatus("Out of Scrolls")
                            flags.summon = false
                            pcall(function() autoSummonToggle:SetValue(false) end)
                            break
                        end
                        count = 1
                    else
                        if scrolls < 1 then
                            updateSummonStatus("Out of Scrolls")
                            flags.summon = false
                            pcall(function() autoSummonToggle:SetValue(false) end)
                            break
                        end
                        count = (scrolls >= multiCount) and multiCount or 1
                    end

                    local ok, hitStop, reason = doSummonOnce(count)
                    if hitStop then
                        flags.summon = false
                        pcall(function() autoSummonToggle:SetValue(false) end)
                        notify("Summon", "Stopped on grade >= " .. stopGrade)
                        break
                    end
                    if not ok and (reason == "NoScrolls" or reason == "NoSlots") then
                        flags.summon = false
                        pcall(function() autoSummonToggle:SetValue(false) end)
                        notify("Summon", tostring(reason))
                        break
                    end
                    task.wait(math.max(summonDelay, 0.2))
                end
            end)
        end
    })

    Tabs.Summon:AddButton({ Title = "Summon x1", Callback = function()
        task.spawn(function()
            elevate()
            doSummonOnce(1)
        end)
    end })

    Tabs.Summon:AddButton({ Title = "Summon x10", Callback = function()
        task.spawn(function()
            elevate()
            local multiCount = (SummonCfg and SummonCfg.MultiCount) or 10
            doSummonOnce(multiCount)
        end)
    end })

    Tabs.Summon:AddButton({ Title = "Equip Best Summons", Callback = function()
        task.spawn(function()
            elevate()
            local ok = invoke("EquipBestSummons")
            notify("Summon", ok and "Equipped best summons" or "Failed to equip best")
        end)
    end })
end)

---------------------------------------------------------------- 6. REWARDS & CODES TAB
safeSection("Rewards", function()
    local function claimAll()
        fire("ClaimDailyReward")
        fire("ClaimGroupReward")
        fire("ClaimOfflineReward")
        fire("ClaimAllSeasonRewards")
    end

    Tabs.Rewards:AddButton({ Title = "Claim all now", Description = "Daily / Group / Offline / Season Pass", Callback = function()
        claimAll(); notify("Rewards", "Claim requests sent")
    end })

    Tabs.Rewards:AddToggle("AutoClaim", { Title = "Auto claim rewards (every 60s)", Default = false, Callback = function(v)
        flags.claim = v
        if v then loop("claim", function() return 60 end, claimAll) end
    end })

    local knownCodes = { "WORLD4", "WORLD5", "GRANDLADY", "UPDATE4", "WORLD3", "MOFIA", "KAYDO", "RELEASE" }
    Tabs.Rewards:AddButton({
        Title = "Redeem All Update Codes",
        Description = "WORLD4, WORLD5, GRANDLADY, etc.",
        Callback = function()
            task.spawn(function()
                elevate()
                local okCount = 0
                for _, code in ipairs(knownCodes) do
                    local ok, res = invoke("RedeemCode", code)
                    if ok and type(res) == "table" and res.ok then
                        okCount += 1
                    end
                    task.wait(0.25)
                end
                notify("Codes", ("Finished redeeming %d codes (%d new redeemed)"):format(#knownCodes, okCount))
            end)
        end
    })

    local customCode = ""
    local codeInput = Tabs.Rewards:AddInput("CustomCodeInput", {
        Title = "Custom Code",
        Default = "",
        Placeholder = "Enter code...",
        Numeric = false,
        Finished = false,
        Callback = function(v) customCode = tostring(v or "") end,
    })
    Tabs.Rewards:AddButton({ Title = "Redeem Custom Code", Callback = function()
        local c = (codeInput and codeInput.Value) or customCode
        if type(c) ~= "string" or c == "" then
            notify("Code", "Please enter a code first")
            return
        end
        local ok, res = invoke("RedeemCode", c)
        local msg = (ok and type(res) == "table" and (res.ok and "Success!" or tostring(res.reason or "Failed"))) or tostring(res)
        notify("Redeem: " .. c, msg)
    end })

    local adminDrops = {}

    Tabs.Rewards:AddToggle("AutoAdminMeteors", { Title = "Auto Claim Live Event Meteors (AdminShowClaim)", Default = true, Callback = function(v)
        flags.adminmeteor = v
        if not v then return end
        task.spawn(function()
            elevate()
            if Workspace:GetAttribute("AS_Active") == true then
                local ok, res = invoke("AdminShowSync")
                if ok and type(res) == "table" then
                    for _, d in ipairs(res) do
                        if type(d) == "table" and type(d.id) == "string" then
                            adminDrops[d.id] = d
                        end
                    end
                end
            end
            while flags.adminmeteor do
                local now = Workspace:GetServerTimeNow()
                local fxFolder = Workspace:FindFirstChild("_AdminShowFx")
                if fxFolder then
                    for _, ch in ipairs(fxFolder:GetChildren()) do
                        if ch:IsA("Model") and ch.Name:sub(1, 7) == "Meteor_" then
                            local mid = ch.Name:sub(8)
                            if mid ~= "" and not adminDrops[mid] then
                                local okP, piv = pcall(function() return ch:GetPivot().Position end)
                                if okP and piv then
                                    adminDrops[mid] = { id = mid, pos = piv, landAt = 0, expireAt = now + 60 }
                                end
                            end
                        end
                    end
                end
                local hrp = hrpOf()
                local inRaid = LocalPlayer:GetAttribute("InRaid") == true
                if hrp and not inRaid then
                    for id, d in pairs(adminDrops) do
                        if not flags.adminmeteor then break end
                        if (tonumber(d.expireAt) or 0) > 0 and now > tonumber(d.expireAt) then
                            adminDrops[id] = nil
                        elseif now >= (tonumber(d.landAt) or 0) and typeof(d.pos) == "Vector3" then
                            local back = hrp.CFrame
                            hrp.CFrame = CFrame.new(d.pos + Vector3.new(0, 2, 0))
                            task.wait(0.12)
                            fire("AdminShowClaim", id)
                            task.wait(0.08)
                            hrp.CFrame = back
                            adminDrops[id] = nil
                        end
                    end
                end
                task.wait(0.5)
            end
        end)
    end })

    -- Register AdminShowDrops listener in background thread so main UI thread never loses Plugin capability
    task.spawn(function()
        elevate()
        pcall(function()
            Net:OnClient("AdminShowDrops", function(payload)
                if type(payload) ~= "table" then return end
                if payload.clear then
                    table.clear(adminDrops)
                    return
                end
                if type(payload.add) == "table" then
                    for _, d in ipairs(payload.add) do
                        if type(d) == "table" and type(d.id) == "string" then
                            adminDrops[d.id] = d
                        end
                    end
                end
                if type(payload.claimed) == "string" then adminDrops[payload.claimed] = nil end
                if type(payload.gone) == "string" then adminDrops[payload.gone] = nil end
            end)
        end)
        elevate()
    end)
end)

---------------------------------------------------------------- 7. UPGRADE TAB
safeSection("Upgrade", function()
    local upgradeKeys = { "SeedCap", "Luck", "Train" }
    local selected    = { SeedCap = true, Luck = true, Train = true }

    local up = Tabs.Upgrade:AddDropdown("UpgradeSel", {
        Title   = "Upgrades",
        Values  = { "SeedCap", "Luck", "Train" },
        Multi   = true,
        Default = { "SeedCap", "Luck", "Train" },
    })
    up:OnChanged(function(v) selected = v end)

    Tabs.Upgrade:AddToggle("AutoUpgrade", { Title = "Auto Buy Upgrade", Default = false, Callback = function(v)
        flags.upgrade = v
        if v then loop("upgrade", function() return 1.5 end, function()
            for _, k in ipairs(upgradeKeys) do
                if selected[k] then invoke("BuyUpgrade", k) end
            end
        end) end
    end })
end)

---------------------------------------------------------------- 8. TRAVEL TAB
safeSection("Travel", function()
    local world = 1
    local wd = Tabs.Travel:AddDropdown("World", { Title = "World", Values = { "1", "2", "3", "4", "5" }, Default = 1 })
    wd:OnChanged(function(v) world = tonumber(v) or 1 end)
    Tabs.Travel:AddButton({ Title = "Set World", Callback = function()
        local ok, res = invoke("SetWorld", world)
        notify("SetWorld", ok and "Sent" or tostring(res))
    end })
end)

---------------------------------------------------------------- 9. MISC TAB
safeSection("Misc", function()
    local function doAntiAfk()
        elevate()
        pcall(function()
            local cam = Workspace.CurrentCamera
            if cam then
                VirtualUser:CaptureController()
                VirtualUser:Button2Down(Vector2.new(0, 0), cam.CFrame)
                task.wait(0.05)
                VirtualUser:Button2Up(Vector2.new(0, 0), cam.CFrame)
            end
        end)
        pcall(function()
            local vim = game:GetService("VirtualInputManager")
            vim:SendKeyEvent(true, Enum.KeyCode.Unknown, false, game)
            vim:SendKeyEvent(false, Enum.KeyCode.Unknown, false, game)
        end)
    end
    local function disableIdledConns()
        if type(getconnections) == "function" then
            pcall(function()
                for _, c in ipairs(getconnections(LocalPlayer.Idled)) do
                    if c.Function ~= doAntiAfk and type(c.Disable) == "function" then
                        c:Disable()
                    end
                end
            end)
        end
    end
    Tabs.Misc:AddToggle("AntiAFK", { Title = "Anti-AFK", Default = true, Callback = function(v)
        flags.afk = v
        if v then disableIdledConns() end
    end })
    disableIdledConns()
    LocalPlayer.Idled:Connect(function()
        if flags.afk then
            doAntiAfk()
        end
    end)
    task.spawn(function()
        while not uiUnloaded do
            task.wait(60)
            if flags.afk then
                doAntiAfk()
            end
        end
    end)
    flags.afk = true

    Tabs.Misc:AddButton({ Title = "Skip cutscene flags", Description = "BossSeen _Intro + MarkWorld2CutsceneSeen", Callback = function()
        fire("BossSeen", "_Intro")
        invoke("MarkWorld2CutsceneSeen")
        notify("Cutscene", "Sent")
    end })

    Tabs.Misc:AddSlider("FOV", { Title = "Camera FOV", Min = 40, Max = 120, Default = 70, Rounding = 0, Callback = function(v)
        flags.fov = v
    end })
    task.spawn(function()
        while task.wait(0.2) do
            if flags.fov and Workspace.CurrentCamera then
                Workspace.CurrentCamera.FieldOfView = flags.fov
            end
        end
    end)

    Tabs.Misc:AddButton({ Title = "Unload", Callback = function()
        elevate()
        uiUnloaded = true
        for k in pairs(flags) do flags[k] = false end
        pcall(function()
            if cachedECtrl and cachedECtrl._origApplyDamage then
                cachedECtrl.ApplyDamage = cachedECtrl._origApplyDamage
                cachedECtrl._pirateInstaHooked = nil
            end
        end)
        pcall(function() if toggleGui then toggleGui:Destroy() end end)
        Fluent:Destroy()
    end })
end)

elevate()
if flags.instahp then startInstaHpLoop() end
Window:SelectTab(1)
notify("Pirate Hub", "Loaded All Tabs! (RightCtrl = hide/show)")
