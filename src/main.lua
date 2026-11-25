-- Number Park watchface (v0.3: animations)
-- Time + today's system step count + an "-ity" character that changes with steps.
-- DEVICE is injected by tools/build.py.
local lvgl = require("lvgl")
local dataman = require("dataman")

local W, H = DEVICE.width, DEVICE.height

-- Characters unlock as today's steps grow.
local TIERS = {
    { steps = 0,     name = "Primity",   img = "c1.png", color = "#4aa3ff" },
    { steps = 1000,  name = "Squarity",  img = "c2.png", color = "#52d36a" },
    { steps = 3000,  name = "Factority", img = "c3.png", color = "#ff9a3c" },
    { steps = 6000,  name = "Doublity",  img = "c4.png", color = "#b77bff" },
    { steps = 10000, name = "Googolity", img = "c5.png", color = "#ffd040" },
}

-- lvgl.TEXT_ALIGN.CENTER (= 2 in LVGL); lvgl.ALIGN.CENTER is a different enum.
local TEXT_CENTER = (lvgl.TEXT_ALIGN and lvgl.TEXT_ALIGN.CENTER) or 2

local fontCache = {}
local function font(size)
    if fontCache[size] then return fontCache[size] end
    for _, name in ipairs(DEVICE.fonts) do
        local ok, f = pcall(lvgl.Font, name, size)
        if ok and f then fontCache[size] = f; return f end
    end
    fontCache[size] = lvgl.BUILTIN_FONT.MONTSERRAT_14
    return fontCache[size]
end

local function label(parent, text, y, size, color)
    return parent:Label {
        text = text, w = W, x = 0, y = y,
        text_font = font(size), text_color = color or "#ffffff",
        text_align = TEXT_CENTER,
    }
end

local function box(parent, x, y, w, h, color, radius)
    local o = lvgl.Object(parent, {
        x = x, y = y, w = w, h = h, bg_color = color, bg_opa = lvgl.OPA(100),
        border_width = 0, pad_all = 0, radius = radius or 0,
    })
    o:clear_flag(lvgl.FLAG.SCROLLABLE)
    return o
end

local root = lvgl.Object(nil, {
    w = lvgl.HOR_RES(), h = lvgl.VER_RES(), bg_color = "#000000",
    bg_opa = lvgl.OPA(100), border_width = 0, pad_all = 0,
})
root:clear_flag(lvgl.FLAG.SCROLLABLE)
root:add_flag(lvgl.FLAG.EVENT_BUBBLE)

local L = DEVICE.layout
local timeLabel  = label(root, "--:--", L.timeY, L.timeSize)
local capLabel   = label(root, "今天走了", L.capY, L.capSize, "#9a9a9a")
local stepLabel  = label(root, "0", L.stepY, L.stepSize, "#ffd040")
local function imgPath(name) return SCRIPT_PATH .. name end
local ballSize = L.ballSize
local ball = lvgl.Image(root, { x = (W - ballSize) // 2, y = L.ballY, src = imgPath(TIERS[1].img) })
local nameLabel  = label(root, "Primity", L.nameY, L.nameSize, TIERS[1].color)
local barW = L.barW
local barX = (W - barW) // 2
box(root, barX, L.barY, barW, L.barH, "#333333", L.barH // 2)
local fill = box(root, barX, L.barY, 1, L.barH, TIERS[1].color, L.barH // 2)
local nextLabel  = label(root, "", L.nextY, L.nextSize, "#8a8a8a")

local hh, hl, mh, ml = 0, 0, 0, 0
local function showTime()
    timeLabel:set { text = string.format("%d%d:%d%d", hh, hl, mh, ml) }
end

-- Short feedback loop: a new character every STEP_PER_CHANGE steps, cycling through all five.
local STEP_PER_CHANGE = 300
local INFINITE = lvgl.ANIM_REPEAT_INFINITE or 0xFFFF

-- Big "变身！" banner over the character, hidden until a transformation.
local banner = label(root, "变身！", L.ballY + ballSize // 2 - 30, 44, "#ffffff")
banner:add_flag(lvgl.FLAG.HIDDEN)

-- Idle: the character floats up and down.
local function startBob()
    pcall(function()
        ball:Anim {
            run = true, start_value = L.ballY - 6, end_value = L.ballY + 6,
            duration = 1200, playback_time = 1200, repeat_count = INFINITE,
            path = "ease_in_out",
            exec_cb = function(obj, v) obj:set { y = v } end,
        }
    end)
end

-- Transformation: the new character pops in from nothing while spinning, banner flashes.
local bannerTimer
local function playTransform(times)
    pcall(function()
        ball:Anim {
            run = true, start_value = 0, end_value = 256, duration = 700,
            repeat_count = 1, path = "overshoot",
            exec_cb = function(obj, v) obj:set { zoom = math.max(1, v) } end,
        }
        ball:Anim {
            run = true, start_value = 0, end_value = 3600, duration = 700,
            repeat_count = 1, path = "ease_out",
            exec_cb = function(obj, v) obj:set { angle = v % 3600 } end,
        }
    end)
    banner:set { text = times > 1 and ("变身 " .. times .. " 次！") or "变身！" }
    banner:clear_flag(lvgl.FLAG.HIDDEN)
    pcall(function()
        banner:Anim {
            run = true, start_value = 0, end_value = 255, duration = 300,
            playback_time = 300, playback_delay = 1200, repeat_count = 1,
            path = "ease_out",
            exec_cb = function(obj, v) obj:set { text_opa = v } end,
        }
    end)
    if bannerTimer then pcall(function() bannerTimer:delete() end) end
    bannerTimer = lvgl.Timer {
        period = 2200, repeat_count = 1,
        cb = function() banner:add_flag(lvgl.FLAG.HIDDEN) end,
    }
end

local screenOn = true
local seenN = nil      -- last transformation count the viewer actually saw
local curN = 0

local function showSteps(steps)
    stepLabel:set { text = tostring(steps) }
    local n = steps // STEP_PER_CHANGE
    curN = n
    local cur = TIERS[n % #TIERS + 1]
    ball:set { src = imgPath(cur.img) }
    nameLabel:set { text = cur.name, text_color = cur.color }
    local done = steps % STEP_PER_CHANGE
    fill:set { bg_color = cur.color, w = math.max(1, barW * done // STEP_PER_CHANGE) }
    nextLabel:set { text = "再走 " .. (STEP_PER_CHANGE - done) .. " 步变身" }
    if seenN == nil or n < seenN then seenN = n end   -- first load, or a new day
    if screenOn and n > seenN then
        playTransform(n - seenN)
        seenN = n
    end
end

-- When the screen comes back on, celebrate every transformation that happened meanwhile.
function ScreenStateChangedCB(previous, current, reason)
    screenOn = (current == "ON")
    if screenOn and previous ~= "ON" then
        startBob()
        if seenN and curN > seenN then
            playTransform(curN - seenN)
            seenN = curN
        end
    end
end

local function sub(key, obj, cb)
    pcall(dataman.subscribe, key, obj, function(o, encoded)
        if type(encoded) ~= "number" or encoded ~= encoded or encoded < 0 or encoded == 2147483647 then return end
        cb(encoded // 256)
    end)
end

sub("timeHourHigh",   timeLabel, function(v) hh = v; showTime() end)
sub("timeHourLow",    timeLabel, function(v) hl = v; showTime() end)
sub("timeMinuteHigh", timeLabel, function(v) mh = v; showTime() end)
sub("timeMinuteLow",  timeLabel, function(v) ml = v; showTime() end)
sub("healthStepCount", stepLabel, function(v) if v <= 1000000 then showSteps(v) end end)

showSteps(0)
startBob()
