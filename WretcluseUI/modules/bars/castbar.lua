
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

-----------------------------
-- SPELLBAR TIMER / POSITION
-----------------------------
	PlayerCastingBarFrame.CastTimeText:SetFontObject("TextStatusBarText")
	PlayerCastingBarFrame.CastTimeText:SetPoint("LEFT", PlayerCastingBarFrame, "RIGHT", -28, -0.5)

	TargetFrameSpellBar.timer = TargetFrameSpellBar:CreateFontString(nil)
	TargetFrameSpellBar.timer:SetFontObject("TextStatusBarText")
	TargetFrameSpellBar.timer:SetPoint("RIGHT", TargetFrameSpellBar, "RIGHT", -1, -0.5)
	TargetFrameSpellBar.update = 0.1

	FocusFrameSpellBar.timer = FocusFrameSpellBar:CreateFontString(nil)
	FocusFrameSpellBar.timer:SetFontObject("TextStatusBarText")
	FocusFrameSpellBar.timer:SetPoint("RIGHT", FocusFrameSpellBar, "RIGHT", -1, -0.5)
	FocusFrameSpellBar.update = 0.1

-----------------------------
-- SPELLBAR TIMER / HOOK
-----------------------------
	TargetFrameSpellBar:HookScript("OnUpdate", function(self, elapsed)
		if not self.timer then return end
		if self.update and self.update < elapsed then
			if self.casting then
				self.timer:SetText(format("%.1f" .. " s", max(self.maxValue - self.value, 0)))
			elseif self.channeling then
				self.timer:SetText(format("%.1f" .. " s", max(self.value, 0)))
			else
				self.timer:SetText("")
			end
			self.update = .1
		else
			self.update = self.update - elapsed
		end
	end)

	FocusFrameSpellBar:HookScript("OnUpdate", function(self, elapsed)
		if not self.timer then return end
		if self.update and self.update < elapsed then
			if self.casting then
				self.timer:SetText(format("%.1f" .. " s", max(self.maxValue - self.value, 0)))
			elseif self.channeling then
				self.timer:SetText(format("%.1f" .. " s", max(self.value, 0)))
			else
				self.timer:SetText("")
			end
			self.update = .1
		else
			self.update = self.update - elapsed
		end
	end)