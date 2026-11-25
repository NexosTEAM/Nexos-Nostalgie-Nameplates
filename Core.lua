local _, ns = ...
ns.start[#ns.start+1] = function(...)

local addonName = ...
if NexosNostalgieDB and NexosNostalgieDB.classicPlates == false then return end
local plates = setmetatable({}, { __mode = "k" })
local fillTexture = "Interface\\AddOns\\NexosNostalgieNameplates\\Media\\ResourceFill"
local function permitted(frame)
    if not frame then return false end
    local ok, forbidden = pcall(function() return frame:IsForbidden() end)
    return ok and not (issecretvalue and issecretvalue(forbidden)) and not forbidden
end
local function friendlyPlatesEnabled()
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local ok, value = pcall(get, "nameplateShowFriends")
    return ok and value == "1"
end
local function styleName(frame, unit)
    local name = frame.name or frame.Name
    if not name or not name.SetFont then return end
    pcall(function()
        local player = UnitIsPlayer(unit)
        if issecretvalue and issecretvalue(player) then return end
        -- Player names belong entirely to Blizzard in both modes.
        -- The native name CVars select Classic or class-colored rendering.
        if player then return end
        name:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
        name:SetShadowOffset(1, -1)
        name:SetShadowColor(0, 0, 0, 1)
    end)
end
local function disableClassColors()
    if InCombatLockdown() then return end
    local get = C_CVar and C_CVar.GetCVar or GetCVar
    local set = C_CVar and C_CVar.SetCVar or SetCVar
    if not get or not set then return end
    for _, key in ipairs({"nameplateShowFriendlyMinions", "nameplateShowFriendlyPets", "nameplateShowFriendlyGuardians", "nameplateShowFriendlyTotems"}) do
        pcall(function() if get(key) ~= nil and get(key) ~= "0" then set(key, "0") end end)
    end
    local enabled = friendlyPlatesEnabled() and "1" or "0"
    pcall(function() if get("nameplateShowFriendlyPlayers") ~= nil and get("nameplateShowFriendlyPlayers") ~= enabled then set("nameplateShowFriendlyPlayers", enabled) end end)
    for _, key in ipairs({"ShowClassColorInNameplate", "ShowClassColorInFriendlyNameplate", "UnitNameFriendlyPlayerNameClassColor"}) do
        pcall(function() if get(key) ~= nil and get(key) ~= enabled then set(key, enabled) end end)
    end
    -- Prefer native world-space friendly names over compact friendly plates.
    for _, key in ipairs({"UnitNameFriendlyPlayerName", "UnitNameFriendlyPlayerGuild", "UnitNameFriendlyPlayerTitle", "UnitNameFriendlyNPCName"}) do
        pcall(function() if get(key) ~= nil and get(key) ~= "1" then set(key, "1") end end)
    end
end
local function border(parent)
    local t = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    t:SetTexture("Interface\\AddOns\\NexosNostalgieNameplates\\Media\\ClassicPlateBorder")
    t:SetPoint("TOPLEFT", parent, "TOPLEFT", -4, 5)
    t:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 4, -5)
    return {t}
end
local function friendlyNPC(unit)
    local ok, result = pcall(function()
        local player, friendly = UnitIsPlayer(unit), UnitIsFriend("player", unit)
        if issecretvalue and (issecretvalue(player) or issecretvalue(friendly)) then return false end
        return not player and friendly
    end)
    return ok and result
end
local function npcTitle(unit)
    if type(UnitSubName)=="function" then
        local ok,v=pcall(UnitSubName,unit)
        if ok and not (issecretvalue and issecretvalue(v)) and type(v)=="string" and v~="" then return v end
    end
    if C_TooltipInfo and C_TooltipInfo.GetUnit then
        local ok,v=pcall(function()
            local data=C_TooltipInfo.GetUnit(unit)
            local line=data and data.lines and data.lines[2]
            if not line then return end
            local t=line.leftText
            if issecretvalue and issecretvalue(t) then return end
            if type(t)~="string" or t=="" then return end
            local types=Enum and Enum.TooltipDataLineType
            if types and types.UnitTitle and line.type==types.UnitTitle then return t end
            -- Generic subtitle lines precede the level line on clients without UnitTitle.
            if types and types.None and line.type==types.None and not t:find("%d") and not t:find("[Pp][Vv][Pp]") then return t end
        end)
        if ok then return v end
    end
end
local function restoreBar(bar, state)
    if state.bg then state.bg:Show() end
    local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture() or bar.barTexture
    if texture then texture:SetTexture(fillTexture) end
    if state.container and state.container.SetHeight then state.container:SetHeight(10) end
    if bar.SetHeight then bar:SetHeight(10) end
    for _, key in ipairs({"bgTexture", "selectedBorder", "deselectedOverlay"}) do
        if bar[key] then bar[key]:SetAlpha(0) end
    end
    for _, edge in ipairs(state.edges) do edge:Show() end
end
-- Use the client world-name font object where available; keep a readable fallback.
local function classicWorldFont(label)
    local font = _G.WorldFrameNameFont or _G.SystemFont_NamePlate or _G.GameFontNormal
    if font and font.GetFont then
        local path, size = font:GetFont()
        if path then label:SetFont(path, math.max(14, size or 14), "") end
    else
        label:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    end
    label:SetShadowColor(0,0,0,1)
    label:SetShadowOffset(1,-1)
    if label.SetSpacing then label:SetSpacing(0) end
    label:SetJustifyH("CENTER")
end
local function classicNPC(bar, frame, unit, state)
    if not InCombatLockdown() then restoreBar(bar, state) else
        if state.bg then state.bg:Show() end
    end
    local active = friendlyNPC(unit)
    if not state.gold then
        state.gold = bar:CreateTexture(nil, "OVERLAY", nil, 5)
        state.gold:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
        state.gold:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
        state.gold:SetTexture("Interface\\Buttons\\WHITE8X8")
        state.gold:SetAlpha(0)
        state.gold:Hide()
        state.level = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        state.level:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
        state.level:SetJustifyH("CENTER")
        state.level:SetPoint("CENTER", bar, "RIGHT", 17.5, 0)
        state.badge = bar:CreateTexture(nil, "OVERLAY", nil, 5)
        state.badge:SetTexture("Interface\\AddOns\\NexosNostalgieNameplates\\Media\\ClassicPlateBadge")
        state.badge:SetSize(28, 20)
        state.badge:SetPoint("CENTER", bar, "RIGHT", 16, 0)
        state.badge:Hide()
        state.level:SetTextColor(1, .82, 0)
        state.level:Hide(); if state.badge then state.badge:Hide() end
    end
    for _, edge in ipairs(state.edges) do
        edge:Show()
    end
    if active and not InCombatLockdown() then
        local name = frame.name or frame.Name
        if not state.label then
            state.label=bar:CreateFontString(nil,"OVERLAY")
            classicWorldFont(state.label)
            state.label:SetShadowOffset(1,-1)
            state.label:SetTextColor(0,1,0)
            state.title=bar:CreateFontString(nil,"OVERLAY")
            classicWorldFont(state.title)
            state.title:SetTextColor(0,1,0)
            state.title:SetShadowOffset(1,-1)
            state.title:SetPoint("BOTTOM",bar,"TOP",0,2)
        end
        local full=UnitName(unit)
        if not (issecretvalue and issecretvalue(full)) and type(full)=="string" then
            state.label:SetText(full)
            state.label:Show()
            if name then
                if state.nativeAlpha==nil then state.nativeAlpha=name:GetAlpha() end
                name:SetAlpha(0)
            end
        end
        local title=npcTitle(unit)
        if title and title~="" then
            state.title:SetText("<"..title:gsub("^<", ""):gsub(">$", "")..">")
            state.title:Show()
        else state.title:Hide() end
        state.label:ClearAllPoints()
        state.label:SetPoint("BOTTOM",state.title:IsShown() and state.title or bar,"TOP",0,2)
        local level = UnitLevel(unit)
        if not (issecretvalue and issecretvalue(level)) and type(level)=="number" then
            state.level:SetText(level > 0 and tostring(level) or "??")
            local color = level > 0 and GetQuestDifficultyColor and GetQuestDifficultyColor(level)
            if color then state.level:SetTextColor(color.r,color.g,color.b) else state.level:SetTextColor(1,.82,0) end
            state.level:Show(); state.badge:Show()
        else state.level:Hide(); if state.badge then state.badge:Hide() end end
    else
        local level = UnitLevel(unit)
        if not (issecretvalue and issecretvalue(level)) and type(level)=="number" then
            state.level:SetText(level > 0 and tostring(level) or "??")
            local color = level > 0 and GetQuestDifficultyColor and GetQuestDifficultyColor(level)
            if color then state.level:SetTextColor(color.r,color.g,color.b) else state.level:SetTextColor(1,.82,0) end
            state.level:Show(); state.badge:Show()
        else state.level:Hide(); if state.badge then state.badge:Hide() end end
        if state.label then state.label:Hide() end
        if state.nativeAlpha~=nil and state.name then state.name:SetAlpha(state.nativeAlpha); state.nativeAlpha=nil end
        if state.title then state.title:Hide() end
        local name = frame.name or frame.Name
        if name and state.namePoints then
            name:ClearAllPoints()
            for _, point in ipairs(state.namePoints) do name:SetPoint(unpack(point)) end
            state.namePoints=nil
        end
    end
end
local function skin(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not permitted(plate) then return end
    local frame = plate.UnitFrame
    if not permitted(frame) then return end
    local nativeOK, native = pcall(function()
        local player, friendly = UnitIsPlayer(unit), UnitIsFriend("player", unit)
        if issecretvalue and (issecretvalue(player) or issecretvalue(friendly)) then return false end
        return player and friendly
    end)
    if nativeOK and native then
        local c = frame.HealthBarsContainer
        local b = c and c.healthBar
        local state = b and plates[b]
        if state then
            if state.label then state.label:Hide() end
            if state.title then state.title:Hide() end
            if state.level then state.level:Hide(); if state.badge then state.badge:Hide() end end
            if state.nativeAlpha~=nil and state.name then state.name:SetAlpha(state.nativeAlpha); state.nativeAlpha=nil end
            for _,edge in ipairs(state.edges) do edge:Hide() end
            if state.bg then state.bg:Hide() end
            state.unit=nil
        end
        return
    end
    if not InCombatLockdown() then styleName(frame, unit) end
    local container = frame.HealthBarsContainer
    local bar = container and container.healthBar
    if not permitted(bar) or not bar.barTexture then return end
    if InCombatLockdown() and ((bar.IsProtected and bar:IsProtected()) or (frame.IsProtected and frame:IsProtected())) then return end
    if not plates[bar] then
        local function initialize()
            -- One-time changes only: never toggle the whole plate's visibility.
            bar.barTexture:SetTexture(fillTexture)
            if bar.bgTexture then bar.bgTexture:SetAlpha(0) end
            if bar.selectedBorder then bar.selectedBorder:SetAlpha(0) end
            if bar.deselectedOverlay then bar.deselectedOverlay:SetAlpha(0) end
            local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
            bg:SetAllPoints(bar)
            bg:SetColorTexture(0.13, 0.11, 0.075, 0.92)
            plates[bar] = {edges = border(bar), bg=bg}
        end
        if not pcall(initialize) then return end
    end
    -- Layout is applied once per visible unit, without OnUpdate loops.
    do
        pcall(function()
            if not InCombatLockdown() and container.SetHeight then container:SetHeight(10) end
            plates[bar].frame=frame
            plates[bar].container=container
            plates[bar].unit=unit
            plates[bar].name=frame.name or frame.Name
            classicNPC(bar, frame, unit, plates[bar])
            if frame.PlayerLevelDiffFrame then frame.PlayerLevelDiffFrame:SetAlpha(plates[bar].level and plates[bar].level:IsShown() and 0 or 1) end
            if frame.ClassificationFrame then frame.ClassificationFrame:SetAlpha(0) end
        end)
    end
end
local f = CreateFrame("Frame")
f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("CVAR_UPDATE")
f:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_REMOVED" then
        for bar,state in pairs(plates) do
            if state.unit == unit then
                if state.label then state.label:Hide() end
                if state.nativeAlpha~=nil and state.name then pcall(state.name.SetAlpha,state.name,state.nativeAlpha); state.nativeAlpha=nil end
                if state.title then state.title:Hide() end
                if state.level then state.level:Hide(); if state.badge then state.badge:Hide() end end
                local name=state.name
                if name and state.namePoints and not InCombatLockdown() then
                    pcall(function()
                        name:ClearAllPoints()
                        for _,point in ipairs(state.namePoints) do name:SetPoint(unpack(point)) end
                        state.namePoints=nil
                    end)
                end
                for _,edge in ipairs(state.edges) do edge:Hide() end
                if state.bg then state.bg:Hide() end
                if state.frame and state.frame.PlayerLevelDiffFrame then pcall(state.frame.PlayerLevelDiffFrame.SetAlpha,state.frame.PlayerLevelDiffFrame,1) end
                state.unit=nil
            end
        end
        return
    end
    if event == "CVAR_UPDATE" then
        if type(unit) ~= "string" or (unit:lower() ~= "nameplateshowfriends" and unit:lower() ~= "nameplateshowfriendlynpcs") then return end
        disableClassColors()
    end
    if event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_REGEN_ENABLED" then disableClassColors() end
    if event == "NAME_PLATE_UNIT_ADDED" then
        skin(unit)
        if C_Timer and C_Timer.After then C_Timer.After(0.1,function() if UnitExists(unit) then skin(unit) end end) end
    elseif C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, active = pcall(C_NamePlate.GetNamePlates)
        if ok and active then
            for _, plate in ipairs(active) do
                local frame = plate.UnitFrame
                if frame and frame.unit then skin(frame.unit) end
            end
        end
    end
end)

-- Refresh only visible friendly NPC labels, not player names or unit frames.
local elapsed=0
f:SetScript("OnUpdate",function(_,dt)
    elapsed=elapsed+dt
    if elapsed<0.5 then return end
    elapsed=0
    if InCombatLockdown() then return end
    for bar,state in pairs(plates) do
        if state.unit and permitted(bar) then
            pcall(function()
                local plate=C_NamePlate.GetNamePlateForUnit(state.unit)
                local frame=plate and plate.UnitFrame
                if frame and frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar==bar then
                    skin(state.unit)
                end
            end)
        end
    end
end)

end
