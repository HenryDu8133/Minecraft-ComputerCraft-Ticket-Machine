-- Initialize parameters
local mon = peripheral.find("monitor") or error("Monitor not found")
mon.setTextScale(0.5)
local w, h = mon.getSize()

-- Get speaker peripheral
local speaker = peripheral.find("speaker") or error("Speaker not found")

-- Config file path and redstone signal side settings
local configPath = "ticket_config"
local coinInputSide = "right"
local normalTicketSide = "back"
local expressTicketSide = "left"
local configUpdateSide = "right"

-- Initialize default values
local priceNormal = 10
local priceExpress = 15
local coinTimeout = 30
local stations = {}
local coins = 0  -- Add coins variable
local lastCoinTime = os.epoch("local")  -- Add lastCoinTime variable
local selected = {
    start = 1,
    dest = 1,
    type = 1
}
local currentPage = 1

-- Load configuration function (moved to the front)
local function loadConfig()
    if fs.exists(configPath) then
        local file = fs.open(configPath, "r")
        local data = file.readAll()
        file.close()

        local config = textutils.unserialize(data)
        if config then
            if config.stations and type(config.stations) == "table" then
                stations = config.stations
            end

            -- Update price configuration
            if config.prices then
                if type(config.prices.normal) == "table" and type(config.prices.express) == "table" then
                    -- Update current selected station price
                    if selected.start ~= selected.dest then
                        if config.prices.normal[selected.start] and config.prices.normal[selected.start][selected.dest] then
                            priceNormal = config.prices.normal[selected.start][selected.dest]
                        end
                        if config.prices.express[selected.start] and config.prices.express[selected.start][selected.dest] then
                            priceExpress = config.prices.express[selected.start][selected.dest]
                        end
                    end
                end
            end
        end
    end
end

local function drawButton(x, y, text, bgColor, fgColor)
    mon.setBackgroundColor(bgColor)
    mon.setTextColor(fgColor)
    mon.setCursorPos(x, y)
    mon.write(" " .. text .. " ")
end

-- Page drawing function (moved to drawButton after)
-- Modify drawStationPage function
local function drawStationPage()
    -- Clear screen and set default background
    mon.setBackgroundColor(colors.black)
    mon.clear()

    -- Title bar decoration
    mon.setBackgroundColor(colors.blue)
    mon.setTextColor(colors.yellow)
    mon.setCursorPos(1, 1)
    mon.write(string.rep("=", w))  -- Top decoration line
    mon.setCursorPos((w - 19) / 2, 1)
    mon.write("=== Ticket Machine ===")

    -- Departure station title decoration
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.green)
    mon.setCursorPos(1, 4)
    mon.write(">> From: ")
    mon.write(string.rep("-", w - 8))  -- Title decoration line

    -- Departure station button
    local row = 5
    local col = 7
    for i, station in ipairs(stations) do
        if col + #station + 2 > w then
            row = row + 2
            col = 7
        end
        drawButton(col, row, station,
            selected.start == i and colors.green or colors.lightGray,
            selected.start == i and colors.white or colors.black)
        col = col + #station + 3
    end

    -- Calculate destination station title position
    local toRow = row + 3

    -- Destination station title decoration
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.blue)
    mon.setCursorPos(1, toRow)
    mon.write(">> To: ")
    mon.write(string.rep("-", w - 6))  -- Title decoration line

    -- Destination station button
    row = toRow + 1
    col = 7
    for i, station in ipairs(stations) do
        if col + #station + 2 > w then
            row = row + 2
            col = 7
        end
        drawButton(col, row, station,
            selected.dest == i and colors.blue or colors.lightGray,
            selected.dest == i and colors.white or colors.black)
        col = col + #station + 3
    end

    -- Next button area decoration
    local lastRow = row + 2
    if selected.start == selected.dest then
        mon.setTextColor(colors.red)
        mon.setBackgroundColor(colors.black)
        mon.setCursorPos(1, h)
        mon.write(string.rep("!", 3) .. " Please select different stations " .. string.rep("!", 3))
    else
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.orange)
        mon.setCursorPos(1, lastRow)
        mon.write(string.rep("-", w))  -- Bottom decoration line
        drawButton(w - 6, lastRow, "Next", colors.orange, colors.white)
        return lastRow
    end
    return nil
end

-- Modify drawTrainTypePage function
local function drawTrainTypePage()
    mon.setBackgroundColor(colors.black)
    mon.clear()

    -- Title bar decoration
    mon.setBackgroundColor(colors.blue)
    mon.setTextColor(colors.yellow)
    mon.setCursorPos(1, 1)
    mon.write(string.rep("=", w))
    mon.setCursorPos((w - 16) / 2, 1)
    mon.write("Select Train Type")

    -- Decoration line
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.setCursorPos(1, 2)
    mon.write(string.rep("-", w))

    -- Normal train button
    drawButton((w - 12) / 2, 4, "Normal Train",
        selected.type == 1 and colors.green or colors.lightGray,
        selected.type == 1 and colors.white or colors.black)

    -- Express train button
    drawButton((w - 13) / 2, 6, "Express Train",
        selected.type == 2 and colors.blue or colors.lightGray,
        selected.type == 2 and colors.white or colors.black)

    -- Bottom button (removed decoration line)
    mon.setTextColor(colors.orange)
    mon.setBackgroundColor(colors.black)
    mon.setCursorPos(w - 6, 8)
    mon.write("Next >")
end

-- Station selection touch handling function (moved before main loop)
local function handleStationPageTouch(x, y)
    -- Calculate departure station area
    local fromRow = 5
    local fromLastRow = fromRow
    local col = 7
    for i, station in ipairs(stations) do
        if col + #station + 2 > w then
            fromLastRow = fromLastRow + 2
            col = 7
        end
        col = col + #station + 3
    end

    -- Calculate destination station area
    local toStartRow = fromLastRow + 4
    local toLastRow = toStartRow
    col = 7
    for i, station in ipairs(stations) do
        if col + #station + 2 > w then
            toLastRow = toLastRow + 2
            col = 7
        end
        col = col + #station + 3
    end

    -- Select departure station
    local row = 5
    col = 7
    for i, station in ipairs(stations) do
        if col + #station + 2 > w then
            row = row + 2
            col = 7
        end
        if y == row and x >= col and x < col + #station + 3 then
            selected.start = i
            drawStationPage()
            break
        end
        col = col + #station + 3
    end

    -- Select destination station
    row = toStartRow
    col = 7
    for i, station in ipairs(stations) do
        if col + #station + 2 > w then
            row = row + 2
            col = 7
        end
        if y == row and x >= col and x < col + #station + 3 then
            selected.dest = i
            drawStationPage()
            break
        end
        col = col + #station + 3
    end

    -- Update ticket price after station selection
    if selected.start ~= selected.dest then
        loadConfig()  -- 重新加载配置以更新票价
    end

    -- Next button detection
    local nextButtonRow = toLastRow + 2
    if y == nextButtonRow and x >= w - 6 and x <= w and selected.start ~= selected.dest then
        currentPage = 2
        drawTrainTypePage()
    end
end

-- Add coin page drawing function (moved here)
local function drawCoinPage()
    mon.setBackgroundColor(colors.black)
    mon.clear()

    -- Small ticket top decoration
    mon.setTextColor(colors.white)
    mon.setCursorPos(1, 1)
    mon.write(string.rep("=", w))
    mon.setCursorPos((w - 12) / 2, 1)
    mon.write("TRAIN TICKET")
    mon.setCursorPos(1, 2)
    mon.write(string.rep("-", w))

    -- Receipt information
    local currentTime = os.date("*t")
    mon.setCursorPos(2, 3)
    mon.write(string.format("Date: %04d-%02d-%02d", currentTime.year, currentTime.month, currentTime.day))
    mon.setCursorPos(2, 4)
    mon.write(string.format("Time: %02d:%02d", currentTime.hour, currentTime.min))
    mon.setCursorPos(1, 5)
    mon.write(string.rep("-", w))

    -- Modify train type display color in coin page
    mon.setTextColor(colors.green)
    mon.setCursorPos(2, 6)
    mon.write("From: " .. stations[selected.start])
    mon.setTextColor(colors.blue)
    mon.setCursorPos(2, 7)
    mon.write("To  : " .. stations[selected.dest])
    mon.setTextColor(colors.yellow)  -- Modified: Changed train type display color to yellow
    mon.setCursorPos(2, 8)
    mon.write("Type: " .. (selected.type == 1 and "Normal Train" or "Express Train"))
    mon.setCursorPos(1, 9)
    mon.write(string.rep("-", w))

    -- Price information
    local price = selected.type == 1 and priceNormal or priceExpress
    mon.setTextColor(colors.red)
    mon.setCursorPos(2, 10)
    mon.write(string.format("Price: %d coins", price))
    mon.setCursorPos(2, 11)
    mon.write(string.format("Paid : %d coins", coins))
    mon.setCursorPos(1, 12)
    mon.write(string.rep("-", w))

    -- Coin insert prompt
    mon.setTextColor(colors.yellow)
    mon.setCursorPos(2, 13)
    mon.write("Please insert coins...")
    mon.setCursorPos(2, 14)
    mon.write(string.format("Remaining: %d coins", price - coins))
end

-- Check configuration update function
local function checkConfigUpdate()
    if redstone.getInput(configUpdateSide) then
        loadConfig()
        if currentPage == 1 then
            drawStationPage()
        end
        sleep(0.5)
    end
end

-- Initialize configuration loading and draw interface
loadConfig()
drawStationPage()

-- Main loop
while true do
    local event, side, x, y = os.pullEvent()
    
    if event == "monitor_touch" then
        if currentPage == 1 then
            handleStationPageTouch(x, y)
        elseif currentPage == 2 then
            -- Normal train button detection
            if y == 4 and x >= (w - 12) / 2 and x <= (w + 12) / 2 then
                selected.type = 1
                drawTrainTypePage()
            -- Express train button detection
            elseif y == 6 and x >= (w - 13) / 2 and x <= (w + 13) / 2 then
                selected.type = 2
                drawTrainTypePage()
            -- Next button detection
            elseif y == 8 and x >= w - 6 and x <= w then
                currentPage = 3
                drawCoinPage()
            end
        elseif currentPage == 4 then
            -- Check return button
            if y == h-2 and x >= w-6 and x <= w then
                -- Reset state
                coins = 0
                lastCoinTime = os.epoch("local")
                selected.start = 1
                selected.dest = 1
                selected.type = 1
                currentPage = 1
                drawStationPage()
            end
        end
    elseif event == "redstone" and currentPage == 3 then
        if redstone.getInput(coinInputSide) then
            -- Play note function
            local function playNote(instrument, note, volume)
                speaker.playNote(instrument, volume or 1.0, note)
            end
            
            -- Play success melody
            local function playSuccessTune()
                local melody = {
                    -- Opening notes
                    {instrument = "bit", note = 1.0, volume = 0.8},
                    {instrument = "bit", note = 1.2, volume = 0.9},
                    {instrument = "bit", note = 1.5, volume = 1.0},
                    -- Rising main melody
                    {instrument = "harp", note = 1.7, volume = 0.9},
                    {instrument = "harp", note = 2.0, volume = 1.0},
                    {instrument = "bell", note = 2.2, volume = 1.0},
                    {instrument = "bell", note = 2.5, volume = 1.0},
                    -- Cheerful counter melody
                    {instrument = "bit", note = 2.0, volume = 0.9},
                    {instrument = "bit", note = 2.2, volume = 1.0},
                    {instrument = "bit", note = 2.5, volume = 1.0},
                    {instrument = "bit", note = 2.2, volume = 0.9},
                    -- Elegant transition
                    {instrument = "chime", note = 2.0, volume = 0.9},
                    {instrument = "chime", note = 2.2, volume = 1.0},
                    {instrument = "chime", note = 2.5, volume = 1.0},
                    -- Ending section
                    {instrument = "bell", note = 2.2, volume = 0.9},
                    {instrument = "bell", note = 2.5, volume = 1.0},
                    {instrument = "bell", note = 2.0, volume = 0.8}
                }
                
                -- Play main melody
                for i, note in ipairs(melody) do
                    if i <= 3 then
                        sleep(0.12)  -- Slower opening
                    elseif i <= 7 then
                        sleep(0.08)  -- Medium tempo main melody
                    elseif i <= 11 then
                        sleep(0.06)  -- Faster counter melody
                    else
                        sleep(0.08)  -- Moderate ending
                    end
                    playNote(note.instrument, note.note, note.volume)
                end
                
                -- Final triple chord
                sleep(0.04)
                playNote("bell", 2.5, 0.9)
                playNote("chime", 2.0, 0.8)
                playNote("harp", 1.5, 0.7)
                sleep(0.02)
                playNote("bit", 3.0, 0.6)  -- Final accent note
            end

            -- Coin sound effect
            local function playCoinSound()
                playNote("bell", 1.5, 1.0)  -- Adjusted for clearer sound
                sleep(0.05)
            end

            -- Update coin display
            local function updateCoinDisplay()
                local price = selected.type == 1 and priceNormal or priceExpress
                mon.setTextColor(colors.red)
                mon.setCursorPos(2, 11)
                mon.write(string.format("Paid : %d coins", coins))
                mon.setTextColor(colors.yellow)
                mon.setCursorPos(2, 14)
                mon.write(string.format("Remaining: %d coins", price - coins))
            end

            playCoinSound()
            coins = coins + 1
            lastCoinTime = os.epoch("local")
            updateCoinDisplay()

            local price = selected.type == 1 and priceNormal or priceExpress
            if coins >= price then
                playSuccessTune()
                -- Output corresponding ticket type
                if selected.type == 1 then
                    redstone.setOutput(normalTicketSide, true)
                    sleep(0.5)
                    redstone.setOutput(normalTicketSide, false)
                else
                    redstone.setOutput(expressTicketSide, true)
                    sleep(0.5)
                    redstone.setOutput(expressTicketSide, false)
                end
                
                -- Draw completion page
                local function drawCompletePage()
                    mon.setBackgroundColor(colors.green)  -- Set overall background to green
                    mon.clear()
                    
                    -- Top decoration
                    mon.setBackgroundColor(colors.lime)   -- Brighter green title bar
                    mon.setTextColor(colors.black)        -- Black text for better visibility
                    mon.setCursorPos(1, 1)
                    mon.write(string.rep("=", w))
                    mon.setCursorPos((w - 16) / 2, 1)
                    mon.write("Purchase Complete!")
                    
                    -- Ticket information
                    mon.setBackgroundColor(colors.green)
                    mon.setTextColor(colors.white)        -- White text for clarity
                    mon.setCursorPos((w - 20) / 2, 4)
                    mon.write("Thank you for your purchase!")
                    
                    mon.setTextColor(colors.yellow)       -- Yellow for ticket info
                    mon.setCursorPos(2, 6)
                    mon.write("From: " .. stations[selected.start])
                    mon.setCursorPos(2, 7)
                    mon.write("To  : " .. stations[selected.dest])
                    mon.setCursorPos(2, 8)
                    mon.write("Type: " .. (selected.type == 1 and "Normal Train" or "Express Train"))
                    
                    -- Bottom return button
                    mon.setTextColor(colors.white)
                    mon.setCursorPos(2, h-2)
                    mon.write("Returning to main menu...")
                    mon.setBackgroundColor(colors.lime)   -- Bright green button background
                    mon.setTextColor(colors.black)        -- Black text for button
                    mon.setCursorPos(w-6, h-2)
                    mon.write("Back >")
                end
                currentPage = 4
                drawCompletePage()
                timer = os.startTimer(5)  -- Return after 5 seconds
            end
            
            -- Wait for redstone signal to disappear
            while redstone.getInput(coinInputSide) do
                sleep(0.1)
            end
        end
    elseif event == "timer" and currentPage == 4 then
        if side == timer then
            -- Auto return
            coins = 0
            lastCoinTime = os.epoch("local")
            selected.start = 1
            selected.dest = 1
            selected.type = 1
            currentPage = 1
            drawStationPage()
        end
    end

    -- Check timeout
    if currentPage == 3 and coins > 0 and os.epoch("local") - lastCoinTime > coinTimeout * 1000 then
        mon.setTextColor(colors.red)
        mon.setCursorPos(1, 10)
        mon.write("Timeout! Transaction cancelled")
        sleep(2)
        -- Reset state
        coins = 0
        lastCoinTime = os.epoch("local")
        selected.start = 1
        selected.dest = 1
        selected.type = 1
        currentPage = 1
        drawStationPage()
    end
    checkConfigUpdate()
    sleep(0.1)
end

