-- core.lua
-- WretcluseUI: lightweight module system
-- Loads registered modules on PLAYER_LOGIN with per-module error isolation.

local ADDON, ns = ...

ns.name = ADDON
ns.modules = ns.modules or {}

-- ------------------------------------------------------------
-- Shared constants & helpers (safe + lightweight)
-- ------------------------------------------------------------

ns.Media = ns.Media or {
	HealthBackground = "Interface\\Addons\\WretcluseUI\\media\\TARGETINGFRAME\\UI-HealthBackground",
}

function ns:Print(msg)
	print("|cFFFFD100WretcluseUI:|r " .. tostring(msg))
end

-- Create a single background texture on a frame (no OnUpdate, no re-creation).
function ns:CreateBackgroundTexture(frame, texturePath, alpha, layer, subLevel)
	if not frame or frame.__wret_bg then return frame and frame.__wret_bg end
	local tex = frame:CreateTexture(nil, layer or "BACKGROUND", nil, subLevel or -8)
	tex:SetAllPoints(frame)
	tex:SetTexture(texturePath or (self.Media and self.Media.HealthBackground))
	tex:SetAlpha(alpha or 1)
	frame.__wret_bg = tex
	return tex
end

-- ------------------------------------------------------------
-- Module registration & initialization
-- ------------------------------------------------------------

function ns:RegisterModule(name, fn)
	if type(name) ~= "string" or name == "" then
		error("RegisterModule(name, fn): name must be a non-empty string", 2)
	end
	if type(fn) ~= "function" then
		error("RegisterModule(name, fn): fn must be a function", 2)
	end
	ns.modules[name] = fn
end

function ns:Init()
	for name, fn in pairs(ns.modules) do
		local ok, err = pcall(fn, ns)
		if not ok then
			self:Print(("Module '%s' error: %s"):format(name, tostring(err)))
		end
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	ns:Init()
end)
