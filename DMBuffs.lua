-- Helper methods

function cleanName(name)
	-- Name can sometimes include server name as well, need to strip it out
	if string.find(name, "-") ~= nil then
		local index = string.find(name, "-") 
		name = name:sub(1, index - 1)
	end
	return name
end


function SummonPlayer(target_player)
	PlaySound(8459)
	for i = 1, 10 do
		local button = buttons[i]
		if not button:IsShown() then
			button:SetText("["..customer_count.."] Summon "..target_player.."?")
			button:SetAttribute("type1", "macro")
			button:SetAttribute("macrotext", "/w Dmbuffs Summoning "..target_player.."\n/raid Summoning "..target_player.."\n/tar "..target_player.."\n/cast Ritual of Summoning")
			button:Show()
			customers[i] = target_player
			break
		end
	end
end



function FindKeywords(message, keywords)
 	for index, keyword in ipairs(keywords) do
   		if string.match(string.gsub(message, "%s+", ""), keyword) then
			return index
   		end
 	end
	return nil
end


player = cleanName(UnitName("player"))
active_invite = false
active_summon = false

-- Auto-invite keywords
keywords_required_1 = {"LF","ANY","WTB"}
keywords_required_2 = {"DM"}
keywords_ignored = {"DEADMINES", "LFG", "WTS", "LFM", "DMW", "DME", "RECRUIT", "LF1", "LF2", "LF3", "LF4", "LF5", "LF6", "LF7", "LF8", "LF9"}


function Initialize()
	
	-- Whether to auto-invite people based on keyword
	active_invite = true

	-- Setup invite buttons
	buttons = {}
	for i = 1, 10 do
		buttons[i] = CreateFrame("Button", "btn_1", UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
		buttons[i]:SetPoint("CENTER", mainframe, "Center", 200, 350 - 50 * i)
		buttons[i]:SetWidth(200)
		buttons[i]:SetHeight(50) 
		buttons[i]:Hide()
	end
	
	-- Setup table for managing customers
	customers = {}
	customer_count = 0

	-- For monitoring how much gold has been made for the current session
	start_gold = GetMoney()
	cur_gold = GetMoney()
	gold_changed = false

	StaticPopup_Show ("ActivateSummons")

end


StaticPopupDialogs["Activate"] = {
	text = "DM Buffs: Would you like to enable auto invite, "..player.."?",
	button1 = "Yes",
	button2 = "No",
	OnAccept = function()
		Initialize()
	end,
}


StaticPopupDialogs["ActivateSummons"] = {
	text = "DM Buffs: Would you like to enable summon capabilities, "..player.."?",
	button1 = "Yes",
	button2 = "No",
	OnAccept = function()
		active_summon = true
	end,
}


TradeFrame = CreateFrame ("Frame")
TradeFrame:RegisterEvent("PLAYER_TRADE_MONEY")
TradeFrame:SetScript("OnEvent",function(self, event, ...)
	gold_changed = true
end)


InviteFrame = CreateFrame("Frame")
InviteFrame:RegisterEvent("CHAT_MSG_WHISPER")
InviteFrame:RegisterEvent("CHAT_MSG_CHANNEL")
InviteFrame:RegisterEvent("CHAT_MSG_SAY")
InviteFrame:RegisterEvent("PLAYER_LOGIN")
InviteFrame:SetScript("OnEvent", function(self, event, ...)

	if event == "CHAT_MSG_CHANNEL" then
		-- Invite players sending messages in open chat channels
		-- Message contains "DM", does not contain "deadmines", and contains at least one of: "any", "WTB", "LF", etc.
		local text, author, lang, channel = ...
		local upper_text = text:upper()
		if FindKeywords(upper_text, keywords_required_1) > 0 and FindKeywords(upper_text, keywords_required_2) > 0 and FindKeywords(upper_text, keywords_ignored) == 0 then
			if active_invite then
				print("Invite sent: "..author)
				InviteUnit(author)
			else
				print("Auto-invite not activated: "..author)
			end
		end
	elseif event == "CHAT_MSG_WHISPER" then
		-- Invite player if they whisper directly
		local text, playername = ...
		local upper_text = text:upper()
		if active_invite then
			if string.match(upper_text, "INV") or string.match(upper_text, "ME") then
				print("Invite sent: "..playername)
				InviteUnit(playername)
			end
		end
	elseif event == "PLAYER_LOGIN" then
		-- Activates the addon upon login
		StaticPopup_Show("Activate")
	end

	if gold_changed then
		cur_gold = GetMoney()
		print("You started with "..tonumber(start_gold / 10000).."g and currently have "..tonumber(cur_gold / 10000).."g: You have made "..tonumber((cur_gold - start_gold) / 10000).."g!")
		gold_changed = false
	end

end)


SummonFrame = CreateFrame("Frame")
SummonFrame:RegisterEvent("CHAT_MSG_SYSTEM")
SummonFrame:RegisterEvent("CHAT_MSG_RAID")
SummonFrame:SetScript("OnEvent",function(self, event, ...)
	if active_summon then
		if event == "CHAT_MSG_SYSTEM" then
			local msg = ...

			local target = msg:sub(1, string.find(msg, " ") - 1)
			-- if string.match(msg, "has joined the raid") or string.match(msg, "joins the party") then
			-- 	customer_count = customer_count + 1
			-- 	SummonPlayer(target_player)
			elseif string.match(msg, "has left the raid") or string.match(msg, "has left the party") then
				if FindKeywords(target, customers) > 0 then
					local summoned_number = FindKeywords(target, customers)
					buttons[summoned_number]:Hide()
					customers[summoned_number] = '.'
				end
			end
		elseif event == "CHAT_MSG_RAID" then
			local msg, author = ...
			local author = cleanName(author)
			-- We don't want messages from other players to cause buttons to be hidden
			-- Only messages from you, the player, should be considered when deciding to hide a button
			-- FIXME(Cody): There is an issue here where after we reload addon if a player in the raid leaves then this can bug out
			if (author == player) and msg:sub(1, 10) == "Summoning " then
				local summoned_number = FindKeywords(msg:sub(11, string.len(msg)), customers)
				buttons[summoned_number]:Hide()
				customers[summoned_number] = '.'
			end
		end

	end
end)


print("DM Buffs Loaded")