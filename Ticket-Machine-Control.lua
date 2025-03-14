
-- Configuration file path
local configPath = "ticket_config"

-- Initial configuration
local config = {
    stations = {"Station A", "Station B", "Station C", "Station D", "Station E", "Station F", "Station G", "Station H"},
    prices = {
        normal = {},  -- Regular ticket price list
        express = {}  -- Express ticket price list
    }
}

-- The currently selected site
local selectedStation = 1

-- Save configuration
local function saveConfig()
    local file = fs.open(configPath, "w")
    file.write(textutils.serialize(config))
    file.close()
    
    -- Create an update tag file
    local updateFile = fs.open(configPath .. "_update", "w")
    updateFile.write("update")
    updateFile.close()
    
    print("Configuration saved and ticket machine updated")
end

-- Show site list
local function showStations()
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.yellow)
    print("=== Station List ===")
    term.setTextColor(colors.lime)
    for i, station in ipairs(config.stations) do
        print(i .. ". " .. station)
    end
    term.setTextColor(colors.white)
    print("\nPress Enter to return...")
    read()
end

-- Add a new Site
local function addStation()
    term.clear()
    term.setCursorPos(1,1)
    print("=== Add New Station ===")
    print("Enter station name:")
    local input = read()
    if input and #input > 0 then
        table.insert(config.stations, input)
        -- Initializes the price list for the new site
        local idx = #config.stations
        config.prices.normal[idx] = {}
        config.prices.express[idx] = {}
        for i = 1, idx-1 do
            config.prices.normal[idx][i] = 10
            config.prices.express[idx][i] = 15
            config.prices.normal[i][idx] = 10
            config.prices.express[i][idx] = 15
        end
        saveConfig()
        print("Station added successfully!")
    end
    sleep(1)
end

-- Delete site
local function deleteStation()
    term.clear()
    term.setCursorPos(1,1)
    print("=== Delete Station ===")
    for i, station in ipairs(config.stations) do
        print(i .. ". " .. station)
    end
    print("\nEnter station number to delete:")
    local input = tonumber(read())
    if input and input >= 1 and input <= #config.stations then
        table.remove(config.stations, input)
        -- 更新价格表
        table.remove(config.prices.normal, input)
        table.remove(config.prices.express, input)
        for i = 1, #config.stations do
            table.remove(config.prices.normal[i], input)
            table.remove(config.prices.express[i], input)
        end
        saveConfig()
        print("Station deleted successfully!")
    else
        print("Invalid station number!")
    end
    sleep(1)
end

-- Managed fare
local function managePrices()
    while true do
        term.clear()
        term.setCursorPos(1,1)
        print("=== Price Management ===")
        print("Select departure station:")
        for i, station in ipairs(config.stations) do
            print(i .. ". " .. station)
        end
        print("\nEnter station number (0 to return):")
        local from = tonumber(read())
        if not from or from == 0 then return end
        if from >= 1 and from <= #config.stations then
            while true do
                term.clear()
                print("Prices from " .. config.stations[from] .. ":")
                for i, station in ipairs(config.stations) do
                    if i ~= from then
                        print(string.format("%d. To %s (Normal: %d, Express: %d)",
                            i, station,
                            config.prices.normal[from][i] or 10,
                            config.prices.express[from][i] or 15))
                    end
                end
                print("\nSelect destination station number (0 to return):")
                local to = tonumber(read())
                if not to or to == 0 then break end
                if to >= 1 and to <= #config.stations and to ~= from then
                    print("Enter normal ticket price:")
                    local normal = tonumber(read())
                    print("Enter express ticket price:")
                    local express = tonumber(read())
                    if normal and express then
                        config.prices.normal[from][to] = normal
                        config.prices.express[from][to] = express
                        saveConfig()
                        print("Prices updated successfully!")
                        sleep(1)
                    end
                end
            end
        end
    end
end

-- Show the main menu
local function showMainMenu()
    term.clear()
    term.setCursorPos(1,1)
    term.setTextColor(colors.yellow)
    print("=== Ticket Machine Management System ===")
    term.setTextColor(colors.white)
    print("1. View All Stations")
    print("2. Add New Station")
    print("3. Delete Station")
    print("4. Manage Prices")
    term.setTextColor(colors.lime)
    print("5. View Price Table")  -- 新增选项
    term.setTextColor(colors.red)
    print("6. Exit")
    term.setTextColor(colors.white)
    print("\nPlease enter your choice (1-6):")
end

-- Added the ability to display ticket tables
local function showPriceTable()
    while true do
        term.clear()
        term.setCursorPos(1,1)
        term.setTextColor(colors.yellow)
        print("=== Price Table ===")
        term.setTextColor(colors.white)
        print("\nSelect ticket type:")
        term.setTextColor(colors.lime)
        print("1. Normal Train")
        term.setTextColor(colors.lightBlue)
        print("2. Express Train")
        term.setTextColor(colors.red)
        print("0. Return to Main Menu")
        term.setTextColor(colors.white)
        print("\nEnter your choice:")
        
        local choice = tonumber(read())
        if not choice or choice == 0 then return end
        
        if choice == 1 or choice == 2 then
            term.clear()
            term.setCursorPos(1,1)
            term.setTextColor(colors.yellow)
            print(string.format("=== %s Price Table ===", choice == 1 and "Normal Train" or "Express Train"))
            term.setTextColor(colors.white)
            

            local priceTable = choice == 1 and config.prices.normal or config.prices.express
            write("From\\To |")
            for i, station in ipairs(config.stations) do
                write(string.format(" %-10s|", station:sub(1,10)))
            end
            print()
            

            local line = string.rep("-", 10 * (#config.stations + 1))
            print(line)
            

            for i, fromStation in ipairs(config.stations) do
                term.setTextColor(colors.lime)
                write(string.format("%-8s |", fromStation:sub(1,8)))
                term.setTextColor(colors.white)
                for j, toStation in ipairs(config.stations) do
                    if i == j then
                        term.setTextColor(colors.gray)
                        write(string.format(" %-10s|", "---"))
                    else
                        term.setTextColor(colors.white)
                        write(string.format(" %-10d|", priceTable[i][j] or 0))
                    end
                end
                print()
            end
            
            print("\nPress Enter to continue...")
            read()
        end
    end
end


local function loadConfig()
    if fs.exists(configPath) then
        local file = fs.open(configPath, "r")
        config = textutils.unserialize(file.readAll())
        file.close()
    else

        for i = 1, #config.stations do
            config.prices.normal[i] = {}
            config.prices.express[i] = {}
            for j = 1, #config.stations do
                if i ~= j then
                    config.prices.normal[i][j] = 10  -- 默认普通票价
                    config.prices.express[i][j] = 15 -- 默认快车票价
                end
            end
        end
        saveConfig()
    end
end


loadConfig()
while true do
    showMainMenu()
    local choice = tonumber(read())
    if choice == 1 then
        showStations()
    elseif choice == 2 then
        addStation()
    elseif choice == 3 then
        deleteStation()
    elseif choice == 4 then
        managePrices()
    elseif choice == 5 then
        showPriceTable()
    elseif choice == 6 then
        term.setTextColor(colors.red)
        print("Exiting...")
        term.setTextColor(colors.white)
        break
    end
end
