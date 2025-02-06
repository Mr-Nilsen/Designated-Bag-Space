-- DesignatedBagSpaces.lua: Automatically place items in designated slots after sorting

-- Addon namespace
local addonName, addonTable = ...

-- Global table for saved variables
DesignatedBagSpacesCharDB = DesignatedBagSpacesCharDB or {} -- Persistent storage for character-specific data
local designatedSlots = {} -- Runtime cache for designated item slots

-- Helper function: Validate and assign an item to a specific slot
local function AssignItemToSlot(itemID, bag, slot)
    itemID, bag, slot = tonumber(itemID), tonumber(bag), tonumber(slot)
    
    if not itemID or not bag or not slot then
        print("DBS: Invalid input. Usage: /designate <itemID> <bagID> <slot>")
        return
    end

    for existingID, location in pairs(designatedSlots) do
        if bag == location.bag and slot == location.slot then
            print(string.format("DBS: Slot conflict: Item %d is already assigned to bag %d, slot %d. Remove it first.",existingID, bag, slot))
            return
        end
    end

    -- Assign or update designation
    local action = designatedSlots[itemID] and "Updated" or "Assigned"
	designatedSlots[itemID] = { bag = bag, slot = slot }
    print(string.format("DBS: %s item %d to bag %d, slot %d.", action, itemID, bag, slot))
end

-- Function: Organize items into their designated slots
local function OrganizeBags()
    for itemID, location in pairs(designatedSlots) do
        local itemFound = false
        for bag = 0, NUM_BAG_SLOTS + 1 do
            local bagID = (bag > NUM_BAG_SLOTS) and 5 or bag -- Account for reagent bag
            for slot = 1, C_Container.GetContainerNumSlots(bagID) do
                if C_Container.GetContainerItemID(bagID, slot) == itemID then
                    itemFound = true
                    if bagID ~= location.bag or slot ~= location.slot then
						local tempItem = C_Container.GetContainerItemInfo(location.bag, location.slot)
						if tempItem then
							if tempItem.itemID == itemID then
								break
							end
						end
						
                        C_Container.PickupContainerItem(bagID, slot)
                        C_Container.PickupContainerItem(location.bag, location.slot)
                    end
                    break
                end
            end
            if itemFound then break end
        end
    end
end

-- Function: Persist runtime designations to saved variables
local function SaveDesignations()
    DesignatedBagSpacesCharDB = designatedSlots
    print("DBS: Designations saved.")
end

-- Function: Load designations from saved variables
local function LoadDesignations()
    if not DesignatedBagSpacesCharDB then
        print("DBS: No saved designations found.")
        return
    end
    for itemID, location in pairs(DesignatedBagSpacesCharDB) do
        designatedSlots[itemID] = location
    end
    print("DBS: Designations loaded.")
end

-- Function: Add all items from a specific bag to designated slots
local function AddAllItemsInBag(bagID)
    if bagID < 0 or bagID > NUM_BAG_SLOTS + 1 then
        print("DBS: Invalid bag ID. Valid IDs: 0 to", NUM_BAG_SLOTS, "or reagent bag 5.")
        return
    end

    for slot = 1, C_Container.GetContainerNumSlots(bagID) do
        local itemID = C_Container.GetContainerItemID(bagID, slot)
        if itemID then
			AssignItemToSlot(itemID, bagID, slot)
        end
    end
end

-- Function: List all current designations
local function ListDesignations()
    if next(designatedSlots) == nil then
        print("DBS: No current designations.")
        return
    end

    print("DBS: Current item-slot designations:")
    for itemID, location in pairs(designatedSlots) do
        print(string.format("- Item %d: Bag %d, Slot %d", itemID, location.bag, location.slot))
    end
end

-- Function: Remove a designation for a given item ID
local function RemoveDesignation(itemID)
    itemID = tonumber(itemID)
    if not itemID or not designatedSlots[itemID] then
        print("DBS: Invalid item ID or no designation found.")
        return
    end
    designatedSlots[itemID] = nil
    DesignatedBagSpacesCharDB[itemID] = nil
    print(string.format("DBS: Removed designation for item %d.", itemID))
end

local function ClearAllDesignations()
    -- Clear the runtime cache and saved variables
    designatedSlots = {}
    DesignatedBagSpacesCharDB = {}
    print("DBS: All item-slot designations have been cleared.")
end

-- Slash Commands: User-facing commands for the addon
SLASH_DBS1 = "/dbs"
SlashCmdList["DBS"] = function(msg)
    local command, args = strsplit(" ", msg, 2)
    command = command:lower()

    if command == "add" and args then
        local itemID, bag, slot = strsplit(" ", args)
        AssignItemToSlot(itemID, bag, slot)
    elseif command == "addall" then
        AddAllItemsInBag(tonumber(args))
    elseif command == "list" then
        ListDesignations()
    elseif command == "remove" then
        RemoveDesignation(args)
	elseif command == "clear" then
		ClearAllDesignations()
    elseif command == "save" then
        SaveDesignations()
    elseif command == "load" then
        LoadDesignations()
    else
        print("/dbs add [ItemID] [BagID] [SlotID]")
		print("/dbs addall [BagID]")
		print("/dbs remove [ItemID]")
		print("/dbs list")
		print("/dbs clear")
		print("/dbs save")
		print("/dbs load")
    end
end

local function EventHandler(self, event, ...)

	if event == "PLAYER_LOGIN" then
		LoadDesignations()
	end
	
	if event == "BAG_UPDATE_DELAYED" then
		OrganizeBags()
	end

end

-- Initialize on player login
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("BAG_UPDATE_DELAYED")
initFrame:SetScript("OnEvent", EventHandler)
