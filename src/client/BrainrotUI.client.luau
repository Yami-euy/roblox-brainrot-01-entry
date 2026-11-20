-- PLAZA DEL DELIRIO — DICE + BASE + REBIRTH (REBUILD v7) — BrainrotUI
-- (StarterPlayerScripts). The Plaza UI (Aura + Dollar counters, event
-- banner, 6-tab Index, Luck shop, click-to-farm, announcements) with the
-- v7 rework, built from Yami's playtest feedback on v6:
--  * The old 15-second speed-burst button is gone entirely (Yami: "gaperlu").
--  * NO in-game collection panel — brainrots live in the Roblox Backpack
--    as Tools ("Name • RARITY", hotbar 1, 2, 3...). The Index stays.
--  * Dice panel rows say "Dice" (never "Die") and the "Inside:" line is
--    left-aligned + truncated, so it can never clip to "de:" again (v6).
--  * Panels are top-anchored (y = 170) so they never cover the HUD top
--    bar; Index/Luck buttons moved to the bottom-right so they never
--    collide with the top bar.
--  * HUD income line shows the Friend buff (👥 Friends +X%) and the
--    event banner names the 60-second buff.
--  * v7.2 TOP-3 PRESENTATION (no gameplay change): white-pill feature
--    strip under the top bar ("37 BRAINROTS · 8 DICE · 10 BASES ·
--    REBIRTH") + a big event banner that replaces the small weather bar
--    while a buff event runs (name + multiplier + live seconds).
--  * v7.3 STEAL & DEFEND: hold E to steal from an enemy base, L / the
--    LOCK button locks your own base for 30s (60s cooldown).
--  * v7.4 INVENTORY + PLAYFUL FONTS: a 🎒 INVENTORY panel lists every
--    brainrot you rolled (copies, Aura/s, value) with a HELD/STORED
--    toggle per name — HELD puts its Tools in the Backpack hotbar,
--    STORED keeps it in the inventory only. Titles and row names use
--    FredokaOne everywhere; the v6 overflow lesson is applied across
--    the whole UI (see the label() helper: every label truncates at
--    its edge instead of spilling past its background).
-- Brainrots live in the player's personal base (2x models, 10 slots, 4
-- open at Rebirth 0) and pay passive Aura.
--  * v7.1 HARDENING: ScreenGui + red "SERVER TIDAK MERESPONS" label are
--    built before any wait; every Remotes/leaderstats wait has a 10s
--    timeout that SHOWS the label instead of hanging silently.
-- Brainrots live in the player's personal base (2x models, 10 slots, 4
-- open at Rebirth 0) and pay passive Aura.
-- Visual style is the v4.1 upgrade everywhere: FredokaOne display titles,
-- GothamBlack numbers, UIGradients and UIStrokes. No external assets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- v7.1 HARDENING (Yami 2026-11-19 12:51 WIB: world built, UI total zero —
-- the client hung silently in WaitForChild): the ScreenGui + a big red
-- "SERVER TIDAK MERESPONS" label are built FIRST, before any wait that
-- could hang, so the player always sees SOMETHING. Every later wait goes
-- through waitChild: after 10s it SHOWS the label (and reports to the
-- server) instead of hanging invisibly forever.
local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

local serverErrorLabel = Instance.new("TextLabel")
serverErrorLabel.Name = "ServerError"
serverErrorLabel.Size = UDim2.new(0, 560, 0, 110)
serverErrorLabel.Position = UDim2.new(0.5, -280, 0.5, -55)
serverErrorLabel.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
serverErrorLabel.BackgroundTransparency = 0.2
serverErrorLabel.BorderSizePixel = 0
serverErrorLabel.Font = Enum.Font.GothamBlack
serverErrorLabel.TextSize = 22
serverErrorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
serverErrorLabel.TextWrapped = true
serverErrorLabel.Text = "⚠️ SERVER TIDAK MERESPONS\nTunggu sebentar atau rejoin (tutup lalu Play lagi)."
serverErrorLabel.Visible = false
serverErrorLabel.Parent = gui

-- waitChild: like WaitForChild, but after 10s it makes the failure VISIBLE
-- (red label + server report) and keeps waiting instead of hanging silently.
local function waitChild(parent, name)
	local child = parent:WaitForChild(name, 10)
	if not child then
		serverErrorLabel.Visible = true
		warn("[Plaza] Client waited 10s for " .. parent.Name .. "." .. name .. " — server may be down; still waiting.")
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local ce = remotes and remotes:FindFirstChild("ClientError")
		if ce then
			pcall(function()
				ce:FireServer("wait:" .. parent.Name .. "." .. name)
			end)
		end
		child = parent:WaitForChild(name)
	end
	return child
end

local DB = require(waitChild(ReplicatedStorage, "BrainrotDatabase"))
local Remotes = waitChild(ReplicatedStorage, "Remotes")
local RollDie = waitChild(Remotes, "RollDie")
local DoRebirth = waitChild(Remotes, "DoRebirth")
local LockBase = waitChild(Remotes, "LockBase")
local SetHeld = waitChild(Remotes, "SetHeld") -- v7.4: inventory hold toggle
local GetState = waitChild(Remotes, "GetState")
local ClickAura = waitChild(Remotes, "ClickAura")
local ClientFX = waitChild(Remotes, "ClientFX")
local BuyLuck = waitChild(Remotes, "BuyLuck")
local ShopOpen = waitChild(Remotes, "ShopOpen")

local leaderstats = waitChild(player, "leaderstats")
local auraValue = waitChild(leaderstats, "Aura")
local dollarValue = waitChild(leaderstats, "Dollar")
serverErrorLabel.Visible = false

-- Mirror of the server's income tables (WorldAndSystems): the client needs
-- them to show "+X Aura/s" without a server round-trip per slot.
local AURA_PER_SEC_BY_RARITY = {
	Common = 5, Uncommon = 20, Rare = 75, Epic = 250,
	Legendary = 1000, Mythic = 5000, Secret = 25000, Godly = 100000,
}
-- v7.5: no per-character overrides — every brainrot pays its rarity rate.
local function auraPerSec(name)
	local ch = DB.GetCharacter(name)
	if ch then
		return AURA_PER_SEC_BY_RARITY[ch.Rarity] or 5
	end
	return 5
end

-- v7.4 INVENTORY: a name is HELD unless the server says it is stored
-- (state.Unheld[name] == true). Held names have Tools in the Backpack;
-- stored names live in the inventory panel only.
local function isHeld(name)
	return not (state.Unheld and state.Unheld[name])
end

-- Best sell value of a name across the event tabs the player owns.
local function bestValueOf(ch, copies)
	local best = 0
	for eventKey in pairs(copies or {}) do
		local v = DB.ValueOf(ch, eventKey)
		if v > best then
			best = v
		end
	end
	return best
end

-- Dice prices (mirror of the server's DICE_COSTS).
local DICE_COSTS = {
	Common = 100, Uncommon = 1000, Rare = 10000, Epic = 100000,
	Legendary = 1000000, Mythic = 10000000, Secret = 100000000,
	Godly = 1000000000,
}
-- Rebirth costs (mirror of the server's REBIRTH_COSTS).
local REBIRTH_COSTS = { 5000, 25000, 125000, 500000, 2500000, 10000000, 50000000 }

local state = { Owned = {}, Aura = 0, Dollar = 0, Luck = 0, Unlocked = 0, Rebirth = 0, Base = 0, Index = {}, Copies = {}, Unheld = {}, Event = "Basic", EventLeft = 0, IndexBonus = 0, Friends = 0, LockUntil = 0, LockCooldownUntil = 0 }

-- Player income multiplier (same formula as the server's income tick):
-- Rebirth (+50% per level) x Index completion (+10% per completed tab)
-- x Friend buff (+5% per other player, cap +20%).
local function incomeMult()
	return (1 + 0.5 * (state.Rebirth or 0)) * (1 + (state.IndexBonus or 0)) * (1 + 0.05 * math.min(state.Friends or 0, 4))
end

-- Aura Shrine positions (mirror of the server's ShrineCenters in
-- WorldAndSystems): standing within 9 studs harvests +20 Aura/s.
-- The server adds the shrine BEFORE the multiplier, so the display
-- must too — otherwise the HUD understates the real gain.
local SHRINE_CENTERS = { Vector2.new(-80, -60), Vector2.new(80, -60) }
local SHRINE_AURA_PER_SEC = 20
local function inShrine()
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	for _, c in ipairs(SHRINE_CENTERS) do
		local dx = root.Position.X - c.X
		local dz = root.Position.Z - c.Y
		if dx * dx + dz * dz < 81 then
			return true
		end
	end
	return false
end
local lastAuraShown = 0
local lastDollarShown = 0
local rolling = false
local eventLeft = 0

local EVENT_EMOJI = {
	Basic = "☀️", Summer = "🌞", Rainy = "🌧️", Cold = "❄️",
	Gothic = "🦇", Void = "🌌",
}
-- Big event banner colours (v7.2): gradient start + end per buff event.
local EVENT_BANNER_COLORS = {
	Summer = { Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 90, 40) },
	Rainy = { Color3.fromRGB(60, 120, 255), Color3.fromRGB(30, 60, 180) },
	Cold = { Color3.fromRGB(140, 220, 255), Color3.fromRGB(60, 140, 255) },
	Gothic = { Color3.fromRGB(170, 60, 220), Color3.fromRGB(80, 20, 120) },
	Void = { Color3.fromRGB(120, 60, 255), Color3.fromRGB(40, 10, 80) },
}
local RARITY_EMOJI = {
	Common = "⚪", Uncommon = "🟢", Rare = "🔵", Epic = "🟣",
	Legendary = "🟡", Mythic = "💗", Secret = "🌐", Godly = "👑",
}

-- Forward declarations: openIndex (defined in the Index section below)
-- hides the shop/inventory frames, which are built later; openInventory
-- hides the dice/rebirth frames, also built later. Without these,
-- those opens would index nil globals and the buttons would error.
local shopFrame
local inventoryFrame
local indexFrame
local diceFrame
local rebirthFrame

--------------------------------------------------------------------------------
-- GUI construction helpers
--------------------------------------------------------------------------------

-- (v7.1: the ScreenGui is created at the top of the file now, before any
-- wait, so the player always sees SOMETHING — the old creation block here
-- is deleted.)

-- v7.4 TEXT OVERFLOW (the v6 lesson, applied everywhere): EVERY label
-- truncates at its own edge with "..." instead of spilling past its
-- background. Centred labels overflowed BOTH sides in v6 ("de:"), so
-- nothing here is allowed to draw outside its frame anymore.
local function label(parent, name, size, pos, text, textSize, color, font)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Font = font or Enum.Font.GothamBold
	l.TextSize = textSize
	l.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	l.TextStrokeTransparency = 0.3
	l.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	l.Text = text
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.Parent = parent
	return l
end

local function button(parent, name, size, pos, text, color)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Size = size
	b.Position = pos
	b.BackgroundColor3 = color or Color3.fromRGB(40, 45, 70)
	b.BorderSizePixel = 0
	b.Font = Enum.Font.GothamBlack
	b.TextSize = 20
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = b
	return b
end

local function panel(parent, name, size, pos)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = Color3.fromRGB(24, 26, 44)
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	f.Visible = false
	f.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = f
	return f
end

local function formatMoney(n)
	n = math.floor(n + 0.5)
	local s = tostring(n)
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, #s - 3)
	end
	return s .. out
end

local function formatTime(sec)
	sec = math.max(0, math.floor(sec + 0.5))
	local m = math.floor(sec / 60)
	local s = sec % 60
	return string.format("%02d:%02d", m, s)
end

local function addGradient(instance, c1, c2, rotation)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c1),
		ColorSequenceKeypoint.new(1, c2),
	})
	g.Rotation = rotation or 90
	g.Parent = instance
	return g
end

local function addStroke(instance, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 2
	s.Color = color or Color3.fromRGB(20, 10, 40)
	s.Parent = instance
	return s
end

-- Top bar: Aura (left) + Dollar (right) + income line.
-- v7.4: widened 640 → 720 so the long income line (income + Index +
-- Rebirth + Luck + Friends) fits on one line at 13pt instead of
-- clipping at both edges.
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(0, 720, 0, 64)
topBar.Position = UDim2.new(0.5, -360, 0, 12)
topBar.BackgroundColor3 = Color3.fromRGB(30, 15, 50)
topBar.BackgroundTransparency = 0.25
topBar.BorderSizePixel = 0
local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 14)
topCorner.Parent = topBar
topBar.Parent = gui

local auraLabel = label(topBar, "AuraCounter", UDim2.new(0, 300, 0, 36), UDim2.new(0, 16, 0, 4), "0 AURA", 26, Color3.fromRGB(255, 220, 60), Enum.Font.GothamBlack)
auraLabel.TextXAlignment = Enum.TextXAlignment.Left
addGradient(auraLabel, Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 180, 40))
addStroke(auraLabel, 2, Color3.fromRGB(60, 35, 0))
local dollarLabel = label(topBar, "DollarCounter", UDim2.new(0, 300, 0, 36), UDim2.new(1, -316, 0, 4), "$0", 26, Color3.fromRGB(120, 255, 120), Enum.Font.GothamBlack)
dollarLabel.TextXAlignment = Enum.TextXAlignment.Right
addGradient(dollarLabel, Color3.fromRGB(170, 255, 170), Color3.fromRGB(60, 220, 90))
addStroke(dollarLabel, 2, Color3.fromRGB(10, 50, 20))
local incomeLabel = label(topBar, "Income", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 40), "+0/s", 13, Color3.fromRGB(255, 255, 255))

-- Feature strip (v7.2, top-3 presentation): white pill under the top bar.
local featureStrip = label(gui, "FeatureStrip", UDim2.new(0, 560, 0, 24), UDim2.new(0.5, -280, 0, 80), "37 BRAINROTS · 8 DICE · 10 BASES · REBIRTH", 13, Color3.fromRGB(40, 20, 70), Enum.Font.GothamBold)
featureStrip.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
featureStrip.BackgroundTransparency = 0
featureStrip.TextStrokeTransparency = 1
addStroke(featureStrip, 2, Color3.fromRGB(180, 140, 255))
local featureCorner = Instance.new("UICorner")
featureCorner.CornerRadius = UDim.new(0, 12)
featureCorner.Parent = featureStrip

-- Weather / event countdown bar (centre, under the feature strip).
-- Hidden while a buff event runs: the big event banner takes its slot.
local weatherBar = label(gui, "WeatherBar", UDim2.new(0, 560, 0, 38), UDim2.new(0.5, -280, 0, 108), "☀️ Basic x1  •  03:00", 18, Color3.fromRGB(255, 255, 255), Enum.Font.FredokaOne)
weatherBar.BackgroundColor3 = Color3.fromRGB(20, 22, 38)
weatherBar.BackgroundTransparency = 0.3
addStroke(weatherBar, 2, Color3.fromRGB(10, 20, 40))
local weatherCorner = Instance.new("UICorner")
weatherCorner.CornerRadius = UDim.new(0, 10)
weatherCorner.Parent = weatherBar

-- Big event banner (v7.2, top-3 presentation): while a random buff event
-- runs, this replaces the small weather bar — name + multiplier + live
-- seconds, in the event's colours. Hidden during Basic.
local eventBanner = label(gui, "EventBanner", UDim2.new(0, 720, 0, 54), UDim2.new(0.5, -360, 0, 108), "", 26, Color3.fromRGB(255, 255, 255), Enum.Font.FredokaOne)
eventBanner.BackgroundColor3 = Color3.fromRGB(255, 170, 40)
eventBanner.BackgroundTransparency = 0.1
eventBanner.TextStrokeTransparency = 0
eventBanner.TextStrokeColor3 = Color3.fromRGB(20, 10, 40)
addStroke(eventBanner, 3, Color3.fromRGB(20, 10, 40))
local eventCorner = Instance.new("UICorner")
eventCorner.CornerRadius = UDim.new(0, 16)
eventCorner.Parent = eventBanner
local eventBannerGradient = addGradient(eventBanner, Color3.fromRGB(255, 170, 40), Color3.fromRGB(255, 90, 40))
eventBanner.Visible = false

-- Announcement banner (server-wide Epic+ pulls, event changes).
local banner = label(gui, "Banner", UDim2.new(0, 640, 0, 40), UDim2.new(0.5, -320, 0, 168), "", 18, Color3.fromRGB(255, 255, 255), Enum.Font.FredokaOne)
banner.BackgroundColor3 = Color3.fromRGB(20, 22, 38)
banner.BackgroundTransparency = 0.3
addStroke(banner, 2, Color3.fromRGB(10, 10, 30))
local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 10)
bannerCorner.Parent = banner
banner.Visible = false

-- v7.6: HUD buttons are ~30% smaller, and the LOCK button sits ABOVE
-- the DICE button (bottom left). The REBIRTH button is GONE from the HUD
-- entirely — to rebirth, walk to the Rebirth Altar in the plaza centre
-- (its prompt opens the rebirth panel). The rebirth panel and
-- openRebirthPanel stay for that altar path.
-- Lock button (v7.3 STEAL & DEFEND): lock your own base for 30s
-- (60s cooldown). Same action as the L key. Text + colour show the
-- live state (see refreshLockButton).
local lockButton = button(gui, "LockButton", UDim2.new(0, 150, 0, 46), UDim2.new(0, 16, 1, -118), "🔒 LOCK [L]", Color3.fromRGB(90, 70, 160))
lockButton.TextSize = 15
local lockGradient = addGradient(lockButton, Color3.fromRGB(130, 110, 220), Color3.fromRGB(70, 50, 140))
local diceButton = button(gui, "DiceButton", UDim2.new(0, 150, 0, 46), UDim2.new(0, 16, 1, -62), "🎲 DICE", Color3.fromRGB(60, 200, 90))
diceButton.TextSize = 15
addGradient(diceButton, Color3.fromRGB(110, 235, 130), Color3.fromRGB(25, 140, 65))

-- Lock button state (v7.3): shows the live lock state from the last
-- GetState sync — locked (green, countdown), cooldown (grey, countdown)
-- or ready (purple). The countdown is local (os.time vs the absolute
-- LockUntil epoch), so it ticks without a server round-trip.
local function refreshLockButton()
	local now = os.time()
	local lockUntil = state.LockUntil or 0
	local lockCooldownUntil = state.LockCooldownUntil or 0
	if now < lockUntil then
		lockButton.Text = "🔒 LOCKED " .. tostring(lockUntil - now) .. "s"
		lockGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 235, 130)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(25, 140, 65)),
		})
	elseif now < lockCooldownUntil then
		lockButton.Text = "🔒 " .. tostring(lockCooldownUntil - now) .. "s"
		lockGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 150, 160)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 70, 80)),
		})
	else
		lockButton.Text = "🔒 LOCK [L]"
		lockGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 110, 220)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 50, 140)),
		})
	end
end

-- Menu column (bottom right — moved here in v7 so the buttons can never
-- collide with the top bar on narrow screens): Inventory / Index / Luck.
-- v7.6: ~30% smaller (150x36) so they cover less of the screen.
local inventoryButton = button(gui, "InventoryButton", UDim2.new(0, 150, 0, 36), UDim2.new(1, -166, 1, -140), "🎒 INVENTORY", Color3.fromRGB(200, 90, 200))
inventoryButton.TextSize = 14
addGradient(inventoryButton, Color3.fromRGB(240, 130, 240), Color3.fromRGB(150, 50, 180))
local indexButton = button(gui, "IndexButton", UDim2.new(0, 150, 0, 36), UDim2.new(1, -166, 1, -96), "📖 INDEX", Color3.fromRGB(90, 70, 160))
indexButton.TextSize = 14
local luckButton = button(gui, "LuckButton", UDim2.new(0, 150, 0, 36), UDim2.new(1, -166, 1, -52), "🍀 LUCK", Color3.fromRGB(170, 80, 255))
luckButton.TextSize = 14

-- Result card (centre, shown after a roll). v7.6.2: taller (360px) for the
-- character ViewportFrame, ZIndex 50 so it always sits ABOVE the panels
-- (v7.5 bug: the dice panel covered the result, so Yami never saw what
-- he rolled). The rolling dice face sits over the viewport during the
-- roll animation, then the character's 3D model spins there.
-- v7.6.2: card 360px, fully opaque + stroke (the translucent dark card
-- washed the text out); viewport bright + lit (see below).
local resultCard = panel(gui, "ResultCard", UDim2.new(0, 360, 0, 360), UDim2.new(0.5, -180, 0.5, -180))
resultCard.BackgroundTransparency = 0
resultCard.ZIndex = 50
addStroke(resultCard, 3, Color3.fromRGB(120, 90, 220))
local resultViewport = Instance.new("ViewportFrame")
resultViewport.Name = "Character"
resultViewport.Size = UDim2.new(0, 160, 0, 160)
resultViewport.Position = UDim2.new(0.5, -80, 0, 10)
resultViewport.BackgroundColor3 = Color3.fromRGB(150, 190, 255)
resultViewport.BackgroundTransparency = 0
resultViewport.BorderSizePixel = 0
-- v7.6.2 VIEWPORT FIX (Yami: the character was invisible — a dark box):
-- the old near-black background (10,12,26) + the default top-down
-- viewport light left the model in shadow, so it read as a black hole.
-- Bright sky background + diagonal light (front + top lit) + high
-- ambient, so the model is lit from the front and pops against the sky.
resultViewport.LightColor = Color3.fromRGB(255, 255, 255)
resultViewport.LightDirection = Vector3.new(-0.5, -1, -0.5)
resultViewport.Ambient = 0.8
addGradient(resultViewport, Color3.fromRGB(190, 220, 255), Color3.fromRGB(150, 160, 230))
resultViewport.Parent = resultCard
local resultViewportCorner = Instance.new("UICorner")
resultViewportCorner.CornerRadius = UDim.new(0, 12)
resultViewportCorner.Parent = resultViewport
local resultWorld = Instance.new("WorldModel")
resultWorld.Name = "World"
resultWorld.Parent = resultViewport
local resultCam = nil
-- Rolling dice face (shown over the viewport while the roll animates).
local resultDice = label(resultCard, "Rolling", UDim2.new(0, 160, 0, 160), UDim2.new(0.5, -80, 0, 10), "🎲", 72, Color3.fromRGB(255, 220, 80), Enum.Font.FredokaOne)
resultDice.Visible = false
local resultName = label(resultCard, "Name", UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 178), "", 22, Color3.fromRGB(255, 255, 255), Enum.Font.FredokaOne)
local resultRarity = label(resultCard, "Rarity", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 212), "", 17, Color3.fromRGB(255, 255, 255))
local resultIncome = label(resultCard, "Income", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 240), "", 17, Color3.fromRGB(255, 220, 60))
local resultValue = label(resultCard, "Value", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 266), "", 15, Color3.fromRGB(120, 255, 120))
local resultNew = label(resultCard, "New", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 292), "", 16, Color3.fromRGB(80, 255, 120), Enum.Font.GothamBlack)
local resultLucky = label(resultCard, "Lucky", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 316), "", 16, Color3.fromRGB(255, 220, 80), Enum.Font.GothamBlack)
resultLucky.Visible = false

-- Build the rolled character's 3D model into the result card's
-- ViewportFrame and frame it with a camera. Returns the camera + framing
-- (for the slow spin) or nil if the model could not be built. Safe:
-- DB.BuildModel clones custom models, so the game world is untouched.
local function setupResultViewport(name, eventKey)
	for _, child in ipairs(resultWorld:GetChildren()) do
		child:Destroy()
	end
	if resultCam then
		resultCam:Destroy()
		resultCam = nil
	end
	local ok, model = pcall(function()
		return DB.BuildModel(name, eventKey, incomeMult())
	end)
	if not ok or not model then
		return nil
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
	model.Parent = resultWorld
	local cf, size = model:GetBoundingBox()
	local center = cf.Position
	-- v7.6.2: closer camera (1.8x) so the model fills more of the frame.
	local dist = math.max(size.X, size.Y, size.Z) * 1.8 + 1
	local cam = Instance.new("Camera")
	cam.FieldOfView = 50
	cam.CFrame = CFrame.new(center + Vector3.new(0, size.Y * 0.15, dist), center)
	cam.Parent = resultViewport
	resultViewport.CurrentCamera = cam
	resultCam = cam
	return { cam = cam, center = center, dist = dist, height = size.Y }
end

-- Popup layer for floating "+Aura" / "+$" texts.
local popupLayer = Instance.new("Frame")
popupLayer.Name = "PopupLayer"
popupLayer.Size = UDim2.new(1, 0, 1, 0)
popupLayer.BackgroundTransparency = 1
popupLayer.Parent = gui

--------------------------------------------------------------------------------
-- State helpers
--------------------------------------------------------------------------------

-- Passive income preview: every distinct brainrot owned pays its rarity
-- Aura/s, plus the Shrine bonus (+20/s while standing in a Shrine),
-- all multiplied by Rebirth / Index / Friend. This MUST match the
-- server's income tick exactly (same formula, same order) — it is the
-- number the HUD shows as "+X/s", and Yami compares it against the
-- Aura counter climbing live. (v7.6.6: the old version omitted the
-- Shrine entirely, and the HUD only refreshed on panel opens / rolls —
-- so a 3D-die roll left it stale at the old rate.)
local function previewIncome()
	local base = 0
	for _, name in ipairs(state.Owned or {}) do
		base = base + auraPerSec(name)
	end
	if inShrine() then
		base = base + SHRINE_AURA_PER_SEC
	end
	return math.floor(base * incomeMult() + 0.5)
end

-- Refresh just the "+X/s" income label from the current state (no server
-- round-trip). Called every second so the rate tracks the player walking
-- in/out of a Shrine and stays honest between full state syncs.
local function refreshIncomeLabel()
	local bonusPct = math.floor((state.IndexBonus or 0) * 100 + 0.5)
	local rebirthMult = 1 + 0.5 * (state.Rebirth or 0)
	local friendPct = 5 * math.min(state.Friends or 0, 4)
	incomeLabel.Text = "+" .. tostring(previewIncome()) .. "/s  •  Index +" .. tostring(bonusPct) .. "%  •  🔄 Rebirth Lv " .. tostring(state.Rebirth or 0) .. " (x" .. tostring(rebirthMult) .. ")  •  🍀 Luck Lv " .. tostring(state.Luck or 0) .. "  •  👥 Friends +" .. tostring(friendPct) .. "%"
end

local function refreshState()
	local ok, fresh = pcall(function()
		return GetState:InvokeServer()
	end)
	if ok and fresh then
		state = fresh
		eventLeft = fresh.EventLeft or 0
	end
	refreshIncomeLabel()
	refreshWeatherBar()
end

function refreshWeatherBar()
	local event = DB.Events[state.Event] or DB.Events.Basic
	if state.Event == "Basic" then
		-- No buff: small countdown bar, big banner hidden.
		eventBanner.Visible = false
		weatherBar.Visible = true
		weatherBar.Text = (EVENT_EMOJI[state.Event] or "☀️") .. " " .. event.Name .. " x" .. tostring(event.Mult) .. "  •  " .. formatTime(eventLeft)
	else
		-- Buff running (v7.2): big banner in the weather bar's slot, with
		-- the live seconds left. Colours follow the event.
		weatherBar.Visible = false
		eventBanner.Visible = true
		local colors = EVENT_BANNER_COLORS[state.Event] or EVENT_BANNER_COLORS.Summer
		eventBannerGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, colors[1]),
			ColorSequenceKeypoint.new(1, colors[2]),
		})
		eventBanner.Text = (EVENT_EMOJI[state.Event] or "🌦️") .. " " .. event.Name:upper() .. " x" .. tostring(event.Mult) .. " — " .. tostring(math.max(0, math.floor(eventLeft + 0.5))) .. "s"
	end
end

local function spawnPopup(text, color)
	local popup = Instance.new("TextLabel")
	popup.Size = UDim2.new(0, 220, 0, 30)
	popup.Position = UDim2.new(0.5, math.random(-140, 140), 0.62, math.random(-20, 20))
	popup.BackgroundTransparency = 1
	popup.Font = Enum.Font.GothamBlack
	popup.TextSize = 20
	popup.TextColor3 = color or Color3.fromRGB(255, 220, 60)
	popup.TextStrokeTransparency = 0.3
	popup.Text = text
	popup.Parent = popupLayer
	local tween = TweenService:Create(popup, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = popup.Position + UDim2.new(0, 0, 0, -70),
		TextTransparency = 1,
	})
	tween:Play()
	tween.Completed:Connect(function()
		popup:Destroy()
	end)
end

-- v7.6: roll reveal — the result card is the star now. It hides every
-- panel first (the dice panel used to cover the result, so Yami never
-- saw what he rolled), plays a ~1.2s dice-rolling animation (the die
-- face cycles 1-6, random names flash, the card shakes a little), then
-- reveals the real result with the character's 3D model spinning slowly
-- in the ViewportFrame. A new roll aborts an in-progress reveal
-- (resultSpinToken); the card hides 4s after the reveal.
local resultSpinToken = 0
local function showResult(result)
	-- Hide every panel so the card is fully visible, on top (ZIndex 50).
	diceFrame.Visible = false
	indexFrame.Visible = false
	shopFrame.Visible = false
	inventoryFrame.Visible = false
	rebirthFrame.Visible = false
	resultCard.Visible = true
	resultCard.ZIndex = 50
	-- v7.6.3: reset the card position FIRST — the rolling shake below
	-- offsets it by ±4px, and an early return (new roll / card hidden)
	-- used to skip the reset, leaving the card stuck off-centre.
	resultCard.Position = UDim2.new(0.5, -180, 0.5, -180)
	local myToken = resultSpinToken + 1
	resultSpinToken = myToken
	-- Rolling phase: die face + flashing names, card shakes a little.
	resultViewport.Visible = false
	resultDice.Visible = true
	resultIncome.Visible = false
	resultValue.Visible = false
	resultNew.Visible = false
	resultLucky.Visible = false
	resultName.Text = "???"
	resultName.TextColor3 = Color3.fromRGB(255, 255, 255)
	resultRarity.Text = "🎲 Rolling..."
	resultRarity.TextColor3 = Color3.fromRGB(255, 220, 80)
	local rollStart = os.clock()
	while os.clock() - rollStart < 1.2 do
		if resultSpinToken ~= myToken or not resultCard.Visible then
			return
		end
		resultDice.Text = "🎲 " .. tostring(math.random(1, 6))
		local ch = DB.Characters[math.random(1, #DB.Characters)]
		if ch then
			resultName.Text = ch.Name
			resultName.TextColor3 = DB.RarityColors[ch.Rarity] or Color3.fromRGB(255, 255, 255)
		end
		resultCard.Position = UDim2.new(0.5, -180 + math.random(-4, 4), 0.5, -180 + math.random(-4, 4))
		task.wait(0.12)
	end
	if resultSpinToken ~= myToken or not resultCard.Visible then
		return
	end
	resultCard.Position = UDim2.new(0.5, -180, 0.5, -180)
	-- Reveal: the real result + the character's 3D model, spinning.
	resultDice.Visible = false
	resultViewport.Visible = true
	resultName.Text = result.Name
	resultName.TextColor3 = DB.RarityColors[result.Rarity] or Color3.fromRGB(255, 255, 255)
	resultRarity.Text = (RARITY_EMOJI[result.Rarity] or "") .. " " .. result.Rarity
	resultRarity.TextColor3 = DB.RarityColors[result.Rarity] or Color3.fromRGB(255, 255, 255)
	-- v7.6.6: show the rate this brainrot REALLY pays — base rarity rate
	-- x the player's income multiplier (Rebirth/Index/Friends), so the
	-- card agrees with the pedestal label and the HUD total.
	resultIncome.Text = "+" .. tostring(math.floor(result.AuraPerSec * incomeMult() + 0.5)) .. " Aura/s"
	resultIncome.Visible = true
	local event = DB.Events[result.EventKey] or DB.Events.Basic
	resultValue.Text = "💰 $" .. formatMoney(result.Value or 0) .. "  (" .. event.Name .. " x" .. tostring(event.Mult) .. ")"
	resultValue.Visible = true
	if result.IsNew then
		-- v7.4: shortened so it fits the 360px card at 16pt (the old
		-- 66-char line spilled past the card's edge).
		resultNew.Text = "✨ NEW! In your base + backpack!"
	else
		resultNew.Text = "Duplicate — sell it at the SELL ZONE!"
	end
	resultNew.Visible = true
	if result.Lucky then
		resultLucky.Text = "🍀 LUCKY ROLL! Jumped one tier up!"
		resultLucky.Visible = true
	else
		resultLucky.Visible = false
	end
	local view = setupResultViewport(result.Name, result.EventKey)
	if view then
		local spinToken = myToken
		task.spawn(function()
			local angle = 0
			while resultCard.Visible and resultSpinToken == spinToken do
				angle = angle + 0.03
				if view.cam.Parent then
					view.cam.CFrame = CFrame.new(view.center + Vector3.new(math.sin(angle) * view.dist, view.height * 0.15, math.cos(angle) * view.dist), view.center)
				end
				task.wait()
			end
		end)
	end
	task.delay(4, function()
		if resultSpinToken == myToken then
			resultCard.Visible = false
		end
	end)
end

local function showBanner(text, color)
	banner.Text = text
	banner.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	banner.Visible = true
	banner.Position = UDim2.new(0.5, -320, 0, 116)
	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -320, 0, 168),
	}):Play()
	task.delay(4, function()
		banner.Visible = false
	end)
end

-- Weather countdown ticks locally between server broadcasts.
task.spawn(function()
	while true do
		task.wait(1)
		if eventLeft > 0 then
			eventLeft = eventLeft - 1
			refreshWeatherBar()
		end
		-- v7.3: the LOCK button countdown ticks here too.
		refreshLockButton()
		-- v7.6.6: re-check the income rate every second (no server call)
		-- so the "+X/s" label tracks walking in/out of a Shrine live.
		refreshIncomeLabel()
	end
end)

--------------------------------------------------------------------------------
-- Brainrot Index: 6 tabs (one per mutation event), 37 slots each. Locked
-- slots show "???"; unlocked slots show the name, rarity colour and value.
-- A completed tab (37/37) grants a permanent +10% Aura income.
-- Panels are top-anchored (y = 170) so they never cover the HUD.
--------------------------------------------------------------------------------
-- (forward-declared at the top: showResult hides this frame too.)
indexFrame = panel(gui, "IndexFrame", UDim2.new(0, 720, 0, 440), UDim2.new(0.5, -360, 0, 170))
local indexTitle = label(indexFrame, "Title", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 8), "📖 BRAINROT INDEX", 26, Color3.fromRGB(255, 220, 80), Enum.Font.FredokaOne)
addGradient(indexTitle, Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 170, 40))
addStroke(indexTitle, 2, Color3.fromRGB(60, 35, 0))
local indexClose = button(indexFrame, "Close", UDim2.new(0, 70, 0, 30), UDim2.new(1, -80, 0, 8), "CLOSE", Color3.fromRGB(180, 60, 60))
indexClose.MouseButton1Click:Connect(function()
	indexFrame.Visible = false
end)

local tabRow = Instance.new("Frame")
tabRow.Name = "Tabs"
tabRow.Size = UDim2.new(1, -20, 0, 36)
tabRow.Position = UDim2.new(0, 10, 0, 52)
tabRow.BackgroundTransparency = 1
tabRow.Parent = indexFrame

local indexProgress = label(indexFrame, "Progress", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 92), "", 15, Color3.fromRGB(200, 230, 255))

local indexGrid = Instance.new("ScrollingFrame")
indexGrid.Name = "Grid"
indexGrid.Size = UDim2.new(1, -20, 1, -132)
indexGrid.Position = UDim2.new(0, 10, 0, 122)
indexGrid.BackgroundTransparency = 1
indexGrid.BorderSizePixel = 0
indexGrid.ScrollBarThickness = 6
indexGrid.Parent = indexFrame
local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 158, 0, 52)
gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
gridLayout.Parent = indexGrid

local currentTab = "Basic"

local function indexCount(eventKey)
	if not state or not state.Index then
		return 0
	end
	local tab = state.Index[eventKey]
	if not tab then
		return 0
	end
	local count = 0
	for _ in pairs(tab) do
		count = count + 1
	end
	return count
end

local function buildIndexGrid()
	for _, child in ipairs(indexGrid:GetChildren()) do
		if child:IsA("TextButton") or child:IsA("Frame") then
			child:Destroy()
		end
	end
	local tab = state and state.Index and state.Index[currentTab] or {}
	for _, ch in ipairs(DB.Characters) do
		local unlocked = tab[ch.Name] == true
		local slot = Instance.new("TextButton")
		slot.Size = UDim2.new(0, 158, 0, 52)
		if unlocked then
			local rc = DB.RarityColors[ch.Rarity]
			slot.BackgroundColor3 = Color3.new(rc.R * 0.28, rc.G * 0.28, rc.B * 0.28)
		else
			slot.BackgroundColor3 = Color3.fromRGB(28, 30, 46)
		end
		slot.BorderSizePixel = 0
		slot.Font = Enum.Font.GothamBold
		slot.TextSize = 12
		slot.TextColor3 = unlocked and DB.RarityColors[ch.Rarity] or Color3.fromRGB(120, 120, 130)
		slot.TextWrapped = true
		-- v7.4: truncate so a very long name can never push the value
		-- line out of the 52px slot (same v6 overflow lesson).
		slot.TextTruncate = Enum.TextTruncate.AtEnd
		if unlocked then
			slot.Text = (RARITY_EMOJI[ch.Rarity] or "") .. " " .. ch.Name .. "\n💰 $" .. formatMoney(DB.ValueOf(ch, currentTab)) .. " • " .. ch.Rarity
		else
			slot.Text = "🔒 ???\n" .. (RARITY_EMOJI[ch.Rarity] or "") .. " " .. ch.Rarity
		end
		slot.Parent = indexGrid
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = slot
	end
	local count = indexCount(currentTab)
	local complete = count >= DB.CharacterCount
	if complete then
		indexProgress.Text = currentTab .. ": " .. tostring(count) .. "/" .. tostring(DB.CharacterCount) .. "  •  COMPLETE! +10% Aura income"
		indexProgress.TextColor3 = Color3.fromRGB(120, 255, 120)
	else
		indexProgress.Text = currentTab .. ": " .. tostring(count) .. "/" .. tostring(DB.CharacterCount) .. " unlocked"
		indexProgress.TextColor3 = Color3.fromRGB(200, 230, 255)
	end
end

local tabButtons = {}
for i, eventKey in ipairs(DB.EventOrder) do
	local b = button(tabRow, "Tab" .. eventKey, UDim2.new(0, 108, 1, 0), UDim2.new(0, (i - 1) * 114, 0, 0),
		eventKey, Color3.fromRGB(50, 55, 90))
	b.TextSize = 13
	tabButtons[eventKey] = b
	b.MouseButton1Click:Connect(function()
		currentTab = eventKey
		for key, btn in pairs(tabButtons) do
			btn.BackgroundColor3 = key == eventKey and Color3.fromRGB(90, 70, 160) or Color3.fromRGB(50, 55, 90)
		end
		buildIndexGrid()
	end)
end

local function openIndex()
	refreshState()
	shopFrame.Visible = false
	inventoryFrame.Visible = false
	diceFrame.Visible = false
	rebirthFrame.Visible = false
	indexFrame.Visible = true
	for key, btn in pairs(tabButtons) do
		btn.BackgroundColor3 = key == currentTab and Color3.fromRGB(90, 70, 160) or Color3.fromRGB(50, 55, 90)
	end
	buildIndexGrid()
end

--------------------------------------------------------------------------------
-- Inventory (v7.4): every brainrot rolled from the dice, with a
-- HELD/STORED toggle per name. HELD = its Tools sit in the Backpack
-- hotbar (press 1, 2, 3); STORED = inventory only, so it frees hotbar
-- slots. Copies, base display and income are untouched either way.
-- Rows are sorted rarest-first. Panels are top-anchored (y = 170) so
-- they never cover the HUD.
--------------------------------------------------------------------------------
inventoryFrame = panel(gui, "InventoryFrame", UDim2.new(0, 720, 0, 440), UDim2.new(0.5, -360, 0, 170))
local inventoryTitle = label(inventoryFrame, "Title", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 8), "🎒 MY INVENTORY", 26, Color3.fromRGB(255, 220, 80), Enum.Font.FredokaOne)
addGradient(inventoryTitle, Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 120, 200))
addStroke(inventoryTitle, 2, Color3.fromRGB(60, 20, 60))
local inventoryClose = button(inventoryFrame, "Close", UDim2.new(0, 70, 0, 30), UDim2.new(1, -80, 0, 8), "CLOSE", Color3.fromRGB(180, 60, 60))
inventoryClose.MouseButton1Click:Connect(function()
	inventoryFrame.Visible = false
end)
local inventorySummary = label(inventoryFrame, "Summary", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 52), "", 15, Color3.fromRGB(200, 230, 255), Enum.Font.FredokaOne)
local inventoryHint = label(inventoryFrame, "Hint", UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0, 80), "✋ HELD = in your backpack (press 1, 2, 3)  •  📦 STORED = inventory only", 13, Color3.fromRGB(190, 200, 220))
local inventoryList = Instance.new("ScrollingFrame")
inventoryList.Name = "List"
inventoryList.Size = UDim2.new(1, -20, 1, -116)
inventoryList.Position = UDim2.new(0, 10, 0, 106)
inventoryList.BackgroundTransparency = 1
inventoryList.BorderSizePixel = 0
inventoryList.ScrollBarThickness = 6
inventoryList.AutomaticCanvasSize = Enum.AutomaticSize.Y
inventoryList.Parent = inventoryFrame
local inventoryLayout = Instance.new("UIListLayout")
inventoryLayout.Padding = UDim.new(0, 8)
inventoryLayout.Parent = inventoryList

local function totalCopiesOf(name)
	local copies = state and state.Copies and state.Copies[name]
	if not copies then
		return 0
	end
	local total = 0
	for _, c in pairs(copies) do
		total = total + c
	end
	return total
end

local function openInventory()
	refreshState()
	indexFrame.Visible = false
	shopFrame.Visible = false
	diceFrame.Visible = false
	rebirthFrame.Visible = false
	inventoryFrame.Visible = true
	for _, child in ipairs(inventoryList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local names = {}
	for name in pairs(state.Copies or {}) do
		if totalCopiesOf(name) > 0 then
			table.insert(names, name)
		end
	end
	table.sort(names, function(a, b)
		local ca, cb = DB.GetCharacter(a), DB.GetCharacter(b)
		local ra = ca and (DB.RarityRank[ca.Rarity] or 0) or 0
		local rb = cb and (DB.RarityRank[cb.Rarity] or 0) or 0
		if ra ~= rb then
			return ra > rb
		end
		return a < b
	end)
	local totalCount = 0
	local heldCount = 0
	for _, name in ipairs(names) do
		totalCount = totalCount + totalCopiesOf(name)
		if isHeld(name) then
			heldCount = heldCount + 1
		end
	end
	if #names == 0 then
		inventorySummary.Text = "No brainrots yet — roll a die!"
		inventorySummary.TextColor3 = Color3.fromRGB(255, 220, 120)
	else
		inventorySummary.Text = tostring(#names) .. " brainrots  •  " .. tostring(totalCount) .. " copies  •  " .. tostring(heldCount) .. " held in backpack"
		inventorySummary.TextColor3 = Color3.fromRGB(200, 230, 255)
	end
	for _, name in ipairs(names) do
		local ch = DB.GetCharacter(name)
		if ch then
			local rc = DB.RarityColors[ch.Rarity]
			local held = isHeld(name)
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -6, 0, 64)
			row.BackgroundColor3 = Color3.new(rc.R * 0.28, rc.G * 0.28, rc.B * 0.28)
			row.BorderSizePixel = 0
			row.Parent = inventoryList
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = row
			local rowName = label(row, "Name", UDim2.new(0.52, 0, 0, 28), UDim2.new(0, 12, 0, 6), (RARITY_EMOJI[ch.Rarity] or "") .. " " .. name, 16, rc, Enum.Font.FredokaOne)
			rowName.TextXAlignment = Enum.TextXAlignment.Left
			local rowInfo = label(row, "Info", UDim2.new(0.52, 0, 0, 22), UDim2.new(0, 12, 0, 34), "×" .. tostring(totalCopiesOf(name)) .. " copies  •  +" .. tostring(math.floor(auraPerSec(name) * incomeMult() + 0.5)) .. " Aura/s  •  💰 $" .. formatMoney(bestValueOf(ch, state.Copies[name])), 12, Color3.fromRGB(210, 215, 235), Enum.Font.Gotham)
			rowInfo.TextXAlignment = Enum.TextXAlignment.Left
			local toggle = button(row, "HoldToggle", UDim2.new(0, 150, 0, 40), UDim2.new(1, -162, 0, 12), held and "✋ HELD" or "📦 STORED", held and Color3.fromRGB(40, 160, 80) or Color3.fromRGB(90, 90, 100))
			toggle.TextSize = 15
			toggle.Font = Enum.Font.FredokaOne
			if held then
				addGradient(toggle, Color3.fromRGB(90, 220, 120), Color3.fromRGB(30, 140, 70))
			end
			toggle.MouseButton1Click:Connect(function()
				SetHeld:FireServer(name, not held)
				task.wait(0.3)
				openInventory()
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- Luck shop: one upgrade row. Costs mirror the server. Luck now powers the
-- LUCKY ROLL: +2% per level (max 10%) for a dice result to jump one tier.
--------------------------------------------------------------------------------
shopFrame = panel(gui, "ShopFrame", UDim2.new(0, 560, 0, 220), UDim2.new(0.5, -280, 0, 170))
local shopTitle = label(shopFrame, "Title", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 8), "🍀 LUCK ALTAR — Meteor Luck", 24, Color3.fromRGB(255, 220, 80), Enum.Font.FredokaOne)
addGradient(shopTitle, Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 170, 40))
addStroke(shopTitle, 2, Color3.fromRGB(60, 35, 0))
local shopClose = button(shopFrame, "Close", UDim2.new(0, 70, 0, 30), UDim2.new(1, -80, 0, 8), "CLOSE", Color3.fromRGB(180, 60, 60))
shopClose.MouseButton1Click:Connect(function()
	shopFrame.Visible = false
end)
local shopList = Instance.new("Frame")
shopList.Name = "List"
shopList.Size = UDim2.new(1, -20, 1, -60)
shopList.Position = UDim2.new(0, 10, 0, 50)
shopList.BackgroundTransparency = 1
shopList.Parent = shopFrame

local LUCK_COSTS = { 1000, 3000, 8000, 20000, 50000 }

local function openShop(shopKey)
	if shopKey ~= "luck" then
		return
	end
	refreshState()
	indexFrame.Visible = false
	inventoryFrame.Visible = false
	diceFrame.Visible = false
	rebirthFrame.Visible = false
	shopFrame.Visible = true
	for _, child in ipairs(shopList:GetChildren()) do
		child:Destroy()
	end
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 64)
	row.Position = UDim2.new(0, 0, 0, 0)
	row.BackgroundColor3 = Color3.fromRGB(38, 41, 66)
	row.BorderSizePixel = 0
	row.Parent = shopList
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = row
	-- v7.4: playful FredokaOne row name; the Desc is shortened so it
	-- fits the 0.55-wide row at 12pt (the old 68-char line spilled).
	label(row, "Name", UDim2.new(0.55, 0, 0, 26), UDim2.new(0, 12, 0, 6), "🍀 Meteor Luck", 16, Color3.fromRGB(255, 255, 255), Enum.Font.FredokaOne)
	label(row, "Desc", UDim2.new(0.55, 0, 0, 22), UDim2.new(0, 12, 0, 32), "+2% Lucky Roll chance per level (max 10%)", 12, Color3.fromRGB(190, 200, 220), Enum.Font.Gotham)
	local buy = button(row, "Buy", UDim2.new(0, 150, 0, 40), UDim2.new(1, -162, 0, 12), "BUY", Color3.fromRGB(40, 160, 80))
	addGradient(buy, Color3.fromRGB(90, 220, 120), Color3.fromRGB(30, 140, 70))
	local level = state and state.Luck or 0
	if level >= 5 then
		buy.Text = "MAXED 👑"
		buy.BackgroundColor3 = Color3.fromRGB(90, 90, 100)
	else
		buy.Text = "Lv" .. tostring(level) .. " → Lv" .. tostring(level + 1) .. "  $" .. formatMoney(LUCK_COSTS[level + 1])
		buy.MouseButton1Click:Connect(function()
			BuyLuck:FireServer()
			task.wait(0.4)
			openShop("luck")
		end)
	end
	-- v7.4: shortened (the old line was ~75 chars in a 540px panel).
	label(shopList, "Balance", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 76), "Your Dollars: $" .. formatMoney(state and state.Dollar or 0) .. "  •  Sell brainrots at the SELL ZONE!", 13, Color3.fromRGB(200, 230, 255))
end

--------------------------------------------------------------------------------
-- Dice panel: all 8 dice with prices, lock status and example contents.
-- ROLL here or hold E at the physical die in the plaza.
-- v7: rows say "Dice" (never "Die"); the "Inside:" line is LEFT-aligned
-- and truncated at the row edge — v6 centred it, so the long Mythic line
-- overflowed both sides and read as "de: La Vaca..." in Yami's screenshot.
--------------------------------------------------------------------------------
-- (forward-declared at the top: openIndex/openInventory hide this frame.)
diceFrame = panel(gui, "DiceFrame", UDim2.new(0, 560, 0, 440), UDim2.new(0.5, -280, 0, 170))
local diceTitle = label(diceFrame, "Title", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 8), "🎲 DICE — Roll for Aura", 24, Color3.fromRGB(255, 220, 80), Enum.Font.FredokaOne)
addGradient(diceTitle, Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 170, 40))
addStroke(diceTitle, 2, Color3.fromRGB(60, 35, 0))
local diceClose = button(diceFrame, "Close", UDim2.new(0, 70, 0, 30), UDim2.new(1, -80, 0, 8), "CLOSE", Color3.fromRGB(180, 60, 60))
diceClose.MouseButton1Click:Connect(function()
	diceFrame.Visible = false
end)
local diceList = Instance.new("ScrollingFrame")
diceList.Name = "List"
diceList.Size = UDim2.new(1, -20, 1, -60)
diceList.Position = UDim2.new(0, 10, 0, 50)
diceList.BackgroundTransparency = 1
diceList.BorderSizePixel = 0
diceList.ScrollBarThickness = 6
diceList.AutomaticCanvasSize = Enum.AutomaticSize.Y
diceList.Parent = diceFrame
local diceLayout = Instance.new("UIListLayout")
diceLayout.Padding = UDim.new(0, 8)
diceLayout.Parent = diceList

local function tierExamples(tier)
	local names = {}
	for _, ch in ipairs(DB.Characters) do
		if ch.Rarity == tier then
			table.insert(names, ch.Name)
			if #names >= 2 then
				break
			end
		end
	end
	return table.concat(names, ", ")
end

local function openDicePanel()
	refreshState()
	indexFrame.Visible = false
	shopFrame.Visible = false
	inventoryFrame.Visible = false
	rebirthFrame.Visible = false
	diceFrame.Visible = true
	for _, child in ipairs(diceList:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local rebirth = state and state.Rebirth or 0
	for i, tier in ipairs(DB.RarityOrder) do
		local rc = DB.RarityColors[tier]
		local locked = rebirth < i - 1
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -6, 0, 56)
		row.BackgroundColor3 = Color3.new(rc.R * 0.22, rc.G * 0.22, rc.B * 0.22)
		row.BorderSizePixel = 0
		row.Parent = diceList
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = row
		local lockText = locked and ("  🔒 Rebirth " .. tostring(i - 1)) or ""
		-- v7.4: playful FredokaOne row names (truncation still guards the edge).
		local nameLabel = label(row, "Name", UDim2.new(0.62, 0, 0, 26), UDim2.new(0, 12, 0, 4), (RARITY_EMOJI[tier] or "") .. " " .. tier .. " Dice — " .. formatMoney(DICE_COSTS[tier]) .. " Aura" .. lockText, 16, rc, Enum.Font.FredokaOne)
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
		local descLabel = label(row, "Desc", UDim2.new(0.68, 0, 0, 20), UDim2.new(0, 12, 0, 30), "Inside: " .. tierExamples(tier) .. " + more", 11, Color3.fromRGB(190, 200, 220), Enum.Font.Gotham)
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.TextTruncate = Enum.TextTruncate.AtEnd
		local roll = button(row, "Roll", UDim2.new(0, 130, 0, 40), UDim2.new(1, -142, 0, 8), locked and "🔒 LOCKED" or "🎲 ROLL", locked and Color3.fromRGB(90, 90, 100) or Color3.fromRGB(40, 160, 80))
		roll.TextSize = 15
		if not locked then
			addGradient(roll, Color3.fromRGB(90, 220, 120), Color3.fromRGB(30, 140, 70))
			roll.MouseButton1Click:Connect(function()
				if rolling then
					return
				end
				rolling = true
				roll.Text = "ROLLING..."
				local ok, result = pcall(function()
					return RollDie:InvokeServer(tier)
				end)
				if ok and result and result.ok then
					-- v7.6: showResult runs the rolling animation + reveal
					-- (it hides the dice panel). The panel is NOT re-opened
					-- after the roll, so the result card stays fully
					-- visible; re-open it with the DICE button.
					showResult(result)
					spawnPopup("+" .. tostring(result.AuraPerSec) .. "/s!", Color3.fromRGB(80, 255, 120))
				elseif ok and result and result.reason == "need aura" then
					showBanner("Not enough Aura for the " .. tier .. " Dice! Farm clicks or stand in a Shrine.", Color3.fromRGB(255, 120, 120))
				end
				rolling = false
				roll.Text = "🎲 ROLL"
				task.wait(0.2)
				refreshState()
			end)
		end
	end
end

--------------------------------------------------------------------------------
-- Rebirth panel: current level, next dice tier, cost, income multiplier.
-- Rebirth also opens one more base slot (4 at R0, all 10 at R6).
--------------------------------------------------------------------------------
-- (forward-declared at the top: openIndex/openInventory hide this frame.)
rebirthFrame = panel(gui, "RebirthFrame", UDim2.new(0, 560, 0, 280), UDim2.new(0.5, -280, 0, 170))
local rebirthTitle = label(rebirthFrame, "Title", UDim2.new(1, 0, 0, 40), UDim2.new(0, 0, 0, 8), "🔄 REBIRTH", 24, Color3.fromRGB(255, 220, 80), Enum.Font.FredokaOne)
addGradient(rebirthTitle, Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 170, 40))
addStroke(rebirthTitle, 2, Color3.fromRGB(60, 35, 0))
local rebirthClose = button(rebirthFrame, "Close", UDim2.new(0, 70, 0, 30), UDim2.new(1, -80, 0, 8), "CLOSE", Color3.fromRGB(180, 60, 60))
rebirthClose.MouseButton1Click:Connect(function()
	rebirthFrame.Visible = false
end)
local rebirthBody = Instance.new("Frame")
rebirthBody.Name = "Body"
rebirthBody.Size = UDim2.new(1, -20, 1, -60)
rebirthBody.Position = UDim2.new(0, 10, 0, 50)
rebirthBody.BackgroundTransparency = 1
rebirthBody.Parent = rebirthFrame

local function openRebirthPanel()
	refreshState()
	indexFrame.Visible = false
	shopFrame.Visible = false
	inventoryFrame.Visible = false
	diceFrame.Visible = false
	rebirthFrame.Visible = true
	for _, child in ipairs(rebirthBody:GetChildren()) do
		child:Destroy()
	end
	local level = state and state.Rebirth or 0
	local mult = 1 + 0.5 * level
	label(rebirthBody, "Level", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 0), "Your Rebirth: Lv " .. tostring(level) .. "  •  Aura income x" .. tostring(mult), 17, Color3.fromRGB(255, 255, 255), Enum.Font.FredokaOne)
	local openSlots = math.min(4 + level, 10)
	label(rebirthBody, "Slots", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 30), "Base slots open: " .. tostring(openSlots) .. "/10  •  each rebirth opens +1", 14, Color3.fromRGB(200, 230, 255))
	if level >= 7 then
		label(rebirthBody, "Maxed", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 58), "👑 MAXED — every dice tier is open!", 16, Color3.fromRGB(120, 255, 120))
	else
		local nextTier = DB.RarityOrder[level + 2]
		label(rebirthBody, "Next", UDim2.new(1, 0, 0, 28), UDim2.new(0, 0, 0, 58), "Next: " .. nextTier .. " Dice  •  +50% Aura income (stacking)", 16, Color3.fromRGB(200, 230, 255))
		label(rebirthBody, "Keep", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 88), "Rebirth NEVER deletes your Index, Luck, Dollars or brainrots.", 13, Color3.fromRGB(190, 200, 220))
		local buy = button(rebirthBody, "Buy", UDim2.new(0, 260, 0, 48), UDim2.new(0.5, -130, 0, 122), "🔄 REBIRTH — " .. formatMoney(REBIRTH_COSTS[level + 1]) .. " AURA", Color3.fromRGB(170, 80, 255))
		buy.TextSize = 16
		addGradient(buy, Color3.fromRGB(200, 120, 255), Color3.fromRGB(120, 50, 200))
		buy.MouseButton1Click:Connect(function()
			DoRebirth:FireServer()
			task.wait(0.4)
			openRebirthPanel()
		end)
		label(rebirthBody, "Balance", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 178), "Your Aura: " .. formatMoney(state and state.Aura or 0) .. "  •  Or hold E at the Rebirth Altar in the plaza centre.", 13, Color3.fromRGB(200, 230, 255))
	end
end

--------------------------------------------------------------------------------
-- Intro / title frame: shows once at spawn.
--------------------------------------------------------------------------------
local introFrame = panel(gui, "IntroFrame", UDim2.new(0, 560, 0, 372), UDim2.new(0.5, -280, 0.5, -186))
introFrame.BackgroundColor3 = Color3.fromRGB(22, 20, 48)
introFrame.BackgroundTransparency = 0.08
introFrame.Visible = true
local introTitle = label(introFrame, "Title", UDim2.new(1, -40, 0, 76), UDim2.new(0, 20, 0, 14), "🌸 PLAZA\nDEL DELIRIO", 34, Color3.fromRGB(255, 220, 80), Enum.Font.FredokaOne)
introTitle.TextWrapped = true
addGradient(introTitle, Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 120, 200))
addStroke(introTitle, 3, Color3.fromRGB(60, 20, 60))
label(introFrame, "Tagline", UDim2.new(1, -40, 0, 26), UDim2.new(0, 20, 0, 96), "Roll the dice. Fill your base. Rebirth.", 16, Color3.fromRGB(200, 230, 255), Enum.Font.FredokaOne)
-- v7.4: How-lines shortened so each fits its 520px row at 14pt (How2
-- and How6 were ~75 chars and spilled past the intro frame's edge).
label(introFrame, "How1", UDim2.new(1, -40, 0, 22), UDim2.new(0, 20, 0, 128), "🎲 Roll the 8 dice (Aura) — each dice gives its own tier!", 14, Color3.fromRGB(240, 240, 240))
label(introFrame, "How2", UDim2.new(1, -40, 0, 22), UDim2.new(0, 20, 0, 152), "🏠 Brainrots stand in your base and pay Aura every second", 14, Color3.fromRGB(240, 240, 240))
label(introFrame, "How3", UDim2.new(1, -40, 0, 22), UDim2.new(0, 20, 0, 176), "🎒 Every brainrot is in your backpack — press 1, 2, 3 to hold!", 14, Color3.fromRGB(240, 240, 240))
label(introFrame, "How4", UDim2.new(1, -40, 0, 22), UDim2.new(0, 20, 0, 200), "🔄 Rebirth unlocks the next dice tier + 1 base slot (4 → 10)", 14, Color3.fromRGB(240, 240, 240))
label(introFrame, "How5", UDim2.new(1, -40, 0, 22), UDim2.new(0, 20, 0, 224), "🌦️ Rare weather mutations boost values up to x12!", 14, Color3.fromRGB(240, 240, 240))
label(introFrame, "How6", UDim2.new(1, -40, 0, 22), UDim2.new(0, 20, 0, 248), "💰 Sell copies at the SELL ZONE, buy 🍀 Luck for Lucky Rolls!", 14, Color3.fromRGB(240, 240, 240))
label(introFrame, "How7", UDim2.new(1, -40, 0, 22), UDim2.new(0, 20, 0, 272), "🔒 L = lock your base 30s • Steal brainrots from rivals!", 14, Color3.fromRGB(240, 240, 240))
local playButton = button(introFrame, "Play", UDim2.new(0, 200, 0, 48), UDim2.new(0.5, -100, 0, 310), "▶  PLAY", Color3.fromRGB(40, 160, 80))
playButton.TextSize = 20
playButton.Font = Enum.Font.FredokaOne
addGradient(playButton, Color3.fromRGB(110, 235, 130), Color3.fromRGB(25, 140, 65))
addStroke(playButton, 2, Color3.fromRGB(10, 50, 20))
playButton.MouseButton1Click:Connect(function()
	introFrame.Visible = false
end)

--------------------------------------------------------------------------------
-- Wiring
--------------------------------------------------------------------------------

diceButton.MouseButton1Click:Connect(function()
	openDicePanel()
end)

-- v7.6: NO rebirth button in the HUD anymore — rebirth is via the
-- Rebirth Altar in the plaza centre (its prompt opens the panel).

-- v7.3 LOCK: fire the lock, then re-sync so the button shows the new
-- lock times. The 0.3s wait lets the server apply the lock first.
local function requestLock()
	LockBase:FireServer()
	task.wait(0.3)
	refreshState()
	refreshLockButton()
end

lockButton.MouseButton1Click:Connect(requestLock)

-- v7.4: open the inventory panel.
inventoryButton.MouseButton1Click:Connect(openInventory)

indexButton.MouseButton1Click:Connect(openIndex)

luckButton.MouseButton1Click:Connect(function()
	openShop("luck")
end)

-- Click anywhere that is not a GUI button to farm +2 Aura.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	-- v7.3: L locks your own base (same as the LOCK button).
	if input.KeyCode == Enum.KeyCode.L then
		requestLock()
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		ClickAura:FireServer()
	end
end)

local function popLabel(labelObj, big, normal)
	local pop = TweenService:Create(labelObj, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { TextSize = big })
	pop:Play()
	pop.Completed:Connect(function()
		local back = TweenService:Create(labelObj, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { TextSize = normal })
		back:Play()
	end)
end

-- Aura counter: animate on every leaderstats change + a floating popup.
auraValue.Changed:Connect(function(newValue)
	local delta = newValue - lastAuraShown
	lastAuraShown = newValue
	auraLabel.Text = formatMoney(newValue) .. " AURA"
	if delta > 0 and delta <= 100 then
		spawnPopup("+" .. tostring(delta) .. " Aura", Color3.fromRGB(255, 220, 60))
	end
	popLabel(auraLabel, 30, 26)
end)

-- Dollar counter: animate on every leaderstats change + a floating popup.
dollarValue.Changed:Connect(function(newValue)
	local delta = newValue - lastDollarShown
	lastDollarShown = newValue
	dollarLabel.Text = "$" .. formatMoney(newValue)
	if delta > 0 then
		spawnPopup("+$" .. formatMoney(delta), Color3.fromRGB(120, 255, 120))
	end
	popLabel(dollarLabel, 30, 26)
end)

ClientFX.OnClientEvent:Connect(function(kind, payload)
	if kind == "Announce" and payload then
		showBanner(payload.PlayerName .. " pulled " .. payload.CharacterName .. " (" .. payload.Rarity .. ")!", Color3.fromRGB(255, 220, 80))
	elseif kind == "RollResult" and payload then
		showResult(payload)
		-- v7.6.6: a 3D-die roll (hold E) never re-synced state, so the HUD
		-- income rate stayed stale (Yami saw +5/s while the server paid
		-- +10/s). Mirror the panel ROLL path: re-sync after the grant.
		task.spawn(function()
			task.wait(0.2)
			refreshState()
		end)
	elseif kind == "Notify" and payload then
		showBanner(payload.Text, payload.Color)
	elseif kind == "Popup" and payload then
		spawnPopup(payload.Text, payload.Color)
	elseif kind == "Weather" and payload then
		if state then
			state.Event = payload.Event
		end
		eventLeft = payload.SecondsLeft or 60
		refreshWeatherBar()
		local event = DB.Events[payload.Event] or DB.Events.Basic
		if payload.Event == "Basic" then
			showBanner("☀️ Back to Basic (x1) — no buff. Next event coming!", Color3.fromRGB(200, 230, 255))
		else
			showBanner((EVENT_EMOJI[payload.Event] or "🌦️") .. " " .. event.Name:upper() .. " x" .. tostring(event.Mult) .. " — 60 dtk! Values boosted!", Color3.fromRGB(255, 220, 80))
		end
	elseif kind == "OpenIndex" then
		openIndex()
	elseif kind == "OpenRebirth" then
		openRebirthPanel()
	elseif kind == "Cash" then
		refreshState()
	end
end)

ShopOpen.OnClientEvent:Connect(function(shop)
	openShop(shop)
end)

-- First sync.
lastAuraShown = auraValue.Value
auraLabel.Text = formatMoney(auraValue.Value) .. " AURA"
lastDollarShown = dollarValue.Value
dollarLabel.Text = "$" .. formatMoney(dollarValue.Value)
refreshState()
