--Initalize mod storage is not existant in loaded save 
local mod = game.mod_runtime[ game.current_mod ]
if not game.mod_storage.omt_resources.grids then
    game.mod_storage.omt_resources.grids = {}
    gapi.add_msg("New save, writting grid storage")
end

--DONT DO THIS FUTURE ME. It creates a copy of not refrence to.
-- local grid_storage =  game.mod_storage.omt_resources.grids



--Functions for reading/editing the resource grids
mod.grid_functions = {}
---Initalizes the values for a newly accessed grid, creates overmap table if needed
---@param coord_str string
---@param resource_table table
mod.grid_functions.Initalize_resource_grid = function(resource_id, abs_omt_str)
    if not game.mod_storage.omt_resources.grids[abs_omt_str] then game.mod_storage.omt_resources.grids[abs_omt_str] = {} end
    gdebug.log_info("Initalizing " ..resource_id.." grid at ".. abs_omt_str)
    local resource_table = mod.grid_functions.Get_resource_table_from_id(resource_id)
    game.mod_storage.omt_resources.grids[abs_omt_str][resource_id] = {}
    game.mod_storage.omt_resources.grids[abs_omt_str][resource_id].amount = resource_table.starting_amount
    game.mod_storage.omt_resources.grids[abs_omt_str][resource_id].active_mod = 0
    game.mod_storage.omt_resources.grids[abs_omt_str][resource_id].capacity = resource_table.base_capacity
    game.mod_storage.omt_resources.grids[abs_omt_str][resource_id].modifying_furniture = {}
    mod.grid_functions.Register_furniture_in_map(gapi.get_map(), resource_id)
    mod.grid_functions.Update_grid(resource_table, abs_omt_str)
end

---Updates resource_table based on furniture in grid
---@param resource_table table
---@param abs_omt_str string
mod.grid_functions.Update_grid = function(resource_table, abs_omt_str)
    local capacity_mod = 0
    local active_mod = 0
    local resource_id = resource_table.resource_id

    -- Go through the stat value pairs in each furniture table, check and add to correct modification value
    for _, furn_id_str in pairs(game.mod_storage.omt_resources.grids[abs_omt_str][resource_id]["modifying_furniture"]) do
        active_mod = active_mod + resource_table.modifying_furniture[furn_id_str].active_mod
        capacity_mod = capacity_mod + resource_table.modifying_furniture[furn_id_str].capacity_mod
    end

    -- Apply the new stat values to the resource grid
    game.mod_storage.omt_resources.grids[abs_omt_str][resource_id].active_mod = active_mod
    game.mod_storage.omt_resources.grids[abs_omt_str][resource_id].capacity = resource_table.base_capacity + capacity_mod
end


--TODO convert resource_table usage to resource_id
--- Fetches the resource grid for a given map square or overmap tile and resource. Initalizes if no grid exists.
---@param resource_table table
---@param coord tripoint
---@param is_local_ms boolean
---@return table
mod.grid_functions.Get_grid = function(resource_id, coord, is_local_ms)
    if is_local_ms == nil then is_local_ms = true end
    local abs_omt
    if is_local_ms then
        local abs_ms = gapi.get_map():get_abs_ms(coord)
        abs_omt = coords.ms_to_omt(abs_ms)
        gdebug.log_info("Get grid translated coords to"..abs_omt:__tostring())
    else abs_omt = coord
    end
    abs_omt.z = 0
    local abs_omt_str = abs_omt:__tostring()
    if not game.mod_storage.omt_resources.grids[abs_omt_str] or not game.mod_storage.omt_resources.grids[abs_omt_str][resource_id] then
        mod.grid_functions.Initalize_resource_grid(resource_id, abs_omt_str)
    end
    return game.mod_storage.omt_resources.grids[abs_omt_str][resource_id]
end

---Retrieves the resource table from resource_table_list with a resource_id
---@param resource_id any
mod.grid_functions.Get_resource_table_from_id = function(resource_id)
    for x = 1, #mod.resource_table_list do
        if mod.resource_table_list[x].resource_id == resource_id then
            return mod.resource_table_list[x]
        end
    end
end

---Checks a resource_table for a given flag
---@param resource_table table
---@param flag string
mod.grid_functions.Check_for_flag = function(resource_table, flag)
    local next = next
    if next(resource_table) == nil then
        return false
    end
    for x = 1, #resource_table.flags do
        if resource_table.flags[x] == flag then
            return true
        end
    end
    return false
end

---Calls Modify_resource_grid_amount and returns true if sucessful, false otherwise.
---@param resource_id string
---@param coord tripoint
---@param modify_amount number
---@param is_local_ms boolean
---@return boolean
mod.grid_functions.Modify_resource_amount_call = function(resource_id, coord, modify_amount, is_local_ms)
    local resource_grid = mod.grid_functions.Get_grid(resource_id, coord, is_local_ms)
    return mod.grid_functions.Modify_resource_grid_amount(resource_id, resource_grid, modify_amount)
end

---Attempts to edit a resource grid's amount by a given number, and checks if result is valid. Return true if valid, false if not.
---@param resource_id string
---@param resource_grid table
---@param modify_amount number
---@return boolean
mod.grid_functions.Modify_resource_grid_amount = function(resource_id, resource_grid, modify_amount)
    local new_amount = resource_grid.amount + modify_amount
    local resource_table = mod.grid_functions.Get_resource_table_from_id(resource_id)
    if new_amount >= 0 or mod.grid_functions.Check_for_flag(resource_table, "CAN_GO_NEGITIVE") then
        if new_amount >= resource_grid.capacity then new_amount = resource_grid.capacity end
        resource_grid.amount = new_amount
        return true
    else
        return false
    end
end

--TODO Fetch furniture matching specified furniture in resource_furniture_storage of given id
mod.grid_functions.Register_furniture_in_map = function(map, resource_id)
    --Go through all loaded tiles one z level above and below character
    local map_size = map:get_map_size()
    for y = 0, map_size - 1 do
        for x = 0, map_size - 1 do
            for z = gapi.get_avatar():get_pos_ms().z - 1, gapi.get_avatar():get_pos_ms().z + 1 do
                --Some variables we'll need
                local map_square = Tripoint.new(x, y, z)
                local furniture_int_id = map:get_furn_at(map_square)
                local abs_ms = map:get_abs_ms(map_square)
                local abs_omt = coords.ms_to_omt(abs_ms)
                --Furniture registered to grid here
                if furniture_int_id:str_id():str() ~= "f_null" then
                    local resource_table = mod.grid_functions.Get_resource_table_from_id(resource_id)
                    for furniture_id_str, _  in pairs(resource_table.modifying_furniture) do
                        if  furniture_id_str == furniture_int_id:str_id():str() then
                            abs_omt.z = 0
                            mod.grid_functions.Get_grid(resource_id, abs_omt, false)
                            gdebug.log_info("furn reg to grid at ".. abs_omt:__tostring())
                            game.mod_storage.omt_resources.grids[abs_omt:__tostring()][resource_id].modifying_furniture[abs_ms:__tostring()] = furniture_int_id:str_id():str()
                        end
                    end
                end
            end
        end
    end
end



--Timed hooks
---Cleans then updates grid modifying around player then calculates and updates grid amounts
mod.on_every_hour = function()
    --Clean furniture entries of grids in/adjacent to player omt
    for entry = 1, #mod.resource_table_list do
        local player_abs_omt = mod.debug.Abs_omt_at_player()
        local resource_id = mod.resource_table_list[entry].resource_id
        for x = player_abs_omt.x - 1, player_abs_omt.x + 1 do
            for y = player_abs_omt.y - 1, player_abs_omt.y + 1 do
                for z = player_abs_omt.z - 1, player_abs_omt.z + 1 do
                    local abs_omt = Tripoint.new(x, y, z)
                    if game.mod_storage.omt_resources.grids[abs_omt:__tostring()] and game.mod_storage.omt_resources.grids[abs_omt:__tostring()][resource_id] then
                        game.mod_storage.omt_resources.grids[abs_omt:__tostring()][resource_id].modifying_furniture = {}
                    end
                end
            end
        end
    end

    --Registers furntiture in currently loaded map 1 z level above/below player
    for x = 1, #mod.resource_table_list do
        local resource_id = mod.resource_table_list[x].resource_id
        mod.grid_functions.Register_furniture_in_map(gapi.get_map(), resource_id)
    end

    --Runs Modify_resource_grid_amount for every grid in storage
    for abs_omt_str, resource_ids_table in pairs(game.mod_storage.omt_resources.grids) do
        for resource_id, _ in pairs(resource_ids_table) do
            local resource_grid = game.mod_storage.omt_resources.grids[abs_omt_str][resource_id]
            local resource_table = mod.grid_functions.Get_resource_table_from_id(resource_id)
            local modify_amount = resource_table.passive_mod + resource_grid.active_mod
            mod.grid_functions.Update_grid(resource_table, abs_omt_str)
            mod.grid_functions.Modify_resource_grid_amount(resource_id, resource_grid, modify_amount)
        end
    end
end

gapi.add_on_every_x_hook(TimeDuration.from_hours(1), mod.on_every_hour)
gdebug.log_info("Applied per hour hook for omt_resources")



--Other Hooks

--Difficulties having another mod load into the resource table before mapgen, no clue but for now just have things update per hour
---Function applied on mapgen
-- mod.on_mapgen_postprocess_hook = function( map, p_omt, when )
--     --populate modifying_furniture_list
--     for x = 1, #mod.resource_table_list do
--         local resource_table = mod.resource_table_list[x]
--         local resource_id = resource_table.resource_id
--         mod.modifying_furniture_list[resource_id] = {}
--         for furniture_id_str, _  in pairs(resource_table.furniture) do
--             table.insert(mod.modifying_furniture_list[resource_id], furniture_id_str)
--         end
--     end

--     for x = 1, #mod.resource_table_list do
--         mod.grid_functions.Register_furniture_in_grid(map, p_omt, mod.resource_table_list[x].resource_id)
--     end
-- end



--Debugging functions
mod.debug = {}

---Returns the absolute overmap tile the player is in. I hate it
---@return tripoint
mod.debug.Abs_omt_at_player = function ()
    return coords.ms_to_omt(gapi.get_map():get_abs_ms(gapi.get_avatar():get_pos_ms()))
end

---Modifies the amount field in the resource_grid at the player's location. Also can be used to log grid amount with mod_amount of 0
---@param resource_id string
---@param mod_amount number
mod.debug.Mod_grid_at_player = function(resource_id, mod_amount)
    local resource_grid = mod.grid_functions.Get_grid(resource_id, gapi.get_avatar():get_pos_ms())
    mod.grid_functions.Modify_resource_grid_amount(resource_id, resource_grid, mod_amount)
    gdebug.log_info("Grid at ".. mod.debug.Abs_omt_at_player():__tostring() .." has "..resource_grid.amount)
end

---Forces the grid of a given resource at the given absolute overmap tile to reinitialize. Defaults to player location if no abs_omt given
---@param resource_id string
---@param abs_omt tripoint
mod.debug.Force_grid_initialization = function(resource_id, abs_omt)
    local abs_omt = abs_omt or mod.debug.Abs_omt_at_player()
    abs_omt.z = 0
    mod.grid_functions.Initalize_resource_grid(mod.grid_functions.Get_resource_table_from_id(resource_id), abs_omt:__tostring())
end

mod.debug.Dump_player_grid = function(resource_id)
    local grid = mod.grid_functions.Get_grid(resource_id, gapi.get_avatar():get_pos_ms())
    gdebug.log_info(mod.debug.dump(grid))
end

mod.debug.Dump_resource_table_list = function()
    gdebug.log_info(mod.debug.dump(mod.resource_table_list))
end

mod.debug.Dump_resource_grids = function()
    gdebug.log_info(mod.debug.dump(game.mod_storage.omt_resources))
end

mod.debug.dump = function(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. mod.debug.dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end