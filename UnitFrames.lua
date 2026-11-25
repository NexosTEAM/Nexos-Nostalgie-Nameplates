local _, ns = ...
ns.start[#ns.start+1] = function(...)
if NexosNostalgieDB and NexosNostalgieDB.classicFrames == false then return end
-- NexosTEAM: native unit-frame presentation, without replacing unit buttons or health values.
local media = 'Interface\\AddOns\\NexosNostalgieNameplates\\Media\\'
local fill = 'Interface\\TargetingFrame\\UI-StatusBar'
local states = setmetatable({}, {__mode='k'})
local function permitted(o)
    if not o then return false end
    local ok, allowed=pcall(function() return not o.IsForbidden or not o:IsForbidden() end)
    return ok and allowed
end
local function safe(o, method, ...)
    if InCombatLockdown and InCombatLockdown() then return false end
    if permitted(o) and o[method] then return pcall(o[method], o, ...) end
    return false
end
local function first(...) for i=1,select('#',...) do local v=select(i,...); if v then return v end end end
-- Never compare restricted anchor values, even outside combat.
local function accessible(...)
    if not issecretvalue then return true end
    for i=1,select('#',...) do
        if issecretvalue((select(i,...))) then return false end
    end
    return true
end
local function move(o, parent, x,y,w,h)
    if not o then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local point, relative, anchor, ox, oy = o:GetPoint(1)
    local count = o:GetNumPoints()
    if not accessible(point, relative, anchor, ox, oy, count) then return end
    if point~='TOPLEFT' or relative~=parent or anchor~='TOPLEFT' or ox~=x or oy~=-y or count~=1 then
        safe(o,'ClearAllPoints'); safe(o,'SetPoint','TOPLEFT',parent,'TOPLEFT',x,-y)
    end
    local width,height=o:GetWidth(),o:GetHeight()
    if w and h and accessible(width,height) and (math.abs(width-w)>0.01 or math.abs(height-h)>0.01) then safe(o,'SetSize',w,h) end
end
local function hide(o) safe(o,'SetAlpha',0) end
local function masks(t)
    if not t or not t.GetNumMaskTextures then return end
    local ok,n=safe(t,'GetNumMaskTextures'); if not ok then return end
    for i=n,1,-1 do local good,m=safe(t,'GetMaskTexture',i); if good and m then safe(t,'RemoveMaskTexture',m) end end
end
local function styleBar(b, health, selfPower)
    if not b then return end
    safe(b,'SetStatusBarTexture',(health or selfPower) and fill or (media..'ResourceFill'))
    local ok,t=safe(b,'GetStatusBarTexture'); if ok then masks(t) end
    if health then safe(b,'SetStatusBarColor',0,0.85,0) end
end
-- Restore resource tint after changing the native status-bar texture.
local powerBars = setmetatable({}, {__mode='k'})
local classicPower = {MANA={0,0,1}, RAGE={1,0,0}, ENERGY={1,1,0}, FOCUS={1,0.5,0.25}, RUNIC_POWER={0,0.82,1}}
local function updatePower(bar, unit)
    if not bar or not unit then return end
    pcall(function()
        local id, token, r, g, b = UnitPowerType(unit)
        if issecretvalue and (issecretvalue(id) or issecretvalue(token)) then return end
        local c = classicPower[token]
        if c then bar:SetStatusBarColor(c[1],c[2],c[3]); return end
        local native = PowerBarColor and (PowerBarColor[token] or PowerBarColor[id])
        if native then bar:SetStatusBarColor(native.r,native.g,native.b)
        elseif r and g and b then bar:SetStatusBarColor(r,g,b) end
    end)
end
-- Pet and focus use their own unit tokens and native resource bars.
local colorHooks = setmetatable({}, {__mode='k'})
local function bindPower(bar, unit)
    if not bar then return end
    powerBars[bar]=unit
    if not colorHooks[bar] then
        colorHooks[bar]=true
        local busy=false
        hooksecurefunc(bar,'SetStatusBarColor',function(self)
            if busy then return end
            busy=true
            updatePower(self,powerBars[self])
            busy=false
        end)
    end
    updatePower(bar,unit)
end
local selfTextureHooks = setmetatable({}, {__mode='k'})
local function bindSelfTexture(bar, unit)
    if selfTextureHooks[bar] then return end
    selfTextureHooks[bar]=true
    local busy=false
    hooksecurefunc(bar,'SetStatusBarTexture',function(self)
        if busy then return end
        busy=true
        local ok,err=pcall(function()
            local texture=self:GetStatusBarTexture()
            if InCombatLockdown and InCombatLockdown() then return end
            local path=texture and texture:GetTexture()
            if texture and accessible(path) and path~=fill then
                self:SetStatusBarTexture(fill)
            end
            if unit then updatePower(self,unit) else self:SetStatusBarColor(0,0.85,0) end
        end)
        busy=false
    end)
end
-- Optional models are independent of the native unit buttons. Keep the
-- square model inside the circular opening; never alter the existing mask.
local models = setmetatable({}, {__mode='k'})
local function portrait3D(frame, portrait, unit)
    if NexosNostalgieDB.portraits3D ~= true or not permitted(frame) or not permitted(portrait) then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local state=models[frame]
    if not state then
        local ok, model=pcall(CreateFrame,'PlayerModel',nil,frame)
        if not ok or not model then return end
        model:EnableMouse(false); model:Hide()
        local backdrop=frame:CreateTexture(nil,'ARTWORK',nil,2)
        backdrop:SetTexture(media..'PortraitBlack')
        backdrop:Hide()
        state={model=model,backdrop=backdrop}; models[frame]=state
    end
    local model=state.model
    local function fallback()
        state.guid=nil; state.bound=false; state.generation=(state.generation or 0)+1; model:Hide(); state.backdrop:Hide(); if state.portrait then safe(state.portrait,'SetAlpha',1) end
    end
    local ok, exists=pcall(UnitExists,unit)
    if not ok or not accessible(exists) or not exists then fallback(); return end
    local good,w,h=pcall(function() return portrait:GetWidth(),portrait:GetHeight() end)
    if not good or not accessible(w,h) or w<=0 or h<=0 then fallback(); return end
    local success=pcall(function()
        state.backdrop:ClearAllPoints(); state.backdrop:SetAllPoints(portrait)
        model:ClearAllPoints(); model:SetPoint('CENTER',portrait,'CENTER')
        local size=math.min(w,h)*0.97
        model:SetSize(size,size); model:SetFrameLevel(frame:GetFrameLevel()+1)
        -- Slight inset for the animated model; leave 2D unchanged.
        local guid
        if UnitGUID then
            local valid, value=pcall(UnitGUID,unit)
            if valid and accessible(value) then guid=value end
        end
        if not state.bound or state.guid~=guid or state.unit~=unit then
            state.generation=(state.generation or 0)+1
            local generation=state.generation
            local function frameHead()
                if state.generation~=generation or NexosNostalgieDB.portraits3D~=true then return end
                if InCombatLockdown and InCombatLockdown() then return end
                if not permitted(model) then return end
                -- Embedded camera zero is not necessarily a head camera.
                -- Use the generated portrait camera, not an authored model camera.
                if model.RefreshCamera then safe(model,'RefreshCamera') end
                safe(model,'SetPortraitZoom',1)
                safe(model,'SetCamDistanceScale',1)
                safe(model,'SetPortraitZoom',1)
            end
            -- Clear the previous asset before binding a different unit.
            safe(model,'SetScript','OnModelLoaded',nil)
            safe(model,'ClearModel')
            safe(model,'SetScript','OnModelLoaded',frameHead)
            model:SetUnit(unit)
            frameHead()
            if C_Timer and C_Timer.After then
                for _,delay in ipairs({0.05,0.2,0.5,1,2,4}) do
                    C_Timer.After(delay,function()
                        if state.generation~=generation or not model:IsShown() then return end
                        frameHead()
                    end)
                end
            end
            state.guid=guid; state.unit=unit; state.bound=true
        end
        if model.SetBackgroundColor then pcall(model.SetBackgroundColor,model,0,0,0,0) end
    end)
    if not success then fallback(); return end
    state.portrait=portrait
    if safe(portrait,'SetAlpha',0) then state.backdrop:Show(); model:Show() else fallback() end
end
-- During combat use native 2D portraits rather than risk stale models or
-- protected layout changes. These models are addon-owned and noninteractive.
local function suspendModels()
    for _,state in pairs(models) do
        state.generation=(state.generation or 0)+1
        state.guid=nil; state.bound=false
        pcall(state.model.Hide,state.model)
        pcall(state.backdrop.Hide,state.backdrop)
        if permitted(state.portrait) then pcall(state.portrait.SetAlpha,state.portrait,1) end
    end
end
local function refreshPetPower()
    local f=PetFrame
    if not f then return end
    local content=f.PetFrameContent
    local main=content and (content.PetFrameContentMain or content)
    local bar=first(f.ManaBar,f.manaBar,f.manabar,f.PowerBar,f.powerBar,
        main and main.ManaBarArea and main.ManaBarArea.ManaBar,
        main and main.ManaBar, _G.PetFrameManaBar)
    if bar then styleBar(bar,false); bindPower(bar,'pet') end
    local c=f.PetFrameContainer
    portrait3D(f,first(c and c.PetPortrait,c and c.Portrait,f.Portrait,f.portrait,_G.PetFramePortrait),'pet')
end
local function label(t, anchor, side)
    if not t or not anchor then return end
    safe(t,'ClearAllPoints'); safe(t,'SetPoint',side,anchor,side,side=='LEFT' and 2 or side=='RIGHT' and -2 or 0,0)
end
-- Independent Classic-style name strip and readable numeric overlays.
local function readable(v)
    return accessible(v) and v ~= nil
end
local function numbers(bar, unit, power)
    if not bar then return end
    local ok, value, maximum = pcall(function()
        if power then return UnitPower(unit), UnitPowerMax(unit) end
        return UnitHealth(unit), UnitHealthMax(unit)
    end)
    if not ok or not readable(value) or not readable(maximum) then
        if bar.nexosLeft then bar.nexosLeft:Hide(); bar.nexosRight:Hide() end
        return
    end
    if not bar.nexosLeft then return end
    bar.nexosLeft:SetText(maximum > 0 and string.format('%d%%', math.floor(value / maximum * 100 + 0.5)) or '')
    bar.nexosRight:SetText(tostring(value))
    bar.nexosLeft:Show(); bar.nexosRight:Show()
end
local numericBars = setmetatable({}, {__mode='k'})
local function attachNumbers(bar, unit, power)
    if not bar then return end
    if not bar.nexosLeft then
        bar.nexosLeft=bar:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
        bar.nexosRight=bar:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
        bar.nexosLeft:SetPoint('LEFT',bar,'LEFT',2,0)
        bar.nexosRight:SetPoint('RIGHT',bar,'RIGHT',-2,0)
    end
    numericBars[bar]={unit,power}
    numbers(bar,unit,power)
end
local function nameTint(s,unit)
    if not s.strip then return end
    pcall(function()
        local reaction=UnitReaction('player',unit)
        local player=UnitIsPlayer(unit)
        local friend=UnitIsFriend('player',unit)
        local enemy=UnitCanAttack('player',unit)
        local pvp=UnitIsPVP(unit)
        if readable(reaction) and reaction<=3 then s.strip:SetVertexColor(0.72,0.015,0.015,1); return end
        if not readable(player) or not readable(friend) or not readable(enemy) or not readable(pvp) then
            if readable(enemy) and enemy then s.strip:SetVertexColor(0.72,0.015,0.015,1)
            elseif readable(reaction) then if reaction==4 then s.strip:SetVertexColor(0.78,0.65,0,1) else s.strip:SetVertexColor(0,0.72,0,1) end end
            return
        end
        if player then
            if enemy and not friend then s.strip:SetVertexColor(0.72,0.015,0.015,1)
            elseif friend then
                if pvp then s.strip:SetVertexColor(0,0.72,0,1) else s.strip:SetVertexColor(0,0,0.78,1) end
            else s.strip:SetVertexColor(0.78,0.65,0,1) end
        elseif readable(reaction) then
            if reaction<=3 then s.strip:SetVertexColor(0.72,0.015,0.015,1)
            elseif reaction==4 then s.strip:SetVertexColor(0.78,0.65,0,1)
            else s.strip:SetVertexColor(0,0.72,0,1) end
        end
    end)
end
-- Use the client-provided legacy classification artwork, never external assets.
local function classificationArt(frame, container, state, unit, px, py, d)
    local ok, classification=pcall(UnitClassification,unit)
    if not ok or not readable(classification) then return end
    local suffix=({elite='Elite',worldboss='Elite',rare='Rare',rareelite='Rare-Elite'})[classification]
    -- Legacy assets contain the complete frame, not just a dragon. Keep the
    -- bar portion behind our opaque frame body; preserve the entire dragon.
    for _,owner in ipairs({container or frame,frame}) do
        for _,key in ipairs({'BossPortraitFrameTexture','BossPortraitTexture','ClassificationTexture','EliteTexture','RareTexture','FrameTextureBoss'}) do
            hide(owner[key])
        end
    end
    if not state.dragon then state.dragon=frame:CreateTexture(nil,'BACKGROUND',nil,-2) end
    if not suffix then state.dragon:Hide(); return end
    state.dragon:SetTexture('Interface\\TargetingFrame\\UI-TargetingFrame-'..suffix)
    -- Keep the complete left wing and align the legacy portrait opening.
    -- The frame body covers the residual legacy bar artwork.
    state.dragon:SetTexCoord(0.5,1,0,0.78125)
    move(state.dragon,frame,px-25,py-19,128,100)
    -- Mask only the legacy level badge embedded in the classification texture.
    -- The normal level badge and portrait use independent regions.
    if not state.dragonBadgeMask and frame.CreateMaskTexture and state.dragon.AddMaskTexture then
        local mask=frame:CreateMaskTexture(nil,'BACKGROUND')
        mask:SetTexture(media..'DragonBadgeMask','CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE')
        mask:SetAllPoints(state.dragon)
        state.dragon:AddMaskTexture(mask)
        state.dragonBadgeMask=mask
    end
    state.dragon:Show()

end
-- Target-only display bars: native values, independent fixed geometry.
local updateTargetDisplay
local function targetDisplay(s, frame, hp, mp, x, y, w, h)
    if not s.display then
        local host=CreateFrame('Frame',nil,frame)
        host:SetPoint('TOPLEFT',frame,'TOPLEFT',x,-y)
        host:SetSize(w,h*2+1)
        -- Separate strata from native unit-frame text containers, not just native bars.
        host:SetFrameStrata('HIGH')
        host:SetFrameLevel(math.max(frame:GetFrameLevel(),hp:GetFrameLevel(),mp and mp:GetFrameLevel() or 0)+12)
        host:EnableMouse(false)
        -- Cover native fill and text even when Blizzard restores their alpha in combat.
        local cover=host:CreateTexture(nil,'BACKGROUND',nil,-8)
        cover:SetAllPoints(host)
        cover:SetColorTexture(0.13,0.11,0.075,1)
        local function make(offset)
            local bar=CreateFrame('StatusBar',nil,host)
            bar:SetFrameStrata('HIGH'); bar:SetFrameLevel(host:GetFrameLevel()+1)
            bar:SetPoint('TOPLEFT',host,'TOPLEFT',0,-offset)
            bar:SetSize(w,h)
            bar:SetStatusBarTexture(fill)
            local bg=bar:CreateTexture(nil,'BACKGROUND',nil,-1)
            bg:SetAllPoints(); bg:SetColorTexture(0.035,0.035,0.035,1)
            bar.text=bar:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
            bar.text:SetPoint('CENTER'); bar.text:SetDrawLayer('OVERLAY',7); bar:EnableMouse(false)
            return bar
        end
        s.display={host=host,hp=make(0),mp=make(h+1)}
    end
    local d=s.display
    d.nativeHP=hp; d.nativeMP=mp
    d.refresh=function() updateTargetDisplay(s) end
    if not d.tick then
        d.tick=0
        d.host:SetScript('OnUpdate',function(_,dt)
            d.tick=d.tick+dt
            if d.tick>=0.10 then d.tick=0; d.refresh() end
        end)
    end
    -- Only hide the native visual regions during an out-of-combat layout pass.
    safe(hp,'SetAlpha',0)
    if mp then safe(mp,'SetAlpha',0) end
    local content=frame.TargetFrameContent
    local main=content and content.TargetFrameContentMain
    local owners={hp,mp or hp,main or hp,main and main.HealthBarsContainer or hp,frame}
    for _,owner in ipairs(owners) do
        if permitted(owner) then
            for _,key in ipairs({'LeftText','RightText','HealthBarText','ManaBarText','TextString','DeadText','UnconsciousText','HealthText','PowerText'}) do
                local ok,t=pcall(function() return owner[key] end)
                if ok and permitted(t) then hide(t) end
            end
        end
    end
    d.hp:SetStatusBarColor(0,0.85,0)
end
updateTargetDisplay=function(s)
    local d=s and s.display
    if not d then return end
    local function copy(bar,native,power)
        if not native then bar:Hide(); return end
        local ok=pcall(function()
            local lo,hi=native:GetMinMaxValues()
            local value=native:GetValue()
            bar:SetMinMaxValues(lo,hi); bar:SetValue(value)
            if power then
                updatePower(bar,'target')
                if readable(hi) and hi<=0 then bar:Hide(); return end
                if not native:IsShown() then bar:Hide(); return end
            end
            bar:Show()
            if readable(value) and readable(hi) then
                bar.text:SetText(tostring(math.floor(value+0.5))..' / '..tostring(math.floor(hi+0.5)))
            else
                local t=first(native.TextString,native.HealthBarText,native.ManaBarText)
                bar.text:SetText(t and t:GetText() or '')
            end
        end)
        if not ok then bar.text:SetText(''); bar:SetMinMaxValues(0,1); bar:SetValue(0) end
    end
    local okDead, dead = pcall(UnitIsDeadOrGhost, 'target')
    if okDead and readable(dead) and dead then
        d.hp:SetMinMaxValues(0,1)
        d.hp:SetValue(0)
        d.hp.text:SetText('Dead')
        d.hp.text:SetTextColor(1,1,1)
        d.hp:Show()
        d.mp.text:SetText('')
        d.mp:Hide()
        return
    end
    copy(d.hp,d.nativeHP,false); copy(d.mp,d.nativeMP,true)
end
-- Suppress native PvP artwork only, including nested client-specific regions.
local factionKeys = {'PvpBackgroundIcon','PvPBackgroundIcon','PVPBackgroundIcon','pvpBackgroundIcon','pvpIcon','pvpIndicator','PvpIndicator','PvPIndicator','PVPIndicator','PVPIcon','PvPIcon','PvpIcon','PVPTexture','PvPTexture','PVPBadge','PvPBadge','PvpBadge','PVPIconTexture','PvPIconTexture'}
local factionSuppressed = setmetatable({}, {__mode='k'})
local function suppressNativeEmblem(t)
    if not permitted(t) or not t.SetAlpha then return end
    if not factionSuppressed[t] then
        factionSuppressed[t]=true
        local busy=false
        hooksecurefunc(t,'SetAlpha',function(region,alpha)
            if busy or not accessible(alpha) or alpha==0 then return end
            if InCombatLockdown and InCombatLockdown() then return end
            busy=true; hide(region); busy=false
        end)
    end
    hide(t)
end
local function suppressFaction(s)
    if InCombatLockdown and InCombatLockdown() then return end
    local seen={}
    local function visit(o)
        if not permitted(o) or seen[o] then return end
        seen[o]=true
        for _,key in ipairs(factionKeys) do
            local t=o[key]
            if t and t~=s.faction then suppressNativeEmblem(t) end
        end
        local ok,regions=pcall(function() return {o:GetRegions()} end)
        if not ok then return end
        for _,t in ipairs(regions) do
            if t~=s.faction and permitted(t) then
                pcall(function()
                    if not t.GetTexture then return end
                    local tex=t:GetTexture()
                    local atlas=t.GetAtlas and t:GetAtlas()
                    if not accessible(tex,atlas) then return end
                    local key=((type(tex)=='string' and tex or '')..' '..(type(atlas)=='string' and atlas or '')):lower()
                    if key:find('pvp',1,true) and (key:find('alliance',1,true) or key:find('horde',1,true) or key:find('ffa',1,true) or key:find('badge',1,true) or key:find('icon',1,true)) then suppressNativeEmblem(t) end
                end)
            end
        end
    end
    -- Explicit portrait containers only; never traverse aura buttons or arbitrary children.
    local frame=s.frame
    if not permitted(frame) then return end
    visit(frame)
    for _,key in ipairs({'PlayerFrameContainer','TargetFrameContainer','PlayerFrameContent','TargetFrameContent','TextureFrame','PortraitFrame'}) do
        local owner=frame[key]
        if permitted(owner) then
            visit(owner)
            for _,sub in ipairs({'PlayerFrameContentMain','TargetFrameContentMain','PlayerFrameContentContextual','TargetFrameContentContextual','PortraitFrame','PortraitContainer','TextureFrame','PvpIconContainer','PvPIconContainer'}) do visit(owner[sub]) end
        end
    end
    if s.unit=='player' then suppressNativeEmblem(_G.PlayerPVPIcon) else suppressNativeEmblem(_G.TargetFrameTextureFramePVPIcon) end
end
local function updateFaction(s)
    if not s.faction or not s.unit then return end
    pcall(suppressFaction,s)
    local faction=UnitFactionGroup(s.unit)
    local flagged=UnitIsPVP(s.unit)
    local ffa=UnitIsPVPFreeForAll and UnitIsPVPFreeForAll(s.unit)
    if not accessible(faction,flagged,ffa) then return end
    if ffa then s.faction:SetTexture('Interface\\TargetingFrame\\UI-PVP-FFA')
    elseif flagged and (faction=='Alliance' or faction=='Horde') then
        s.faction:SetTexture('Interface\\TargetingFrame\\UI-PVP-'..faction)
    else s.faction:Hide(); return end
    s.faction:Show()
end
local function apply(frame, kind)
    if not frame then return end
    local player=kind=='player'; local small=kind=='small'
    local c=player and frame.PlayerFrameContainer or frame.TargetFrameContainer
    local content=player and frame.PlayerFrameContent or frame.TargetFrameContent
    local main=content and (content.PlayerFrameContentMain or content.TargetFrameContentMain)
    local hc=main and main.HealthBarsContainer
    local hp=first(hc and hc.HealthBar,hc and hc.healthBar,frame.HealthBar,frame.healthBar,frame.healthbar,small and _G.TargetFrameToTHealthBar)
    local mp=first(main and main.ManaBarArea and main.ManaBarArea.ManaBar,main and main.ManaBar,frame.ManaBar,frame.manaBar,frame.manabar,frame.PowerBar,frame.powerBar,small and _G.TargetFrameToTManaBar)
    local portrait=first(c and c.PlayerPortrait,c and c.Portrait,frame.Portrait,frame.portrait)
    local art=first(c and c.FrameTexture,frame.FrameTexture)
    if frame==FocusFrame and mp then bindPower(mp,'focus') end
    if not hp or not portrait or not art then return end
    local s=states[frame]
    if not s then
        s={}; states[frame]=s
        s.shell=frame:CreateTexture(nil,'BACKGROUND',nil,-1)
        s.ring=frame:CreateTexture(nil,'OVERLAY',nil,7)
        s.shell:SetTexture(media..'Body'); s.ring:SetTexture(media..'Ring')
        s.art=art
    end
    local px=small and 4 or (player and 22 or 154)
    local py=small and 4 or 19
    local d=small and 36 or 58
    local bx=small and 46 or (player and 83 or 27)
    local by=small and 15 or 43
    local bw=small and 44 or 119
    local bh=small and 7 or 12
    hide(art)
    hide(main and main.ReputationColor)
    hide(hc and hc.Background)
    hide(hp.Background); hide(hp.HealthBarMask)
    if mp then hide(mp.Background); hide(mp.ManaBarMask) end
    move(s.shell,frame,bx-4,by-18,bw+8,small and 38 or 49)
    move(portrait,frame,px,py,d,d)
    safe(portrait,'SetDrawLayer','ARTWORK',1)
    local mask=c and (c.PlayerPortraitMask or c.PortraitMask)
    if mask then safe(mask,'ClearAllPoints'); safe(mask,'SetAllPoints',portrait); safe(mask,'SetTexture','Interface\\CHARACTERFRAME\\TempPortraitAlphaMask','CLAMPTOBLACKADDITIVE','CLAMPTOBLACKADDITIVE') end
    move(s.ring,frame,px-4,py-4,d+8,d+8)
    if player or frame==TargetFrame then
        -- Native threat visibility remains Blizzard-owned. Draw only our
        -- portrait-sized replacement, never move the native threat region.
        local native=first(frame.threatIndicator,c and c.FrameFlash,
            frame.ThreatIndicator,c and c.ThreatIndicator,
            player and _G.PlayerFrameFlash,
            player and _G.PlayerFrameThreatIndicator,
            not player and _G.TargetFramePortraitThreatIndicator)
        if native and native.GetObjectType and native:GetObjectType()=='Texture' then
            if not s.threatRing then
                s.threatRing=frame:CreateTexture(nil,'OVERLAY',nil,6)
                s.threatRing:SetTexture(media..'ThreatRing')
                s.threatRing:Hide()
            end
            move(s.threatRing,frame,px-4,py-4,d+8,d+8)
            s.nativeThreat=native
            safe(native,'SetAlpha',0)
            if not s.threatWatcher then
                local watcher=CreateFrame('Frame')
                s.threatWatcher=watcher
                local elapsed=0
                watcher:SetScript('OnUpdate',function(_,dt)
                    elapsed=elapsed+dt
                    if elapsed<0.05 then return end
                    elapsed=0
                    local t=s.nativeThreat
                    if (NexosNostalgieDB and NexosNostalgieDB.aggroRing == false) or not t or not frame:IsVisible() or not t:IsShown() then
                        s.threatRing:Hide(); return
                    end
                    -- No protected anchors, masks or texture mutations in combat.
                    -- The independent ring has its own transparent circular alpha.
                    local r,g,b=t:GetVertexColor()
                    if readable(r) and readable(g) and readable(b) then
                        s.threatRing:SetVertexColor(r,g,b,1)
                    else s.threatRing:SetVertexColor(1,0,0,1) end
                    s.threatRing:Show()
                    if not (InCombatLockdown and InCombatLockdown()) then
                        local a=t:GetAlpha()
                        if readable(a) and a~=0 then safe(t,'SetAlpha',0) end
                    end
                end)
            end
        end
    end
    if hc then move(hc,frame,bx,by,bw,bh) end
    move(hp,frame,bx,by,bw,bh); styleBar(hp,true)
    -- Target display owns its fill; no native texture hook needed.
    if mp then if small then move(mp,frame,bx,by+bh+1,bw,7) end; styleBar(mp,false,player or frame==TargetFrame); local unit=player and 'player' or (small and 'targettarget' or (frame==FocusFrame and 'focus' or 'target')); if player or frame==FocusFrame or frame==TargetFrame then bindPower(mp,unit); if player then bindSelfTexture(mp,unit) end else powerBars[mp]=unit; updatePower(mp,unit) end end
    if small and mp and not s.powerHook then
        s.powerHook=true
        local busy=false
        hooksecurefunc(mp,'SetStatusBarColor',function(bar)
            if busy then return end
            busy=true; updatePower(bar,'targettarget'); busy=false
        end)
    end
    -- Anchor the full status bars to each other, not their changing fill textures.
    if mp and not small then
        local a,b,c,x,y=mp:GetPoint(1)
        local d,e,f,u,v=mp:GetPoint(2)
        if accessible(a,b,c,x,y,d,e,f,u,v) and (a~='TOPLEFT' or b~=hp or c~='BOTTOMLEFT' or x~=0 or y~=-1 or d~='TOPRIGHT' or e~=hp or f~='BOTTOMRIGHT' or u~=0 or v~=-1) then
            safe(mp,'ClearAllPoints')
            safe(mp,'SetPoint','TOPLEFT',hp,'BOTTOMLEFT',0,-1)
            safe(mp,'SetPoint','TOPRIGHT',hp,'BOTTOMRIGHT',0,-1)
        end
        local height=mp:GetHeight()
        if accessible(height) and math.abs(height-bh)>0.01 then safe(mp,'SetHeight',bh) end
    end
    local unit=player and 'player' or (small and 'targettarget' or (frame==FocusFrame and 'focus' or 'target'))
    s.unit=unit
    portrait3D(frame,portrait,unit)
    if player or frame==TargetFrame then
        if not s.faction then
            -- Dedicated non-interactive overlay above native portrait decorations.
            local emblemHost=CreateFrame('Frame',nil,frame)
            emblemHost:SetAllPoints(frame)
            emblemHost:SetFrameStrata('HIGH')
            emblemHost:SetFrameLevel(frame:GetFrameLevel()+20)
            emblemHost:EnableMouse(false)
            s.factionHost=emblemHost
            s.faction=emblemHost:CreateTexture(nil,'OVERLAY',nil,7)
            s.faction:SetSize(64,64)
            s.faction:SetPoint('CENTER',s.ring,player and 'LEFT' or 'RIGHT',player and 7 or 3,4)
        end
        s.frame=frame
        updateFaction(s)
    end
    if not player and not small then classificationArt(frame,c,s,unit,px,py,d) end
    if not small then
        if not s.strip then s.strip=frame:CreateTexture(nil,'BACKGROUND',nil,1) end
        s.strip:SetTexture('Interface\\TargetingFrame\\UI-TargetingFrame-BarFill')
        move(s.strip,frame,bx,by-15,bw,13); nameTint(s,unit)
        if frame~=TargetFrame then attachNumbers(hp,unit,false); attachNumbers(mp,unit,true) end
    end
    local name=first(main and main.Name,main and main.NameText,frame.Name,frame.name)
    if name then move(name,frame,bx,by-15,bw,14); safe(name,'SetJustifyH','CENTER'); safe(name,'SetTextColor',1,0.82,0) end
    if frame~=TargetFrame then
    for _,owner in ipairs({hc or hp,hp}) do
        label(owner.LeftText,hp,'LEFT'); label(owner.RightText,hp,'RIGHT'); label(owner.HealthBarText,hp,'CENTER'); label(owner.DeadText,hp,'CENTER'); label(owner.UnconsciousText,hp,'CENTER')
    end
    if not small then
        for _,owner in ipairs({hc or hp,hp,mp or hp}) do
            for _,key in ipairs({'LeftText','RightText','HealthBarText','ManaBarText','TextString'}) do
                local t=owner[key]; if t and not (issecretvalue and issecretvalue(UnitHealth(unit))) then hide(t) end
            end
        end
    end
    if mp then label(mp.LeftText,mp,'LEFT'); label(mp.RightText,mp,'RIGHT'); label(mp.ManaBarText,mp,'CENTER') end
    end -- Native target labels retain their original anchors beneath the display.
    if frame==TargetFrame then targetDisplay(s,frame,hp,mp,bx,by,bw,bh); updateTargetDisplay(s) end
end
local function refresh()
    if InCombatLockdown and InCombatLockdown() then return end
    refreshPetPower()
    for _,entry in ipairs({{PlayerFrame,'player'},{TargetFrame,'target'},{FocusFrame,'target'},{TargetFrame and TargetFrame.totFrame or TargetFrameToT,'small'}}) do
        local ok,err=pcall(apply,entry[1],entry[2]); if not ok then geterrorhandler()(err) end
    end
end
local function refreshFaction(frame)
    local state=states[frame]
    if state and state.faction then updateFaction(state) end
end
if type(PlayerFrame_UpdatePvPStatus)=='function' then
    hooksecurefunc('PlayerFrame_UpdatePvPStatus',function() refreshFaction(PlayerFrame) end)
end
if TargetFrame and type(TargetFrame.CheckFaction)=='function' then
    hooksecurefunc(TargetFrame,'CheckFaction',function() refreshFaction(TargetFrame) end)
end
local pending=false
local function queue()
    if InCombatLockdown and InCombatLockdown() then return end
    if pending then return end; pending=true
    C_Timer.After(0,function() pending=false; refresh() end)
end
local portraitEvents=CreateFrame('Frame')
for _,event in ipairs({'UNIT_MODEL_CHANGED','PLAYER_TARGET_CHANGED','PLAYER_FOCUS_CHANGED','UNIT_PET','UNIT_TARGET'}) do
    pcall(portraitEvents.RegisterEvent,portraitEvents,event)
end
portraitEvents:SetScript('OnEvent',function(_,event,unit)
    if NexosNostalgieDB.portraits3D~=true then return end
    if InCombatLockdown and InCombatLockdown() then return end
    for frame,state in pairs(models) do
        local token=state.unit
        local affected=(event=='PLAYER_TARGET_CHANGED' and (token=='target' or token=='targettarget'))
            or (event=='PLAYER_FOCUS_CHANGED' and token=='focus')
            or (event=='UNIT_PET' and unit=='player' and token=='pet')
            or (event=='UNIT_TARGET' and unit=='target' and token=='targettarget')
            or ((event=='UNIT_MODEL_CHANGED') and token==unit)
        if affected then
            state.bound=false
            state.generation=(state.generation or 0)+1
            if state.portrait and token then portrait3D(frame,state.portrait,token) end
        end
    end
end)
local events=CreateFrame('Frame')
for _,event in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_TARGET_CHANGED','PLAYER_FOCUS_CHANGED','UNIT_PET','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED','UNIT_DISPLAYPOWER','UNIT_TARGET','UNIT_POWER_UPDATE','UNIT_MAXPOWER','UNIT_HEALTH','UNIT_MAXHEALTH','UNIT_FACTION','PLAYER_FLAGS_CHANGED','UNIT_CLASSIFICATION_CHANGED'}) do events:RegisterEvent(event) end
events:SetScript('OnEvent',function(_, event, unit)
    if event=='PLAYER_REGEN_DISABLED' then suspendModels() end
    if event=='PLAYER_TARGET_CHANGED' or event=='PLAYER_REGEN_DISABLED' or event=='PLAYER_REGEN_ENABLED' then
        local state=states[TargetFrame]
        if state then
            if event=='PLAYER_TARGET_CHANGED' and state.strip then state.strip:SetVertexColor(0.13,0.11,0.075,1) end
            nameTint(state,'target')
        end
    end
    if not unit or unit=='target' or event=='PLAYER_TARGET_CHANGED' then updateTargetDisplay(states[TargetFrame]) end
    for bar, info in pairs(numericBars) do if not unit or info[1]==unit or event=='PLAYER_TARGET_CHANGED' then numbers(bar,info[1],info[2]) end end
    if event=='UNIT_FACTION' or event=='PLAYER_FLAGS_CHANGED' then for _,s in pairs(states) do if s.unit then nameTint(s,s.unit); updateFaction(s) end end end
    if event=='UNIT_HEALTH' or event=='UNIT_MAXHEALTH' then return end
    if event == 'UNIT_DISPLAYPOWER' or event == 'UNIT_POWER_UPDATE' or event == 'UNIT_MAXPOWER' then
        for bar, owner in pairs(powerBars) do
            if owner == unit then updatePower(bar,owner) end
        end
    end
    if event=='PLAYER_ENTERING_WORLD' or event=='PLAYER_TARGET_CHANGED' or event=='PLAYER_FOCUS_CHANGED' or event=='UNIT_PET' or event=='PLAYER_REGEN_ENABLED' or (event=='UNIT_DISPLAYPOWER' and (unit=='player' or unit=='target' or unit=='focus' or unit=='pet' or unit=='targettarget')) or (event=='UNIT_TARGET' and unit=='target') or (event=='UNIT_CLASSIFICATION_CHANGED' and (unit=='target' or unit=='focus')) then queue() end
end)

end
