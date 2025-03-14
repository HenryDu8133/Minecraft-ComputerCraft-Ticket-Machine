-- 初始化参数
local mon = peripheral.find("monitor") or error("Monitor not found")
mon.setTextScale(0.5)
local w, h = mon.getSize()

-- 获取扬声器外设
local speaker = peripheral.find("speaker") or error("Speaker not found")

-- 配置文件路径和红石信号面设置
local configPath = "ticket_config"
local coinInputSide = "right"
local normalTicketSide = "back"
local expressTicketSide = "left"
local configUpdateSide = "right"

-- 初始化默认值
local priceNormal = 10
local priceExpress = 15
local coinTimeout = 30
local stations = {}
local coins = 0  -- 添加 coins 变量
local lastCoinTime = os.epoch("local")  -- 添加 lastCoinTime 变量
local selected = {
    start = 1,
    dest = 1,
    type = 1
}
local currentPage = 1

-- 加载配置函数（移到最前面）
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

            -- 更新票价配置
            if config.prices then
                if type(config.prices.normal) == "table" and type(config.prices.express) == "table" then
                    -- 更新当前选择的车站之间的票价
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

-- 页面绘制函数（移到 drawButton 后面）
-- 修改 drawStationPage 函数
local function drawStationPage()
    -- 清屏并设置默认背景
    mon.setBackgroundColor(colors.black)
    mon.clear()

    -- 标题栏装饰
    mon.setBackgroundColor(colors.blue)
    mon.setTextColor(colors.yellow)
    mon.setCursorPos(1, 1)
    mon.write(string.rep("=", w))  -- 顶部装饰线
    mon.setCursorPos((w - 19) / 2, 1)
    mon.write("=== Ticket Machine ===")

    -- 起点站标题装饰
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.green)
    mon.setCursorPos(1, 4)
    mon.write(">> From: ")
    mon.write(string.rep("-", w - 8))  -- 标题装饰线

    -- 起点站按钮
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

    -- 计算终点站标题位置
    local toRow = row + 3

    -- 终点站标题装饰
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.blue)
    mon.setCursorPos(1, toRow)
    mon.write(">> To: ")
    mon.write(string.rep("-", w - 6))  -- 标题装饰线

    -- 终点站按钮
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

    -- Next 按钮区域装饰
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
        mon.write(string.rep("-", w))  -- 底部装饰线
        drawButton(w - 6, lastRow, "Next", colors.orange, colors.white)
        return lastRow
    end
    return nil
end

-- 修改 drawTrainTypePage 函数
local function drawTrainTypePage()
    mon.setBackgroundColor(colors.black)
    mon.clear()

    -- 标题栏装饰
    mon.setBackgroundColor(colors.blue)
    mon.setTextColor(colors.yellow)
    mon.setCursorPos(1, 1)
    mon.write(string.rep("=", w))
    mon.setCursorPos((w - 16) / 2, 1)
    mon.write("Select Train Type")

    -- 装饰线
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.white)
    mon.setCursorPos(1, 2)
    mon.write(string.rep("-", w))

    -- 普通车按钮
    drawButton((w - 12) / 2, 4, "Normal Train",
        selected.type == 1 and colors.green or colors.lightGray,
        selected.type == 1 and colors.white or colors.black)

    -- 快车按钮
    drawButton((w - 13) / 2, 6, "Express Train",
        selected.type == 2 and colors.blue or colors.lightGray,
        selected.type == 2 and colors.white or colors.black)

    -- 底部按钮（移除装饰线）
    mon.setTextColor(colors.orange)
    mon.setBackgroundColor(colors.black)
    mon.setCursorPos(w - 6, 8)
    mon.write("Next >")
end

-- 站点选择触摸处理函数（移到主循环前）
local function handleStationPageTouch(x, y)
    -- 计算起点站区域
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

    -- 计算终点站区域
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

    -- 选择起点站
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

    -- 选择终点站
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

    -- 在站点选择后更新票价
    if selected.start ~= selected.dest then
        loadConfig()  -- 重新加载配置以更新票价
    end

    -- Next 按钮检测
    local nextButtonRow = toLastRow + 2
    if y == nextButtonRow and x >= w - 6 and x <= w and selected.start ~= selected.dest then
        currentPage = 2
        drawTrainTypePage()
    end
end

-- 添加投币页面绘制函数（移到这里）
local function drawCoinPage()
    mon.setBackgroundColor(colors.black)
    mon.clear()

    -- 小票顶部装饰
    mon.setTextColor(colors.white)
    mon.setCursorPos(1, 1)
    mon.write(string.rep("=", w))
    mon.setCursorPos((w - 12) / 2, 1)
    mon.write("TRAIN TICKET")
    mon.setCursorPos(1, 2)
    mon.write(string.rep("-", w))

    -- 票据信息
    local currentTime = os.date("*t")
    mon.setCursorPos(2, 3)
    mon.write(string.format("Date: %04d-%02d-%02d", currentTime.year, currentTime.month, currentTime.day))
    mon.setCursorPos(2, 4)
    mon.write(string.format("Time: %02d:%02d", currentTime.hour, currentTime.min))
    mon.setCursorPos(1, 5)
    mon.write(string.rep("-", w))

    -- 修改投币页面中车种显示的颜色
    mon.setTextColor(colors.green)
    mon.setCursorPos(2, 6)
    mon.write("From: " .. stations[selected.start])
    mon.setTextColor(colors.blue)
    mon.setCursorPos(2, 7)
    mon.write("To  : " .. stations[selected.dest])
    mon.setTextColor(colors.yellow)  -- 修改：车种显示颜色改为黄色
    mon.setCursorPos(2, 8)
    mon.write("Type: " .. (selected.type == 1 and "Normal Train" or "Express Train"))
    mon.setCursorPos(1, 9)
    mon.write(string.rep("-", w))

    -- 价格信息
    local price = selected.type == 1 and priceNormal or priceExpress
    mon.setTextColor(colors.red)
    mon.setCursorPos(2, 10)
    mon.write(string.format("Price: %d coins", price))
    mon.setCursorPos(2, 11)
    mon.write(string.format("Paid : %d coins", coins))
    mon.setCursorPos(1, 12)
    mon.write(string.rep("-", w))

    -- 投币提示
    mon.setTextColor(colors.yellow)
    mon.setCursorPos(2, 13)
    mon.write("Please insert coins...")
    mon.setCursorPos(2, 14)
    mon.write(string.format("Remaining: %d coins", price - coins))
end

-- 检查配置更新函数
local function checkConfigUpdate()
    if redstone.getInput(configUpdateSide) then
        loadConfig()
        if currentPage == 1 then
            drawStationPage()
        end
        sleep(0.5)
    end
end

-- 初始化加载配置并绘制界面
loadConfig()
drawStationPage()

-- 主循环
while true do
    local event, side, x, y = os.pullEvent()
    
    if event == "monitor_touch" then
        if currentPage == 1 then
            handleStationPageTouch(x, y)
        elseif currentPage == 2 then
            -- 普通车按钮检测
            if y == 4 and x >= (w - 12) / 2 and x <= (w + 12) / 2 then
                selected.type = 1
                drawTrainTypePage()
            -- 快车按钮检测
            elseif y == 6 and x >= (w - 13) / 2 and x <= (w + 13) / 2 then
                selected.type = 2
                drawTrainTypePage()
            -- Next 按钮检测
            elseif y == 8 and x >= w - 6 and x <= w then
                currentPage = 3
                drawCoinPage()
            end
        elseif currentPage == 4 then
            -- 检查返回按钮
            if y == h-2 and x >= w-6 and x <= w then
                -- 重置状态
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
            -- 播放音符函数
            local function playNote(instrument, note, volume)
                speaker.playNote(instrument, volume or 1.0, note)
            end
            
            local function updateCoinDisplay()
                local price = selected.type == 1 and priceNormal or priceExpress
                mon.setTextColor(colors.red)
                mon.setCursorPos(2, 11)
                mon.write(string.format("Paid : %d coins", coins))
                mon.setTextColor(colors.yellow)
                mon.setCursorPos(2, 14)
                mon.write(string.format("Remaining: %d coins", price - coins))
            end
            -- 投币音效
            local function playCoinSound()
                playNote("bell", 1.5, 1.0)  -- 调整为更清脆的音色
                sleep(0.05)
            end
            
            -- 播放成功曲调
            local function playSuccessTune()
                local melody = {
                    -- 开场音
                    {instrument = "flute", note = 1.0, volume = 0.8},  -- 改用长笛开场
                    {instrument = "flute", note = 1.2, volume = 0.9},
                    {instrument = "flute", note = 1.5, volume = 1.0},
                    -- 上升主旋律
                    {instrument = "harp", note = 1.5, volume = 0.9},   -- 竖琴主旋律
                    {instrument = "harp", note = 1.7, volume = 1.0},
                    {instrument = "harp", note = 2.0, volume = 1.0},
                    -- 欢快结尾
                    {instrument = "bell", note = 1.7, volume = 1.0},   -- 铃声点缀
                    {instrument = "bell", note = 2.0, volume = 0.9},
                    {instrument = "xylophone", note = 1.5, volume = 0.8}  -- 木琴收尾
                }
                
                -- 演奏主旋律
                for i, note in ipairs(melody) do
                    if i <= 3 then
                        sleep(0.12)  -- 开场稍慢
                    elseif i <= 6 then
                        sleep(0.09)  -- 主旋律中速
                    else
                        sleep(0.07)  -- 结尾略快
                    end
                    playNote(note.instrument, note.note, note.volume)
                end
                
                -- 结尾和弦
                sleep(0.05)
                playNote("harp", 2.0, 0.9)    -- 竖琴和弦
                playNote("bell", 1.5, 0.8)    -- 铃声和弦
                sleep(0.03)
                playNote("flute", 1.7, 0.7)   -- 长笛收尾
            end

            playCoinSound()
            coins = coins + 1
            lastCoinTime = os.epoch("local")
            updateCoinDisplay()

            local price = selected.type == 1 and priceNormal or priceExpress
            if coins >= price then
                playSuccessTune()
                -- 输出对应类型的车票
                if selected.type == 1 then
                    redstone.setOutput(normalTicketSide, true)
                    sleep(0.5)
                    redstone.setOutput(normalTicketSide, false)
                else
                    redstone.setOutput(expressTicketSide, true)
                    sleep(0.5)
                    redstone.setOutput(expressTicketSide, false)
                end
                
                -- 添加完成界面绘制函数
                local function drawCompletePage()
                    mon.setBackgroundColor(colors.green)  -- 整体背景改为绿色
                    mon.clear()
                    
                    -- 顶部装饰
                    mon.setBackgroundColor(colors.lime)   -- 更亮的绿色标题栏
                    mon.setTextColor(colors.black)        -- 黑色文字更醒目
                    mon.setCursorPos(1, 1)
                    mon.write(string.rep("=", w))
                    mon.setCursorPos((w - 16) / 2, 1)
                    mon.write("Purchase Complete!")
                    
                    -- 票据信息
                    mon.setBackgroundColor(colors.green)
                    mon.setTextColor(colors.white)        -- 白色文字更清晰
                    mon.setCursorPos((w - 20) / 2, 4)
                    mon.write("Thank you for your purchase!")
                    
                    mon.setTextColor(colors.yellow)       -- 票据信息用黄色
                    mon.setCursorPos(2, 6)
                    mon.write("From: " .. stations[selected.start])
                    mon.setCursorPos(2, 7)
                    mon.write("To  : " .. stations[selected.dest])
                    mon.setCursorPos(2, 8)
                    mon.write("Type: " .. (selected.type == 1 and "Normal Train" or "Express Train"))
                    
                    -- 底部返回按钮
                    mon.setTextColor(colors.white)
                    mon.setCursorPos(2, h-2)
                    mon.write("Returning to main menu...")
                    mon.setBackgroundColor(colors.lime)   -- 按钮背景用亮绿色
                    mon.setTextColor(colors.black)        -- 按钮文字用黑色
                    mon.setCursorPos(w-6, h-2)
                    mon.write("Back >")
                end
                currentPage = 4
                drawCompletePage()
                timer = os.startTimer(5)  -- 5秒后自动返回
            end
            
            -- 等待红石信号消失
            while redstone.getInput(coinInputSide) do
                sleep(0.1)
            end
        end
    elseif event == "timer" and currentPage == 4 then
        if side == timer then
            -- 自动返回
            coins = 0
            lastCoinTime = os.epoch("local")
            selected.start = 1
            selected.dest = 1
            selected.type = 1
            currentPage = 1
            drawStationPage()
        end
    end

    -- 检查超时
    if currentPage == 3 and coins > 0 and os.epoch("local") - lastCoinTime > coinTimeout * 1000 then
        mon.setTextColor(colors.red)
        mon.setCursorPos(1, 10)
        mon.write("Timeout! Transaction cancelled")
        sleep(2)
        -- 重置状态
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

