local _, addon_table = ...

Queue = {}
Queue.__index = Queue

function Queue:new()
	-- Constructor for Queue class
	local self = {_length = 0}
	setmetatable(self, Queue)
	return self
end 

function Queue:Enqueue(item)
	-- Adds the item to the end of the queue
	self._length = self._length + 1
	table.insert(self, item)
end

function Queue:Dequeue()
	-- Removes and returns the item at the front of the queue
	if self._length == 0 then
		error("Queue is empty!")
	end
	self._length = self._length - 1
	return table.remove(self, 1)
end

function Queue:Clear()
	-- Clears the queue
	-- Iterate over array entries in decreasing order and remove entries
	-- Set length to 0
end

function Queue:Remove(item)
	-- Removes the given item from the queue if it exists, otherwise raises an error
	-- Adjusts the indices of all items behind the removed item accordingly
	local found = nil
	for index, name in ipairs(self) do
		if item == name then
			found = index
			break
		end
	end

	if not found then
		error("The item " .. item .. " was not found in the queue.")
	end

	self._length = self._length - 1
	return table.remove(self, found)
end

function Queue:Contains(item)
	-- Returns true if the item is in the queue and false otherwise
	for _, name in ipairs(self) do
		if item == name then
			return true
		end
	end
	return false
end

function Queue:Size()
	-- Returns the size of the queue
	return self._length
end

function Queue:IsEmpty()
	-- Returns true if the queue is empty and false otherwise
	return self._length == 0
end

function Queue:__tostring()
	local s = "{"
	local sep = ""
	for _, name in ipairs(self) do
		s = s .. sep .. name
		sep = ", "
	end
	s = s .. "}"
	return s
end

addon_table.Queue = Queue