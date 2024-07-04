
-----------------------------
-- THREAT MACRO UPDATER
-----------------------------
	local playerName = UnitName("player")
	if playerName ~= "Wretcluse" then return end--Worried that others may have full macro slots and IDK what happens. 

	local template = '#showtooltip %s\n/cast [mod:alt, target=focus, help, nodead] %s\n/cast [target=%s, help, nodead][@pet, help, nodead] %s'
	local spells = {
		["ROGUE"] = { id = 57934, name = 'Tricks of the Trade' },
		["HUNTER"] = { id = 34477, name = 'Misdirection' }
	}

	local TankName = ""

	local function PrintMessage(message)
		print("|cFFFFD100WretcluseUI:|r " .. message)
	end

	local function PlayerHasRequiredSpell()
		local class = select(2, UnitClass('player'))
		local spellInfo = spells[class]
		return spellInfo and IsSpellKnown(spellInfo.id)
	end

	local function UpdateMacro()
		if not PlayerHasRequiredSpell() then return end

		local class = select(2, UnitClass('player'))
		local spellInfo = spells[class]
		local spellName = spellInfo.name
		local name = UnitClass('player') .. " 00T"
		local body = string.format(template, spellName, spellName, TankName, spellName)
		local icon = select(3, GetSpellInfo(spellInfo.id)) or 134400

		local currMacro, _, currBody = GetMacroInfo(name)
		if currBody then currBody = strtrim(currBody) end

		local macroUpdated = false
		if not currMacro then
			CreateMacro(name, icon, body)
			macroUpdated = true
		elseif currBody ~= body then
			EditMacro(name, name, icon, body)
			macroUpdated = true
		end

		if macroUpdated and not InCombatLockdown() then
			if TankName ~= "" then
				PrintMessage('Updated "' .. name .. '" macro to use ' .. spellName .. ' on "' .. TankName .. '".')
			else
				PrintMessage('No tank found. Updated "' .. name .. '" macro to only work on active pet or current target.')
			end
		elseif macroUpdated then
			local function OnPlayerRegenEnabled()
				UpdateMacro()
				f:UnregisterEvent("PLAYER_REGEN_ENABLED")
			end
			f:RegisterEvent("PLAYER_REGEN_ENABLED")
		end
	end

	local function FindTank_OnEvent(self, event, ...)
		local groupType = (IsInRaid() and "raid") or (IsInGroup() and "party") or nil
		if groupType then
			for i = 1, GetNumGroupMembers() do
				if UnitGroupRolesAssigned(groupType .. i) == "TANK" then
					TankName = UnitName(groupType .. i)
					UpdateMacro()
					return
				end
			end
		end
		TankName = ""
		UpdateMacro()
	end

	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("GROUP_JOINED")
	f:RegisterEvent("READY_CHECK")
	f:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	f:RegisterEvent("GROUP_ROSTER_UPDATE")
	f:SetScript("OnEvent", FindTank_OnEvent)