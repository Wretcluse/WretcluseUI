local ADDON, ns = ...

ns:RegisterModule("threatmacro", function(ns)
	-----------------------------
	-- THREAT MACRO UPDATER
	-----------------------------
	local allowedPlayers = {
		Wretcluse = true,
		Mekkadorque = true,
	}

	local playerName = UnitName("player")
	if not allowedPlayers[playerName] then
		return
	end -- Worried that others may have full macro slots.

	local template = '#showtooltip %s\n/cast [mod:alt,@focus,help,nodead] %s\n/cast [@%s,help,nodead][@pet,help,nodead][help,nodead] %s'
	local spells = {
		ROGUE = { id = 57934, name = "Tricks of the Trade" },
		HUNTER = { id = 34477, name = "Misdirection" },
	}

	local tankName = ""

	local function PrintMessage(message)
		ns:Print(message)
	end

	local function PlayerHasRequiredSpell()
		local class = select(2, UnitClass("player"))
		local spellInfo = spells[class]
		if not spellInfo then return false end

		if C_Spell and C_Spell.IsSpellKnown then
			return C_Spell.IsSpellKnown(spellInfo.id)
		end

		if IsPlayerSpell then
			return IsPlayerSpell(spellInfo.id)
		end

		if IsSpellKnown then
			return IsSpellKnown(spellInfo.id)
		end

		return false
	end

	local function GetMacroName()
		local _, classFile = UnitClass("player")
		return classFile .. " 00T"
	end

	local function UpdateMacro()
		if not PlayerHasRequiredSpell() then return end

		local class = select(2, UnitClass("player"))
		local spellInfo = spells[class]
		local spellName = spellInfo.name
		local name = GetMacroName()

		local targetName = tankName ~= "" and tankName or "target"
		local body = string.format(template, spellName, spellName, targetName, spellName)
		local spellData = C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellInfo.id)
		local icon = (spellData and spellData.iconID) or 134400

		local currMacro, _, currBody = GetMacroInfo(name)
		if currBody then currBody = strtrim(currBody) end

		local macroUpdated = false
		if not currMacro then
			CreateMacro(name, icon, body, true)
			macroUpdated = true
		elseif currBody ~= body then
			EditMacro(name, name, icon, body, 1, 1)
			macroUpdated = true
		end

		if macroUpdated then
			if tankName ~= "" then
				PrintMessage('Updated "' .. name .. '" macro to use ' .. spellName .. ' on "' .. tankName .. '".')
			else
				PrintMessage('No tank found. Updated "' .. name .. '" macro to fall back to pet or current target.')
			end
		end
	end

	local function FindTank()
		tankName = ""

		if IsInRaid() then
			for i = 1, GetNumGroupMembers() do
				local unit = "raid" .. i
				if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "TANK" then
					tankName = UnitName(unit)
					return
				end
			end
		elseif IsInGroup() then
			if UnitGroupRolesAssigned("player") == "TANK" then
				tankName = UnitName("player")
				return
			end

			for i = 1, GetNumSubgroupMembers() do
				local unit = "party" .. i
				if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "TANK" then
					tankName = UnitName(unit)
					return
				end
			end
		end
	end

	local function HandleUpdate()
		if InCombatLockdown() then return end
		FindTank()
		UpdateMacro()
	end

	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:RegisterEvent("GROUP_JOINED")
	f:RegisterEvent("READY_CHECK")
	f:RegisterEvent("PLAYER_ROLES_ASSIGNED")
	f:RegisterEvent("GROUP_ROSTER_UPDATE")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_REGEN_ENABLED" and not InCombatLockdown() then
			HandleUpdate()
			return
		end

		HandleUpdate()
	end)
end)
