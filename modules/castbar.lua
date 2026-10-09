-- modules/castbar.lua
local ADDON, ns = ...

ns:RegisterModule("castbar", function(ns)
	-----------------------------
	-- PLAYER CAST BAR TIMER
	-----------------------------
		local castTime = PlayerCastingBarFrame.CastTimeText

		castTime:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
		castTime:ClearAllPoints()
		castTime:SetPoint("RIGHT", PlayerCastingBarFrame, "RIGHT", -3, 0)
		castTime:SetJustifyH("RIGHT")


	-----------------------------
	-- TAR/FOC SPELLBAR / HOOKS
	-- NOTES: Calls through self will trigger our hook, so we're making them through the metatable. 
	-----------------------------
		local function TarSpellBar_SetPoint(self)
			local meta = getmetatable(self).__index
				meta.ClearAllPoints(self)
				TargetFrameSpellBar:SetScale(1.5)
				meta.SetPoint(self, "TOPLEFT", UIParent, "CENTER", 145, 0)
		end
		hooksecurefunc(TargetFrame.spellbar,"SetPoint", TarSpellBar_SetPoint)

		local function FocSpellBar_SetPoint(self)
			local meta = getmetatable(self).__index
				meta.ClearAllPoints(self)
				FocusFrameSpellBar:SetScale(1.5)
				meta.SetPoint(self, "TOPLEFT", UIParent, "CENTER", -275, 0)
		end
		hooksecurefunc(FocusFrame.spellbar, "SetPoint", FocSpellBar_SetPoint)
end)
