
-- This table is used by the client to show items in the equipment menu, and by
-- the server to check if a certain role is allowed to buy a certain item.


-- If you have custom items you want to add, consider using a separate lua
-- script that uses table.insert to add an entry to this table. This method
-- means you won't have to add your code back in after every TTT update. Just
-- make sure the script is also run on the client.
--
-- For example:
--	table.insert(EquipmentItems[ROLES.DETECTIVE.index], { id = EQUIP_ARMOR, ... })
--
-- Note that for existing items you can just do:
--	table.insert(EquipmentItems[ROLES.DETECTIVE.index], GetEquipmentItem(ROLES.TRAITOR.index, EQUIP_ARMOR))


-- Special equipment bitflags. Every unique piece of equipment needs its own
-- id. 
--
-- Use the GenerateNewEquipmentID function (see below) to get a unique ID for
-- your equipment. This is guaranteed not to clash with other addons (as long
-- as they use the same safe method).
--
-- Details you shouldn't need:
-- The number should increase by a factor of two for every item (ie. ids
-- should be powers of two).
EQUIP_NONE = 0
EQUIP_ARMOR	= 1
EQUIP_RADAR	= 2
EQUIP_DISGUISE = 4

EQUIP_MAX = 4

-- Icon doesn't have to be in this dir, but all default ones are in here
local mat_dir = "vgui/ttt/"

-- Stick to around 35 characters per description line, and add a "\n" where you
-- want a new line to start.

EquipmentItems = {}
SYNC_EQUIP = {}
ALL_ITEMS = {}
EQUIPMENT_DEFAULT_TRAITOR = {}
EQUIPMENT_DEFAULT_DETECTIVE = {}

function SetupEquipment()
	for _, v in pairs(GetTeamRoles(TEAM_TRAITOR)) do
		if not EquipmentItems[v.index] then
			EquipmentItems[v.index] = {
				-- body armor
				{	
					id		 = EQUIP_ARMOR,
					type	 = "item_passive",
					material = mat_dir .. "icon_armor",
					name	 = "item_armor",
					desc	 = "item_armor_desc"
				},
				-- radar
				{	
					id		 = EQUIP_RADAR,
					type	 = "item_active",
					material = mat_dir .. "icon_radar",
					name	 = "item_radar",
					desc	 = "item_radar_desc"
				},
				-- disguiser
				{	
					id		 = EQUIP_DISGUISE,
					type	 = "item_active",
					material = mat_dir .. "icon_disguise",
					name	 = "item_disg",
					desc	 = "item_disg_desc"
				}
			}
		end
	end

	for _, v in pairs(ROLES) do
		if v.team ~= TEAM_TRAITOR and not EquipmentItems[v.index] then
			EquipmentItems[v.index] = {}
		end
	end
end

SetupEquipment() -- pre init to support normal TTT addons

hook.Add("TTT2_FinishedSync", "updateEquRol", function()
	SetupEquipment()
end)

function GetShopFallback(role)
	local rd = GetRoleByIndex(role)
	
	if not rd.shop then
		return role
	end
	
	local shopFallback = GetConVar("ttt_" .. rd.abbr .. "_shop_fallback"):GetString()
	
	return GetRoleByName(shopFallback).index
end

function GetShopFallbackTable(role)
	local rd = GetRoleByIndex(role)
	
	if not rd.shop then
		return {}
	end
	
	local fallback = GetShopFallback(role)
	
	-- test whether shop is linked with traitor or detective default shop
	if fallback ~= ROLES.INNOCENT.index then
		local tmp = GetShopFallback(fallback)
		if tmp == ROLES.INNOCENT.index then
			role = fallback
			fallback = tmp
		end
	end

	if fallback == ROLES.INNOCENT.index then -- fallback is "UNSET"
		if role == ROLES.TRAITOR.index then
			return EQUIPMENT_DEFAULT_TRAITOR
		elseif role == ROLES.DETECTIVE.index then
			return EQUIPMENT_DEFAULT_DETECTIVE
		end
	end
end

-- Search if an item is in the equipment table of a given role, and return it if
-- it exists, else return nil.
function GetEquipmentItem(role, id)
	local tbl = GetShopFallbackTable(role) or EquipmentItems[GetShopFallback(role)]
	
	if not tbl then return end

	for _, v in pairs(tbl) do
		if v and v.id == id then
			return v
		end
	end
end

function GetEquipmentItemByID(id)
	for _, eq in pairs(ALL_ITEMS) do
		if eq.id == id then
			return eq
		end
	end
end

function GetEquipmentItemByName(name)
	for _, equip in pairs(ALL_ITEMS) do
		if string.lower(equip.name) == name then
			return equip
		end
	end
end

function GetEquipmentFileName(name)
	local newName = name

	string.gsub(newName, "%W", "_") -- clean string
	string.gsub(newName, "%s", "_") -- clean string
	
	newName = string.lower(newName)
	
	return newName
end

function GetEquipmentItemByFileName(name)
	for _, equip in pairs(ALL_ITEMS) do
		if GetEquipmentFileName(equip.name) == name then
			return equip
		end
	end
end

-- Utility function to register a new Equipment ID
function GenerateNewEquipmentID()
	EQUIP_MAX = EQUIP_MAX * 2
	
	return EQUIP_MAX
end

function EquipmentTableHasValue(tbl, equip)
	if not tbl then 
		return false 
	end

	for _, eq in pairs(tbl) do
		if eq.id == equip.id then
			return true
		end
	end
	
	return false
end

function SyncTableHasValue(tbl, equip)
	for _, v in pairs(tbl) do
		if v.equip == equip.equip and v.type == equip.type then
			return true
		end
	end
	
	return false
end

function InitDefaultEquipment()
	-- set default equipment tables
	
-- TRAITOR
	local tbl = table.Copy(EquipmentItems[ROLES.TRAITOR.index])

	-- find buyable weapons to load info from
	for _, v in ipairs(weapons.GetList()) do
		if v and not v.Doublicated and v.CanBuy and table.HasValue(v.CanBuy, ROLES.TRAITOR.index) then
			local data = v.EquipMenuData or {}
			local base = {
				id		 = WEPS.GetClass(v),
				name	 = v.ClassName or "Unnamed",
				limited	 = v.LimitedStock,
				kind	 = v.Kind or WEAPON_NONE,
				slot	 = (v.Slot or 0) + 1,
				material = v.Icon or "vgui/ttt/icon_id",
				-- the below should be specified in EquipMenuData, in which case
				-- these values are overwritten
				type	 = "Type not specified",
				model	 = "models/weapons/w_bugbait.mdl",
				desc	 = "No description specified."
			}

			-- Force material to nil so that model key is used when we are
			-- explicitly told to do so (ie. material is false rather than nil).
			if data.modelicon then
				base.material = nil
			end

			table.Merge(base, data)
			
			base.id = v.ClassName,
			
			table.insert(tbl, base)
		end
	end

	-- mark custom items
	for _, i in pairs(tbl) do
		if i and i.id then
			i.custom = not table.HasValue(DefaultEquipment[ROLES.TRAITOR.index], i.id) -- TODO
		end
	end

	EQUIPMENT_DEFAULT_TRAITOR = tbl
	
-- DETECTIVE
	local tbl = table.Copy(EquipmentItems[ROLES.DETECTIVE.index])

	-- find buyable weapons to load info from
	for _, v in ipairs(weapons.GetList()) do
		if v and not v.Doublicated and v.CanBuy and table.HasValue(v.CanBuy, ROLES.DETECTIVE.index) then
			local data = v.EquipMenuData or {}
			local base = {
				id		 = WEPS.GetClass(v),
				name	 = v.ClassName or "Unnamed",
				limited	 = v.LimitedStock,
				kind	 = v.Kind or WEAPON_NONE,
				slot	 = (v.Slot or 0) + 1,
				material = v.Icon or "vgui/ttt/icon_id",
				-- the below should be specified in EquipMenuData, in which case
				-- these values are overwritten
				type	 = "Type not specified",
				model	 = "models/weapons/w_bugbait.mdl",
				desc	 = "No description specified."
			}

			-- Force material to nil so that model key is used when we are
			-- explicitly told to do so (ie. material is false rather than nil).
			if data.modelicon then
				base.material = nil
			end

			table.Merge(base, data)
			
			base.id = v.ClassName,
			
			table.insert(tbl, base)
		end
	end

	-- mark custom items
	for _, i in pairs(tbl) do
		if i and i.id then
			i.custom = not table.HasValue(DefaultEquipment[ROLES.DETECTIVE.index], i.id) -- TODO
		end
	end

	EQUIPMENT_DEFAULT_DETECTIVE = tbl
end

function InitAllItems()
	for _, roleData in pairs(ROLES) do
		if EquipmentItems[roleData.index] then
			for _, eq in pairs(EquipmentItems[roleData.index]) do
				if not EquipmentTableHasValue(ALL_ITEMS, eq) then
					eq.defaultRole = roleData.index
					
					table.insert(ALL_ITEMS, eq)
				end
			end
			
			-- reset normal equipment tables
			EquipmentItems[roleData.index] = {}
		end
	end
end

if SERVER then
	util.AddNetworkString("TTT2SyncEquipment")
	
	-- Sync Equipment
	local function EncodeForStream(tbl)
		-- may want to filter out data later
		-- just serialize for now

		local result = util.TableToJSON(tbl)
		if not result then
			ErrorNoHalt("Round report event encoding failed!\n")
			
			return false
		else
			return result
		end
	end
	
	function SyncEquipment(ply, add)
		add = add or true
	
		print("[TTT2][SHOP] Sending new SHOP list to " .. ply:Nick() .. "...")
		
		local s = EncodeForStream(SYNC_EQUIP)
		if not s then return end

		-- divide into happy lil bits.
		-- this was necessary with user messages, now it's
		-- a just-in-case thing if a round somehow manages to be > 64K
		local cut = {}
		local max = 65499
		
		while #s ~= 0 do
			local bit = string.sub(s, 1, max - 1)
			
			table.insert(cut, bit)

			s = string.sub(s, max, -1)
		end

		local parts = #cut
		
		for k, bit in ipairs(cut) do
			net.Start("TTT2SyncEquipment")
			net.WriteBool(add)
			net.WriteBit((k ~= parts)) -- continuation bit, 1 if there's more coming
			net.WriteString(bit)

			if ply then
				net.Send(ply)
			else
				net.Broadcast()
			end
		end
	end

	function SyncSingleEquipment(ply, role, equipTbl, add)
		print("[TTT2][SHOP] Sending updated equipment '" .. equipTbl.equip .. "' to " .. ply:Nick() .. "...")
		
		local s = EncodeForStream({[role] = {equipTbl}})
		if not s then return end

		-- divide into happy lil bits.
		-- this was necessary with user messages, now it's
		-- a just-in-case thing if a round somehow manages to be > 64K
		local cut = {}
		local max = 65500
		
		while #s ~= 0 do
			local bit = string.sub(s, 1, max - 1)
			
			table.insert(cut, bit)

			s = string.sub(s, max, -1)
		end

		local parts = #cut
		
		for k, bit in ipairs(cut) do
			net.Start("TTT2SyncEquipment")
			net.WriteBool(add)
			net.WriteBit((k ~= parts)) -- continuation bit, 1 if there's more coming
			net.WriteString(bit)

			if ply then
				net.Send(ply)
			else
				net.Broadcast()
			end
		end
	end
	
	function AddEquipmentItemToRole(role, item)
		EquipmentItems[role] = EquipmentItems[role] or {}
		
		if not EquipmentTableHasValue(EquipmentItems[role], item) then
			table.insert(EquipmentItems[role], item)
		end
		
		SYNC_EQUIP[role] = SYNC_EQUIP[role] or {}
		
		local tbl = {equip = item.id, type = 1}
		
		if not SyncTableHasValue(SYNC_EQUIP[role], tbl) then
			table.insert(SYNC_EQUIP[role], tbl)
		end
		
		for _, v in pairs(player.GetAll()) do
			SyncSingleEquipment(v, role, tbl, true)
		end
	end
	
	function RemoveEquipmentItemFromRole(role, item)
		EquipmentItems[role] = EquipmentItems[role] or {}
		
		for k, eq in pairs(EquipmentItems[role]) do
			if eq.id == item.id then
				table.remove(EquipmentItems[role], k)
				
				break
			end
		end
		
		SYNC_EQUIP[role] = SYNC_EQUIP[role] or {}
		
		local tbl = {equip = item.id, type = 1}
		
		for k, v in pairs(SYNC_EQUIP[role]) do
			if v.equip == tbl.equip and v.type == tbl.type then
				table.remove(SYNC_EQUIP[role], k)
			end
		end
		
		for _, v in pairs(player.GetAll()) do
			SyncSingleEquipment(v, role, tbl, false)
		end
	end
	
	function AddEquipmentWeaponToRole(role, swep_table)
		if not swep_table.CanBuy then
			swep_table.CanBuy = {}
		end
		
		if not table.HasValue(swep_table.CanBuy, role) then
			table.insert(swep_table.CanBuy, role)
		end
		--
		
		SYNC_EQUIP[role] = SYNC_EQUIP[role] or {}
		
		local tbl = {equip = swep_table.ClassName, type = 0}
		
		if not SyncTableHasValue(SYNC_EQUIP[role], tbl) then
			table.insert(SYNC_EQUIP[role], tbl)
		end
		
		for _, v in pairs(player.GetAll()) do
			SyncSingleEquipment(v, role, tbl, true)
		end
	end
	
	function RemoveEquipmentWeaponFromRole(role, swep_table)
		if not swep_table.CanBuy then
			swep_table.CanBuy = {}
		else
			for k, v in ipairs(swep_table.CanBuy) do
				if v == role then
					table.remove(swep_table.CanBuy, k)
					
					break
				end
			end
		end
		--
		
		SYNC_EQUIP[role] = SYNC_EQUIP[role] or {}
		
		local tbl = {equip = swep_table.ClassName, type = 0}
		
		for k, v in pairs(SYNC_EQUIP[role]) do
			if v.equip == tbl.equip and v.type == tbl.type then
				table.remove(SYNC_EQUIP[role], k)
			end
		end
		
		for _, v in pairs(player.GetAll()) do
			SyncSingleEquipment(v, role, tbl, false)
		end
	end
else -- CLIENT
	function AddEquipmentToRoleEquipment(role, equip, item)
		-- start with all the non-weapon goodies
		local toadd

		-- find buyable weapons to load info from
		if not item then
			if equip and not equip.Doublicated and equip.CanBuy and table.HasValue(equip.CanBuy, role) then
				local data = equip.EquipMenuData or {}
				local base = {
					id		 = WEPS.GetClass(equip),
					name	 = equip.ClassName or "Unnamed",
					limited	 = equip.LimitedStock,
					kind	 = equip.Kind or WEAPON_NONE,
					slot	 = (equip.Slot or 0) + 1,
					material = equip.Icon or "vgui/ttt/icon_id",
					-- the below should be specified in EquipMenuData, in which case
					-- these values are overwritten
					type	 = "Type not specified",
					model	 = "models/weapons/w_bugbait.mdl",
					desc	 = "No description specified.",
					is_item  = false
				}

				-- Force material to nil so that model key is used when we are
				-- explicitly told to do so (ie. material is false rather than nil).
				if data.modelicon then
					base.material = nil
				end

				table.Merge(base, data)
				
				toadd = base
				
				if not table.HasValue(equip.CanBuy, role) then
					table.insert(equip.CanBuy, role)
				end
			end
		else
			toadd = equip
			
			EquipmentItems[role] = EquipmentItems[role] or {}
			
			if not EquipmentTableHasValue(EquipmentItems[role], toadd) then
				table.insert(EquipmentItems[role], toadd)
			end
		end

		-- mark custom items
		if toadd and toadd.id then
			toadd.custom = not table.HasValue(DefaultEquipment[role], toadd.id) -- TODO
		end
		
		Equipment[role] = Equipment[role] or {}
		
		if toadd and not EquipmentTableHasValue(Equipment[role], toadd) then
			table.insert(Equipment[role], toadd)
		end
	end
	
	function RemoveEquipmentFromRoleEquipment(role, equip, item)
		equip.id = item and equip.id or equip.name
	
		if item then
			for k, eq in pairs(EquipmentItems[role]) do
				if eq.id == equip.id then
					table.remove(EquipmentItems[role], k)
					
					break
				end
			end
		else
			for k, v in ipairs(equip.CanBuy) do
				if v == role then
					table.remove(equip.CanBuy, k)
					
					break
				end
			end
		end
	
		for k, eq in pairs(Equipment[role]) do
			if eq.id == equip.id then
				table.remove(Equipment[role], k)
				
				break
			end
		end
	end
	
	-- sync ROLES
	local buff = ""

	net.Receive("TTT2SyncEquipment", function(len)
		print("[TTT2][SHOP] Received new SHOP list from server! Updating...")

		local add = net.ReadBool()
		local cont = net.ReadBit() == 1

		buff = buff .. net.ReadString()

		if cont then
			return
		else
			-- do stuff with buffer contents
			local json_shop = buff -- util.Decompress(buff)
			
			if not json_shop then
				ErrorNoHalt("SHOP decompression failed!\n")
			else
				-- convert the json string back to a table
				local tmp = util.JSONToTable(json_shop)

				if istable(tmp) then
					for role, tbl in pairs(tmp) do
						EquipmentItems[role] = EquipmentItems[role] or {}
						
						-- init
						Equipment = Equipment or {}

						if not Equipment[role] then
							GetEquipmentForRole(role)
						end
					
						for _, equip in pairs(tbl) do
							if equip.type == 1 then
								local item = GetEquipmentItemByID(equip.equip)
								if item then
									if add then
										AddEquipmentToRoleEquipment(role, item, true)
									else
										RemoveEquipmentFromRoleEquipment(role, item, true)
									end
								end
							else
								local swep_table = weapons.GetStored(equip.equip)
								if swep_table then
									if not swep_table.CanBuy then
										swep_table.CanBuy = {}
									end
								
									if add then
										AddEquipmentToRoleEquipment(role, swep_table, false)
									else
										RemoveEquipmentFromRoleEquipment(role, swep_table, false)
									end
								end
							end
						end
					end
				else
					ErrorNoHalt("SHOP decoding failed!\n")
				end
			end

			-- flush
			buff = ""
		end
	end)
end
