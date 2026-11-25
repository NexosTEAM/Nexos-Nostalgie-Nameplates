local _, ns = ...
ns.start[#ns.start+1] = function(...)
if NexosNostalgieDB and (NexosNostalgieDB.realLevels == false or NexosNostalgieDB.classicFrames == false) then return end
-- NexosTEAM: one numeric target level, using the existing native badge.
local cache, count = {}, 0
local function public(v) return not (issecretvalue and issecretvalue(v)) end
local function read(unit)
    local ok, n = pcall(UnitLevel, unit)
    local valid = ok and public(n) and type(n)=='number' and n>0
    local good, guid = pcall(UnitGUID, unit)
    if good and public(guid) and type(guid)=='string' and guid:match('^Creature%-') then
        if valid then
            if not cache[guid] then
                if count>=1024 then cache={}; count=0 end
                count=count+1
            end
            cache[guid]=n
        else return cache[guid] end
    end
    if valid then return n end
end
local overlay, native, skull, oldTextAlpha, oldSkullAlpha
local function restore()
    if overlay then overlay:Hide() end
    if native and oldTextAlpha~=nil then native:SetAlpha(oldTextAlpha) end
    if skull and oldSkullAlpha~=nil then skull:SetAlpha(oldSkullAlpha) end
    oldTextAlpha,oldSkullAlpha=nil,nil
end
local function refresh()
    if InCombatLockdown and InCombatLockdown() then restore(); return end
    local f=TargetFrame
    if not f then return end
    local cc=_G.NexosCC
    local profile=cc and cc.db and cc.db.profile
    if profile and profile.customTargetLevels then restore(); return end
    local content=f.TargetFrameContent
    local main=content and content.TargetFrameContentMain
    local context=content and content.TargetFrameContentContextual
    local tf=f.TextureFrame or _G.TargetFrameTextureFrame
    local text=(main and main.LevelText) or f.LevelText or f.levelText or (tf and tf.LevelText) or _G.TargetFrameTextureFrameLevelText
    local icon=(context and context.HighLevelTexture) or (main and main.HighLevelTexture) or f.HighLevelTexture or (tf and tf.HighLevelTexture) or _G.TargetFrameTextureFrameHighLevelTexture
    if text~=native or icon~=skull then restore(); native,skull=text,icon end
    local n=read('target')
    if not n or not native or not UnitExists('target') then restore(); return end
    if not overlay then
        local host=CreateFrame('Frame',f)
        host:SetAllPoints(f)
        host:SetFrameLevel(math.max(f:GetFrameLevel(),native:GetParent():GetFrameLevel())+20)
        overlay=host:CreateFontString(nil,'OVERLAY','GameFontNormalSmall',7)
    end
    overlay:ClearAllPoints(); overlay:SetPoint('CENTER',native,'CENTER')
    -- Match the player's native level typography, not the larger target font.
    local pf=PlayerFrame
    local pc=pf and pf.PlayerFrameContent
    local pm=pc and pc.PlayerFrameContentMain
    local pt=pf and (pf.TextureFrame or _G.PlayerFrameTextureFrame)
    local source=(pm and pm.LevelText) or (pf and (pf.LevelText or pf.levelText)) or (pt and pt.LevelText) or _G.PlayerFrameLevelText or _G.PlayerFrameTextureFrameLevelText
    local font,size,flags=(source or native):GetFont()
    if public(font) and public(size) and public(flags) and font and type(size)=='number' then
        if not source then size=math.min(size,12) end
        overlay:SetFont(font,size,flags)
    end
    overlay:SetJustifyH('CENTER'); overlay:SetJustifyV('MIDDLE')
    local color
    if GetQuestDifficultyColor then local ok,c=pcall(GetQuestDifficultyColor,n); if ok then color=c end end
    local r,g,b=1,0.82,0
    if color and public(color.r) and public(color.g) and public(color.b) then r,g,b=color.r,color.g,color.b end
    local p=UnitLevel('player')
    if public(p) and type(p)=='number' and n>=p+5 then r,g,b=1,0.1,0.1 end
    overlay:SetText(n); overlay:SetTextColor(r,g,b)
    local a=native:GetAlpha(); if not public(a) then restore(); return end
    if oldTextAlpha==nil then oldTextAlpha=1 end
    if skull then local s=skull:GetAlpha(); if not public(s) then restore(); return end; if oldSkullAlpha==nil then oldSkullAlpha=s end; skull:SetAlpha(0) end
    overlay:Show(); native:SetAlpha(0)
end
local pending=false
local function queue()
    if pending then return end
    pending=true; C_Timer.After(0,function() pending=false; pcall(refresh) end)
end
local events=CreateFrame('Frame')
for _,e in ipairs({'PLAYER_ENTERING_WORLD','PLAYER_TARGET_CHANGED','PLAYER_REGEN_ENABLED','PLAYER_REGEN_DISABLED','UNIT_LEVEL','UPDATE_MOUSEOVER_UNIT','NAME_PLATE_UNIT_ADDED','ADDON_LOADED'}) do events:RegisterEvent(e) end
events:SetScript('OnEvent',function(_,e,u)
    if e=='UPDATE_MOUSEOVER_UNIT' then read('mouseover') elseif e=='NAME_PLATE_UNIT_ADDED' then read(u) end
    if e=='PLAYER_TARGET_CHANGED' or e=='PLAYER_REGEN_DISABLED' then restore() end
    queue()
end)
if type(TargetFrame_CheckLevel)=='function' then hooksecurefunc('TargetFrame_CheckLevel',queue) end

end
