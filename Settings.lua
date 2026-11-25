local _, ns = ...
ns.start[#ns.start+1] = function(...)
-- NexosTEAM: independent settings interface.
local db=NexosNostalgieDB
local npcReady, npcApplying = false, false
local defaults={classicFrames=true,portraits3D=false,classicPlates=true,realLevels=true,aggroRing=true,minimap=true}
for k,v in pairs(defaults) do if db[k]==nil then db[k]=v end end
local function combat() return InCombatLockdown and InCombatLockdown() end
local function surface(parent,w,h)
 local f=CreateFrame('Frame',nil,parent,'BackdropTemplate'); f:SetSize(w,h)
 f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Buttons\\WHITE8X8',edgeSize=1}); f:SetBackdropColor(.045,.055,.075,1); f:SetBackdropBorderColor(.27,.34,.43,1); return f
end
local panel=surface(UIParent,550,550); _G.NexosNostalgieSettings=panel; UISpecialFrames[#UISpecialFrames+1]='NexosNostalgieSettings'; panel:SetPoint('CENTER'); panel:SetFrameStrata('DIALOG'); panel:SetClampedToScreen(true); panel:EnableMouse(true); panel:SetMovable(true); panel:RegisterForDrag('LeftButton'); panel:SetScript('OnDragStart',panel.StartMoving); panel:SetScript('OnDragStop',panel.StopMovingOrSizing); panel:Hide()
local close=CreateFrame('Button',nil,panel,'UIPanelCloseButton'); close:SetPoint('TOPRIGHT',-8,-8)
local function text(parent,x,y,w,value,large)
 local t=parent:CreateFontString(nil,'OVERLAY',large and 'GameFontNormalLarge' or 'GameFontHighlight'); t:SetPoint('TOPLEFT',x,y); t:SetWidth(w); t:SetJustifyH('LEFT'); t:SetText(value); return t
end
local function button(parent,label,x,y,w,fn)
 local b=CreateFrame('Button',nil,parent,'UIPanelButtonTemplate'); b:SetSize(w,26); b:SetPoint('TOPLEFT',x,y); b:SetText(label); b:SetScript('OnClick',fn); return b
end
text(panel,24,-20,490,'Nexos Nostalgie Nameplates',true)
text(panel,24,-46,490,'Original Classic appearance  |  NexosTEAM'):SetTextColor(.65,.72,.82)
local main=surface(panel,502,281); main:SetPoint('TOPLEFT',24,-76); main:SetBackdropColor(.075,.09,.12,1)
text(main,16,-12,460,'Classic appearance',true)
local studio=surface(panel,502,138); studio:SetPoint('TOPLEFT',24,-369); studio:SetBackdropColor(.075,.09,.12,1)
text(studio,16,-12,470,'Style Studio  |  NexosCC',true)
text(studio,16,-36,470,'Customize cooldown colors, fonts, buffs and debuffs with NexosCC.')
local status=text(panel,24,-517,502,''); status:SetTextColor(.65,.72,.82)
local popup=surface(UIParent,390,150); popup:SetPoint('CENTER',0,110); popup:SetFrameStrata('FULLSCREEN_DIALOG'); popup:EnableMouse(true); popup:Hide()
text(popup,20,-18,350,'Apply Classic settings',true)
local countdown=text(popup,20,-49,350,''); local token=0; local pending=false
local function reload() if combat() then countdown:SetText('Waiting for combat to end...'); return end; ReloadUI() end
button(popup,'Reload Now',20,-108,165,reload)
button(popup,'Cancel Reload',205,-108,165,function() token=token+1; popup:Hide(); status:SetText('Changes saved. Reload UI to apply.') end)
local function schedule()
 pending=true; token=token+1; local id=token; local left=10; popup:Show(); status:SetText('Changes saved. Reload required.')
 local function tick()
  if token~=id or not popup:IsShown() then return end
  if combat() then countdown:SetText('Waiting for combat to end...'); return end
  if left<=0 then countdown:SetText('Ready to reload. Click Reload Now.'); return end
  countdown:SetText('Reload available in '..left..' seconds...'); left=left-1; C_Timer.After(1,tick)
 end
 tick()
end
local icon=CreateFrame('Button','NexosNostalgieMinimapButton',Minimap); icon:SetSize(32,32); icon:SetFrameStrata('MEDIUM'); icon:SetFrameLevel(Minimap:GetFrameLevel()+8); icon:RegisterForClicks('LeftButtonUp','RightButtonUp'); icon:RegisterForDrag('LeftButton')
local art=icon:CreateTexture(nil,'ARTWORK'); art:SetSize(20,20); art:SetPoint('CENTER'); art:SetTexture('Interface\\AddOns\\NexosNostalgieNameplates\\Media\\ClassicIcon.tga')
local rim=icon:CreateTexture(nil,'OVERLAY'); rim:SetSize(52,52); rim:SetPoint('TOPLEFT'); rim:SetTexture('Interface\\Minimap\\MiniMap-TrackingBorder'); icon:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight')
local function position()
 local a=math.rad(tonumber(db.minimapAngle) or 220); icon:ClearAllPoints(); icon:SetPoint('CENTER',Minimap,'CENTER',math.cos(a)*(Minimap:GetWidth()/2+5),math.sin(a)*(Minimap:GetHeight()/2+5)); icon:SetShown(db.minimap~=false)
end
local function drag()
 local x,y=GetCursorPosition(); local scale=Minimap:GetEffectiveScale(); local cx,cy=Minimap:GetCenter(); if not cx or not cy or not scale or scale==0 then return end
 local dx,dy=x/scale-cx,y/scale-cy; local a=math.atan2 and math.atan2(dy,dx) or (dx==0 and (dy>=0 and math.pi/2 or -math.pi/2) or math.atan(dy/dx)+(dx<0 and math.pi or 0)); db.minimapAngle=math.deg(a)%360; position()
end
local function stop(self) if self.dragging then drag(); self.dragging=false; self:SetScript('OnUpdate',nil) end end
icon:SetScript('OnDragStart',function(self) self.dragging=true; self:SetScript('OnUpdate',drag) end); icon:SetScript('OnDragStop',stop); icon:SetScript('OnHide',stop)
local function npcGet() local get=C_CVar and C_CVar.GetCVar or GetCVar; return get('nameplateShowFriendlyNPCs')=='1' end
local function npcSet(v)
 if combat() then status:SetText('Leave combat before changing NPC nameplates.'); return end
 local set=C_CVar and C_CVar.SetCVar or SetCVar; npcApplying=true; local ok=pcall(set,'nameplateShowFriendlyNPCs',v and '1' or '0'); npcApplying=false; if ok and npcGet()==v then db.friendlyNPCPreference=v and '1' or '0' else status:SetText('NPC setting could not be applied.') end
end
local checks={}; local sync
local function check(y,label,key,reloadRequired)
 local b=CreateFrame('CheckButton',nil,main,'UICheckButtonTemplate'); b:SetPoint('TOPLEFT',12,y); local t=b:CreateFontString(nil,'OVERLAY','GameFontHighlight'); t:SetPoint('LEFT',b,'RIGHT',5,0); t:SetText(label); checks[key]=b
 b:SetScript('OnClick',function(self) local v=not not self:GetChecked(); if key=='npc' then npcSet(v) else db[key]=v; if key=='minimap' then position() end; if reloadRequired then schedule() end end; sync() end)
end
check(-36,'Classic unit frames','classicFrames',true); check(-65,'Classic overhead nameplates','classicPlates',true); check(-94,'Friendly NPC nameplates','npc'); check(-123,'Real target levels','realLevels',true); check(-152,'Custom aggro rings','aggroRing'); check(-181,'Show minimap icon','minimap'); check(-210,'Enable 3D portraits','portraits3D',true)
button(main,'Reload UI',16,-246,120,reload)
button(main,'Restore Classic defaults',150,-246,220,function() if combat() then status:SetText('Leave combat before restoring defaults.'); return end; for k,v in pairs(defaults) do db[k]=v end; npcSet(true); position(); sync(); schedule() end)
local link=CreateFrame('EditBox',nil,studio,'InputBoxTemplate'); link:SetSize(460,24); link:SetPoint('TOPLEFT',20,-92); link:SetAutoFocus(false); link:SetText('https://www.curseforge.com/wow/addons/nexoscc'); link:SetScript('OnEscapePressed',function(self) self:ClearFocus(); self:Hide() end); link:Hide()
local function openCC()
 local cc=_G.NexosCC
 if cc then
  if combat() then status:SetText('Leave combat before opening NexosCC.'); return end
  local load=C_AddOns and C_AddOns.LoadAddOn or LoadAddOn; if load then pcall(load,'NexosCC_Config') end
  if cc.OpenToStyleStudio then cc:OpenToStyleStudio(); panel:Hide(); return end
  if cc.OpenOptions then cc:OpenOptions(); panel:Hide(); return end
  status:SetText('Enable NexosCC Config to open its settings.'); return
 end
 link:Show(); link:SetFocus(); link:HighlightText()
end
local launch=button(studio,'Get NexosCC on CurseForge',16,-59,270,openCC)
sync=function() for k,b in pairs(checks) do if k=='npc' then b:SetChecked(db.friendlyNPCPreference~='0') elseif k=='portraits3D' then b:SetChecked(db[k]==true) else b:SetChecked(db[k]~=false) end end; checks.portraits3D:SetEnabled(db.classicFrames~=false); checks.realLevels:SetEnabled(db.classicFrames~=false); checks.aggroRing:SetEnabled(db.classicFrames~=false); launch:SetText(_G.NexosCC and 'Open NexosCC settings' or 'Get NexosCC on CurseForge') end
panel:SetScript('OnShow',sync)
local function toggle() if panel:IsShown() then panel:Hide() else panel:Show() end end
icon:SetScript('OnClick',function() toggle() end); icon:SetScript('OnEnter',function(self) GameTooltip:SetOwner(self,'ANCHOR_LEFT'); GameTooltip:AddLine('Nexos Nostalgie Nameplates'); GameTooltip:AddLine('Click: Settings | Drag: Move',1,1,1); GameTooltip:Show() end); icon:SetScript('OnLeave',function() GameTooltip:Hide() end)
SLASH_NEXOSNOSTALGIE1='/nexosnp'; SLASH_NEXOSNOSTALGIE2='/nostalgie'; SlashCmdList.NEXOSNOSTALGIE=toggle
local events=CreateFrame('Frame')
local function restoreNPC()
 if combat() then return end
 npcSet(db.friendlyNPCPreference ~= '0')
 npcReady=true
end
 events:RegisterEvent('PLAYER_LOGIN'); events:RegisterEvent('PLAYER_ENTERING_WORLD'); events:RegisterEvent('PLAYER_REGEN_ENABLED'); events:RegisterEvent('CVAR_UPDATE')
 events:SetScript('OnEvent',function(_,event,key)
 if event=='PLAYER_LOGIN' or event=='PLAYER_ENTERING_WORLD' then
  position(); if not npcReady then restoreNPC() end
 elseif event=='CVAR_UPDATE' then
  if npcReady and not npcApplying and type(key)=='string' and key:lower()=='nameplateshowfriendlynpcs' then db.friendlyNPCPreference=npcGet() and '1' or '0' end
 elseif event=='PLAYER_REGEN_ENABLED' then
  if not npcReady then restoreNPC() end
  if popup:IsShown() and pending then schedule() end
 end
 end)
 position()

end
