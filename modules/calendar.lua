-- WretcluseUI - calendar.lua
-- Lightweight, default-style scale slider for the default Blizzard Calendar.

local addonName, ns = ...

local MODULE_NAME = "calendar"
local MIN_SCALE = 50
local MAX_SCALE = 150
local DEFAULT_SCALE = 100
local STEP = 10


local frame = CreateFrame("Frame")
local sliderHolder
local slider
local valueText
local hookedCalendar = false
local currentScalePercent = DEFAULT_SCALE

local function Clamp(value, minValue, maxValue)
    value = tonumber(value) or DEFAULT_SCALE

    if value < minValue then
        return minValue
    elseif value > maxValue then
        return maxValue
    end

    return value
end

local function GetScalePercent()
    currentScalePercent = Clamp(currentScalePercent, MIN_SCALE, MAX_SCALE)
    return currentScalePercent
end

local function ApplyCalendarScale(percent)
    if not CalendarFrame then
        return
    end

    percent = Clamp(percent, MIN_SCALE, MAX_SCALE)
    CalendarFrame:SetScale(percent / 100)
end

local function UpdateValueText(percent)
    if valueText then
        valueText:SetText(string.format("%d%%", percent))
    end
end

local function PositionSlider()
    if not sliderHolder or not CalendarFrame then
        return
    end

    sliderHolder:ClearAllPoints()
    sliderHolder:SetPoint("BOTTOMLEFT", UIParent, "TOPLEFT", 6, -64)
end

local function SetSliderShown(shown)
    if sliderHolder then
        sliderHolder:SetShown(shown and CalendarFrame and CalendarFrame:IsShown())
    end
end

local function CreateCalendarSlider()
    if slider or not CalendarFrame then
        return
    end

    -- Keep the slider outside CalendarFrame so it does not inherit CalendarFrame:SetScale().
    -- This lets the Calendar scale while the slider remains easy to drag.
    sliderHolder = CreateFrame("Frame", "WretcluseUICalendarScaleSliderHolder", UIParent, "BackdropTemplate")
    sliderHolder:SetSize(186, 64)
    -- Do not derive numeric frame state from a Blizzard-owned frame.
    -- Fixed strata/level keeps this addon frame isolated from protected/secret UI state.
    sliderHolder:SetFrameStrata("DIALOG")
    sliderHolder:SetFrameLevel(100)
    sliderHolder:SetScale(1)
    sliderHolder:EnableMouse(true)
    sliderHolder:Hide()

    -- Blizzard-style Lua backdrop; no XML file is needed for this small panel.
    sliderHolder:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    sliderHolder:SetBackdropColor(0, 0, 0, 0.85)

    local title = sliderHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", sliderHolder, "TOP", 0, -12)
    title:SetText("Calendar Scale")

    -- IMPORTANT: use a plain Slider rather than OptionsSliderTemplate.
    -- OptionsSliderTemplate owns tooltip scripts that touch the global GameTooltip.
    -- In Midnight, touching GameTooltip from addon execution can taint tooltip
    -- dimensions and later make Blizzard arithmetic fail on secret numbers.
    slider = CreateFrame("Slider", nil, sliderHolder)
    slider:SetSize(150, 16)
    slider:SetPoint("TOP", title, "BOTTOM", 0, -2)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(MIN_SCALE, MAX_SCALE)
    slider:SetValueStep(STEP)
    slider:SetObeyStepOnDrag(true)

    -- Recreate the small amount of slider artwork we need without inheriting
    -- any Blizzard option-template scripts.
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetTexture("Interface\\Buttons\\UI-SliderBar-Background")
    track:SetPoint("LEFT", slider, "LEFT", 0, 0)
    track:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    track:SetHeight(8)

    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    local thumb = slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(32, 32)
    end

    local lowText = sliderHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lowText:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, 0)
    lowText:SetText(MIN_SCALE .. "%")

    local highText = sliderHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    highText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, 0)
    highText:SetText(MAX_SCALE .. "%")

    valueText = sliderHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, 0)

    slider:SetScript("OnValueChanged", function(self, value)
        local percent = Clamp(math.floor(value + 0.5), MIN_SCALE, MAX_SCALE)

        if self:GetValue() ~= percent then
            self:SetValue(percent)
            return
        end

        currentScalePercent = percent
        ApplyCalendarScale(percent)
        UpdateValueText(percent)
        PositionSlider()
    end)

    local percent = GetScalePercent()
    slider:SetValue(percent)
    ApplyCalendarScale(percent)
    UpdateValueText(percent)
    PositionSlider()
    SetSliderShown(true)
end

local function HookCalendar()
    if hookedCalendar or not CalendarFrame then
        return
    end

    hookedCalendar = true

    CreateCalendarSlider()

    CalendarFrame:HookScript("OnShow", function()
        local percent = GetScalePercent()

        CreateCalendarSlider()

        if slider then
            slider:SetValue(percent)
        end

        ApplyCalendarScale(percent)
        UpdateValueText(percent)
        PositionSlider()
        SetSliderShown(true)
    end)

    CalendarFrame:HookScript("OnHide", function()
        SetSliderShown(false)
    end)
end

local function InitializeCalendarModule()
    if CalendarFrame then
        HookCalendar()
    end
end

frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(_, event, addon)
    if event ~= "ADDON_LOADED" then
        return
    end

    if addon == addonName then
        InitializeCalendarModule()
    elseif addon == "Blizzard_Calendar" then
        HookCalendar()
    end
end)

if ns and ns.RegisterModule then
    ns:RegisterModule(MODULE_NAME, function()
        InitializeCalendarModule()
    end)
end
