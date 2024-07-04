
-----------------------------
-- COLLAPSE BY DEFAULT
-----------------------------
	BuffFrame.CollapseAndExpandButton:SetChecked(false)
	BuffFrame.CollapseAndExpandButton:UpdateOrientation()
	BuffFrame:SetBuffsExpandedState()

-----------------------------
-- BUFF SOURCE
-----------------------------
	local function ProcessAura(tooltip, caster)
		if not caster or UnitIsUnit(caster, "player") then return end

		local pet = caster
		caster = (UnitIsUnit(caster, "pet") and "player" or caster:gsub("[pP][eE][tT]", ""))

		tooltip:AddDoubleLine(" ",
			(pet == caster and "|cffffc000Source:|r %s" or "|cffffc000Source:|r %s (%s)"):format(UnitName(caster), UnitName(pet)),
			1, 0.82, 0, RAID_CLASS_COLORS[select(2, UnitClass(caster))]:GetRGB()
		)
		tooltip:Show()
	end

	local function CasterByAuraInstanceID(unit, id)
		local data = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
		return data and data.sourceUnit
	end

	local CasterByInfoGetter = {
		GetUnitAura = function(...) return (select(7, UnitAura(...))) end,
		GetUnitBuff = function(...) return (select(7, UnitBuff(...))) end,
		GetUnitDebuff = function(...) return (select(7, UnitDebuff(...))) end,
		GetUnitBuffByAuraInstanceID = CasterByAuraInstanceID,
		GetUnitDebuffByAuraInstanceID = CasterByAuraInstanceID,
	}

	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.UnitAura, function(self)
		local info = self:GetProcessingTooltipInfo()
		local func = CasterByInfoGetter[info.getterName]
		if func then
			ProcessAura(self, func(unpack(info.getterArgs)))
		end
	end)