local _, addon_table = ...

-- TODO(Cody): Encapsulate these upvalues in a class.

---- START UPVALUES ----

local player = UnitName("player")

-- Patterns for determining when someone joins the group
local party_join_pattern = string.gsub(ERR_JOINED_GROUP_S, "%%s", "(.+)")
local party_left_pattern = string.gsub(ERR_LEFT_GROUP_S , "%%s", "(.+)")
local raid_join_pattern = string.gsub(ERR_RAID_MEMBER_ADDED_S, "%%s", "(.+)")
local raid_left_pattern = string.gsub(ERR_RAID_MEMBER_REMOVED_S, "%%s", "(.+)")

-- Variables for inviting
local do_invite = false
local invite_whisper_keywords = {"INV", "ME"}
local invite_buy_keywords = {"WTB", "LF", "ANY"}
local invite_dmt_keywords = {"DM"}
local invite_ignore_keywords = {"DEADMINES", "LFG", "LFM", "WTS", "DME", "DMW"}

-- Variables for summoning
local do_summon = false -- Whether or not to summon
local num_buttons = 10 -- Max number of buttons to display on the screen
local num_active_buttons = 0 -- Number of active buttons showing
local buttons = {} -- Array of button objects
local button_targets = {}  -- Maps target name to button index
local summon_id = 1  -- Running counter
local summon_queue = addon_table.Queue:new() -- For maintaining overflow when >10 people want a summon

-- Maintains the line for customers to get their buffs
local position_queue = addon_table.Queue:new()

-- For monitoring how much gold has been made for the current session
local prev_gold = GetMoney()
local curr_gold = prev_gold

---- END UPVALUES ----


---- START HELPER FUNCTIONS ----

local function CreateButtons()
	-- Create all buttons used for summoning
	buttons = {}
	for i = 1, num_buttons do
		buttons[i] = CreateFrame("Button", string.format("Button %d", i), UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
		buttons[i]:SetPoint("CENTER", mainframe, "Center", 200, 350 - 50 * i)
		buttons[i]:SetWidth(200)
		buttons[i]:SetHeight(50) 
		buttons[i]:Hide()
	end
end

-- local function SummonPlayer(target) 
-- 	-- Cast Ritual of Summoning on the target
-- 	SendChatMessage("Summoning "..target, "RAID")
-- 	TargetUnit(target)
-- 	CastSpellByName("Ritual of Summoning")
-- end

local function UnsetButton(target)
	-- Unset the button used for summoning the target
	local button_idx = button_targets[target]
	buttons[button_idx]:Hide()
	button_targets[target] = nil
	num_active_buttons = num_active_buttons - 1
end

local function SetButton(target)
	-- Set the button used for summoning the target
	PlaySound(8459)
	for i = 1, num_buttons do
		if not buttons[i]:IsShown() then
			buttons[i]:SetText("["..summon_id.."] Summon "..target.."?")
			buttons[i]:SetAttribute("type1", "macro")
			buttons[i]:SetAttribute("macrotext", "/raid Summoning "..target.."\n/tar "..target.."\n/cast Ritual of Summoning")
			buttons[i]:SetScript(
				"PostClick",
				function()
					UnsetButton(target)
					if not summon_queue:IsEmpty() then
						local next_target = summon_queue:Dequeue()
						SetButton(next_target)
					end
				end
			)
			buttons[i]:Show()
			button_targets[target] = i
			summon_id = summon_id + 1
			num_active_buttons = num_active_buttons + 1
			return
		end
	end
end

local function MayStripServerFromName(name)
	-- Name can sometimes include server name as well, need to strip it out
	if string.find(name, "-") ~= nil then
		local index = string.find(name, "-") 
		name = name:sub(1, index - 1)
	end
	return name
end

local function AnyKeywordsMatch(target, keywords)
	for _, keyword in ipairs(keywords) do
		if string.match(target, keyword) then
			return true
		end
	end
	return false
end


---- END HELPER FUNCTIONS ----


---- START ADDON CODE ----

StaticPopupDialogs["ActivateInvites"] = {
	text = "DM Buffs: Would you like to enable auto invite, "..player.."?",
	button1 = "Yes",
	button2 = "No",
	OnAccept = function()
		do_invite = true
	end,
}

StaticPopupDialogs["ActivateSummons"] = {
	text = "DM Buffs: Would you like to enable summon capabilities, "..player.."?",
	button1 = "Yes",
	button2 = "No",
	OnAccept = function()
		do_summon = true
		CreateButtons()
	end,
}

local activate_frame = CreateFrame("Frame", "ActivateFrame")
activate_frame:RegisterEvent("PLAYER_LOGIN")
activate_frame:SetScript(
	"OnEvent",
	function(self, event, ...)
		StaticPopup_Show("ActivateInvites")
		StaticPopup_Show("ActivateSummons")
	end
)

local invite_frame = CreateFrame("Frame", "InviteFrame")
invite_frame:RegisterEvent("CHAT_MSG_CHANNEL")
invite_frame:RegisterEvent("CHAT_MSG_WHISPER")
invite_frame:RegisterEvent("CHAT_MSG_SAY")
invite_frame:SetScript(
	"OnEvent", 
	function(self, event, ...)
		if not do_invite then return end
		if (
			event == "CHAT_MSG_WHISPER" 
			or event == "CHAT_MSG_SAY"
	 	) then
			local msg, target = ...
			local upper_msg = msg:upper()
			target = MayStripServerFromName(target)
			if AnyKeywordsMatch(upper_msg, invite_whisper_keywords) then
				InviteUnit(target)
			end
		elseif event == "CHAT_MSG_CHANNEL" then
			local msg, target = ...
			local upper_msg = msg:upper()
			target = MayStripServerFromName(target)
			if (
				AnyKeywordsMatch(upper_msg, invite_buy_keywords) 
				and AnyKeywordsMatch(upper_msg, invite_dmt_keywords) 
				and not AnyKeywordsMatch(upper_msg, invite_ignore_keywords)
			) then
				InviteUnit(target)
			end
		end
	end
)


local summon_frame = CreateFrame("Frame", "SummonFrame")
summon_frame:RegisterEvent("CHAT_MSG_SYSTEM")
summon_frame:RegisterEvent("CHAT_MSG_PARTY")
summon_frame:RegisterEvent("CHAT_MSG_RAID")
summon_frame:SetScript(
	"OnEvent",
	function(self, event, ...)
		if not do_summon then return end
		if event == "CHAT_MSG_SYSTEM" then
			local msg = ...
			local target = nil
			-- Check to see if someone joined the group
			target = (
				string.match(msg, party_join_pattern) 
				or string.match(msg, raid_join_pattern)
			)
			if target then 
				target = MayStripServerFromName(target)
				position_queue:Enqueue(target)
				return
			end
			-- Check to see if someone left the group
			target = (
				string.match(msg, party_left_pattern) 
				or string.match(msg, raid_left_pattern)
			)
			if target then
				target = MayStripServerFromName(target)
				position_queue:Remove(target)
				-- If the target had requested a summon prior to leaving
				-- the raid, then we need to remove him from the summoning 
				-- queue and hide his button if one was showing for him.
				-- If there is a queue, then we can use the button for the
				-- next person.
				if summon_queue:Contains(target) then
					summon_queue:Remove(target)
				end
				if button_targets[target] ~= nil then
					UnsetButton(target)
					if not summon_queue:IsEmpty() then
						local next_target = summon_queue:Dequeue()
						SetButton(next_target)
					end
				end
				return
			end
		elseif event == "CHAT_MSG_RAID" then
			local msg, target = ...
			target = MayStripServerFromName(target)
			if (target ~= player and msg == "123") then
				-- People tend to spam "123" when they get impatient. 
				-- Check if the target is already in line for a summon.
				-- If he is, do nothing.
				if (
					button_targets[target] ~= nil 
					or summon_queue:Contains(target)
				 ) then 
					return 
				end
				if num_active_buttons < num_buttons then
					SetButton(target)
				else
					summon_queue:Enqueue(target)
				end
			end
		end
	end
)

local trade_frame = CreateFrame("Frame", "TradeFrame")
trade_frame:RegisterEvent("PLAYER_TRADE_MONEY")
trade_frame:SetScript(
	"OnEvent",
	function(self, event, ...)
		prev_gold = curr_gold
		curr_gold = GetMoney()
		local diff_gold = curr_gold - prev_gold
	end
)