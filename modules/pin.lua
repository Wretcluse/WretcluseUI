-- modules/pin.lua
local ADDON, ns = ...

ns:RegisterModule("pin", function(ns)
	-----------------------------
	-- CHAT MESSAGE FORMAT
	-----------------------------
		local function PrintMessage(message)
			ns:Print(message)
		end

	-----------------------------
	-- MOVE DECIMAL FOR MAP COORDINATES
	-----------------------------
	local function NormalizeCoord(v)
		if v > 1 then
			return v / 100
		end
		return v
	end

	-----------------------------
	-- SET PIN FOR INHABITED ZONE
	-----------------------------
	local function SetPin(x, y)
		local uiMapID = C_Map.GetBestMapForUnit("player")
		if not uiMapID then
			PrintMessage("|cffff5555Couldn't determine your current map.|r")
			return
		end

		x = NormalizeCoord(x)
		y = NormalizeCoord(y)

		if x <= 0 or x >= 1 or y <= 0 or y >= 1 then
			PrintMessage("|cffff5555Coords must be between 0–100 (or 0–1). Example: /pin 48.6 52.1|r")
			return
		end

		local point = UiMapPoint.CreateFromCoordinates(uiMapID, x, y)
		C_Map.SetUserWaypoint(point)
		C_SuperTrack.SetSuperTrackedUserWaypoint(true)

		PrintMessage(string.format("Pinned %.1f, %.1f", x * 100, y * 100))
	end

	-----------------------------
	-- CLEAR PIN
	-----------------------------
	local function ClearPin()
		if C_Map.ClearUserWaypoint then
			C_Map.ClearUserWaypoint()
		end

		if C_SuperTrack.SetSuperTrackedUserWaypoint then
			C_SuperTrack.SetSuperTrackedUserWaypoint(false)
		end

		PrintMessage("Pin cleared.")
	end

	-----------------------------
	-- REGISTER SLASH COMMANDS
	-----------------------------
	SLASH_PIN1 = "/pin"
	SlashCmdList.PIN = function(msg)
		msg = (msg or ""):match("^%s*(.-)%s*$"):gsub(",", " ")

		if msg == "" then
			PrintMessage("Usage: /pin 48.6 52.1  or  /pin clear")
			return
		end

		local lower = msg:lower()
		if lower == "clear" or lower == "reset" then
			ClearPin()
			return
		end

		local xStr, yStr = msg:match("^(%S+)%s+(%S+)$")
		local x = tonumber(xStr)
		local y = tonumber(yStr)

		if not x or not y then
			PrintMessage("|cffff5555Couldn't parse coords. Example: /pin 48.6 52.1|r")
			return
		end

		SetPin(x, y)
	end

end)
