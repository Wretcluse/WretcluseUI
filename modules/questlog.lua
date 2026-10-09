-- WretcluseUI - Quest Log
-- Adds an "Abandon All" button to Blizzard's Midnight quest list.
--
-- The button is parented to the quest-list ScrollFrame, so it is only visible
-- while Blizzard's quest list is visible. It uses only Blizzard's public quest
-- APIs and does not hook or replace Blizzard quest-log functions.

local PREFIX = "|cFFFFD100WretcluseUI:|r "
local POPUP_KEY = "WRETCLUSEUI_ABANDON_ALL_QUESTS"

local abandonButton
local isAbandoning = false
local hoverTooltip

local function GetHoverTooltip()
    if not hoverTooltip then
        -- Midnight: keep addon-owned hover text off Blizzard's shared GameTooltip.
        -- The global tooltip can contain Blizzard UIWidget sets with secret layout
        -- values; clearing those from tainted addon execution can trip LayoutFrame.lua.
        hoverTooltip = CreateFrame(
            "GameTooltip",
            "WretcluseUIQuestLogTooltip",
            UIParent,
            "GameTooltipTemplate"
        )
    end

    return hoverTooltip
end

local function PrintMessage(message)
    print(PREFIX .. message)
end

local function UpdateButton()
    if not abandonButton then
        return
    end

    local _, numQuests = C_QuestLog.GetNumQuestLogEntries()
    local enabled = not isAbandoning and numQuests > 0 and not InCombatLockdown()

    abandonButton:SetEnabled(enabled)
    abandonButton:SetText(isAbandoning and "Working..." or "Abandon All")
end

-- GetNumQuestLogEntries() only guarantees the currently shown log entries.
-- Expanding collapsed headers before collection makes "Abandon All" actually
-- consider quests hidden beneath collapsed headers as well.
local function ExpandAllQuestHeaders()
    if not ExpandQuestHeader then
        return
    end

    -- Expanding one header can change every following quest-log index, so
    -- restart the scan after each expansion rather than caching indices.
    for _ = 1, 100 do
        local numEntries = C_QuestLog.GetNumQuestLogEntries()
        local expandedOne = false

        for questLogIndex = 1, numEntries do
            local info = C_QuestLog.GetInfo(questLogIndex)
            if info and info.isHeader and info.isCollapsed then
                ExpandQuestHeader(questLogIndex)
                expandedOne = true
                break
            end
        end

        if not expandedOne then
            break
        end
    end
end

local function CollectAbandonableQuests()
    ExpandAllQuestHeaders()

    local questIDs = {}
    local numEntries = C_QuestLog.GetNumQuestLogEntries()

    for questLogIndex = 1, numEntries do
        local info = C_QuestLog.GetInfo(questLogIndex)
        if info and not info.isHeader and info.questID and info.questID > 0 then
            if C_QuestLog.CanAbandonQuest(info.questID) then
                questIDs[#questIDs + 1] = info.questID
            end
        end
    end

    return questIDs
end

local function FinishAbandon(questIDs)
    local remaining = 0

    for _, questID in ipairs(questIDs) do
        if C_QuestLog.GetLogIndexForQuestID(questID) then
            remaining = remaining + 1
        end
    end

    local abandoned = #questIDs - remaining
    isAbandoning = false
    UpdateButton()

    if abandoned == 1 then
        PrintMessage("Abandoned 1 quest.")
    else
        PrintMessage(("Abandoned %d quests."):format(abandoned))
    end

    if remaining > 0 then
        PrintMessage(("%d quest%s could not be abandoned and were left in the log.")
            :format(remaining, remaining == 1 and "" or "s"))
    end
end

local function BeginAbandon(questIDs)
    if isAbandoning or not questIDs or #questIDs == 0 then
        return
    end

    if InCombatLockdown() then
        PrintMessage("Cannot abandon quests while in combat.")
        UpdateButton()
        return
    end

    isAbandoning = true
    UpdateButton()

    local nextQuest = 1

    local function Step()
        if nextQuest > #questIDs then
            -- Give the quest log a moment to process the final QUEST_REMOVED.
            C_Timer.After(0.25, function()
                FinishAbandon(questIDs)
            end)
            return
        end

        local questID = questIDs[nextQuest]
        nextQuest = nextQuest + 1

        -- Re-check immediately before abandoning in case the quest changed
        -- between confirmation and this step.
        if C_QuestLog.GetLogIndexForQuestID(questID)
            and C_QuestLog.CanAbandonQuest(questID) then

            C_QuestLog.SetSelectedQuest(questID)
            C_QuestLog.SetAbandonQuest()

            -- Only call AbandonQuest if Blizzard agrees that this is the
            -- quest currently marked for abandonment.
            if C_QuestLog.GetAbandonQuest() == questID then
                C_QuestLog.AbandonQuest()
            end
        end

        -- Bulk abandonment is deliberately paced. Besides being gentler on
        -- the quest-log update chain, this lets QUEST_REMOVED settle before
        -- selecting the next quest.
        C_Timer.After(0.12, Step)
    end

    Step()
end

StaticPopupDialogs[POPUP_KEY] = {
    text = "Abandon all %d abandonable quests?\n\nThis cannot be undone. Quest-related items may also be removed.",
    button1 = YES,
    button2 = NO,
    OnAccept = function(_, questIDs)
        BeginAbandon(questIDs)
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function OnAbandonAllClicked()
    if isAbandoning then
        return
    end

    if InCombatLockdown() then
        PrintMessage("Cannot abandon quests while in combat.")
        return
    end

    local questIDs = CollectAbandonableQuests()
    if #questIDs == 0 then
        PrintMessage("There are no abandonable quests in the quest log.")
        UpdateButton()
        return
    end

    StaticPopup_Show(POPUP_KEY, #questIDs, nil, questIDs)
end

local function CreateAbandonAllButton()
    if abandonButton then
        return true
    end

    local questMapFrame = QuestMapFrame
    local questsFrame = questMapFrame and questMapFrame.QuestsFrame
    local scrollFrame = questsFrame and questsFrame.ScrollFrame
    local searchBox = scrollFrame and scrollFrame.SearchBox

    if not scrollFrame or not searchBox then
        return false
    end

    -- Blizzard currently gives the search box almost the entire top row.
    -- Reduce it just enough to fit our native-looking button beside it.
    searchBox:SetWidth(188)

    abandonButton = CreateFrame(
        "Button",
        "WretcluseUIQuestLogAbandonAllButton",
        scrollFrame,
        "UIPanelButtonTemplate"
    )
    abandonButton:SetSize(108, 22)
    abandonButton:SetPoint("LEFT", searchBox, "RIGHT", 4, 0)
    abandonButton:SetFrameLevel(searchBox:GetFrameLevel() + 1)
    abandonButton:SetText("Abandon All")
    abandonButton:SetScript("OnClick", OnAbandonAllClicked)

    abandonButton:SetScript("OnEnter", function(self)
        local tooltip = GetHoverTooltip()
        tooltip:SetOwner(self, "ANCHOR_RIGHT")
        tooltip:SetText("Abandon All Quests")
        tooltip:AddLine(
            "Abandons every quest that Blizzard currently allows you to abandon.",
            1, 1, 1, true
        )
        tooltip:AddLine(
            "You will be asked to confirm before anything is removed.",
            0.8, 0.8, 0.8, true
        )
        if InCombatLockdown() then
            tooltip:AddLine("Unavailable while in combat.", 1, 0.2, 0.2, true)
        end
        tooltip:Show()
    end)

    abandonButton:SetScript("OnLeave", function()
        if hoverTooltip then
            hoverTooltip:Hide()
        end
    end)

    UpdateButton()
    return true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("QUEST_LOG_UPDATE")
eventFrame:RegisterEvent("QUEST_ACCEPTED")
eventFrame:RegisterEvent("QUEST_REMOVED")
eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LOGIN"
        or (event == "ADDON_LOADED" and arg1 == "Blizzard_UIPanels_Game") then
        CreateAbandonAllButton()
    end

    if event == "QUEST_LOG_UPDATE"
        or event == "QUEST_ACCEPTED"
        or event == "QUEST_REMOVED"
        or event == "PLAYER_REGEN_DISABLED"
        or event == "PLAYER_REGEN_ENABLED" then
        UpdateButton()
    end
end)

-- WretcluseUI may load after Blizzard_UIPanels_Game, so initialize immediately
-- when the quest frame already exists instead of waiting for another event.
CreateAbandonAllButton()
