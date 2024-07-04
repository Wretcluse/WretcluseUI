
	if not BigWigsAPI then return end

	local CUSTOM_TEXTURE = "Interface\\Addons\\WretcluseUI\\media\\TARGETINGFRAME\\UI-HealthBackground.tga"
	local glowTex = "Interface\\Buttons\\WHITE8X8"

	local backdrop = {
		bgFile = CUSTOM_TEXTURE, -- Use the custom texture here
		edgeFile = glowTex,
		tile = false, tileSize = 0, edgeSize = 1,
	}

	local borderBackdrop = {
		edgeFile = glowTex,
		edgeSize = 1,
		insets = { left = 1, right = 1, top = 1, bottom = 1 }
	}

	local function removeStyle(bar)
		local bd = bar.candyBarBackdrop
		bd:Hide()
		if bd.wretiborder then
			bd.wretiborder:Hide()
			bd.wretoborder:Hide()
		end

		-- Restore the original font settings
		local label = bar.candyBarLabel
		local timer = bar.candyBarDuration
		local originalFont, originalSize = label:GetFont()
		label:SetFont(originalFont, originalSize)
		timer:SetFont(originalFont, originalSize)
	end

	local function styleBar(bar)
		local bd = bar.candyBarBackdrop
		bd:SetBackdrop(backdrop)
		bd:SetBackdropColor(1, 0, 0, 1) -- Set the background color to red (RGB: 1, 0, 0)

		if C then
			bd:SetBackdropBorderColor(unpack(C.Medias.BorderColor))
			bd:SetOutside(bar)
		else
			bd:SetBackdropBorderColor(0.5, 0.5, 0.5)
			bd:ClearAllPoints()
			bd:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
			bd:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
		end

		if not bd.wretiborder then
			local border = CreateFrame("Frame", nil, bd, "BackdropTemplate")
			if C then
				border:SetInside(bd, 1, 1)
			else
				border:SetPoint("TOPLEFT", bd, "TOPLEFT", 1, -1)
				border:SetPoint("BOTTOMRIGHT", bd, "BOTTOMRIGHT", -1, 1)
			end
			border:SetBackdrop(borderBackdrop)
			border:SetBackdropBorderColor(0, 0, 0)
			bd.wretiborder = border
		else
			bd.wretiborder:Show()
		end

		if not bd.wretoborder then
			local border = CreateFrame("Frame", nil, bd, "BackdropTemplate")
			if C then
				border:SetOutside(bd, 1, 1)
			else
				border:SetPoint("TOPLEFT", bd, "TOPLEFT", -1, 1)
				border:SetPoint("BOTTOMRIGHT", bd, "BOTTOMRIGHT", 1, -1)
			end
			border:SetBackdrop(borderBackdrop)
			border:SetBackdropBorderColor(0, 0, 0)
			bd.wretoborder = border
		else
			bd.wretoborder:Show()
		end

		bd:Show()

		-- FORCE FLAG TO OUTLINE
		--[[
		local label = bar.candyBarLabel
		local timer = bar.candyBarDuration
		local font, size = label:GetFont()
		label:SetFont(font, size, "OUTLINE")
		timer:SetFont(font, size, "OUTLINE")
		--]]
	end

	BigWigsAPI:RegisterBarStyle("WretcluseUI", {
		apiVersion = 1,
		version = 1,
		barSpacing = 7,
		ApplyStyle = styleBar,
		BarStopped = removeStyle,
		GetStyleName = function() return "WretcluseUI" end,
	})