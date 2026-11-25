local addon, ns = ...
ns.start = {}
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, name)
 if name ~= addon then return end
 self:UnregisterEvent("ADDON_LOADED")
 if type(NexosNostalgieDB) ~= "table" then NexosNostalgieDB = {} end
 local db = NexosNostalgieDB
 for k,v in pairs({classicFrames=true,portraits3D=false,classicPlates=true,realLevels=true,aggroRing=true,minimap=true,friendlyNPCPreference="1",minimapAngle=220}) do
  if db[k] == nil then db[k] = v end
 end
 for _,start in ipairs(ns.start) do start(addon, ns) end
end)
