local addonName = ...
local f = CreateFrame("Frame")

local function PrintMessage(message)
	print("|cFFFFD100WretcluseUI:|r " .. message)
end

-- Per-character saved variables:
-- QuoteTodayDB = { lastDate = "YYYY-MM-DD" }
QuoteTodayDB = QuoteTodayDB or {}

local QUOTES = {
	{ text = "We are what we repeatedly do. Excellence, then, is not an act but a habit.", author = "Aristotle (attributed)" },
	{ text = "It is not death that a man should fear, but he should fear never beginning to live.", author = "Marcus Aurelius" },
	{ text = "If you want to go fast, go alone. If you want to go far, go together.", author = "African proverb" },
	{ text = "What we think, we become.", author = "Buddha (attributed)" },
	{ text = "The obstacle is the way.", author = "Marcus Aurelius (paraphrased)" },
	{ text = "Do what you can, with what you have, where you are.", author = "Theodore Roosevelt" },
	{ text = "The best way out is always through.", author = "Robert Frost" },
	{ text = "You miss 100% of the shots you don’t take.", author = "Wayne Gretzky" },
	{ text = "A ship in harbor is safe, but that is not what ships are built for.", author = "John A. Shedd (attributed)" },
	{ text = "He who has a why to live can bear almost any how.", author = "Friedrich Nietzsche" },
	{ text = "The only way to do great work is to love what you do.", author = "Steve Jobs" },
	{ text = "Simplicity is the ultimate sophistication.", author = "Leonardo da Vinci (attributed)" },
	{ text = "Fall seven times and stand up eight.", author = "Japanese proverb" },
	{ text = "Luck is what happens when preparation meets opportunity.", author = "Seneca (attributed)" },
	{ text = "Start where you are. Use what you have. Do what you can.", author = "Arthur Ashe" },
	{ text = "Whether you think you can or you think you can’t, you’re right.", author = "Henry Ford (attributed)" },
	{ text = "Make it work, make it right, make it fast.", author = "Kent Beck" },
	{ text = "If you’re going through hell, keep going.", author = "Winston Churchill (attributed)" },
	{ text = "The journey of a thousand miles begins with a single step.", author = "Laozi" },
	{ text = "Difficult roads often lead to beautiful destinations.", author = "Unknown" },
	{ text = "Action is the foundational key to all success.", author = "Pablo Picasso (attributed)" },
	{ text = "Courage is grace under pressure.", author = "Ernest Hemingway (attributed)" },
	{ text = "What you do speaks so loudly that I cannot hear what you say.", author = "Ralph Waldo Emerson (attributed)" },
	{ text = "Do not pray for an easy life; pray for the strength to endure a difficult one.", author = "Bruce Lee (attributed)" },
	{ text = "Nothing is impossible. The word itself says ‘I’m possible!’", author = "Audrey Hepburn (attributed)" },
	{ text = "If I have seen further, it is by standing on the shoulders of giants.", author = "Isaac Newton" },
	{ text = "The secret of getting ahead is getting started.", author = "Mark Twain (attributed)" },
	{ text = "The future depends on what you do today.", author = "Mahatma Gandhi" },
	{ text = "Not all those who wander are lost.", author = "J. R. R. Tolkien" },
	{ text = "What lies behind us and what lies before us are tiny matters compared to what lies within us.", author = "Ralph Waldo Emerson (attributed)" },
	{ text = "Do the thing you fear, and the death of fear is certain.", author = "Ralph Waldo Emerson (attributed)" },
	{ text = "If you can dream it, you can do it.", author = "Walt Disney (attributed)" },
	{ text = "One day or day one. You decide.", author = "Unknown" },
	{ text = "The only limit to our realization of tomorrow is our doubts of today.", author = "Franklin D. Roosevelt" },
	{ text = "Quality is not an act, it is a habit.", author = "Aristotle (attributed)" },
	{ text = "You have power over your mind — not outside events. Realize this, and you will find strength.", author = "Marcus Aurelius" },
	{ text = "Be so good they can’t ignore you.", author = "Steve Martin (attributed)" },
	{ text = "It always seems impossible until it’s done.", author = "Nelson Mandela" },
	{ text = "If you get tired, learn to rest, not to quit.", author = "Banksy (attributed)" },
	{ text = "Discipline is choosing between what you want now and what you want most.", author = "Abraham Lincoln (attributed)" },
	{ text = "A smooth sea never made a skilled sailor.", author = "Proverb" },
	{ text = "The man who moves a mountain begins by carrying away small stones.", author = "Confucius (attributed)" },
	{ text = "Be yourself; everyone else is already taken.", author = "Oscar Wilde" },
	{ text = "The best time to plant a tree was 20 years ago. The second best time is now.", author = "Chinese proverb" },
	{ text = "You don’t have to be great to start, but you have to start to be great.", author = "Zig Ziglar (attributed)" },
	{ text = "Small deeds done are better than great deeds planned.", author = "Peter Marshall (attributed)" },
	{ text = "If you want to lift yourself up, lift up someone else.", author = "Booker T. Washington" },
	{ text = "In the middle of difficulty lies opportunity.", author = "Albert Einstein (attributed)" },
	{ text = "The best revenge is massive success.", author = "Frank Sinatra (attributed)" },
}


-- PickIndex: deterministic "random" index using server time + player's GUID tail
local function PickIndex(n)
	if n <= 0 then return 1 end
	-- use server time when available (stable across players on same realm)
	local t = (GetServerTime and GetServerTime()) or time()
	-- UnitGUID returns a long hex string; take the last few hex digits as a small entropy source
	local guid = UnitGUID("player") or ""
	-- try to parse the last 6 hex chars to a number; fallback to 0
	local tail = tonumber(guid:sub(-6), 16) or 0
	-- combine and mod by n, then +1 for 1..n indexing
	return ((t + tail) % n) + 1
end

local function TodayKey()
	local t = (GetServerTime and GetServerTime()) or time()
	return date("%Y-%m-%d", t)
end

local function OutputRandomQuote()
	if #QUOTES == 0 then return end
	local idx = PickIndex(#QUOTES)
	local q = QUOTES[idx]
	PrintMessage(("|cFFFFFFFF“%s”|r |cFFAAAAAA— %s|r"):format(q.text, q.author))
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

f:SetScript("OnEvent", function(_, event, arg1, isInitialLogin, isReloadingUi)
	if event == "ADDON_LOADED" then
		if arg1 == addonName then
			QuoteTodayDB = QuoteTodayDB or {}
		end
		return
	end

	-- Print only on initial login or UI reload, AND only once per day per character.
	if event == "PLAYER_ENTERING_WORLD" then
		if not (isInitialLogin or isReloadingUi) then
			return
		end

		local today = TodayKey()
		if QuoteTodayDB.lastDate == today then
			return
		end

		QuoteTodayDB.lastDate = today
		OutputRandomQuote()
	end
end)
