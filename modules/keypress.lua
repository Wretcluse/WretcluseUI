-- modules/keypress.lua
local ADDON, ns = ...

ns:RegisterModule("keypress", function(ns)

	-- =========================
	-- USER SETTINGS (edit here)
	-- =========================
	local CFG = {
		-- Position of the mirror button (relative to UIParent)
		point = "CENTER",
		relativeTo = UIParent,
		relativePoint = "BOTTOM",
		x = 90,
		y = 280,

		-- Appearance
		scale = 1,
		size = 46,

		-- Behavior
		enableCooldown = true,
		autoKeyup = false,      -- if true: auto-release pressed state shortly after keydown
		holdTime = 0.1,         -- seconds until auto-release (only when autoKeyup=true)
		fadeStart = 1.0,        -- seconds after keydown to begin fading
		fadeDuration = 1.0,     -- seconds to fade out (total visible time = fadeStart + fadeDuration)

		-- Cooldown visuals
		hideCooldownNumbers = false,
		swipeColor = {0, 0, 0, 1},
		edgeTexture = "Interface\\Cooldown\\edge",
	}

	local function IsInPetBattle()
		return C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle()
	end

	local Keypress = CreateFrame("Frame", "WretcluseUI_Keypress", UIParent)
	Keypress:SetScale(CFG.scale)

	local function CreateMirrorButton()
		local b = CreateFrame("Button", "WretcluseUI_KeypressMirror", Keypress, "ActionButtonTemplate")
		b:SetSize(CFG.size, CFG.size)
	b:SetScale(CFG.scale)
		b:EnableMouse(false)
		b:SetPoint(CFG.point, CFG.relativeTo, CFG.relativePoint, CFG.x, CFG.y)
		b:Hide()

		-- Cooldown styling (Cooldown frame comes from ActionButtonTemplate)
		if b.cooldown then
			if CFG.edgeTexture and b.cooldown.SetEdgeTexture then
				b.cooldown:SetEdgeTexture(CFG.edgeTexture)
			end
			if CFG.swipeColor and b.cooldown.SetSwipeColor then
				b.cooldown:SetSwipeColor(CFG.swipeColor[1], CFG.swipeColor[2], CFG.swipeColor[3], CFG.swipeColor[4] or 1)
			end
			if b.cooldown.SetHideCountdownNumbers then
				b.cooldown:SetHideCountdownNumbers(CFG.hideCooldownNumbers and true or false)
			end
		end

		-- Midnight/12.0 safe cooldown apply: do not compare or boolean-test returns from GetActionCooldown.
		local function ApplyCooldownForAction(action)
			if not (CFG.enableCooldown and b.cooldown) then return end
			local start, duration, _, modRate = GetActionCooldown(action)

			-- Treat cooldown returns as write-only tokens.
			local ok = pcall(function()
				b.cooldown:SetCooldown(start, duration, modRate)
			end)

			if ok then
				b.cooldown:Show()
			else
				if b.cooldown.Clear then
					b.cooldown:Clear()
				elseif _G.CooldownFrame_Clear then
					_G.CooldownFrame_Clear(b.cooldown)
				end
				b.cooldown:Hide()
			end
		end

		function b:UpdateAction(fullUpdate)
			local action = self.action
			if not action then return end

			local tex = GetActionTexture(action)
			if not tex then return end
			self.icon:SetTexture(tex)

			if fullUpdate then
				ApplyCooldownForAction(action)
			end
		end

		-- Fade + optional auto-keyup
		b._elapsed = 0
		b.pushed = false
		b:SetScript("OnUpdate", function(self, elapsed)
			self._elapsed = self._elapsed + elapsed

			if CFG.autoKeyup and self.pushed and self._elapsed >= CFG.holdTime then
				if self:GetButtonState() == "PUSHED" then
					self:SetButtonState("NORMAL")
				end
				self.pushed = false
			end

			if self._elapsed >= CFG.fadeStart then
				local t = self._elapsed - CFG.fadeStart
				local alpha = 1 - (t / math.max(CFG.fadeDuration, 0.001))
				if alpha <= 0 then
					self:SetAlpha(0)
					self:Hide()
				else
					self:SetAlpha(alpha)
				end
			end
		end)

		return b
	end

	Keypress.mirror = CreateMirrorButton()

	local function ShowForAction(action)
		if not HasAction(action) then return end
		if IsInPetBattle() then return end

		local mirror = Keypress.mirror
		if mirror.action ~= action then
			mirror.action = action
			mirror:UpdateAction(true)
		else
			mirror:UpdateAction(false)
		end

		mirror:Show()
		mirror:SetAlpha(1)
		mirror._elapsed = 0

		if mirror:GetButtonState() == "NORMAL" then
			mirror:SetButtonState("PUSHED")
			mirror.pushed = true
		end
	end

	local function Release()
		local mirror = Keypress.mirror
		if mirror and mirror:GetButtonState() == "PUSHED" then
			mirror:SetButtonState("NORMAL")
		end
	end

	local function HookActionButtons()
		local GetActionButtonForID = _G.GetActionButtonForID

		hooksecurefunc("ActionButtonDown", function(id)
			local button = GetActionButtonForID and GetActionButtonForID(id)
			if button and button.action then
				ShowForAction(button.action)
			end
		end)

		hooksecurefunc("ActionButtonUp", function()
			Release()
		end)

		hooksecurefunc("MultiActionButtonDown", function(bar, id)
			local button = _G[bar .. "Button" .. id]
			if button and button.action then
				ShowForAction(button.action)
			end
		end)

		hooksecurefunc("MultiActionButtonUp", function()
			Release()
		end)
	end

	HookActionButtons()

	if CFG.enableCooldown then
		Keypress:RegisterEvent("SPELL_UPDATE_COOLDOWN")
	end
	Keypress:SetScript("OnEvent", function(self, event)
		if event == "SPELL_UPDATE_COOLDOWN" then
			local mirror = self.mirror
			if mirror and mirror:IsShown() then
				mirror:UpdateAction(true)
			end
		end
	end)

end)
