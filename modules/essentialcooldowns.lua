-- modules/essentialcooldowns.lua
local ADDON, ns = ...

ns:RegisterModule("essentialcooldowns", function(ns)

    local viewer = EssentialCooldownViewer
    if not viewer or not viewer.itemFramePool then
        return
    end

    local elapsed = 0
    local watcher = CreateFrame("Frame")

    -- Keep all addon-owned state completely separate from Blizzard's
    -- Cooldown Viewer frames. Do not store custom fields on an item and do
    -- not call the item's RefreshOverlayGlow() method; either can allow addon
    -- taint to enter Blizzard's UNIT_AURA processing.
    local glowByItem = setmetatable({}, { __mode = "k" })

    -- Track only addon-owned, non-secret cooldown observations. Blizzard can
    -- temporarily leave isOnActualCooldown stale (notably when a charge
    -- becomes available), or expose state as secret in protected contexts.
    -- Keeping the last safe state lets us recover the icon alpha without
    -- writing anything back onto Blizzard's pooled item frames.
    local cooldownStateByItem = setmetatable({}, { __mode = "k" })

    local function GetCooldownState(item, now)
        local state = cooldownStateByItem[item]
        if not state then
            state = {}
            cooldownStateByItem[item] = state
        end

        -- Blizzard sets wasSetFromCharges only when a charge cooldown is being
        -- displayed while at least one charge is still available. In that
        -- state the ability is usable, so it should be at ready alpha even if
        -- isOnActualCooldown still contains an older value.
        local fromCharges = item.wasSetFromCharges
        if not issecretvalue(fromCharges) and fromCharges == true then
            state.onCooldown = false
            state.endTime = nil
            return false
        end

        local onCooldown = item.isOnActualCooldown
        if not issecretvalue(onCooldown) then
            onCooldown = onCooldown == true

            if onCooldown then
                -- Mirror Blizzard's own cooldown-active test when the timing
                -- fields are readable. This prevents a delayed refresh from
                -- leaving the raw boolean true after the timer has expired.
                local startTime = item.cooldownStartTime
                local duration = item.cooldownDuration

                if not issecretvalue(startTime) and not issecretvalue(duration)
                    and type(startTime) == "number" and type(duration) == "number"
                    and duration > 0 then
                    state.endTime = startTime + duration

                    if state.endTime <= now then
                        onCooldown = false
                        state.endTime = nil
                    end
                end
            else
                state.endTime = nil
            end

            state.onCooldown = onCooldown
            return onCooldown
        end

        -- If the raw value becomes secret, expire a previously observed
        -- cooldown ourselves when its last safe end time passes.
        if state.endTime and now >= state.endTime then
            state.onCooldown = false
            state.endTime = nil
            return false
        end

        -- Reuse the last safe observation instead of leaving the frame at an
        -- arbitrary alpha inherited from an earlier pooled-frame state.
        return state.onCooldown
    end

    local function CreateAuraGlow(item)
        -- Parent the overlay to UIParent rather than the Blizzard item.
        -- Dual-anchor it to the item's corners so its actual on-screen size
        -- follows Blizzard/Edit Mode scaling automatically.
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:SetFrameStrata("HIGH")
        frame:SetPoint("TOPLEFT", item, "TOPLEFT", 0, 0)
        frame:SetPoint("BOTTOMRIGHT", item, "BOTTOMRIGHT", 0, 0)
        frame:Hide()

        local texture = frame:CreateTexture(nil, "OVERLAY")
        texture:SetPoint("CENTER", frame, "CENTER", 0, 0)
        texture:SetBlendMode("ADD")
        texture:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")

        -- Keep the proc-loop artwork slightly larger than the icon itself,
        -- matching the familiar Blizzard action-button glow presentation.
        local function UpdateArtworkSize(_, width, height)
            if not issecretvalue(width) and not issecretvalue(height) then
                texture:SetSize(width * 1.4, height * 1.4)
            end
        end

        frame:SetScript("OnSizeChanged", UpdateArtworkSize)

        -- Establish the initial artwork size immediately when possible.
        local width, height = frame:GetSize()
        UpdateArtworkSize(frame, width, height)

        -- Blizzard's modern action-button proc-loop artwork, played by our
        -- own AnimationGroup rather than Blizzard's alert manager.
        local animGroup = frame:CreateAnimationGroup()
        animGroup:SetLooping("REPEAT")

        local flipBook = animGroup:CreateAnimation("FlipBook")
        flipBook:SetTarget(texture)
        flipBook:SetDuration(1.0)
        flipBook:SetFlipBookRows(6)
        flipBook:SetFlipBookColumns(5)
        flipBook:SetFlipBookFrames(30)

        local state = {
            frame = frame,
            animGroup = animGroup,
            seen = true,
        }

        glowByItem[item] = state
        return state
    end

    local function ShowAuraGlow(item)
        local state = glowByItem[item] or CreateAuraGlow(item)
        state.seen = true

        if not state.frame:IsShown() then
            state.frame:Show()
        end

        if not state.animGroup:IsPlaying() then
            state.animGroup:Play()
        end
    end

    local function HideAuraGlow(item)
        local state = glowByItem[item]
        if not state then
            return
        end

        state.seen = true

        if state.animGroup:IsPlaying() then
            state.animGroup:Stop()
        end

        if state.frame:IsShown() then
            state.frame:Hide()
        end
    end

    watcher:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt

        if elapsed < 0.05 then
            return
        end

        elapsed = 0

        -- Because our overlays are parented to UIParent, hide any overlay
        -- whose pooled Blizzard item is no longer active this pass.
        for _, state in pairs(glowByItem) do
            state.seen = false
        end

        local now = GetTime()

        for item in viewer.itemFramePool:EnumerateActive() do
            local auraActive = item.wasSetFromAura
            local state = glowByItem[item]

            if state then
                state.seen = true
            end

            -- Midnight safety:
            -- Never branch directly on secret aura/cooldown values.
            if not issecretvalue(auraActive) and auraActive == true then
                -- The ability's buff is active: leave the icon fully visible
                -- and show our independent Blizzard-style glow.
                item:SetAlpha(1)
                ShowAuraGlow(item)
            else
                -- A secret aura state cannot safely drive our glow.
                HideAuraGlow(item)

                local onCooldown = GetCooldownState(item, now)

                if onCooldown == nil then
                    -- No safe cooldown observation exists yet. Fail open to
                    -- ready alpha rather than preserving a stale dimmed alpha
                    -- from this pooled frame's previous state.
                    item:SetAlpha(1)
                else
                    item:SetAlpha(onCooldown and 0.2 or 1)
                end
            end
        end

        for _, state in pairs(glowByItem) do
            if not state.seen then
                if state.animGroup:IsPlaying() then
                    state.animGroup:Stop()
                end

                if state.frame:IsShown() then
                    state.frame:Hide()
                end
            end
        end
    end)

end)
