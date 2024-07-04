
-----------------------------
-- CHAT MESSAGE FORMAT
-----------------------------
	local function PrintMessage(message)
		print("|cFFFFD100WretcluseUI:|r " .. message)
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
		UpdateCVar("cameraDistanceMaxZoomFactor", 2.6)		-- MAXIMIZE CAMERA
--		UpdateCVar("floatingCombatTextCombatDamage", 0)		-- HIDE DEFAULT SCT
--		UpdateCVar("floatingCombatTextCombatHealing", 0)	-- HIDE DEFAULT SCT HEALING
--		UpdateCVar("autoInteract", 1)						-- CLICK TO MOVE
	end

-----------------------------
-- RED UI ERROR TEXT
-----------------------------
	local function AdjustUIErrorsFrame()
		UIErrorsFrame:ClearAllPoints()
		UIErrorsFrame:SetJustifyH("LEFT")
		UIErrorsFrame:SetPoint("CENTER", UIParent, "CENTER", 412, -60)
		UIErrorsFrame:SetWidth(512)
		UIErrorsFrame:SetHeight(60)
	end

-----------------------------
-- Faster Looting
-----------------------------
	local lootDelay = 0

	local function LootFaster()
		local thisTime = GetTime()
		if thisTime - lootDelay >= .3 then
			lootDelay = thisTime
			if GetCVarBool("autoLootDefault") ~= IsModifiedClick("AUTOLOOTTOGGLE") then
				for i = GetNumLootItems(), 1, -1 do
					LootSlot(i)
				end
				lootDelay = thisTime
			end
		end
	end

	local function RegisterLootEvents()
		local frame = CreateFrame("Frame")
		frame:RegisterEvent("LOOT_READY")
		frame:SetScript("OnEvent", LootFaster)
	end

-----------------------------
-- HANDLE AUTO SELL LOGIC
-----------------------------
	local function SellJunk()
		local totalGain = 0
		for bag = 0, 4 do
			for slot = 1, C_Container.GetContainerNumSlots(bag) do
				local ItemInfo = C_Container.GetContainerItemInfo(bag, slot)
				if ItemInfo then
					local _, _, quality, _, _, mogSafe, _, _, _, _, itemSellPrice = GetItemInfo(ItemInfo.hyperlink)
					local armor_weapon = ((mogSafe == "Armor") or (mogSafe == "Weapon"))
					local isBound = C_Item.IsBound(ItemLocation:CreateFromBagAndSlot(bag,slot))
					if quality == 0 and not ItemInfo.isLocked and not armor_weapon or (armor_weapon and isBound) and itemSellPrice then
						totalGain = totalGain + (itemSellPrice * ItemInfo.stackCount)
						C_Container.UseContainerItem(bag, slot)
					end
				end
			end
		end
		if totalGain > 0 then
			PrintMessage(format("Sold junk items for %s", GetCoinTextureString(totalGain) .. "."))
		end
	end

-----------------------------
-- HANDLE AUTO REPAIR LOGIC
-----------------------------
	local function AutoRepair(override)
		if not CanMerchantRepair() then return end

		local repairAllCost, canRepair = GetRepairAllCost()
		if not canRepair or repairAllCost == 0 then return end

		local myMoney = GetMoney()
		if IsInGuild() and CanGuildBankRepair() and GetGuildBankWithdrawMoney() >= repairAllCost then
			RepairAllItems(true)
			PrintMessage(format("Repair cost covered by G-Bank: %s", GetCoinTextureString(repairAllCost) .. "."))
		elseif myMoney >= repairAllCost then
			RepairAllItems()
			PrintMessage(format("Repaired all items for %s", GetCoinTextureString(repairAllCost) .. "."))
		else
			PrintMessage("Not enough gold to repair.")
		end
	end

-----------------------------
-- ADD DECIMAL TO PULL PERCENT
-----------------------------
	local function ProgressBar_SetValue(self, percent)
		self.Bar.Label:SetFormattedText("%.2f%%", percent)
	end

	hooksecurefunc("ScenarioTrackerProgressBar_SetValue", ProgressBar_SetValue)

-----------------------------
-- INPUT KEY AUTOMATION & MOVABLE FRAME
-----------------------------
	local IDs = {	[138019] = 1, 
					[151086] = 1, 
					[158923] = 1, 
					[180653] = 1, 
					[186159] = 1
				}

	local function FontofPower_OnShow()
		local ID, Class, SubClass

		for bag = 0, NUM_BAG_FRAMES do
			for slot = 1, C_Container.GetContainerNumSlots(bag) do
				ID = C_Container.GetContainerItemID(bag, slot)

				if ID then
					Class, SubClass = select(12, GetItemInfo(ID))

					if (IDs[ID] or (Class == 5 and SubClass == 1)) then
						return C_Container.UseContainerItem(bag, slot)
					end
				end
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
			RegisterLootEvents()
			self:RegisterEvent("MERCHANT_SHOW")
			self:RegisterEvent("GOSSIP_SHOW")
		elseif event == "MERCHANT_SHOW" then
			SellJunk()
			AutoRepair()
			self:RegisterEvent("UI_ERROR_MESSAGE")
			self:RegisterEvent("MERCHANT_CLOSED")
		elseif event == "UI_ERROR_MESSAGE" then
			local _, msgType = ...
			if msgType == LE_GAME_ERR_GUILD_NOT_ENOUGH_MONEY then
				AutoRepair(true)
			end
		elseif event == "MERCHANT_CLOSED" then
			self:UnregisterEvent("UI_ERROR_MESSAGE")
			self:UnregisterEvent("MERCHANT_CLOSED")
		elseif event == "GOSSIP_SHOW" then
			if IsShiftKeyDown() then return end

			local repairGossipIDs = {
				[37005] = true, -- Jeeves
				[44982] = true, -- Reeves
			}

			local options = C_GossipInfo.GetOptions()
			for i = 1, #options do
				local option = options[i]
				if repairGossipIDs[option.gossipOptionID] then
					C_GossipInfo.SelectOption(option.gossipOptionID)
				end
			end
		elseif event == "ADDON_LOADED" then
			local addon = ...
			if addon ~= "Blizzard_ChallengesUI" then return end

			if ChallengesKeystoneFrame then
				local Frame = ChallengesKeystoneFrame

				Frame:HookScript("OnShow", FontofPower_OnShow)

				if not Frame:IsMovable() then
					Frame:SetMovable(true)
					Frame:SetClampedToScreen(true)
					Frame:RegisterForDrag("LeftButton")
					Frame:SetScript("OnDragStart", Frame.StartMoving)
					Frame:SetScript("OnDragStop", Frame.StopMovingOrSizing)
				end

				self:UnregisterEvent(event)
			end
		end
	end

	local addon = CreateFrame("Frame")

	addon:RegisterEvent("PLAYER_ENTERING_WORLD")
	addon:RegisterEvent("ADDON_LOADED")
	addon:SetScript("OnEvent", OnEvent)