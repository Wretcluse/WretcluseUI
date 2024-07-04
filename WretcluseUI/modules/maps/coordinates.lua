
-----------------------------
-- CHAT MESSAGE FORMAT
-----------------------------
	local function PrintMessage(message)
		print("|cFFFFD100WretcluseUI:|r " .. message)
	end

	local MyCoordsAddon = {}
	MyCoordsAddon.minimapEnabled = false  -- Default state is disabled
	MyCoordsAddon.mapMessageSent = false  -- Flag to track if the message has been sent

	local IsInInstance = IsInInstance
	local WorldMapFrame = WorldMapFrame
	local UnitPosition = UnitPosition
	local C_Map_GetBestMapForUnit = C_Map.GetBestMapForUnit

	local currentMapID, MinimapCoords, cursorCoords

	function MyCoordsAddon.UpdatePlayerCoords(self, elapsed)
		if not self.minimapEnabled then
			MinimapCoords.text:SetText('')
			return
		end
		
		self.elapsed = (self.elapsed or 0) + elapsed
		if self.elapsed > .05 then
			local inInstance = IsInInstance()

			if inInstance then
				MinimapCoords.text:SetText('')
				return
			end

			local map = C_Map_GetBestMapForUnit('player')

			if map then
				if Minimap:IsVisible() then
					local position = C_Map.GetPlayerMapPosition(map, 'player')
					if not position then 
						MinimapCoords.text:SetText('')
						return
					end

					local playerX, playerY = position:GetXY()
					if playerX ~= 0 and playerY ~= 0 then
						MinimapCoords.text:SetFormattedText('%d,%d', playerX * 100, playerY * 100)
					else
						MinimapCoords.text:SetText('')
					end
				end
			end
			self.elapsed = 0
		end
	end

	function MyCoordsAddon.GetCursorCoords()
		if not WorldMapFrame.ScrollContainer:IsMouseOver() then return end

		local cursorX, cursorY = WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition()
		if cursorX < 0 or cursorX > 1 or cursorY < 0 or cursorY > 1 then return end
		return cursorX, cursorY
	end

	function MyCoordsAddon.UpdateCursorCoords(self, elapsed)
		self.elapsed = (self.elapsed or 0) + elapsed
		if self.elapsed > .05 then
			local mapInfo = C_Map.GetMapInfo(WorldMapFrame:GetMapID())
			local cursorX, cursorY = self:GetCursorCoords()
			if cursorX and cursorY and mapInfo and mapInfo.mapType == 3 then
				cursorCoords:SetFormattedText('Cursor: %d, %d', cursorX * 100, cursorY * 100)
				cursorCoords:SetTextColor(1, 0.82, 0)
			else
				cursorCoords:SetText('')
				cursorCoords:SetTextColor(1, 0, 0)
			end
			self.elapsed = 0
		end
	end

	function MyCoordsAddon.UpdateMapID()
		if WorldMapFrame:GetMapID() == C_Map_GetBestMapForUnit("player") then
			if not MyCoordsAddon.mapMessageSent then
				PrintMessage("Minimap coordinates can be enabled & disabled with the command |cFFFFD100/coords|r.")
				MyCoordsAddon.mapMessageSent = true
			end
			currentMapID = WorldMapFrame:GetMapID()
		else
			currentMapID = nil
		end
	end

	function MyCoordsAddon.SetupCoords(self)
		MinimapCoords = CreateFrame('Frame', nil, Minimap)
		MinimapCoords.text = MinimapCoords:CreateFontString(nil, 'OVERLAY', 'SystemFont_Outline')
		MinimapCoords:SetFrameStrata('LOW')
		MinimapCoords:SetWidth(32)
		MinimapCoords:SetHeight(32)
		MinimapCoords:SetPoint('BOTTOM', 1, -8)
		MinimapCoords.text:SetPoint('CENTER', 0, 0)
		MinimapCoords.text:SetTextColor(1, 0.82, 0, 1)

		cursorCoords = WorldMapFrameCloseButton:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
		cursorCoords:SetPoint('BOTTOMLEFT', WorldMapFrameCloseButton, 'BOTTOMLEFT', -120, 6)

		hooksecurefunc(WorldMapFrame, "OnFrameSizeChanged", function() MyCoordsAddon.UpdateMapID() end)
		hooksecurefunc(WorldMapFrame, "OnMapChanged", function() MyCoordsAddon.UpdateMapID() end)

		local MiniMapCoordsUpdater = CreateFrame("Frame", nil, Minimap)
		MiniMapCoordsUpdater:SetScript("OnUpdate", function(_, elapsed) MyCoordsAddon.UpdatePlayerCoords(self, elapsed) end)

		local cursorCoordsUpdater = CreateFrame("Frame", nil, WorldMapFrame.BorderFrame)
		cursorCoordsUpdater:SetScript("OnUpdate", function(_, elapsed) MyCoordsAddon.UpdateCursorCoords(self, elapsed) end)
	end

	function MyCoordsAddon.SetupWorldMap(self)
		if IsAddOnLoaded("Mapster") then return end

		self:SetupCoords()
	end

	function MyCoordsAddon.ToggleMinimapCoords(self)
		self.minimapEnabled = not self.minimapEnabled
		if self.minimapEnabled then
			PrintMessage("Minimap coordinates have been |cFF4EADD7enabled|r.")
		else
			PrintMessage("Minimap coordinates have been |cFFC6644Bdisabled|r.")
		end
	end

	function MyCoordsAddon.OnLogin(self)
		self:SetupWorldMap()
		self:RegisterChatCommand()
	end

	function MyCoordsAddon.RegisterChatCommand()
		SLASH_MYCOORDS1 = "/coords"
		SlashCmdList["MYCOORDS"] = function()
			MyCoordsAddon.ToggleMinimapCoords(MyCoordsAddon)
		end
	end

	local eventFrame = CreateFrame("Frame")
	eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
	eventFrame:SetScript("OnEvent", function()
		MyCoordsAddon.OnLogin(MyCoordsAddon)
	end)