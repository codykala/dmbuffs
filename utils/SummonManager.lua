local _, addon_table = ...

SummonQueue = {}
SummonQueue.__index = SummonQueue

local function CreateButtons(num_buttons)
	-- Create all buttons used for summoning
	local buttons = {}
	for i = 1, num_buttons do
		buttons[i] = CreateFrame("Button", string.format("Button %d", i), UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
		buttons[i]:SetPoint("CENTER", mainframe, "Center", 200, 350 - 50 * i)
		buttons[i]:SetWidth(200)
		buttons[i]:SetHeight(50) 
		buttons[i]:Hide()
    end
    return buttons
end

local function SummonPlayer(target) 
	-- Cast Ritual of Summoning on the target
	SendChatMessage("Summoning "..target, "RAID")
	TargetUnit(target)
	CastSpellByName("Ritual of Summoning")
end

function SummonQueue:New(num_buttons)
	-- Constructor for SummonQueue class
	local self = {
        -- The total number of buttons
        _num_buttons = num_buttons,

        -- The array of buttons
        _buttons = CreateButtons(num_buttons),

        -- The number of buttons showing on the screen
        _num_active_buttons = 0,

        -- Maps targets to index in buttons array
        _button_targets = {},

        -- A counter that increments with the number of customers
        -- Used to specify order in which to click buttons
        _summon_id = 1,

        -- Stores overflow targets (i.e. when the number of customers exceeds 
        -- the number of available buttons)
        _overflow_queue = addon_table.Queue:New(),
    }
	setmetatable(self, SummonQueue)
	return self
end 

function SummonQueue:_UnsetButton(target)
	-- Unset the button used for summoning the target
	local button_idx = self._button_targets[target]
	self._buttons[button_idx]:Hide()
	self._button_targets[target] = nil
	self._num_active_buttons = self._num_active_buttons - 1
end

function SummonQueue:_SetButton(target)
    -- Set the button used for summoning the target
    PlaySound(8459)
    for i = 1, self._num_buttons do
        if not self._buttons[i]:IsShown() then
            self._buttons[i]:SetText("["..self._summon_id.."] Summon "..target.."?")
            self._buttons[i]:SetScript(
                "OnClick",
                function()
                    SummonPlayer(target)
                    self:_UnsetButton(target)
                    if not self._overflow_queue:Empty() then
                        local next_target = self._overflow_queue:Dequeue()
                        self:_SetButton(next_target)
                    end
                end
            )
            self._buttons[i]:Show()
            self._button_targets[target] = i
            self._summon_id = self._summon_id + 1
            self._num_active_buttons = self._num_active_buttons + 1
            return
        end
    end
end

function SummonQueue:Remove(target)
    -- Removes the target from the SummonQueue.
    if self._summon_queue:Contains(target) then
        self._summon_queue:Remove(target)
    end
    if self._button_targets[target] ~= nil then
        self:_UnsetButton(target)
        if not summon_queue:Empty() then
            local next_target = summon_queue:Dequeue()
            self:_SetButton(next_target)
        end
    end
end

function SummonQueue:Add(target)
    -- Adds the target to the SummonQueue.
    if self._button_targets[target] ~= nil or self._summon_queue:Contains(target) then
        return
    end

    if self._num_active_buttons < self._num_buttons then
        self:_SetButton(target)
    else
        self._summon_queue:Enqueue(target)
    end
end

addon_table.SummonQueue = SummonQueue