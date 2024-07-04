
-----------------------------
-- MOUSEOVER SCROLLING WINDOW
-----------------------------
	local function ScrollChat(frame, delta)
		if IsControlKeyDown() then -- Faster Scroll
			if delta > 0 then -- Faster scrolling by triggering a few scroll up in a loop
				for i = 1, 5 do 
					frame:ScrollUp()
				end
			elseif delta < 0 then
				for i = 1, 5 do
					frame:ScrollDown()
				end
			end
		elseif IsAltKeyDown() or IsShiftKeyDown() then
			if delta > 0 then -- Scroll to the top or bottom
				frame:ScrollToTop()
			elseif delta < 0 then
				frame:ScrollToBottom()
			end
		else
			if delta > 0 then -- Normal Scroll
				frame:ScrollUp()
			elseif delta < 0 then
				frame:ScrollDown()
			end
		end
	end

-----------------------------
-- CHAT FRAME LINK DETECTION
-----------------------------
	local function DetectUrls()
		local newAddMsg = {}

		local function AddMessage(frame, message, ...)
			if message then
				-- Replace URLs with clickable links
				message = gsub(message, '([wWhH][wWtT][wWtT][%.pP]%S+[^%p%s])', '|cffffffff|Hurl:%1|h[%1]|h|r')
				message = gsub(message, " ([_A-Za-z0-9-%.]+@[_A-Za-z0-9-]+%.+[_A-Za-z0-9-%.]+)%s?", "|cffffffff|Hurl:%1|h[%1]|h|r")
				message = gsub(message, " (%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?:%d%d?%d?%d?%d?)%s?", "|cffffffff|Hurl:%1|h[%1]|h|r")
				message = gsub(message, " (%d%d?%d?%.%d%d?%d?%.%d%d?%d?%.%d%d?%d?)%s?", "|cffffffff|Hurl:%1|h[%1]|h|r")
				return newAddMsg[frame:GetName()](frame, message, ...)
			end
		end

		for i = 1, NUM_CHAT_WINDOWS do
			if i ~= 2 then -- Skip the combat log
				local frame = _G[format("%s%d", "ChatFrame", i)]
				if not newAddMsg[frame:GetName()] then
					newAddMsg[frame:GetName()] = frame.AddMessage
					frame.AddMessage = AddMessage
				end
			end
		end
	end

-----------------------------
-- HYPERLINK HANDLING
-----------------------------
	local function SetupHyperlinkHandler()
		local orig = ChatFrame_OnHyperlinkShow

		ChatFrame_OnHyperlinkShow = function(frame, link, text, button)
			local type, value = link:match("(%a+):(.+)")
			if type == "url" then
				local editBox = _G[frame:GetName()..'EditBox']
				if editBox then
					editBox:Show()
					editBox:SetText(value)
					editBox:SetFocus()
					editBox:HighlightText()
				end
			else
				orig(frame, link, text, button)
			end
		end
	end

-----------------------------
-- CALL CHAT FRAME UPDATES
-----------------------------
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("PLAYER_ENTERING_WORLD")

	frame:SetScript("OnEvent", function(self, event)
		if event == "PLAYER_ENTERING_WORLD" then
			DetectUrls()
			SetupHyperlinkHandler()
			for i = 1, NUM_CHAT_WINDOWS do
				local ChatFrame = _G["ChatFrame"..i]
				if ChatFrame then
					ChatFrame:SetClampedToScreen(false)
					ChatFrame:EnableMouseWheel(true)
					ChatFrame:SetScript('OnMouseWheel', ScrollChat)
					ChatFrame:SetMaxLines(500)
				end
			end
		end
	end)