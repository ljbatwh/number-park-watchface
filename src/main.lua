-- Number Park watchface (test build v0.1)
-- Time + today's system step count + an "-ity" character that changes with steps.
-- DEVICE is injected by tools/build.py.
local lvgl = require("lvgl")
local dataman = require("dataman")

local W, H = DEVICE.width, DEVICE.height

-- Characters unlock as today's steps grow.
local TIERS = {
    { steps = 0,     name = "Primity",   sym = "P",   color = "#4aa3ff" },
    { steps = 1000,  name = "Squarity",  sym = "x^2", color = "#52d36a" },
    { steps = 3000,  name = "Factority", sym = "n!",  color = "#ff9a3c" },
    { steps = 6000,  name = "Doublity",  sym = "2^n", color = "#b77bff" },
    { steps = 10000, name = "Googolity", sym = "G",   color = "#ffd040" },
}

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
        text_align = lvgl.ALIGN.CENTER,
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
local ballSize = L.ballSize
local ball = box(root, (W - ballSize) // 2, L.ballY, ballSize, ballSize, TIERS[1].color, ballSize // 2)
local symLabel = ball:Label {
    text = "P", text_font = font(L.symSize), text_color = "#000000", align = lvgl.ALIGN.CENTER,
}
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

local function showSteps(steps)
    stepLabel:set { text = tostring(steps) }
    local idx = 1
    for i, t in ipairs(TIERS) do if steps >= t.steps then idx = i end end
    local cur, nxt = TIERS[idx], TIERS[idx + 1]
    ball:set { bg_color = cur.color }
    symLabel:set { text = cur.sym }
    nameLabel:set { text = cur.name, text_color = cur.color }
    fill:set { bg_color = cur.color }
    if nxt then
        local span = nxt.steps - cur.steps
        local done = steps - cur.steps
        fill:set { w = math.max(1, barW * done // span) }
        nextLabel:set { text = "再走 " .. (nxt.steps - steps) .. " 步变身" }
    else
        fill:set { w = barW }
        nextLabel:set { text = "全部变身啦！" }
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
