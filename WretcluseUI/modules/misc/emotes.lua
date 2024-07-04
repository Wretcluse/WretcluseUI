
-----------------------------
-- EMOTE ANNOUNCE COMBAT ALERTS
-----------------------------
	-- Required WoW API functions and constants
	local format, select = string.format, select
	local bit_band = bit.band
	local CombatLogGetCurrentEventInfo, GetSpellLink, UnitName, UnitInRaid, UnitInParty, SendChatMessage = CombatLogGetCurrentEventInfo, GetSpellLink, UnitName, UnitInRaid, UnitInParty, SendChatMessage

-----------------------------
-- ACTION FORMAT
-----------------------------
	local infoType = {
		SPELL_MISSED = "reflected %s %s",
		SPELL_STOLEN = "steals %s %s",
		SPELL_DISPEL = "dispels %s %s",
		SPELL_INTERRUPT = "interrupted %s %s",
		SPELL_AURA_BROKEN_SPELL = "acknowledges %s %s",
	}

-----------------------------
-- BLACKLIST AOE STOPS TO AVOID SPAM
-----------------------------
	local blackList = {
		[99] = true,		-- Incapacitating Roar
		[122] = true,		-- Frost Nova
		[1776] = true,		-- Gouge
		[1784] = true,		-- Stealth
		[5246] = true,		-- Intimidating Shout
		[8122] = true,		-- Psychic Scream
		[31661] = true,		-- Dragon's Breath
		[33395] = true,		-- Freeze
		[64695] = true,		-- Earthgrab
		[82691] = true,		-- Ring of Frost
		[91807] = true,		-- Shambling Rush
		[102359] = true,	-- Mass Entanglement
		[105421] = true,	-- Blinding Light
		[115191] = true,	-- Stealth
		[157997] = true,	-- Ice Nova
		[197214] = true,	-- Sundering
		[198120] = true,	-- Frostbite
		[198121] = true,	-- Frostbite
		[207167] = true,	-- Blinding Sleet
		[207685] = true,	-- Sigil of Misery
		[226943] = true,	-- Mind Bomb
		[228600] = true,	-- Glacial Spike
		[331866] = true,	-- Agent of Chaos
		[386770] = true,	-- Freezing Cold
		[354051] = true,	-- Nimble Steps
		[105771] = true,		--IMMUNE
	}

	local function GetMsgChannel()
		return "EMOTE"
	end

	local function IsAllyPet(sourceFlags)
		return bit_band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_MINE) > 0 or
			   bit_band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_PARTY) > 0 or
			   bit_band(sourceFlags, COMBATLOG_OBJECT_AFFILIATION_RAID) > 0
	end

	local function SendFormattedMessage(infoText, sourceName, spellLink)
		SendChatMessage(format(infoText, sourceName .. "'s", spellLink .. "."), GetMsgChannel())
	end

	local function HandleCombatLogEvent()
		local _, eventType, _, sourceGUID, sourceName, sourceFlags, _, _, destName, _, _, spellID, _, _, extraskillID, _, _, auraType = CombatLogGetCurrentEventInfo()
		if not sourceGUID or sourceName == destName then return end

		local infoText = infoType[eventType]
		if not infoText then return end

		if infoText == "reflected %s %s" and select(15, CombatLogGetCurrentEventInfo()) == "REFLECT" and destName == UnitName("player") then
			local spellLink = GetSpellLink(spellID)
			if spellLink then
				SendFormattedMessage(infoText, sourceName, spellLink)
			end
		elseif UnitInRaid(sourceName) or UnitInParty(sourceName) or IsAllyPet(sourceFlags) then
			local sourceSpellID, destSpellID
			if infoText == "acknowledges %s %s" then
				if auraType == "BUFF" or blackList[spellID] or UnitInRaid() then return end
				sourceSpellID, destSpellID = extraskillID, spellID
			else
				sourceSpellID, destSpellID = spellID, extraskillID
			end

			if sourceSpellID and destSpellID then
				local destSpellLink = GetSpellLink(destSpellID)
				if destSpellLink then
					SendFormattedMessage(infoText, destName, destSpellLink)
				end
			end

			if infoText == "acknowledges %s %s" then
				local sourceSpellLink = GetSpellLink(sourceSpellID)
				local destSpellLink = GetSpellLink(destSpellID)
				if sourceSpellLink and destSpellLink then
					SendChatMessage(format(infoText, sourceName .. "'s " .. sourceSpellLink, "clears " .. destName .. "'s " .. destSpellLink) .. ".", GetMsgChannel())
				end
			end
		end
	end

	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	eventFrame:SetScript("OnEvent", HandleCombatLogEvent)