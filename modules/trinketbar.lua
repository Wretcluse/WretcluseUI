local addonName, ns = ...

--[[
    WretcluseUI - Trinketbar_CopyBuffBarViewerAppearance.lua

    Tracks configured trinket / potion buff spell IDs using Blizzard's
    CooldownViewerBuffBarItemTemplate.

    Key idea:
      - Do NOT add items to Blizzard's Cooldown Manager data/layout.
      - Do NOT parent custom bars to BuffBarCooldownViewer.
      - Do copy BuffBarCooldownViewer's already-applied visual settings out of combat:
          iconScale, timerShown, tooltipsShown, barContent, GetBarWidth()
      - During combat, only update alpha/text/icon/statusbar values.

    Add BUFF SPELL IDs, not item IDs.
]]

local eventFrame = CreateFrame("Frame")
local holder = CreateFrame("Frame", "WretcluseUITrinketBarHolder", UIParent)

local TRACKED_BUFFS = {
    [383781] = {
        duration = 20,
        label = "Algeth'ar Puzzle Box",
        triggerSpellIDs = {
            [383781] = true,
        },
    },

    -- Potions / extra buff spell IDs:
     [1236616] = { duration = 30, label = "Light's Potential", triggerSpellIDs = { [1236616] = true } },
     [1236617] = { duration = 30, label = "Light's Potential", triggerSpellIDs = { [1236617] = true } },
}

local ANCHOR_NEAR_BLIZZARD_BUFF_BAR = true
local BLIZZARD_ANCHOR_X_OFFSET = 0
local BLIZZARD_ANCHOR_Y_OFFSET = 26

local FALLBACK_ANCHOR_POINT = "CENTER"
local FALLBACK_ANCHOR_RELATIVE_TO = UIParent
local FALLBACK_ANCHOR_RELATIVE_POINT = "CENTER"
local FALLBACK_ANCHOR_X = 0
local FALLBACK_ANCHOR_Y = -200

local BAR_SPACING = 5

-- Fallback only. Normally we copy Blizzard's current BuffBarCooldownViewer
-- layout direction out of combat and use the opposite direction.
local FALLBACK_CUSTOM_GROW_UP = true

local DEFAULT_BAR_WIDTH = 220
local DEFAULT_BAR_HEIGHT = 30
local FALLBACK_ICON_SCALE = 0.90
local FALLBACK_BAR_WIDTH_SCALE = 1.05
local FALLBACK_BAR_CONTENT = Enum and Enum.CooldownViewerBarContent and Enum.CooldownViewerBarContent.IconAndName or 1
local FALLBACK_TIMER_SHOWN = true
local FALLBACK_TOOLTIPS_SHOWN = true

local barsBySpellID = {}
local orderedBars = {}
local activeData = {}
local appearance = nil
local anchorInfo = nil
local initialized = false
local tickerActive = false

local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function SafeSpellInfo(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then
            return info.name, info.iconID
        end
    end

    return tostring(spellID), nil
end

local function FormatTime(seconds)
    if seconds >= 60 then
        return string.format("%dm", math.ceil(seconds / 60))
    elseif seconds >= 10 then
        return tostring(math.ceil(seconds))
    else
        return string.format("%.1f", seconds)
    end
end

local function CountTrackedBuffs()
    local count = 0
    for _ in pairs(TRACKED_BUFFS) do
        count = count + 1
    end
    return count
end

local function GetFallbackAppearance()
    local barWidth = DEFAULT_BAR_WIDTH * FALLBACK_BAR_WIDTH_SCALE

    return {
        source = "fallback",
        iconScale = FALLBACK_ICON_SCALE,
        barWidth = barWidth,
        barContent = FALLBACK_BAR_CONTENT,
        timerShown = FALLBACK_TIMER_SHOWN,
        tooltipsShown = FALLBACK_TOOLTIPS_SHOWN,
        customGrowUp = FALLBACK_CUSTOM_GROW_UP,
        frameHeight = DEFAULT_BAR_HEIGHT * FALLBACK_ICON_SCALE,
        holderWidth = barWidth,
    }
end

local function CopyNativeAppearance()
    if InCombat() then
        return
    end

    local viewer = _G.BuffBarCooldownViewer
    if not viewer then
        appearance = GetFallbackAppearance()
        return
    end

    local barWidth = DEFAULT_BAR_WIDTH
    if viewer.GetBarWidth then
        local ok, value = pcall(viewer.GetBarWidth, viewer)
        if ok and value and value > 0 then
            barWidth = value
        end
    elseif viewer.baseBarWidth and viewer.barWidthScale then
        barWidth = viewer.baseBarWidth * viewer.barWidthScale
    end

    local iconScale = viewer.iconScale or FALLBACK_ICON_SCALE
    local barContent = viewer.barContent or FALLBACK_BAR_CONTENT

    local timerShown = viewer.timerShown
    if timerShown == nil then
        timerShown = FALLBACK_TIMER_SHOWN
    end

    local tooltipsShown = viewer.tooltipsShown
    if tooltipsShown == nil then
        tooltipsShown = FALLBACK_TOOLTIPS_SHOWN
    end

    local container = viewer.GetItemContainerFrame and viewer:GetItemContainerFrame() or viewer

    -- Blizzard sets this during CooldownViewerMixin:RefreshLayout().
    -- For vertical layouts, true means Blizzard's tracked bars grow upward.
    -- We intentionally use the opposite direction for our custom trinket/potion bars.
    local blizzardGrowsUp = container and container.layoutFramesGoingUp
    local customGrowUp
    if type(blizzardGrowsUp) == "boolean" then
        customGrowUp = not blizzardGrowsUp
    else
        customGrowUp = FALLBACK_CUSTOM_GROW_UP
    end

    appearance = {
        source = "BuffBarCooldownViewer",
        iconScale = iconScale,
        barWidth = barWidth,
        barContent = barContent,
        timerShown = timerShown,
        tooltipsShown = tooltipsShown,
        customGrowUp = customGrowUp,
        frameHeight = DEFAULT_BAR_HEIGHT * iconScale,
        holderWidth = barWidth,
    }
end

local function GetAppearance()
    if not appearance then
        appearance = GetFallbackAppearance()
    end
    return appearance
end

local function CopyNativeAnchor()
    if InCombat() then
        return
    end

    if ANCHOR_NEAR_BLIZZARD_BUFF_BAR then
        local viewer = _G.BuffBarCooldownViewer
        if viewer and viewer.GetCenter then
            local cx, cy = viewer:GetCenter()
            if cx and cy then
                anchorInfo = {
                    point = "CENTER",
                    relativeTo = UIParent,
                    relativePoint = "BOTTOMLEFT",
                    x = cx + BLIZZARD_ANCHOR_X_OFFSET,
                    y = cy + BLIZZARD_ANCHOR_Y_OFFSET,
                    source = "BuffBarCooldownViewer:GetCenter",
                }
                return
            end
        end
    end

    anchorInfo = {
        point = FALLBACK_ANCHOR_POINT,
        relativeTo = FALLBACK_ANCHOR_RELATIVE_TO,
        relativePoint = FALLBACK_ANCHOR_RELATIVE_POINT,
        x = FALLBACK_ANCHOR_X,
        y = FALLBACK_ANCHOR_Y,
        source = "fallback",
    }
end

local function GetAnchorInfo()
    if not anchorInfo then
        CopyNativeAnchor()
    end
    return anchorInfo
end

local function ApplyAppearanceToBar(bar)
    local a = GetAppearance()

    if bar.SetScale then
        bar:SetScale(a.iconScale or 1)
    end

    if bar.SetTimerShown then
        bar:SetTimerShown(a.timerShown)
    elseif bar.Bar and bar.Bar.Duration then
        bar.Bar.Duration:SetShown(a.timerShown)
    end

    if bar.SetTooltipsShown then
        bar:SetTooltipsShown(a.tooltipsShown)
    else
        bar:SetMouseMotionEnabled(a.tooltipsShown)
        bar:SetMouseClickEnabled(false)
    end

    if bar.SetBarContent then
        bar:SetBarContent(a.barContent)
    end

    if bar.SetBarWidth then
        bar:SetBarWidth(a.barWidth or DEFAULT_BAR_WIDTH)
    else
        bar:SetWidth(a.barWidth or DEFAULT_BAR_WIDTH)
    end
end

local function ApplyHolderAnchorAndLayout()
    if InCombat() then
        return
    end

    local a = GetAppearance()
    local anchor = GetAnchorInfo()

    holder:ClearAllPoints()
    holder:SetPoint(anchor.point, anchor.relativeTo, anchor.relativePoint, anchor.x, anchor.y)

    local count = math.max(1, CountTrackedBuffs())
    local rowHeight = (a.frameHeight and a.frameHeight > 0) and a.frameHeight or DEFAULT_BAR_HEIGHT
    holder:SetSize(a.holderWidth or DEFAULT_BAR_WIDTH, (rowHeight * count) + (BAR_SPACING * math.max(0, count - 1)))

    local customGrowUp = a.customGrowUp == true

    for index, bar in ipairs(orderedBars) do
        ApplyAppearanceToBar(bar)

        bar:ClearAllPoints()

        if index == 1 then
            -- Keep the same x-axis center as the holder, but grow away on the y-axis.
            -- If Blizzard grows down, our first bar anchors upward from the center.
            -- If Blizzard grows up, our first bar anchors downward from the center.
            if customGrowUp then
                bar:SetPoint("BOTTOM", holder, "CENTER", 0, 0)
            else
                bar:SetPoint("TOP", holder, "CENTER", 0, 0)
            end
        else
            local previous = orderedBars[index - 1]
            if customGrowUp then
                bar:SetPoint("BOTTOM", previous, "TOP", 0, BAR_SPACING)
            else
                bar:SetPoint("TOP", previous, "BOTTOM", 0, -BAR_SPACING)
            end
        end
    end
end

local function SetBarActive(bar, active)
    bar:SetAlpha(active and 1 or 0)
    bar:EnableMouse(active and true or false)
end

local function CreateTrackedBar(spellID, cfg)
    local bar = CreateFrame("Frame", nil, holder, "CooldownViewerBuffBarItemTemplate")
    bar.spellID = spellID
    bar.configuredDuration = (cfg and cfg.duration) or 1

    local spellName, spellIcon = SafeSpellInfo(spellID)
    bar.cachedName = (cfg and cfg.label) or spellName or tostring(spellID)
    bar.cachedIcon = spellIcon

    ApplyAppearanceToBar(bar)

    if bar.Icon and bar.Icon.Icon and bar.cachedIcon then
        bar.Icon.Icon:SetTexture(bar.cachedIcon)
    end

    if bar.Icon and bar.Icon.Applications then
        bar.Icon.Applications:SetText("")
    end

    if bar.Bar and bar.Bar.Name then
        bar.Bar.Name:SetText(bar.cachedName or "")
    end

    if bar.Bar and bar.Bar.Duration then
        bar.Bar.Duration:SetText("")
    end

    if bar.Bar then
        bar.Bar:SetMinMaxValues(0, bar.configuredDuration)
        bar.Bar:SetValue(0)
    end

    if bar.Bar and bar.Bar.Pip then
        bar.Bar.Pip:Hide()
    end

    bar:Show()
    SetBarActive(bar, false)

    barsBySpellID[spellID] = bar
    orderedBars[#orderedBars + 1] = bar

    return bar
end

local function PrecreateBars()
    if InCombat() then
        return
    end

    for spellID, cfg in pairs(TRACKED_BUFFS) do
        if not barsBySpellID[spellID] then
            CreateTrackedBar(spellID, cfg)
        end
    end

    table.sort(orderedBars, function(a, b)
        return (a.spellID or 0) < (b.spellID or 0)
    end)
end

local function RefreshOutOfCombatGeometry()
    if InCombat() then
        return
    end

    CopyNativeAppearance()
    CopyNativeAnchor()
    PrecreateBars()
    ApplyHolderAnchorAndLayout()
    initialized = true
end

local function UpdateBarVisuals(spellID, data)
    local bar = barsBySpellID[spellID]
    if not bar or not data then
        return
    end

    if bar.Icon and bar.Icon.Icon and data.icon then
        bar.Icon.Icon:SetTexture(data.icon)
    end

    if bar.Icon and bar.Icon.Applications then
        if data.applications and data.applications > 1 then
            bar.Icon.Applications:SetText(data.applications)
        else
            bar.Icon.Applications:SetText("")
        end
    end

    if bar.Bar and bar.Bar.Name then
        bar.Bar.Name:SetText(data.name or bar.cachedName or "")
    end

    SetBarActive(bar, true)
end

local function ApplyAuraState(spellID, aura, allowHide)
    local bar = barsBySpellID[spellID]
    if not bar then
        return
    end

    if not aura or not aura.expirationTime then
        if allowHide then
            activeData[spellID] = nil
            SetBarActive(bar, false)

            if bar.Bar then
                bar.Bar:SetValue(0)
                if bar.Bar.Pip then
                    bar.Bar.Pip:Hide()
                end
            end

            if bar.Bar and bar.Bar.Duration then
                bar.Bar.Duration:SetText("")
            end
        end
        return
    end

    local duration = aura.duration or bar.configuredDuration
    if not duration or duration <= 0 then
        return
    end

    activeData[spellID] = {
        duration = duration,
        expirationTime = aura.expirationTime,
        name = aura.name or bar.cachedName,
        icon = aura.icon or bar.cachedIcon,
        applications = aura.applications,
    }

    UpdateBarVisuals(spellID, activeData[spellID])
end

local function ScanTrackedAuras(allowHide)
    for spellID in pairs(TRACKED_BUFFS) do
        local aura = C_UnitAuras.GetPlayerAuraBySpellID(spellID)
        ApplyAuraState(spellID, aura, allowHide)
    end
end

local function ActivateFromConfiguredDuration(spellID)
    local bar = barsBySpellID[spellID]
    local cfg = TRACKED_BUFFS[spellID]
    if not bar or not cfg then
        return
    end

    activeData[spellID] = {
        duration = cfg.duration or bar.configuredDuration or 1,
        expirationTime = GetTime() + (cfg.duration or bar.configuredDuration or 1),
        name = bar.cachedName,
        icon = bar.cachedIcon,
        applications = nil,
    }

    UpdateBarVisuals(spellID, activeData[spellID])
end

local function UpdateActiveBars()
    local anyActive = false
    local now = GetTime()

    for spellID, data in pairs(activeData) do
        local bar = barsBySpellID[spellID]
        local remaining = data.expirationTime and (data.expirationTime - now) or 0

        if not bar or remaining <= 0 then
            activeData[spellID] = nil

            if bar then
                SetBarActive(bar, false)

                if bar.Bar then
                    bar.Bar:SetValue(0)
                    if bar.Bar.Pip then
                        bar.Bar.Pip:Hide()
                    end
                end

                if bar.Bar and bar.Bar.Duration then
                    bar.Bar.Duration:SetText("")
                end
            end
        else
            anyActive = true

            if bar.Bar then
                bar.Bar:SetMinMaxValues(0, data.duration)
                bar.Bar:SetValue(remaining)

                if bar.Bar.Pip then
                    bar.Bar.Pip:Show()
                end
            end

            if bar.Bar and bar.Bar.Duration and bar.Bar.Duration:IsShown() then
                bar.Bar.Duration:SetText(FormatTime(remaining))
            end
        end
    end

    return anyActive
end

local function EnableTicker()
    if tickerActive then
        return
    end

    tickerActive = true
    eventFrame:SetScript("OnUpdate", function()
        if not UpdateActiveBars() then
            tickerActive = false
            eventFrame:SetScript("OnUpdate", nil)
        end
    end)
end

local function RefreshAuraState()
    if not initialized and not InCombat() then
        RefreshOutOfCombatGeometry()
    end

    ScanTrackedAuras(not InCombat())

    if UpdateActiveBars() then
        EnableTicker()
    end
end

local function HandleSpellcastSucceeded(unit, _castGUID, spellID)
    if unit ~= "player" or not spellID then
        return
    end

    for trackedSpellID, cfg in pairs(TRACKED_BUFFS) do
        if cfg and cfg.triggerSpellIDs and cfg.triggerSpellIDs[spellID] then
            ActivateFromConfiguredDuration(trackedSpellID)
            UpdateActiveBars()
            EnableTicker()
            return
        end
    end
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(_, event, unit, ...)
    if event == "UNIT_AURA" and unit ~= "player" then
        return
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if not InCombat() then
            RefreshOutOfCombatGeometry()
        end
        RefreshAuraState()
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        HandleSpellcastSucceeded(unit, ...)
        RefreshAuraState()
        return
    end

    if event == "EDIT_MODE_LAYOUTS_UPDATED" or event == "UI_SCALE_CHANGED" or event == "PLAYER_REGEN_ENABLED" then
        if not InCombat() then
            RefreshOutOfCombatGeometry()
            RefreshAuraState()
        end
        return
    end

    if event == "UNIT_AURA" then
        RefreshAuraState()
    end
end)
