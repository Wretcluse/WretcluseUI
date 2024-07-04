
-----------------------------
-- HIDE PLAYERFRAME LOGIC
-----------------------------
local ShowAlpha = 1
local HideAlpha = 0

local function UnitFrame_UpdateVisibility(self)
    self:SetAlpha(
        (
            InCombatLockdown()
        or	UnitExists("target")
        or  self:IsMouseOver()
		or	UnitHealth("player") < UnitHealthMax("player")
		or	UnitPower("player") < UnitPowerMax("player")
		or	UnitPower("player") == 0
        ) and ShowAlpha or HideAlpha
    )
end
 
PlayerFrame:HookScript("OnUpdate", UnitFrame_UpdateVisibility)
TargetFrame:HookScript("OnUpdate", UnitFrame_UpdateVisibility)