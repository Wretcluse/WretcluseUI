-- modules/unitframes.lua
local ADDON, ns = ...

ns:RegisterModule("unitframes", function(ns)
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

	if not healthbar.bg then
		healthbar.bg = healthbar:CreateTexture(nil, "BACKGROUND")
		healthbar.bg:SetAllPoints(healthbar)
		healthbar.bg:SetTexture("Interface\\Addons\\WretcluseUI\\media\\TARGETINGFRAME\\UI-HealthBackground")
	end

	if unit then -- temp fix for BOSS FRAME UPDATES SUBMITTED BUG REPORT FOR HEALTHBAR 66% DEPLETE
		if string.match(unit, "boss%d") then
			healthbar.bg:SetAlpha(0)
		else
			healthbar.bg:SetAlpha(1)
		end
	end
end

hooksecurefunc("UnitFrameHealthBar_Update", Health_PostUpdate) -- UnitFrame.lua
hooksecurefunc("HealthBar_OnValueChanged", function(self) -- HealthBar.lua
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
-- DETERMINE ATLAS FOR UNIT FRAME (Midnight/12.0-safe)
-----------------------------
local function GetManaBarAtlas(unit)
	if not unit then return nil end

	-- NOTE (12.0/Midnight): Avoid UnitIsUnit() here.
	-- In some instance-only update paths (arena/arenapet/etc), UnitIsUnit() may return "secret values"
	-- that error when used in boolean tests (if/elseif).
	if unit == "target" then
		return "UI-HUD-UnitFrame-Target-PortraitOn-Bar-Mana-Status"
	elseif unit == "targettarget" then
		return "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana-Status"
	elseif unit == "focustarget" then
		return "UI-HUD-UnitFrame-TargetofTarget-PortraitOn-Bar-Mana-Status"
	elseif unit == "player" then
		return "UI-HUD-UnitFrame-Player-PortraitOn-Bar-Mana-Status"
	elseif unit:match("^party%d$") then
		return "UI-HUD-UnitFrame-Party-PortraitOn-Bar-Mana-Status"
	end

	-- Everything else (arena, arenapet, boss, nameplate, etc.)
	return nil
end

-----------------------------
-- SAFE CLASS COLOR LOOKUP (Midnight/12.1)
-----------------------------
local function GetAccessibleClassColor(unit)
	if not unit then return nil end

	local _, class = UnitClass(unit)
	if not class or not canaccessvalue(class) then
		return nil
	end

	return (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
end

-----------------------------
-- HOOK MANABAR TO APPLY COLOR & BACKGROUND
-----------------------------
hooksecurefunc("UnitFrameManaBar_UpdateType", function(self)
	if not self then return end
	local unit = self.unit
	if not unit then return end

	-- Midnight 12.1 can return a secret class token for identity-restricted units.
	-- pcall() does not make a secret value safe to use as a Lua table key, so
	-- only index the class-color table when the value is accessible.
	if UnitIsPlayer(unit) then
		local c = GetAccessibleClassColor(unit)
		if c then
			self:SetStatusBarColor(c.r, c.g, c.b)
			self:SetStatusBarTexture("Interface\\Addons\\WretcluseUI\\media\\TARGETINGFRAME\\UI-ManaBar")
		end
	end

	-- Determine the appropriate atlas for the unit token directly.
	local atlasName = GetManaBarAtlas(unit)

	-- The old classColor argument was unused by CreateManaBarBackground, so
	-- avoid a second UnitClass() lookup entirely.
	CreateManaBarBackground(self, atlasName)
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
	local DefaultFont, DefaultSize = self.name:GetFont()
	local colorName = defaultTextColor

	if UnitIsPlayer(unit) then
		local classColor = GetAccessibleClassColor(unit)
		if classColor then
			colorName = classColor
		end
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
-- PLAYERFRAME HEALTHPERCENT
-----------------------------
PlayerName:SetAlpha(0)
PetName:SetAlpha(0)

PlayerLevelText:SetFont("Fonts\\ARIALN.TTF", 16, "OUTLINE")
PlayerLevelText:SetPoint("TOPRIGHT", PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.ManaBarArea.ManaBar, "TOPRIGHT", -168, 0)

PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.RightText:SetAlpha(0)
PlayerFrame.PlayerFrameContent.PlayerFrameContentMain.HealthBarsContainer.LeftText:SetAlpha(0)
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
	frame.Name:SetPoint("BOTTOMLEFT", frame.HealthBarsContainer, "TOPLEFT", 1, 1)
	frame.ReputationColor:SetAllPoints(frame.ManaBar)
	frame.LevelText:SetFont("Fonts\\ARIALN.TTF", 16, "OUTLINE")
	frame.LevelText:SetPoint("TOPLEFT", frame.ReputationColor, "TOPLEFT", 168, 0)
	frame.HealthBarsContainer.RightText:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
	frame.HealthBarsContainer.RightText:SetPoint("LEFT", frame.HealthBarsContainer, "LEFT", 2, 2)
	frame.HealthBarsContainer.RightText:SetJustifyH("LEFT")
	frame.HealthBarsContainer.LeftText:SetAlpha(0)
	frame.HealthBarsContainer.LeftText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
	frame.HealthBarsContainer.LeftText:SetPoint("RIGHT", frame.HealthBarsContainer, "RIGHT", 2, 0)
	frame.HealthBarsContainer.LeftText:SetJustifyH("RIGHT")
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
-- HIDE PARTY TEXT
-----------------------------
local function HidePartyFrameText(frame)
	if not frame then return end

	frame.HealthBarContainer.RightText:SetAlpha(0)
	frame.HealthBarContainer.LeftText:SetAlpha(0)
	frame.ManaBar.RightText:SetAlpha(0)
	frame.ManaBar.LeftText:SetAlpha(0)
end

-----------------------------
-- PARTYFRAMES HEALTHPERCENT
-----------------------------
for i = 1, 4 do
	local partyFrame = PartyFrame["MemberFrame"..i]
	-- (Placeholder) Call HidePartyFrameText(partyFrame) if/when desired
end

-----------------------------
-- HIDE BOSS TEXT
-----------------------------
local function HideBossFrameText(frame)
	if not frame then return end

	frame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.RightText:SetAlpha(0)
	frame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer.LeftText:SetAlpha(0)
	frame.TargetFrameContent.TargetFrameContentMain.ManaBar.RightText:SetAlpha(0)
	frame.TargetFrameContent.TargetFrameContentMain.ManaBar.LeftText:SetAlpha(0)
end

-----------------------------
-- BOSSFRAME HEALTHPERCENT
-----------------------------
for i = 1, MAX_BOSS_FRAMES do
	local bossFrame = _G["Boss"..i.."TargetFrame"]
	local healthBar = bossFrame and bossFrame.TargetFrameContent.TargetFrameContentMain.HealthBarsContainer
	-- (Placeholder) Call HideBossFrameText(bossFrame) if/when desired
end

end)
