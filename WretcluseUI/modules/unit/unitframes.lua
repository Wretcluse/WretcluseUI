
-----------------------------
-- HIDE PORTRAIT COMBAT TEXT
-----------------------------
	local function CombatFeedback_OnCombatEvent_Hook(self, event, flags, amount, type)
		if self.feedbackText then
			self.feedbackText:SetText("")
		end
	end

	hooksecurefunc("CombatFeedback_OnCombatEvent", CombatFeedback_OnCombatEvent_Hook)

	local function HideCombatFeedbackText(self)
		if self.feedbackText then
			self.feedbackText:SetText("")
		end
	end

	hooksecurefunc("PlayerFrame_Update", function()
		HideCombatFeedbackText(PlayerFrame)
	end)

-----------------------------
-- COLOR HEALTH BARS
-----------------------------
	local function Health_PostUpdate(healthbar, unit)
		if not healthbar then return end

		if UnitIsPlayer(unit) and (not UnitIsConnected(unit)) then
			healthbar:SetStatusBarDesaturated(true)
			healthbar:SetStatusBarColor(0.5, 0.5, 0.5)
		else
			healthbar:SetStatusBarDesaturated(true)
			healthbar:SetStatusBarColor(0.3, 0.3, 0.3)
		end

		local bg = healthbar:CreateTexture(nil, "BACKGROUND")
		bg:SetTexture("Interface\\Addons\\WretcluseUI\\media\\TARGETINGFRAME\\UI-HealthBackground.tga")
		bg:SetAllPoints()
	end
	hooksecurefunc("UnitFrameHealthBar_Update", Health_PostUpdate)-- UnitFrame.lua 
	hooksecurefunc("HealthBar_OnValueChanged", function(self)-- HealthBar.lua
		Health_PostUpdate(self, self.unit)
	end)

-----------------------------
-- CREATE MANABAR BACKGROUND
-----------------------------
	local function CreateManaBarBackground(manaBar, atlasName, color)
		if not manaBar or manaBar.background then return end

		local bg = manaBar:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(manaBar)

		if atlasName then
			bg:SetAtlas(atlasName, true)
			bg:SetVertexColor(0.3, 0.3, 0.3, 0.5)
		end

		manaBar.background = bg
	end

-----------------------------
-- DETERMINE ATLAS FOR UNIT FRAME
-----------------------------
	local function GetManaBarAtlas(unit)
		if UnitIsUnit(unit, "target") then
			return "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana-Status"
		elseif UnitIsUnit(unit, "party1") or UnitIsUnit(unit, "party2") or UnitIsUnit(unit, "party3") or UnitIsUnit(unit, "party4") then
			return "UI-HUD-UnitFrame-Party-PortraitOn-Bar-Mana-Status"
		elseif UnitIsUnit(unit, "targettarget") then
			return "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana-Status"
		elseif UnitIsUnit(unit, "focustarget") then
			return "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana-Status"
		elseif UnitIsUnit(unit, "player") then
			return "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana-Status"
		end
		return nil
	end

-----------------------------
-- HOOK MANABAR TO APPLY COLOR & BACKGROUND
-----------------------------
	hooksecurefunc("UnitFrameManaBar_UpdateType", function(self)
		if UnitIsPlayer(self.unit) then
			local c = RAID_CLASS_COLORS[select(2, UnitClass(self.unit))]
			if c then
				self:SetStatusBarColor(c.r, c.g, c.b)
				self:SetStatusBarTexture("Interface\\Addons\\WretcluseUI\\media\\TARGETINGFRAME\\UI-ManaBar")
			end
		end

		-- Determine the appropriate atlas for the unit frame
		local atlasName = GetManaBarAtlas(self.unit)
		
		-- Create and set the background for the mana bar with the determined atlas
		-- Pass class color to tint the background
		local classColor = RAID_CLASS_COLORS[select(2, UnitClass(self.unit))]
		CreateManaBarBackground(self, atlasName, classColor)
	end)

-----------------------------
-- SET REPUTATION BEHIND MANA TAR/FOCUS
-----------------------------
	local function ManaBarBG(self)
		self.TargetFrameContent.TargetFrameContentMain.ReputationColor:SetAtlas("UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana", true)
		if UnitIsPlayer(self.unit) then
			self.TargetFrameContent.TargetFrameContentMain.ReputationColor:Hide()
		else
			self.TargetFrameContent.TargetFrameContentMain.ReputationColor:Show()
		end

		self.TargetFrameContent.TargetFrameContentContextual.NumericalThreat:SetPoint("BOTTOM", self.TargetFrameContent.TargetFrameContentMain.ReputationColor, "TOP", 0, 35)
	end

	hooksecurefunc(TargetFrame, "CheckFaction", ManaBarBG)
	hooksecurefunc(FocusFrame, "CheckFaction", ManaBarBG)

-----------------------------
-- NAME COLOR & FONT
-----------------------------
	local function NameColor_PostUpdate(self)
		if not self.name then return end

		local DEFAULT_YELLOW_COLOR = {r = 1.0, g = 0.82, b = 0.0}
		local defaultTextColor = DEFAULT_YELLOW_COLOR -- Ensure default text color is set
		local unit = self.unit
		local DefaultFont, DefaultSize, DefaultStyle = self.name:GetFont()
		local _, class = UnitClass(unit)
		local colorName

		if class and UnitIsPlayer(unit) then
			colorName = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
		else
			colorName = defaultTextColor
		end

		local FontSizeIncrement = 2 
		if self == TargetFrame or self == FocusFrame then
			FontSizeIncrement = 4 
		end

		if not self.name.FontSizeIncreased then
			DefaultSize = DefaultSize + FontSizeIncrement
			self.name.FontSizeIncreased = true
		end

		self.name:SetWidth(145)
		self.name:SetTextColor(colorName.r, colorName.g, colorName.b)
		self.name:SetFont(DefaultFont, DefaultSize, "OUTLINE")
	end

	hooksecurefunc("UnitFrame_Update", NameColor_PostUpdate)

-----------------------------
-- HEALTHPERCENT UPDATE FUNC
-----------------------------
	local namePercent, hpPercent = ...
	local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax

	local function healthUpdate(frame, _, unit)
		if GetCVar("statusTextDisplay") ~= "BOTH" then return end
		unit = unit or frame.unit 
		local hp = UnitHealth(unit)
		local maxhp = UnitHealthMax(unit)
		-- If maxhp then hide
		if hp == maxhp then
			hpPercent[unit]:SetText("") 
		elseif hp == 0 then
			hpPercent[unit]:SetText("")
		elseif hp > 0 then 
			hp = hp / UnitHealthMax(unit) * 100 
			hpPercent[unit]:SetFormattedText("%.1f", hp)
		else 
			hpPercent[unit]:SetText("0%") 
		end 
	end

-----------------------------
-- SHOW/HIDE BASED ON CVAR
-----------------------------
	local function toggleFontStrings()
		local statusTextDisplay = GetCVar("statusTextDisplay")
		for unit, fontString in pairs(hpPercent) do
			if statusTextDisplay == "BOTH" then
				fontString:Show()
			else
				fontString:Hide()
			end
		end
	end

	hooksecurefunc("SetCVar", function(cvar, value)
		if cvar == "statusTextDisplay" then
			toggleFontStrings()
		end
	end)

-----------------------------
-- PLAYERFRAME HEALTHPERCENT
-----------------------------
	PlayerName:SetAlpha(0)
	PlayerLevelText:SetFont("Fonts\\ARIALN.TTF", 16, "OUTLINE")
	PlayerLevelText:SetPoint("TOPRIGHT", PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar, "TOPRIGHT", -168, 0)
	hpPercent.player = CreateFrame("Frame", "PlayerPercent", PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarArea)
	hpPercent.player:SetPoint("LEFT", PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarArea, "LEFT", 50, -1)
	hpPercent.player:SetWidth(80)
	hpPercent.player:SetHeight(22)
	hpPercent.player:SetScript("OnEvent", healthUpdate)
	hpPercent.player.unit = "player"
	hpPercent.player:RegisterUnitEvent("UNIT_HEALTH", "player")
	hpPercent.player = hpPercent.player:CreateFontString("PlayerPercentText", "OVERLAY")
	hpPercent.player:SetAllPoints("PlayerPercent")
	hpPercent.player:SetFont("Fonts\\FRIZQT__.ttf", 18, "OUTLINE")
	hpPercent.player:SetJustifyH("RIGHT")
	PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarArea.HealthBar.RightText:SetAlpha(0)
	PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarArea.HealthBar.LeftText:SetAlpha(0)
	PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar.RightText:SetAlpha(0)
	PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar.LeftText:SetAlpha(0)
	AlternatePowerBar.RightText:SetAlpha(0)
	AlternatePowerBar.LeftText:SetAlpha(0)

-----------------------------
-- UPDATE FUNCTION FOR TEXT
-----------------------------
	local function UpdateFrameContent(frame)
		if not frame then return end
		
		frame.Name:ClearAllPoints()
		frame.Name:SetPoint("TOPLEFT", frame.ReputationColor, "TOPLEFT", 0, 35)
		frame.ReputationColor:SetAllPoints(frame.ManaBar)
		frame.LevelText:SetFont("Fonts\\ARIALN.TTF", 16, "OUTLINE")
		frame.LevelText:SetPoint("TOPLEFT", frame.ReputationColor, "TOPLEFT", 168, 0)
		frame.HealthBar.RightText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
		frame.HealthBar.RightText:SetPoint("LEFT", frame.HealthBar, "LEFT", 2, 2)
		frame.HealthBar.RightText:SetJustifyH("LEFT")
		frame.HealthBar.LeftText:SetAlpha(0)
		frame.HealthBar.LeftText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
		frame.HealthBar.LeftText:SetPoint("RIGHT", frame.HealthBar, "RIGHT", 2, 0)
		frame.HealthBar.LeftText:SetJustifyH("RIGHT")
		frame.ManaBar.RightText:SetAlpha(0)
		frame.ManaBar.LeftText:SetAlpha(0)
	end

-----------------------------
-- Update TargetFrame
-----------------------------
	UpdateFrameContent(TargetFrame.TargetFrameContent.TargetFrameContentMain)

-----------------------------
-- Update FocusFrame
-----------------------------
	UpdateFrameContent(FocusFrame.TargetFrameContent.TargetFrameContentMain)

-----------------------------
-- TARGETFRAME HEALTHPERCENT
-----------------------------
	hpPercent.target = CreateFrame("Frame", namePercent, TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBar)
	hpPercent.target:SetPoint("RIGHT", TargetFrame.TargetFrameContent.TargetFrameContentMain.HealthBar, "RIGHT", 0, -1)
	hpPercent.target:SetWidth(80)
	hpPercent.target:SetHeight(22)
	hpPercent.target:SetScript("OnEvent", healthUpdate)
	hpPercent.target.unit = "target"
	hpPercent.target:RegisterEvent("PLAYER_TARGET_CHANGED")
	hpPercent.target:RegisterUnitEvent("UNIT_HEALTH", "target")
	hpPercent.target = hpPercent.target:CreateFontString("TargetPercentText", "OVERLAY")
	hpPercent.target:SetAllPoints(namePercent)
	hpPercent.target:SetFont("Fonts\\FRIZQT__.ttf", 18, "OUTLINE")
	hpPercent.target:SetJustifyH("RIGHT")

-----------------------------
-- FOCUSFRAME HEALTHPERCENT
-----------------------------
	hpPercent.focus = CreateFrame("Frame", "FocusPercent", FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBar)
	hpPercent.focus:SetPoint("RIGHT", FocusFrame.TargetFrameContent.TargetFrameContentMain.HealthBar, "RIGHT", 0, -1)
	hpPercent.focus:SetWidth(80)
	hpPercent.focus:SetHeight(22)
	hpPercent.focus:SetScript("OnEvent", healthUpdate)
	hpPercent.focus.unit = "focus"
	hpPercent.focus:RegisterEvent("PLAYER_FOCUS_CHANGED")
	hpPercent.focus:RegisterUnitEvent("UNIT_HEALTH", "focus")
	hpPercent.focus = hpPercent.focus:CreateFontString("FocusPercentText", "OVERLAY")
	hpPercent.focus:SetAllPoints("FocusPercent")
	hpPercent.focus:SetFont("Fonts\\FRIZQT__.ttf", 18, "OUTLINE")
	hpPercent.focus:SetJustifyH("RIGHT")

-----------------------------
-- HIDE PARTY TEXT
-----------------------------
	local function HidePartyFrameText(frame)
		if not frame then return end
		
		frame.HealthBar.RightText:SetAlpha(0)
		frame.HealthBar.LeftText:SetAlpha(0)
		frame.ManaBar.RightText:SetAlpha(0)
		frame.ManaBar.LeftText:SetAlpha(0)
	end

-----------------------------
-- PARTYFRAMES HEALTHPERCENT
-----------------------------
	for i = 1, 4 do
		local party, Party = ("party%d"):format(i), ("Party%d"):format(i)
		local partyFrame = PartyFrame["MemberFrame"..i]

		if partyFrame then
			local healthBar = partyFrame.HealthBar

			if healthBar then
				hpPercent[party] = CreateFrame("Frame", Party.."Percent", healthBar)
				hpPercent[party]:SetPoint("LEFT", healthBar, "LEFT", -8, 0)
				hpPercent[party]:SetWidth(30)
				hpPercent[party]:SetHeight(22)
				hpPercent[party]:SetScript("OnEvent", healthUpdate)
				hpPercent[party].unit = party
				hpPercent[party]:RegisterUnitEvent("UNIT_HEALTH", party)
				hpPercent[party] = hpPercent[party]:CreateFontString(Party.."PercentText", "OVERLAY")
				hpPercent[party]:SetAllPoints(Party.."Percent")
				hpPercent[party]:SetFont("Fonts\\FRIZQT__.ttf", 8, "OUTLINE")
				hpPercent[party]:SetJustifyH("RIGHT")
				HidePartyFrameText(partyFrame)
			else
				print("Error: HealthBar not found for PartyFrameMemberFrame" .. i)
			end
		else
			print("Error: PartyFrameMemberFrame" .. i .. " not found")
		end
	end

-----------------------------
-- HIDE BOSS TEXT
-----------------------------
	local function HideBossFrameText(frame)
		if not frame then return end

		frame.TargetFrameContent.TargetFrameContentMain.HealthBar.RightText:SetAlpha(0)
		frame.TargetFrameContent.TargetFrameContentMain.HealthBar.LeftText:SetAlpha(0)
		frame.TargetFrameContent.TargetFrameContentMain.ManaBar.RightText:SetAlpha(0)
		frame.TargetFrameContent.TargetFrameContentMain.ManaBar.LeftText:SetAlpha(0)
	end

-----------------------------
-- BOSSFRAME HEALTHPERCENT
-----------------------------
	for i = 1, 5 do
		local boss, Boss = ("boss%d"):format(i), ("Boss%d"):format(i)
		local bossFrame = _G[Boss.."TargetFrame"]
		local healthBar = bossFrame and bossFrame.TargetFrameContent and bossFrame.TargetFrameContent.TargetFrameContentMain and bossFrame.TargetFrameContent.TargetFrameContentMain.HealthBar

		if healthBar then
			hpPercent[boss] = CreateFrame("Frame", Boss.."Percent", healthBar)
			hpPercent[boss]:SetPoint("RIGHT", healthBar, "RIGHT", 0, -1)
			hpPercent[boss]:SetWidth(80)
			hpPercent[boss]:SetHeight(22)
			hpPercent[boss]:SetScript("OnEvent", healthUpdate)
			hpPercent[boss]:SetScript("OnShow", healthUpdate)
			hpPercent[boss].unit = boss
			hpPercent[boss]:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT")
			hpPercent[boss]:RegisterUnitEvent("UNIT_HEALTH", boss)
			hpPercent[boss] = hpPercent[boss]:CreateFontString(Boss.."PercentText", "OVERLAY")
			hpPercent[boss]:SetAllPoints(Boss.."Percent")
			hpPercent[boss]:SetFont("Fonts\\FRIZQT__.ttf", 8, "OUTLINE")
			hpPercent[boss]:SetJustifyH("RIGHT")
		end
		HideBossFrameText(bossFrame)
	end

-----------------------------
-- INITIAL TOGGLE
-----------------------------
	toggleFontStrings()