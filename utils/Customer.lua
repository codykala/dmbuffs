local _, addon_table = ...

Customer = {}
Customer.__index = Customer

function Customer:new(name)
    -- Constructor for Customer class
    local self = {
        name = name,
        payment = 0,
        alt_name = nil,
    }
    setmetatable(self, Customer)
    return self
end

function Customer:has_paid()
    -- Returns true if the customer has paid and false otherwise
    return self.payment > 0
end

function Customer:__tostring()
    -- Prints a string representation of the customer object
    local s = "{"
    local sep = ""
    for key, value in pairs(self) do
        s = s .. sep .. key .. " = " .. tostring(value)
        sep = ", "
    end
    s = s .. "}"
    return s
end

addon_table.classes.Customer = Customer