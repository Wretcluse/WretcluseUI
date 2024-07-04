
-----------------------------
-- HIDE ACTIONBAR MACRO TEXT
-----------------------------
	local function HideMacroName()
		local bars = {
			"Action",
			"MultiBarBottomLeft",
			-- "MultiBarBottomRight",
			-- "MultiBarLeft",
			-- "MultiBarRight"
		}

		for _, bar in pairs(bars) do
			for i = 1, 12 do
				local buttonName = _G[bar .. "Button" .. i .. "Name"]
				if buttonName then
					buttonName:SetAlpha(0)
				end
			end
		end
	end

-----------------------------
-- STOP AUTO SPELL TO ACTIONBAR FUNCTION
-----------------------------
	local function StopAutoSpellToActionBar()
		IconIntroTracker.RegisterEvent = function() end
		IconIntroTracker:UnregisterEvent('SPELL_PUSHED_TO_ACTIONBAR')

		local f = CreateFrame('frame')
		f:SetScript('OnEvent', function(self, event, spellID, slotIndex, slotPos)
			if not InCombatLockdown() then
				ClearCursor()
				PickupAction(slotIndex)
				ClearCursor()
			end
		end)
		f:RegisterEvent('SPELL_PUSHED_TO_ACTIONBAR')
	end

-----------------------------
-- STOP AUTO HEARTHSTONE TO BAG FUNCTION
-----------------------------
	local function StopAutoHearthstoneToBag()
		local DeleteHearthstone = CreateFrame("Frame")
		DeleteHearthstone:RegisterEvent("PLAYER_LOGIN")

		local Toys = {
			162973, -- Greatfather Winter's Hearthstone
			163045, -- Headless Horseman's Hearthstone
			165669, -- Lunar Elder's Hearthstone
			165670, -- Peddlefeet's Lovely Hearthstone
			165802, -- Noble Gardener's Hearthstone
			166746, -- Fire Eater's Hearthstone
			166747, -- Brewfest Reveler's Hearthstone
			168907, -- Holographic Digitalization Hearthstone
			172179, -- Eternal Traveler's Hearthstone
			180290, -- Night Fae Hearthstone
			182773, -- Necrolord Hearthstone
			183716, -- Venthyr Sinstone
			184353, -- Kyrian Hearthstone
			93672,	-- Dark Portal
			54452,	-- Ethereal Portal
		}

		DeleteHearthstone:SetScript("OnEvent", function(self, event, ...)
			if event == "PLAYER_LOGIN" then
				for i = 1, #Toys do
					if PlayerHasToy(Toys[i]) then
						self.hasToy = true
						break
					end
				end

				if not self.hasToy then return end

				self:RegisterEvent("HEARTHSTONE_BOUND")

				WorldFrame:HookScript("OnMouseDown", function()
					if self.isBound and self.bagID then
						for slotIndex = 1, C_Container.GetContainerNumSlots(self.bagID) do
							local itemLink = C_Container.GetContainerItemLink(self.bagID, slotIndex)
							local itemID = itemLink and GetItemInfoInstant(itemLink)
							if itemID and itemID == 6948 then
								C_Container.PickupContainerItem(self.bagID, slotIndex)
								DeleteCursorItem()
								print("|cffEEE4AEDelete Hearthstone:|r Deleted ".. itemLink)
								self.isBound = false
								self.bagID = nil
								return
							end
						end
					end
				end)
			elseif event == "HEARTHSTONE_BOUND" and self.hasToy then
				self:RegisterEvent("BAG_UPDATE")
				self.isBound = true
			elseif event == "BAG_UPDATE" then
				self:UnregisterEvent("BAG_UPDATE")
				self.bagID = ...
			end
		end)
	end

-----------------------------
-- HIDE LOSE OF CONTROL BUTTON OVERLAY
-----------------------------
	local function HideLossOfControlOverlay()
		hooksecurefunc('CooldownFrame_Set', function(self) 
				if self.currentCooldownType == COOLDOWN_TYPE_LOSS_OF_CONTROL then 
					self:SetCooldown(0,0)
				end
		end)
	end

-----------------------------
-- COOLDOWN BUTTON DESATURATED
-----------------------------
	local function ActionButtonGreyOnCooldown_UpdateCooldown(self, expectedUpdate)
		local icon = self.icon
		local spellID = (self._state_type == "spell") and self._state_action or self.spellID
		local action = self._state_action or self.action

		if icon and (action and type(action) ~= "table" and type(action) ~= "string") or (spellID and type(spellID) ~= "table" and type(spellID) ~= "string") then
				local start, duration
				if spellID then
					start, duration = GetSpellCooldown(spellID)
				else
					start, duration = GetActionCooldown(action)
				end

				if duration and duration >= 1.5 then
					if start > 3085367 and start <= 4294967.295 then
						start = start - 4294967.296
					end
					if not self.onCooldown or self.onCooldown == 0 then
						local nextTime = start + duration - GetTime() - 1.0
						if nextTime < -1.0 then
								nextTime = 0.05
						elseif nextTime < 0 then
								nextTime = -nextTime / 2
						end
						if nextTime <= 4294967.295 then
								C_Timer.After(nextTime, function() ActionButtonGreyOnCooldown_UpdateCooldown(self, true) end)
						end
					elseif expectedUpdate then
						if not self.onCooldown or self.onCooldown < start + duration then
								self.onCooldown = start + duration
						end
						local nextTime = 0.05
						local timeRemains = self.onCooldown - GetTime()
						if timeRemains > 0.31 then
								nextTime = timeRemains / 5
						elseif timeRemains < 0 then
								nextTime = 0.05
						end
						if nextTime <= 4294967.295 then
								C_Timer.After(nextTime, function() ActionButtonGreyOnCooldown_UpdateCooldown(self, true) end)
						end
					end
					if not self.onCooldown or self.onCooldown < start + duration then
						self.onCooldown = start + duration
					end
					if not icon:IsDesaturated() then
						icon:SetDesaturated(true)
					end
				else
					self.onCooldown = 0
					if icon:IsDesaturated() then
						icon:SetDesaturated(false)
					end
				end
		end
	end

	local function HookGreyOnCooldownIcons()
		if not GREYONCOOLDOWN_HOOKED then
			hooksecurefunc('ActionButton_UpdateCooldown', ActionButtonGreyOnCooldown_UpdateCooldown)
			GREYONCOOLDOWN_HOOKED = true
		end
	end

-----------------------------
-- INITIALIZATION
-----------------------------
	local function InitializeAddon()
		HideMacroName()
		StopAutoSpellToActionBar()
		StopAutoHearthstoneToBag()
		HideLossOfControlOverlay()
		HookGreyOnCooldownIcons()
	end

-- REGISTER EVENTS
	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventFrame:SetScript("OnEvent", InitializeAddon)