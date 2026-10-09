-- modules/misc.lua
local ADDON, ns = ...

ns:RegisterModule("misc", function(ns)
	-----------------------------
	-- CHAT MESSAGE FORMAT
	-----------------------------
	local function PrintMessage(message)
		ns:Print(message)
	end

	-----------------------------
	-- CVAR UPDATES
	-----------------------------
	local function UpdateCVar(cVar, desiredValue)
		local currentValue = GetCVar(cVar)
		if tonumber(currentValue) ~= desiredValue then
			SetCVar(cVar, desiredValue)
			PrintMessage(cVar .. " set to " .. desiredValue)
		end
	end

	local function ApplyCVarUpdates()
		UpdateCVar("cameraDistanceMaxZoomFactor", 2.6)       -- MAXIMIZE CAMERA
--		UpdateCVar("floatingCombatTextCombatDamage", 0)    -- HIDE DEFAULT SCT
--		UpdateCVar("floatingCombatTextCombatHealing", 0)   -- HIDE DEFAULT SCT HEALING
--		UpdateCVar("autoInteract", 1)                      -- CLICK TO MOVE
	end

	-----------------------------
	-- RED UI ERROR TEXT
	-----------------------------
	local function AdjustUIErrorsFrame()
		UIErrorsFrame:ClearAllPoints()
		UIErrorsFrame:SetJustifyH("LEFT")
		UIErrorsFrame:SetPoint("CENTER", 412, 160)
		UIErrorsFrame:SetWidth(512)
		UIErrorsFrame:SetHeight(60)
	end

	-----------------------------
	-- FASTER LOOTING
	-----------------------------
	-- Handle LOOT_READY on this module's single event frame. The previous
	-- implementation created a new event frame on every PLAYER_ENTERING_WORLD,
	-- which could accumulate duplicate loot handlers after zoning.
	local lootDelay = 0.1

	local function LootFaster()
		local thisTime = GetTime()
		if thisTime - lootDelay < 0.3 then
			return
		end

		if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
			lootDelay = thisTime
			for i = GetNumLootItems(), 1, -1 do
				LootSlot(i)
			end
		end
	end

	-----------------------------
	-- HANDLE AUTO REPAIR LOGIC
	-----------------------------
	local function AutoRepair(forcePersonal)
		if not CanMerchantRepair() then
			return
		end

		local repairAllCost, canRepair = GetRepairAllCost()
		if not canRepair or repairAllCost == 0 then
			return
		end

		local myMoney = GetMoney()

		-- Prefer guild repair when available. If Blizzard later reports that the
		-- guild repair failed, UI_ERROR_MESSAGE retries with personal gold.
		if not forcePersonal and IsInGuild() and CanGuildBankRepair() then
			local guildWithdraw = GetGuildBankWithdrawMoney()
			if guildWithdraw and guildWithdraw >= repairAllCost then
				RepairAllItems(true)
				PrintMessage(string.format(
					"Repair cost covered by G-Bank: %s.",
					GetCoinTextureString(repairAllCost)
				))
				return
			end
		end

		if myMoney >= repairAllCost then
			RepairAllItems()
			PrintMessage(string.format(
				"Repaired all items for %s.",
				GetCoinTextureString(repairAllCost)
			))
		else
			PrintMessage("Not enough gold to repair.")
		end
	end

	-----------------------------
	-- ADD DECIMAL TO PULL PERCENT
	-----------------------------
	-- Do not replace BonusObjectiveTrackerProgressBarMixin.SetValue. Replacing a
	-- Blizzard mixin method lets addon execution enter Blizzard-owned update paths
	-- and is increasingly taint-prone in Midnight. Instead, securely post-hook the
	-- existing method and only alter the label when the value is safely readable.
	local bonusProgressHooked = false

	local function IsAccessibleNumber(value)
		if issecretvalue and issecretvalue(value) then
			return false
		end

		if canaccessvalue and not canaccessvalue(value) then
			return false
		end

		return type(value) == "number"
	end

	local function BonusObjectiveProgress_PostSetValue(self, percent)
		if not IsAccessibleNumber(percent) then
			return
		end

		local bar = self and self.Bar
		local label = bar and bar.Label
		if label then
			label:SetFormattedText("%.2f%%", percent)
		end
	end

	local function TryHookBonusObjectiveProgress()
		if bonusProgressHooked then
			return
		end

		local mixin = _G.BonusObjectiveTrackerProgressBarMixin
		if mixin and type(mixin.SetValue) == "function" then
			hooksecurefunc(mixin, "SetValue", BonusObjectiveProgress_PostSetValue)
			bonusProgressHooked = true
		end
	end

	-----------------------------
	-- REPAIR GOSSIP SHORTCUTS
	-----------------------------
	local repairGossipIDs = {
		[37005] = true, -- Jeeves
		[44982] = true, -- Reeves
	}

	local function SelectRepairGossip()
		if IsShiftKeyDown() then
			return
		end

		local options = C_GossipInfo.GetOptions()
		for i = 1, #options do
			local option = options[i]
			local optionID = option and option.gossipOptionID
			if optionID and repairGossipIDs[optionID] then
				C_GossipInfo.SelectOption(optionID)
				return
			end
		end
	end

	-----------------------------
	-- EVENT HANDLER
	-----------------------------
	local function OnEvent(self, event, ...)
		if event == "PLAYER_ENTERING_WORLD" then
			AdjustUIErrorsFrame()
			ApplyCVarUpdates()
			TryHookBonusObjectiveProgress()

		elseif event == "LOOT_READY" then
			LootFaster()

		elseif event == "MERCHANT_SHOW" then
			AutoRepair(false)
			self:RegisterEvent("UI_ERROR_MESSAGE")
			self:RegisterEvent("MERCHANT_CLOSED")

		elseif event == "UI_ERROR_MESSAGE" then
			-- UI_ERROR_MESSAGE payload is: errorType, message.
			local errorType = ...
			if errorType == LE_GAME_ERR_GUILD_NOT_ENOUGH_MONEY then
				AutoRepair(true)
			end

		elseif event == "MERCHANT_CLOSED" then
			self:UnregisterEvent("UI_ERROR_MESSAGE")
			self:UnregisterEvent("MERCHANT_CLOSED")

		elseif event == "GOSSIP_SHOW" then
			SelectRepairGossip()

		elseif event == "ADDON_LOADED" then
			TryHookBonusObjectiveProgress()
			if bonusProgressHooked then
				self:UnregisterEvent("ADDON_LOADED")
			end
		end
	end

	-----------------------------
	-- INITIALIZATION
	-----------------------------
	TryHookBonusObjectiveProgress()

	local addon = CreateFrame("Frame")
	addon:RegisterEvent("PLAYER_ENTERING_WORLD")
	addon:RegisterEvent("LOOT_READY")
	addon:RegisterEvent("MERCHANT_SHOW")
	addon:RegisterEvent("GOSSIP_SHOW")

	if not bonusProgressHooked then
		addon:RegisterEvent("ADDON_LOADED")
	end

	addon:SetScript("OnEvent", OnEvent)
end)
