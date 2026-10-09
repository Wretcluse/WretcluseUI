-- modules/nameplates.lua
-- WretcluseUI: Nameplates styling (Midnight / Retail)
--
-- Features:
--   - Adds WretcluseUI's healthbar background texture to nameplate health bars.
--   - Highlights important hostile NPC health bars for Mythic+ readability:
--       boss/worldboss-style units = purple
--       mini-boss/rare/strong elite units = blue
--       caster-style units = cyan
--   - Colors player nameplate health bars grey to match WretcluseUI unitframes.
--   - Adds a subtle focus overlay texture for hostile focus nameplates.
--   - Avoids reading protected/secret nameplate aura data.
--     In Midnight 12.1, direct addon calls that enumerate secret nameplate auras can
--     raise a taint error even when a Blizzard aura filter is supplied. The previous
--     custom player-dispellable/enrage indicator is therefore disabled here until it
--     can be migrated to Blizzard's new filtered-aura display APIs.
--   - Avoids reading Blizzard's protected/secret nameplate color values.
--
-- Name text color priority:
--   1. Current target = white.
--   2. Current focus = gold/yellow.
--   3. Player units = class color.
--   4. NPCs with active combat threat data = Blizzard threat color.
--   5. Out-of-combat hostile NPCs by UnitReaction <= 3 = red.
--   6. Out-of-combat neutral/friendly/non-hostile NPCs = white.
--
-- Note: UnitCanAttack can be true for neutral/yellow NPCs, so NPC name color
-- uses UnitReaction instead of attackability when deciding the idle red/white state.
--
-- Health bar color priority:
--   1. Player units = WretcluseUI grey.
--   2. Important hostile NPCs = type color above.
--   3. Standard hostile/non-hostile NPCs = left to Blizzard/default nameplate coloring.
--

local ADDON, ns = ...

ns:RegisterModule("nameplates", function(ns)

	local BG_TEXTURE = (ns.Media and ns.Media.HealthBackground) or "Interface\\Addons\\WretcluseUI\\media\\TARGETINGFRAME\\UI-HealthBackground"
	local FOCUS_TEXTURE = "Interface\\Addons\\WretcluseUI\\media\\TARGETINGFRAME\\FocusTarget"

	local COLORS = {
		focus = { 1.0, 0.82, 0.0 },
		boss = { 0.80, 0.20, 1.00 },
		miniBoss = { 0.20, 0.40, 1.00 },
		caster = { 0.00, 0.80, 1.00 },
		playerHealth = { 0.30, 0.30, 0.30 },
		npcHostileName = { 1.00, 0.00, 0.00 },
		npcNonHostileName = { 1.00, 1.00, 1.00 },
	}

	local function GetUnitClassColor(unit)
		local _, classFile = UnitClass(unit)
		local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
		if c then return c.r, c.g, c.b end
		return 1, 1, 1
	end

	local function GetUnitThreatColor(unit)
		if not unit or not UnitExists(unit) or not GetThreatStatusColor then return nil end

		-- Keep threat colors as a combat-state override only.
		-- UnitThreatSituation returns nil when there is no meaningful threat data.
		local status = UnitThreatSituation("player", unit)
		if status == nil then return nil end

		-- Avoid letting stale or non-combat threat states override the simple NPC fallback colors.
		if not UnitAffectingCombat("player") and not UnitAffectingCombat(unit) then
			return nil
		end

		return GetThreatStatusColor(status)
	end

	local function GetNameplateFrameForUnit(unit)
		if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return nil end
		return C_NamePlate.GetNamePlateForUnit(unit)
	end

	local function GetUnitFrame(nameplate)
		return (nameplate and (nameplate.UnitFrame or nameplate.unitFrame)) or nil
	end

	local function GetHealthBar(unitFrame)
		return unitFrame and (unitFrame.healthBar or unitFrame.HealthBar or unitFrame.healthbar) or nil
	end

	local function GetNameText(unitFrame)
		return unitFrame and (unitFrame.name or unitFrame.Name or unitFrame.nameText or unitFrame.NameText) or nil
	end

	local function IsHostileEnemy(unit)
		if not unit or not UnitExists(unit) then return false end
		if UnitIsFriend("player", unit) then return false end
		if UnitCanAttack and not UnitCanAttack("player", unit) then return false end
		return true
	end

	local function IsHostileNPCReaction(unit)
		if not unit or not UnitExists(unit) then return false end

		-- UnitCanAttack can also be true for neutral/yellow NPCs.
		-- UnitReaction is better for the idle name-color fallback:
		--   1-3 = hostile/unfriendly, 4 = neutral, 5-8 = friendly.
		local reaction = UnitReaction and UnitReaction("player", unit)
		if reaction then
			return reaction <= 2
		end

		-- Fallback for edge cases where reaction is unavailable.
		if UnitIsEnemy then
			return UnitIsEnemy("player", unit)
		end

		return IsHostileEnemy(unit)
	end

	local function GetUnitType(unit)
		if not unit then return "standard" end

		local classification = UnitClassification(unit)
		if classification == "worldboss" then
			return "boss"
		elseif classification == "rare" then
			return "miniBoss"
		elseif classification == "elite" or classification == "rareelite" then
			local unitLevel = UnitLevel(unit)
			local playerLevel = UnitLevel("player")
			if unitLevel == -1 or (unitLevel and playerLevel and (unitLevel - playerLevel) >= 2) then
				return "boss"
			elseif unitLevel and playerLevel and (unitLevel - playerLevel) >= 1 then
				return "miniBoss"
			end
		end

		if UnitPowerType(unit) == 0 then
			return "caster"
		end

		return "standard"
	end

	local function StyleHealthBar(bar)
		if not bar then return end

		if ns.CreateBackgroundTexture then
			ns:CreateBackgroundTexture(bar, BG_TEXTURE, 1, "BACKGROUND", -8)
		else
			if not bar.__wret_bg then
				local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
				bg:SetAllPoints(bar)
				bg:SetTexture(BG_TEXTURE)
				bg:SetAlpha(1)
				bar.__wret_bg = bg
			end
		end
	end

	local function GetHealthBarTypeColor(unit)
		if not IsHostileEnemy(unit) then return nil end

		local unitType = GetUnitType(unit)
		if unitType == "boss" then
			return unpack(COLORS.boss)
		elseif unitType == "miniBoss" then
			return unpack(COLORS.miniBoss)
		elseif unitType == "caster" then
			return unpack(COLORS.caster)
		end

		return nil
	end

	local function StyleNameText(nameText, unit)
		if not nameText or not unit then return end

		if UnitIsUnit(unit, "target") then
			nameText:SetTextColor(1, 1, 1)
			return
		elseif UnitIsUnit(unit, "focus") then
			nameText:SetTextColor(unpack(COLORS.focus))
			return
		end

		-- Player nameplates keep class-colored names.
		if UnitIsPlayer(unit) then
			local r, g, b = GetUnitClassColor(unit)
			nameText:SetTextColor(r, g, b)
			return
		end

		-- NPC nameplates use threat colors while combat threat data exists.
		-- Outside combat, use UnitReaction instead of UnitCanAttack so neutral/yellow
		-- NPCs do not get treated like truly hostile red-name NPCs.
		local tr, tg, tb = GetUnitThreatColor(unit)
		if tr then
			nameText:SetTextColor(tr, tg, tb)
		elseif IsHostileNPCReaction(unit) then
			nameText:SetTextColor(unpack(COLORS.npcHostileName))
		else
			nameText:SetTextColor(unpack(COLORS.npcNonHostileName))
		end
	end

	local function GetOrCreateFocusOverlay(healthBar)
		if not healthBar then return nil end
		if healthBar.__wret_focusOverlay then
			return healthBar.__wret_focusOverlay
		end

		local overlay = healthBar:CreateTexture(nil, "OVERLAY")
		overlay:SetTexture(FOCUS_TEXTURE)
		overlay:SetPoint("TOPLEFT", healthBar, "TOPLEFT", -1, 1)
		overlay:SetPoint("BOTTOMRIGHT", healthBar, "BOTTOMRIGHT", 1, -1)
		overlay:SetBlendMode("ADD")
		overlay:Hide()
		healthBar.__wret_focusOverlay = overlay
		return overlay
	end

	local function UpdateFocusOverlay(healthBar, unit)
		if not healthBar then return end
		local overlay = GetOrCreateFocusOverlay(healthBar)
		if not overlay then return end

		if UnitExists("focus") and UnitIsUnit(unit, "focus") and IsHostileEnemy(unit) then
			local r, g, b = unpack(COLORS.focus)
			overlay:SetVertexColor(r, g, b, 0.2)
			overlay:Show()
		else
			overlay:Hide()
		end
	end


	local function StyleUnit(unit)
		local nameplate = GetNameplateFrameForUnit(unit)
		local uf = GetUnitFrame(nameplate)
		if not uf then return end

		local healthBar = GetHealthBar(uf)
		local nameText = GetNameText(uf)

		StyleHealthBar(healthBar)
		StyleNameText(nameText, unit)
		UpdateFocusOverlay(healthBar, unit)

		if healthBar then
			if UnitIsPlayer(unit) then
				healthBar:SetStatusBarColor(unpack(COLORS.playerHealth))
			elseif IsHostileEnemy(unit) then
				local r, g, b = GetHealthBarTypeColor(unit)
				if r then
					healthBar:SetStatusBarColor(r, g, b)
				end
			end
		end
	end

	local active = {}

	local function RestyleAllActive()
		for unit in pairs(active) do
			StyleUnit(unit)
		end
	end

	local f = CreateFrame("Frame")
		f:RegisterEvent("NAME_PLATE_UNIT_ADDED")
		f:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
		f:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
		f:RegisterEvent("PLAYER_TARGET_CHANGED")
		f:RegisterEvent("PLAYER_FOCUS_CHANGED")
		f:RegisterEvent("PLAYER_ENTERING_WORLD")

	f:SetScript("OnEvent", function(_, event, arg1)
		if event == "NAME_PLATE_UNIT_ADDED" then
			active[arg1] = true
			StyleUnit(arg1)

		elseif event == "NAME_PLATE_UNIT_REMOVED" then
			active[arg1] = nil

		elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
			if active[arg1] then
				StyleUnit(arg1)
			end

		elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
			RestyleAllActive()
		end
	end)

	local function SafeHook(funcName)
		local fn = _G[funcName]
		if type(fn) == "function" then
			hooksecurefunc(funcName, function(frame)
				if frame and frame.unit and frame.unit:match("^nameplate") then
					StyleUnit(frame.unit)
				end
			end)
		end
	end

	SafeHook("CompactUnitFrame_UpdateHealthColor")
	SafeHook("CompactUnitFrame_UpdateName")
	SafeHook("CompactUnitFrame_UpdateNameColor")

	if C_Timer and C_Timer.After then
		C_Timer.After(0, RestyleAllActive)
	end
end)
