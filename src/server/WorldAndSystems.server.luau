-- PLAZA DEL DELIRIO — DICE + BASE + REBIRTH (REBUILD v7).
-- The Plaza Del Delirio base (checker plaza, Moai, floating islands, Aura
-- Shrines) with the Meteor systems (37 brainrots, 6-tab Index, Sell Zone,
-- Luck Altar) — and the v7 rework, built from Yami's playtest feedback on
-- v6 (screenshot 2026-11-19 08:56 WIB):
--  * The old 15-second speed-burst button is gone entirely (Yami: "gaperlu").
--  * NO in-game collection panel — every owned brainrot is a Tool in the
--    player's Roblox Backpack (hotbar 1, 2, 3...), welded to a Handle so
--    it rides in the hand. The Index panel stays as the collection tracker.
--  * Bases hold 10 slots (2x5 grid, bigger pedestals), only 4 open at
--    Rebirth 0; each rebirth opens +1 slot (R6 = all 10). Displayed
--    brainrots are the top 10 owned by Aura/s; income still comes from
--    ALL owned copies, so a brainrot without a pedestal still pays.
--  * Brainrot display models are 2x bigger (Model:ScaleTo(2), pcall-guarded).
--  * Dice say "DICE" everywhere (never "Die") in player-facing text.
--  * Dice rolls are VISIBLE: the physical die tumbles on multiple axes,
--    hops 4 studs, glows with a Highlight, then bursts sparkles (~1.2s).
--  * Events are RANDOM, never back-to-back the same, never Basic as an
--    event: first buff 2-4 min after start, then every 3-5 min one buff
--    event runs for exactly 60s, then back to Basic (x1, no buff). Each
--    buff event has its own Lighting + particles (Summer sun, Rainy rain,
--    Cold snow, Gothic wisps, Void stars).
--  * WalkSpeed 16 -> 26 (the map is big; Yami picked faster over smaller).
--  * Friend buff: +5% Aura income per other player in the server, cap 20%.
--    Any other player counts (a real IsFriendsWith check is unreliable in
--    a solo Studio session, so it is not used).
--  * Dice-row signs no longer overlap: wider spacing (28) + staggered
--    sign heights + smaller signs. Dice-panel rows use left-aligned,
--    truncated "Inside:" lines (v6 clipped the Mythic row to "de:" because
--    the centred label overflowed both sides).
--  * Panels are top-anchored (y=170) so they never cover the HUD, and the
--    Index/Luck buttons moved to the bottom-right so they never collide
--    with the top bar.
--  * v7.2 TOP-3 PRESENTATION (no gameplay change): a giant double-sided
--    "PLAZA DEL DELIRIO" board on the north edge, above the dice row —
--    the top-1 cover pattern (huge 3D name sign, readable from spawn).
-- The starter Baseplate is DESTROYED at start: the checker floor below is
-- the only floor, so grey studs can never show through.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")

local DB = require(ReplicatedStorage:WaitForChild("BrainrotDatabase"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RollDie = Remotes:WaitForChild("RollDie")
local DoRebirth = Remotes:WaitForChild("DoRebirth")
local LockBase = Remotes:WaitForChild("LockBase")
local SetHeld = Remotes:WaitForChild("SetHeld") -- v7.4: inventory hold/equip toggle
local GetState = Remotes:WaitForChild("GetState")
local ClickAura = Remotes:WaitForChild("ClickAura")
local ClientFX = Remotes:WaitForChild("ClientFX")
local SellCopy = Remotes:WaitForChild("SellCopy")
local BuyLuck = Remotes:WaitForChild("BuyLuck")
local ShopOpen = Remotes:WaitForChild("ShopOpen")
local ClientError = Remotes:WaitForChild("ClientError") -- v7.1: clients report silent waits here

local rng = Random.new()

--------------------------------------------------------------------------------
-- Constants
--------------------------------------------------------------------------------
local STARTING_AURA = 100
local CLICK_AURA = 2
local CLICK_COOLDOWN = 0.25
local SHRINE_AURA_PER_SEC = 20
local NORMAL_SPEED = 26
local LUCK_COSTS = { 1000, 3000, 8000, 20000, 50000 }
local MAX_LUCK = 5
-- One completed Index tab (37/37) grants +10% passive Aura income, forever.
local INDEX_BONUS_PER_TAB = 0.10
-- Friend buff: +5% Aura income per OTHER player in the server, cap 20%.
local FRIEND_BONUS_PER_PLAYER = 0.05
local FRIEND_BONUS_CAP = 0.20
-- Dice prices (Aura only, x10 per tier — Yami: "jauh lebih mahal").
local DICE_COSTS = {
	Common = 100, Uncommon = 1000, Rare = 10000, Epic = 100000,
	Legendary = 1000000, Mythic = 10000000, Secret = 100000000,
	Godly = 1000000000,
}
-- Rebirth costs (Aura): level 0 -> 1 costs 5,000, ... level 6 -> 7 costs 50M.
local REBIRTH_COSTS = { 5000, 25000, 125000, 500000, 2500000, 10000000, 50000000 }
local MAX_REBIRTH = 7
-- Each rebirth adds +50% passive Aura income, stacking.
local REBIRTH_INCOME_BONUS = 0.5
local MAX_BASES = 10
-- Base slots: 10 total, 4 open at Rebirth 0, +1 per rebirth (R6 = all 10).
local BASE_SLOTS = 10
local BASE_SLOTS_OPEN_AT_START = 4
-- Display models on bases are 2x (Yami: v6 was too small).
local BASE_MODEL_SCALE = 2
-- v7.6.4 HELD SCALE: a 1x model in the hand sits ~2-3 studs from the
-- camera and LOOMS larger on screen than a 2x base model viewed from
-- 10-20 studs away (Yami: "ukurannya jadi gede"). 0.5x at hand distance
-- reads on-screen the same size as a 2x model in the base, so held and
-- base models finally look the same size. Applies to Tools (giveTool)
-- and carried steals (attachCarryModel) alike.
local HELD_MODEL_SCALE = 0.5
-- Lucky Roll: +2% per Luck level (max 10% at Lv 5) — the result jumps one tier.
local LUCKY_ROLL_PER_LEVEL = 0.02
-- Buff events (Basic is NOT an event — it is the calm default, x1, no buff).
local BUFF_EVENTS = { "Summer", "Rainy", "Cold", "Gothic", "Void" }
local EVENT_DURATION = 60 -- seconds a buff event runs
local EVENT_FIRST_DELAY_MIN = 240 -- first buff 4-6 min after server start
local EVENT_FIRST_DELAY_MAX = 360
local EVENT_GAP_MIN = 300 -- 5-8 min of Basic between cycles
local EVENT_GAP_MAX = 480
-- v7.6: mutations are RARE — only ~25% of cycles get a buff event at all.
local MUTATION_CHANCE = 0.25

-- Passive Aura/s a brainrot in the base pays, by rarity. (v7.5: the old
-- per-character override table was deleted — every brainrot pays its
-- rarity rate, and no override name exists in the new roster.)
local AURA_PER_SEC_BY_RARITY = {
	Common = 5, Uncommon = 20, Rare = 75, Epic = 250,
	Legendary = 1000, Mythic = 5000, Secret = 25000, Godly = 100000,
}

local function auraPerSec(name)
	local ch = DB.GetCharacter(name)
	if ch then
		return AURA_PER_SEC_BY_RARITY[ch.Rarity] or 5
	end
	return 5
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

--------------------------------------------------------------------------------
-- World building
--------------------------------------------------------------------------------

local World = Instance.new("Folder")
World.Name = "World"
World.Parent = workspace

local Zones = Instance.new("Folder")
Zones.Name = "Zones"
Zones.Parent = workspace

local BasesFolder = Instance.new("Folder")
BasesFolder.Name = "Bases"
BasesFolder.Parent = workspace

local function part(name, size, cframe, color, material, shape, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent or World
	return p
end

-- Small world sign: title + subtitle on a real 3D board above a zone.
-- Size 200x56 and a `height` offset: the dice row staggers heights
-- (5.5 / 8.5) so neighbouring signs never stack into a wall of text
-- (the v6 bug Yami screenshotted — "UNCOMMON DIE" over "EPIC DIE").
-- Labels are named Title/Sub so base signs can be updated per owner.
local function sign(anchorPart, title, sub, color, height)
	local g = Instance.new("BillboardGui")
	g.Name = "Sign"
	g.Size = UDim2.fromOffset(200, 56)
	g.StudsOffsetWorldSpace = Vector3.new(0, height or 5.5, 0)
	g.AlwaysOnTop = false
	g.Adornee = anchorPart
	g.Parent = anchorPart
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.Size = UDim2.new(1, 0, 0.55, 0)
	t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne
	t.TextSize = 16
	t.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	t.TextStrokeTransparency = 0.3
	t.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	t.Text = title
	t.Parent = g
	local s = Instance.new("TextLabel")
	s.Name = "Sub"
	s.Size = UDim2.new(1, 0, 0.45, 0)
	s.Position = UDim2.new(0, 0, 0.55, 0)
	s.BackgroundTransparency = 1
	s.Font = Enum.Font.GothamBold
	s.TextSize = 11
	s.TextColor3 = Color3.fromRGB(240, 240, 240)
	s.TextStrokeTransparency = 0.3
	s.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	s.Text = sub
	s.Parent = g
	return g
end

local function prompt(anchorPart, actionText, hold)
	local pr = Instance.new("ProximityPrompt")
	pr.ActionText = actionText
	pr.ObjectText = anchorPart.Name
	pr.HoldDuration = hold or 0.5
	pr.MaxActivationDistance = 14
	pr.RequiresLineOfSight = false
	pr.Parent = anchorPart
	return pr
end

-- v7.1 HARDENING (Yami 2026-11-19 12:51 WIB: world built, UI total zero —
-- a silent failure must never happen again): every world-build section
-- below runs inside safeSection (pcall + warn), so one bad section can
-- never kill the whole server script — PlayerAdded is always connected
-- and leaderstats always exist. Locals that later code needs are hoisted
-- here (declared now, assigned inside their section).
-- Base lock + steal (v7.3 STEAL & DEFEND): lock your own base for 30s;
-- after it ends, a 60s cooldown runs before you can lock again. After a
-- successful steal, the thief waits 30s before stealing again.
local LOCK_DURATION = 30
local LOCK_COOLDOWN = 60
local STEAL_COOLDOWN = 30
-- Bigger bases (v7.3): slab 44x32 (was 30x28); pedestals 4.6 studs.
local BASE_HALF_W = 22
local BASE_HALF_D = 16
local magenta
local cyan
local ShrineCenters = {} -- {} by default, so the income loop never errors even if section 8 fails
local altarChest
local altarLid
local altarLidClosed
local altarOrb
local WeatherPart
local SunBall
local Dice = {}
local Bases = {}
local setBaseSign

local function safeSection(name, fn)
	local ok, err = pcall(fn)
	if not ok then
		warn("[Plaza] World section failed (" .. name .. "): " .. tostring(err) .. " — continuing without it.")
	end
end

-- 1. The starter Baseplate goes first: the checker floor is the only floor.
safeSection("Baseplate", function()
	local starterPlate = workspace:FindFirstChild("Baseplate")
if starterPlate then
	starterPlate:Destroy()
end
end)

-- 2. Checker floor: 16 x 16 pastel-lavender and white tiles, 256 x 256 studs.
safeSection("Checker floor", function()
	local lavender = Color3.fromRGB(205, 180, 255)
local whiteTile = Color3.fromRGB(250, 245, 255)
for ix = 0, 15 do
	for iz = 0, 15 do
		local color = lavender
		if (ix + iz) % 2 == 0 then
			color = whiteTile
		end
		part("FloorTile", Vector3.new(16, 1, 16), CFrame.new(-120 + ix * 16, -0.5, -120 + iz * 16), color, Enum.Material.SmoothPlastic)
	end
end
end)

-- 3. Neon border around the plaza — with 12-stud gaps at each base
-- entrance (z = -64, -32, 0, 32, 64) so players can walk to their base.
safeSection("Neon border", function()
	magenta = Color3.fromRGB(255, 60, 200)
	cyan = Color3.fromRGB(60, 230, 255)
part("BorderN", Vector3.new(258, 1, 2), CFrame.new(0, 0.5, -129), magenta, Enum.Material.Neon)
part("BorderS", Vector3.new(258, 1, 2), CFrame.new(0, 0.5, 129), cyan, Enum.Material.Neon)
local borderEdges = { -129, -70, -58, -38, -26, -6, 6, 26, 38, 58, 70, 129 }
for _, sideX in ipairs({ -129, 129 }) do
	local color = cyan
	if sideX > 0 then
		color = magenta
	end
	for i = 1, #borderEdges, 2 do
		local z0, z1 = borderEdges[i], borderEdges[i + 1]
		part("Border", Vector3.new(2, 1, z1 - z0), CFrame.new(sideX, 0.5, (z0 + z1) / 2), color, Enum.Material.Neon)
	end
end
end)

-- 4. Spawn pad on the south edge.
safeSection("Spawn pad", function()
	local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Size = Vector3.new(14, 1, 14)
spawn.CFrame = CFrame.new(0, 0.5, 105)
spawn.Color = Color3.fromRGB(140, 255, 150)
spawn.Material = Enum.Material.SmoothPlastic
spawn.Anchored = true
spawn.Neutral = true
spawn.Duration = 0
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.BottomSurface = Enum.SurfaceType.Smooth
spawn.Parent = World
end)

-- 5. Floating islands around the plaza (disc + underside + obelisk + light).
safeSection("Floating islands", function()
	local islandSpots = {
	{ pos = Vector3.new(-150, 30, -80), tint = Color3.fromRGB(180, 220, 255) },
	{ pos = Vector3.new(150, 38, -60), tint = Color3.fromRGB(255, 200, 230) },
	{ pos = Vector3.new(-130, 45, 90), tint = Color3.fromRGB(200, 255, 200) },
	{ pos = Vector3.new(140, 28, 110), tint = Color3.fromRGB(255, 230, 170) },
	{ pos = Vector3.new(0, 50, -160), tint = Color3.fromRGB(220, 190, 255) },
}
for i, spot in ipairs(islandSpots) do
	local top = part("IslandTop" .. tostring(i), Vector3.new(3, 28, 28), CFrame.new(spot.pos) * CFrame.Angles(0, 0, math.rad(90)), spot.tint, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	top.CanCollide = false
	local under = part("IslandUnder" .. tostring(i), Vector3.new(2, 16, 16), CFrame.new(spot.pos.X, spot.pos.Y - 5, spot.pos.Z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(140, 110, 180), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	under.CanCollide = false
	local obelisk = part("Obelisk" .. tostring(i), Vector3.new(3, 10, 3), CFrame.new(spot.pos.X, spot.pos.Y + 6.5, spot.pos.Z), Color3.fromRGB(255, 255, 255), Enum.Material.Neon)
	obelisk.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Color = spot.tint
	glow.Brightness = 1.5
	glow.Range = 30
	glow.Parent = obelisk
end
end)

-- 6. Giant Moai head with pixel sunglasses, north edge.
safeSection("Moai", function()
	local stone = Color3.fromRGB(150, 150, 150)
local moaiBase = part("MoaiBase", Vector3.new(18, 2, 14), CFrame.new(0, 1, -115), stone, Enum.Material.SmoothPlastic)
local moaiHead = part("MoaiHead", Vector3.new(12, 18, 8), CFrame.new(0, 12, -115), stone, Enum.Material.SmoothPlastic)
local moaiNose = part("MoaiNose", Vector3.new(2, 5, 2), CFrame.new(0, 11, -110.5), Color3.fromRGB(130, 130, 130), Enum.Material.SmoothPlastic)
local moaiBrow = part("MoaiBrow", Vector3.new(10, 1.5, 1), CFrame.new(0, 18.5, -110.5), Color3.fromRGB(130, 130, 130), Enum.Material.SmoothPlastic)
local black = Color3.fromRGB(15, 15, 15)
local glassL = part("MoaiGlassL", Vector3.new(3.6, 2.2, 0.6), CFrame.new(-2.6, 16.5, -110.6), black, Enum.Material.SmoothPlastic)
local glassR = part("MoaiGlassR", Vector3.new(3.6, 2.2, 0.6), CFrame.new(2.6, 16.5, -110.6), black, Enum.Material.SmoothPlastic)
local glassBridge = part("MoaiGlassBridge", Vector3.new(2.2, 0.8, 0.6), CFrame.new(0, 16.5, -110.6), black, Enum.Material.SmoothPlastic)
end)

-- 7. Tilted Greek pillars ringing the plaza.
safeSection("Pillars", function()
	local pillarAngles = { 20, 70, 130, 200, 250, 320 }
for i, deg in ipairs(pillarAngles) do
	local rad = math.rad(deg)
	local x = math.cos(rad) * 100
	local z = math.sin(rad) * 100
	local tilt = 0.12
	if i % 2 == 0 then
		tilt = -0.12
	end
	local base = part("PillarBase" .. tostring(i), Vector3.new(5, 1, 5), CFrame.new(x, 0.5, z), Color3.fromRGB(240, 235, 225), Enum.Material.SmoothPlastic)
	local column = part("Pillar" .. tostring(i), Vector3.new(3.5, 24, 3.5), CFrame.new(x, 13, z) * CFrame.Angles(0, 0, tilt), Color3.fromRGB(245, 240, 230), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local capital = part("PillarCap" .. tostring(i), Vector3.new(6, 1.5, 6), CFrame.new(x, 25.5, z) * CFrame.Angles(0, 0, tilt), Color3.fromRGB(240, 235, 225), Enum.Material.SmoothPlastic)
end
end)

-- 8. Aura Shrines: glowing pads; standing inside harvests +20 Aura/s.
safeSection("Aura Shrines", function()
	ShrineCenters = {
	Vector3.new(-80, 0, -60),
	Vector3.new(80, 0, -60),
}
local shrineColors = { cyan, magenta }
for i, center in ipairs(ShrineCenters) do
	local pad = part("ShrinePad" .. tostring(i), Vector3.new(1, 18, 18), CFrame.new(center.X, 0.5, center.Z) * CFrame.Angles(0, 0, math.rad(90)), shrineColors[i], Enum.Material.Neon, Enum.PartType.Cylinder)
	pad.CanCollide = false
	local beam = part("ShrineBeam" .. tostring(i), Vector3.new(30, 16, 16), CFrame.new(center.X, 15, center.Z) * CFrame.Angles(0, 0, math.rad(90)), shrineColors[i], Enum.Material.Neon, Enum.PartType.Cylinder)
	beam.Transparency = 0.75
	beam.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = shrineColors[i]
	light.Brightness = 2
	light.Range = 24
	light.Parent = pad
end
end)

-- 9. Rebirth Altar at the centre (the old central altar, rebuilt as the
-- rebirth gate): pedestal, chest with a tweened lid, a floating orb, and a
-- sign so players can see it from spawn. Hold E on the chest to rebirth.
safeSection("Rebirth Altar", function()
	local altarBase = part("AltarBase", Vector3.new(2, 16, 16), CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(245, 240, 230), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
altarChest = part("AltarChest", Vector3.new(6, 3, 6), CFrame.new(0, 3.5, 0), Color3.fromRGB(150, 80, 200), Enum.Material.SmoothPlastic)
altarLid = part("AltarLid", Vector3.new(6.4, 0.8, 6.4), CFrame.new(0, 5.4, 0), Color3.fromRGB(255, 220, 60), Enum.Material.Neon)
altarLidClosed = altarLid.CFrame
altarOrb = Instance.new("Part")
altarOrb.Name = "AltarOrb"
altarOrb.Size = Vector3.new(4, 4, 4)
altarOrb.CFrame = CFrame.new(0, 10, 0)
altarOrb.Color = magenta
altarOrb.Material = Enum.Material.Neon
altarOrb.Anchored = true
altarOrb.CanCollide = false
altarOrb.Shape = Enum.PartType.Ball
altarOrb.TopSurface = Enum.SurfaceType.Smooth
altarOrb.BottomSurface = Enum.SurfaceType.Smooth
altarOrb.Parent = World
local altarLight = Instance.new("PointLight")
altarLight.Color = magenta
altarLight.Brightness = 2
altarLight.Range = 30
altarLight.Parent = altarOrb

local altarTag = Instance.new("BillboardGui")
altarTag.Name = "AltarSign"
altarTag.Size = UDim2.fromOffset(220, 60)
altarTag.AlwaysOnTop = false
altarTag.LightInfluence = 0
altarTag.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
altarTag.Adornee = altarOrb
altarTag.Parent = World
local altarTitle = Instance.new("TextLabel")
altarTitle.Size = UDim2.new(1, 0, 0, 26)
altarTitle.BackgroundTransparency = 1
altarTitle.Font = Enum.Font.GothamBlack
altarTitle.TextSize = 20
altarTitle.TextColor3 = Color3.fromRGB(255, 220, 60)
altarTitle.TextStrokeTransparency = 0.3
altarTitle.Text = "REBIRTH ALTAR"
altarTitle.Parent = altarTag
local altarSub = Instance.new("TextLabel")
altarSub.Size = UDim2.new(1, 0, 0, 22)
altarSub.Position = UDim2.new(0, 0, 0, 26)
altarSub.BackgroundTransparency = 1
altarSub.Font = Enum.Font.GothamBold
altarSub.TextSize = 16
altarSub.TextColor3 = Color3.fromRGB(255, 255, 255)
altarSub.TextStrokeTransparency = 0.3
altarSub.Text = "Unlock the next dice tier"
altarSub.Parent = altarTag
end)

-- 10. WeatherPart: one high invisible sheet carrying the weather
-- particles. The event cycle enables exactly one emitter per event.
safeSection("Weather", function()
	WeatherPart = Instance.new("Part")
WeatherPart.Name = "WeatherPart"
WeatherPart.Size = Vector3.new(500, 1, 500)
WeatherPart.Position = Vector3.new(0, 140, 0)
WeatherPart.Anchored = true
WeatherPart.CanCollide = false
WeatherPart.CanQuery = false
WeatherPart.CanTouch = false
WeatherPart.Transparency = 1
WeatherPart.Parent = World

local function weatherEmitter(name, color, rate, speed, size, spread, dir)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Color = ColorSequence.new(color)
	e.Rate = rate
	e.Lifetime = NumberRange.new(2.5, 3.5)
	e.Speed = NumberRange.new(speed, speed + 10)
	e.Size = NumberSequence.new(size)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.EmissionDirection = dir or Enum.NormalId.Bottom
	e.Enabled = false
	e.Parent = WeatherPart
	return e
end
-- Rain falls fast and dense; snow drifts slow and wide; summer embers
-- float warm; gothic wisps RISE (purple, slow); void stars twinkle down.
weatherEmitter("RainEmitter", Color3.fromRGB(140, 180, 255), 1200, 80, 0.3, 4)
weatherEmitter("SnowEmitter", Color3.fromRGB(255, 255, 255), 700, 12, 0.7, 25)
weatherEmitter("EmberEmitter", Color3.fromRGB(255, 200, 80), 400, 8, 0.6, 30)
weatherEmitter("StarEmitter", Color3.fromRGB(190, 130, 255), 300, 6, 0.5, 35)
weatherEmitter("WispEmitter", Color3.fromRGB(170, 90, 255), 200, 5, 0.8, 30, Enum.NormalId.Top)

-- 10b. Summer sun: a big glowing ball high in the sky, visible ONLY
-- during the Summer event (the sky itself turns warm and bright too).
SunBall = Instance.new("Part")
SunBall.Name = "SunBall"
SunBall.Size = Vector3.new(20, 20, 20)
SunBall.Shape = Enum.PartType.Ball
SunBall.CFrame = CFrame.new(0, 130, -120)
SunBall.Color = Color3.fromRGB(255, 220, 80)
SunBall.Material = Enum.Material.Neon
SunBall.Anchored = true
SunBall.CanCollide = false
SunBall.CanQuery = false
SunBall.CanTouch = false
SunBall.Visible = false
SunBall.Parent = World
local sunLight = Instance.new("PointLight")
sunLight.Color = Color3.fromRGB(255, 200, 100)
sunLight.Brightness = 2
sunLight.Range = 200
sunLight.Parent = SunBall
end)

-- 11. The two shops (MERGE v5), south half of the plaza so they are
-- visible from spawn and clear of the altar, the shrines and the Moai.
-- Zone pads sit ON the floor (bottom y = +0.05, top y = +0.35) — never
-- coplanar with the checker tiles, so no Z-fighting (the v4.1 lesson).
safeSection("Shops", function()
	local function zone(name, size, pos, color, title, sub, actionText)
	local z = part(name, size, CFrame.new(pos), color, Enum.Material.SmoothPlastic, nil, Zones)
	z.CanCollide = false
	z.CanTouch = true
	sign(z, title, sub, Color3.fromRGB(255, 255, 255))
	prompt(z, actionText, 0.5)
	return z
end

-- Sell Zone: south-west, gold pad + a little coin stack.
zone("SellZone", Vector3.new(24, 0.3, 16), Vector3.new(-80, 0.2, 70),
	Color3.fromRGB(255, 200, 60), "SELL ZONE", "Sell brainrots for $", "Sell Best Copy")
local coinBase = part("SellCoinBase", Vector3.new(4, 1, 4), CFrame.new(-88, 0.5, 62), Color3.fromRGB(200, 150, 40), Enum.Material.SmoothPlastic)
local coinStack = part("SellCoinStack", Vector3.new(2.6, 2.4, 2.6), CFrame.new(-88, 1.7, 62), Color3.fromRGB(255, 210, 60), Enum.Material.Neon, Enum.PartType.Cylinder)

-- Luck Altar: south-east, purple pad + stone base + crystal.
local luckBase = part("LuckAltarBase", Vector3.new(12, 2, 12), CFrame.new(80, 1, 70), Color3.fromRGB(120, 110, 130), Enum.Material.Slate)
local luckCrystal = part("LuckCrystal", Vector3.new(3, 6, 3), CFrame.new(80, 5, 70), Color3.fromRGB(170, 80, 255), Enum.Material.Neon)
luckCrystal.CFrame = CFrame.new(80, 5, 70) * CFrame.Angles(0, math.rad(45), 0)
zone("LuckZone", Vector3.new(16, 0.3, 16), Vector3.new(80, 0.2, 70),
	Color3.fromRGB(170, 80, 255), "LUCK ALTAR", "Buy Meteor Luck with $", "Open Luck Shop")
end)

--------------------------------------------------------------------------------
-- 12. DICE ROW (v6, reworked v7): 8 big dice across the north of the
-- plaza (z = -80, clear of the Moai, shrines and pillars). One die per
-- rarity tier; a die only ever gives brainrots of its own tier. Pip count
-- = tier number (1 Common ... 8 Godly). Hold E on a die to roll it for
-- Aura (gated by Rebirth level). v7: dice spread 28 studs apart and the
-- signs alternate heights (5.5 / 8.5) so they can never stack on top of
-- each other from the plaza camera — the v6 overlap Yami screenshotted.
-- Player-facing text says "DICE", never "Die".
--------------------------------------------------------------------------------

safeSection("Dice row", function()
-- Pip layouts on the 4x4 top face (x, z offsets in studs).
local PIP_LAYOUTS = {
	{ { 0, 0 } },
	{ { -1.2, -1.2 }, { 1.2, 1.2 } },
	{ { -1.2, -1.2 }, { 0, 0 }, { 1.2, 1.2 } },
	{ { -1.2, -1.2 }, { 1.2, -1.2 }, { -1.2, 1.2 }, { 1.2, 1.2 } },
	{ { -1.2, -1.2 }, { 1.2, -1.2 }, { 0, 0 }, { -1.2, 1.2 }, { 1.2, 1.2 } },
	{ { -1.2, -1.2 }, { -1.2, 0 }, { -1.2, 1.2 }, { 1.2, -1.2 }, { 1.2, 0 }, { 1.2, 1.2 } },
	{ { -1.2, -1.2 }, { -1.2, 0 }, { -1.2, 1.2 }, { 0, 0 }, { 1.2, -1.2 }, { 1.2, 0 }, { 1.2, 1.2 } },
	{ { -1.2, -1.2 }, { -1.2, 0 }, { -1.2, 1.2 }, { 0, -1.2 }, { 0, 1.2 }, { 1.2, -1.2 }, { 1.2, 0 }, { 1.2, 1.2 } },
}

-- Dice is hoisted above section 1 (v7.1) — the table already exists.

local function buildDiceRow()
	for i, tier in ipairs(DB.RarityOrder) do
		local x = -98 + (i - 1) * 28
		local z = -80
		local rc = DB.RarityColors[tier]
		local cost = DICE_COSTS[tier]
		-- Low platform so the die reads as a monument, not floor clutter.
		local platform = part("DicePlatform" .. tier, Vector3.new(7, 0.4, 7), CFrame.new(x, 0.2, z), Color3.fromRGB(245, 240, 230), Enum.Material.SmoothPlastic)
		platform.CanCollide = false
		-- The die itself: a Model so PivotTo moves cube + pips together.
		local dieModel = Instance.new("Model")
		dieModel.Name = "Die" .. tier
		dieModel.Parent = World
		local cube = Instance.new("Part")
		cube.Name = "Cube"
		cube.Size = Vector3.new(4, 4, 4)
		cube.CFrame = CFrame.new(x, 2.4, z)
		cube.Color = Color3.fromRGB(250, 250, 250)
		cube.Material = Enum.Material.SmoothPlastic
		cube.Anchored = true
		cube.CanCollide = true
		cube.TopSurface = Enum.SurfaceType.Smooth
		cube.BottomSurface = Enum.SurfaceType.Smooth
		cube.Parent = dieModel
		dieModel.PrimaryPart = cube
		for _, off in ipairs(PIP_LAYOUTS[i]) do
			local pip = Instance.new("Part")
			pip.Name = "Pip"
			pip.Size = Vector3.new(0.7, 0.7, 0.7)
			pip.Shape = Enum.PartType.Ball
			pip.Color = rc
			pip.Material = Enum.Material.Neon
			pip.Anchored = true
			pip.CanCollide = false
			pip.TopSurface = Enum.SurfaceType.Smooth
			pip.BottomSurface = Enum.SurfaceType.Smooth
			pip.CFrame = CFrame.new(x + off[1], 4.45, z + off[2])
			pip.Parent = dieModel
		end
		local lockText = ""
		if i > 1 then
			lockText = " • 🔒 Rebirth " .. tostring(i - 1)
		end
		-- Staggered sign heights: odd dice 5.5, even dice 8.5.
		local signHeight = 5.5
		if i % 2 == 0 then
			signHeight = 8.5
		end
		sign(cube, "🎲 " .. tier:upper() .. " DICE", "Roll — " .. formatMoney(cost) .. " Aura" .. lockText, rc, signHeight)
		prompt(cube, "Roll " .. tier .. " Dice", 0.5)
		Dice[tier] = { model = dieModel, baseCFrame = CFrame.new(x, 2.4, z), busy = false, tier = tier }
	end
end
buildDiceRow()
end)

-- 12b. GROUND APRONS AROUND THE BASES (v7.6.5): the base slabs (44 wide,
-- centred x=±141) stick out 35 studs past the plaza floor edge (x=±128),
-- and beyond each base back wall (x=±163) there was only sky — Yami
-- circled both spots ("kasih tambahan dasaran lagi biar ga tembus").
-- Each apron is one solid slab, top y=0 (flush with the plaza floor,
-- 0.1 below the base-slab top so their faces never Z-fight), spanning
-- x 128..192 (29 studs past the back wall) and the full plaza depth
-- z -128..128. Walkable (CanCollide=true, Anchored=true via part()).
-- It runs UNDER the slab overhang — the slab bottom (y=-0.3) is
-- embedded 0.3 into the apron — so there is no see-through gap under
-- any base, and no void visible just past a base. Lavender, same as
-- the checker tiles, so it reads as the plaza's margin.
safeSection("Ground aprons around bases", function()
	for _, dir in ipairs({ -1, 1 }) do
		part("GroundApron", Vector3.new(64, 2, 256), CFrame.new(dir * 160, -1, 0), Color3.fromRGB(205, 180, 255), Enum.Material.SmoothPlastic)
	end
end)

--------------------------------------------------------------------------------
-- 13. PERSONAL BASES (v6, reworked v7): 10 bases around the plaza, 5 west
-- + 5 east, each with 10 pedestal slots in a 2x5 grid (pedestals are
-- bigger now: 3.4-stud cylinders, top y = 1.1). Only 4 slots are open at
-- Rebirth 0; each rebirth opens +1 (R6 = all 10). Displayed brainrots are
-- the player's top 10 by Aura/s — a brainrot without a pedestal still
-- pays its passive income (income is computed from Copies, never from
-- the displayed models). Owned models stand anchored and slowly spin —
-- never PivotTo'd while unanchored, so no flicker (the v5 follow bug,
-- fixed architecturally). Models are 2x (Model:ScaleTo, pcall-guarded).
--------------------------------------------------------------------------------

safeSection("Personal bases", function()
-- Bases is hoisted above section 1 (v7.1) — the table already exists.
local BASE_ZS = { -96, -48, 0, 48, 96 }
local BASE_SLOT_COLS = { -9, 9 }
local BASE_SLOT_ROWS = { -12, -6, 0, 6, 12 }

-- v7.3 BASE DECOR: the same decoration template on every base so no base
-- reads as an empty slab — tall fence (3 sides, front open; side walls
-- glass in v7.6.4 so small brainrots stay visible), 2 torch posts
-- with lights at the front corners, a flag with the owner's name, a carpet
-- runner + welcome mat, 2 potted plants at the back, and a lit entrance
-- arch. All decor is CanCollide=false (never blocks walking in/out) and
-- the part count is small (~26/base) so 10 bases stay cheap.
local function decorateBase(folder, sideX, centerZ)
	local dir = math.sign(sideX) -- +1 east, -1 west; front (plaza side) is -dir in X
	local frontX = sideX - dir * BASE_HALF_W
	local backX = sideX + dir * BASE_HALF_W
	local wallColor = Color3.fromRGB(70, 55, 110)
	local gold = Color3.fromRGB(240, 220, 140)
	-- Tall fence (6 studs): back wall + 2 side walls (inset 1 stud so
	-- neighbouring bases never share a coplanar wall). Front stays
	-- open (entrance).
	local backWall = part("BaseWallBack", Vector3.new(0.6, 6, BASE_HALF_D * 2), CFrame.new(backX - dir * 0.3, 3.1, centerZ), wallColor, Enum.Material.SmoothPlastic, nil, folder)
	backWall.CanCollide = false
	for _, dz in ipairs({ -1, 1 }) do
		-- v7.6.4: glass (see-through) so small brainrots stay visible
		-- from the side — a 6-stud opaque wall would hide them. Walls
		-- stay 6 studs tall (Yami asked for tall walls); only the
		-- material changed. CanCollide stays false.
		local side = part("BaseWallSide", Vector3.new(BASE_HALF_W * 2, 6, 0.6), CFrame.new(sideX, 3.1, centerZ + dz * (BASE_HALF_D - 1)), wallColor, Enum.Material.Glass, nil, folder)
		side.CanCollide = false
		side.Transparency = 0.5
	end
	-- Torches at the 2 front corners (post + neon flame + light).
	local torchColor = Color3.fromRGB(255, 170, 60)
	for _, dz in ipairs({ -1, 1 }) do
		local tx = frontX + dir * 1
		-- v7.6.4: moved 2 studs inward (was BASE_HALF_D - 1, the same z
		-- as the side wall — the post + flame were swallowed by the
		-- 6-stud wall) and raised to ~7 studs so the flame (y 7.5)
		-- clears the wall top (6.1) and is visible from the plaza.
		local tz = centerZ + dz * (BASE_HALF_D - 3)
		local post = part("TorchPost", Vector3.new(0.5, 7, 0.5), CFrame.new(tx, 3.6, tz), Color3.fromRGB(90, 60, 40), Enum.Material.SmoothPlastic, nil, folder)
		post.CanCollide = false
		local flame = part("TorchFlame", Vector3.new(0.9, 0.9, 0.9), CFrame.new(tx, 7.5, tz), torchColor, Enum.Material.Neon, Enum.PartType.Ball, folder)
		flame.CanCollide = false
		local light = Instance.new("PointLight")
		light.Color = torchColor
		light.Brightness = 1.5
		light.Range = 12
		light.Parent = flame
	end
	-- Back-corner posts (plain, no light) + potted plants.
	for _, dz in ipairs({ -1, 1 }) do
		local bx = backX - dir * 1
		-- v7.6.4: moved 2 studs inward (was BASE_HALF_D - 1, the same z
		-- as the side wall — the post was swallowed by it).
		local bz = centerZ + dz * (BASE_HALF_D - 3)
		local bpost = part("BackPost", Vector3.new(0.5, 2.4, 0.5), CFrame.new(bx, 1.3, bz), gold, Enum.Material.SmoothPlastic, nil, folder)
		bpost.CanCollide = false
		local bball = part("BackPostTop", Vector3.new(0.8, 0.8, 0.8), CFrame.new(bx, 2.9, bz), Color3.fromRGB(255, 60, 200), Enum.Material.Neon, Enum.PartType.Ball, folder)
		bball.CanCollide = false
		local pot = part("PlantPot", Vector3.new(1.2, 1.0, 1.2), CFrame.new(backX - dir * 4, 0.6, centerZ + dz * (BASE_HALF_D - 4)), Color3.fromRGB(160, 90, 60), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, folder)
		pot.CanCollide = false
		local leaves = part("PlantLeaves", Vector3.new(1.6, 1.6, 1.6), CFrame.new(backX - dir * 4, 1.8, centerZ + dz * (BASE_HALF_D - 4)), Color3.fromRGB(60, 200, 90), Enum.Material.SmoothPlastic, Enum.PartType.Ball, folder)
		leaves.CanCollide = false
	end
	-- Flag with the owner's name (label updated by setBaseSign).
	local flagX = frontX + dir * 2
	local flagZ = centerZ + 8
	local pole = part("FlagPole", Vector3.new(0.4, 7, 0.4), CFrame.new(flagX, 3.6, flagZ), gold, Enum.Material.SmoothPlastic, nil, folder)
	pole.CanCollide = false
	local clothColor = dir > 0 and Color3.fromRGB(255, 60, 200) or Color3.fromRGB(60, 230, 255)
	local cloth = part("FlagCloth", Vector3.new(0.15, 1.5, 2.6), CFrame.new(flagX - dir * 1.3, 6.2, flagZ), clothColor, Enum.Material.SmoothPlastic, nil, folder)
	cloth.CanCollide = false
	local flagGui = Instance.new("BillboardGui")
	flagGui.Name = "FlagSign"
	flagGui.Size = UDim2.fromOffset(140, 28)
	flagGui.StudsOffsetWorldSpace = Vector3.new(0, 1.2, 0)
	flagGui.AlwaysOnTop = false
	flagGui.Adornee = pole
	flagGui.Parent = pole
	local flagLabel = Instance.new("TextLabel")
	flagLabel.Name = "Owner"
	flagLabel.Size = UDim2.new(1, 0, 1, 0)
	flagLabel.BackgroundTransparency = 1
	flagLabel.Font = Enum.Font.FredokaOne
	flagLabel.TextSize = 15
	flagLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	flagLabel.TextStrokeTransparency = 0.3
	flagLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	flagLabel.Text = "Unclaimed"
	flagLabel.Parent = flagGui
	-- Carpet runner + welcome mat (the mat sits 0.06 above the carpet top
	-- so their top faces never Z-fight).
	local carpet = part("Carpet", Vector3.new(24, 0.1, 6), CFrame.new(sideX - dir * 10, 0.15, centerZ), Color3.fromRGB(200, 60, 90), Enum.Material.SmoothPlastic, nil, folder)
	carpet.CanCollide = false
	local mat = part("WelcomeMat", Vector3.new(8, 0.06, 5), CFrame.new(frontX + dir * 4, 0.23, centerZ), Color3.fromRGB(255, 220, 60), Enum.Material.SmoothPlastic, nil, folder)
	mat.CanCollide = false
	-- Lit entrance arch: 2 posts + beam + 3 hanging orbs (all high,
	-- players walk under freely).
	for _, dz in ipairs({ -1, 1 }) do
		local ax = frontX + dir * 0.5
		local az = centerZ + dz * (BASE_HALF_D - 2)
		local apost = part("ArchPost", Vector3.new(0.6, 8, 0.6), CFrame.new(ax, 4.1, az), gold, Enum.Material.SmoothPlastic, nil, folder)
		apost.CanCollide = false
	end
	local beam = part("ArchBeam", Vector3.new(0.6, 0.6, (BASE_HALF_D - 2) * 2), CFrame.new(frontX + dir * 0.5, 8.2, centerZ), Color3.fromRGB(240, 220, 140), Enum.Material.SmoothPlastic, nil, folder)
	beam.CanCollide = false
	for i, dz in ipairs({ -0.6, 0, 0.6 }) do
		local orb = part("ArchOrb" .. tostring(i), Vector3.new(0.7, 0.7, 0.7), CFrame.new(frontX + dir * 0.5, 7.2, centerZ + dz * (BASE_HALF_D - 2)), Color3.fromRGB(255, 220, 80), Enum.Material.Neon, Enum.PartType.Ball, folder)
		orb.CanCollide = false
	end
	-- Lock barrier (v7.3 DEFENSE): a red shield wall across the front
	-- entrance, invisible until the base is locked.
	local barrier = part("LockBarrier", Vector3.new(0.5, 8, BASE_HALF_D * 2), CFrame.new(frontX + dir * 0.5, 4.1, centerZ), Color3.fromRGB(255, 40, 60), Enum.Material.Neon, nil, folder)
	barrier.CanCollide = false
	barrier.Transparency = 1
	local lockGui = Instance.new("BillboardGui")
	lockGui.Name = "LockSign"
	lockGui.Size = UDim2.fromOffset(200, 40)
	lockGui.StudsOffsetWorldSpace = Vector3.new(0, 1.5, 0)
	lockGui.AlwaysOnTop = false
	lockGui.Adornee = barrier
	lockGui.Parent = barrier
	local lockLabel = Instance.new("TextLabel")
	lockLabel.Size = UDim2.new(1, 0, 1, 0)
	lockLabel.BackgroundTransparency = 1
	lockLabel.Font = Enum.Font.GothamBlack
	lockLabel.TextSize = 20
	lockLabel.TextColor3 = Color3.fromRGB(255, 80, 90)
	lockLabel.TextStrokeTransparency = 0.2
	lockLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	lockLabel.Text = "🔒 LOCKED"
	lockLabel.Parent = lockGui
	lockGui.Enabled = false
	return { barrier = barrier, lockGui = lockGui, flagLabel = flagLabel }
end

local function buildBase(index, sideX, centerZ)
	local folder = Instance.new("Folder")
	folder.Name = "Base" .. tostring(index)
	folder.Parent = BasesFolder
	-- Floor slab: top y = +0.1, a walkable step from the plaza floor (top 0).
	-- v7.3: bigger slab 44x32 (was 30x28), ~1.68x the area.
	local slab = part("BaseFloor", Vector3.new(44, 0.4, 32), CFrame.new(sideX, -0.1, centerZ), Color3.fromRGB(90, 70, 130), Enum.Material.SmoothPlastic, nil, folder)
	-- Name post at the plaza-side edge (x = +/-120).
	local postX = sideX - math.sign(sideX) * 21
	local post = part("BasePost", Vector3.new(1.5, 4, 1.5), CFrame.new(postX, 2, centerZ), Color3.fromRGB(240, 220, 140), Enum.Material.SmoothPlastic, nil, folder)
	local gui = sign(post, "BASE " .. tostring(index), "Unclaimed", Color3.fromRGB(255, 255, 255))
	-- 10 pedestals, grid 2 x 5 (v7.3: wider spacing on the bigger slab).
	-- Pedestal top y = 1.1 (bottom sits on the slab top, y = 0.1 — never
	-- coplanar with the plaza floor).
	local slots = {}
	local k = 0
	for _, rowZ in ipairs(BASE_SLOT_ROWS) do
		for _, colX in ipairs(BASE_SLOT_COLS) do
			k = k + 1
			local px = sideX + colX
			local pz = centerZ + rowZ
			local ped = part("Pedestal", Vector3.new(4.6, 1.0, 4.6), CFrame.new(px, 0.6, pz), Color3.fromRGB(60, 55, 80), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder, folder)
			ped.CanCollide = false
			slots[k] = {
				pos = Vector3.new(px, 1.1, pz),
				groundY = 1.1,
				pedestal = ped,
				model = nil,
				label = nil,
				cframe = nil,
				phase = rng:NextNumber() * 6.28,
			}
		end
	end
	-- v7.3 decor template (same on every base) + lock state. The lock
	-- times are session-only (NOT saved) — a lock never survives a
	-- rejoin, which is the safe default.
	local decor = decorateBase(folder, sideX, centerZ)
	Bases[index] = {
		folder = folder, owner = nil, slots = slots, signGui = gui,
		centerX = sideX, centerZ = centerZ,
		lockUntil = 0, lockCooldownUntil = 0, lockVisualShown = false,
		lockBarrier = decor.barrier, lockGui = decor.lockGui, flagLabel = decor.flagLabel,
	}
end

for i, z in ipairs(BASE_ZS) do
	buildBase(i, -141, z)
	buildBase(i + 5, 141, z)
end

setBaseSign = function(index, title, sub)
	local base = Bases[index]
	if not base or not base.signGui then
		return
	end
	local titleLabel = base.signGui:FindFirstChild("Title")
	local subLabel = base.signGui:FindFirstChild("Sub")
	if titleLabel then
		titleLabel.Text = title
	end
	if subLabel then
		subLabel.Text = sub
	end
	-- v7.3: the flag on the base shows the same owner name.
	if base.flagLabel then
		base.flagLabel.Text = sub
	end
end
end)

--------------------------------------------------------------------------------
-- 14. GIANT NAME SIGN (v7.2, top-3 presentation — no gameplay change):
-- a huge double-sided "PLAZA DEL DELIRIO" board on the north edge, above
-- the dice row, so the game name reads in the cover screenshot from the
-- spawn/plaza side AND from the dice row (SurfaceGui on both faces).
-- Board bottom (y = 19) clears the dice signs (~y 13); the posts stand
-- clear of the tilted pillar at (-34, -94). LightInfluence = 0 so the
-- sign stays readable even during the dark Gothic / Void events.
--------------------------------------------------------------------------------

safeSection("Giant name sign", function()
	local board = part("NameSignBoard", Vector3.new(84, 14, 1.5), CFrame.new(0, 26, -100), Color3.fromRGB(45, 15, 80), Enum.Material.SmoothPlastic)
	board.CanCollide = false
	local postL = part("NameSignPostL", Vector3.new(2, 19, 2), CFrame.new(-38, 9.5, -100), Color3.fromRGB(240, 220, 140), Enum.Material.SmoothPlastic)
	postL.CanCollide = false
	local postR = part("NameSignPostR", Vector3.new(2, 19, 2), CFrame.new(38, 9.5, -100), Color3.fromRGB(240, 220, 140), Enum.Material.SmoothPlastic)
	postR.CanCollide = false
	local trimTop = part("NameSignTrimTop", Vector3.new(84, 0.6, 1.7), CFrame.new(0, 33.2, -100), Color3.fromRGB(60, 230, 255), Enum.Material.Neon)
	trimTop.CanCollide = false
	local trimBottom = part("NameSignTrimBottom", Vector3.new(84, 0.6, 1.7), CFrame.new(0, 18.8, -100), Color3.fromRGB(255, 60, 200), Enum.Material.Neon)
	trimBottom.CanCollide = false

	local function nameFace(face)
		local g = Instance.new("SurfaceGui")
		g.Name = "NameSign" .. face
		g.Face = Enum.NormalId[face]
		g.PixelsPerStud = 10
		g.LightInfluence = 0
		g.Adornee = board
		g.Parent = board
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.Size = UDim2.new(1, 0, 0.68, 0)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 255, 255)
		title.TextStrokeTransparency = 0
		title.TextStrokeColor3 = Color3.fromRGB(20, 5, 40)
		title.Text = "PLAZA DEL DELIRIO"
		title.Parent = g
		local titleGrad = Instance.new("UIGradient")
		titleGrad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 220)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 230, 255)),
		})
		titleGrad.Parent = title
		local sub = Instance.new("TextLabel")
		sub.Name = "Sub"
		sub.Size = UDim2.new(1, 0, 0.32, 0)
		sub.Position = UDim2.new(0, 0, 0.68, 0)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamBold
		sub.TextScaled = true
		sub.TextColor3 = Color3.fromRGB(255, 220, 60)
		sub.TextStrokeTransparency = 0
		sub.TextStrokeColor3 = Color3.fromRGB(20, 5, 40)
		sub.Text = "ROLL THE DICE  •  FILL YOUR BASE  •  REBIRTH"
		sub.Parent = g
	end
	nameFace("Front")
	nameFace("Back")
end)

--------------------------------------------------------------------------------
-- Player data, leaderstats and economy
--------------------------------------------------------------------------------

local PlayerData = {}

local function getData(player)
	return PlayerData[player]
end

local function setSpeed(player, speed)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

-- Permanent Aura-income bonus: +10% per completed Index tab (37/37).
local function indexBonus(data)
	local bonus = 0
	for _, eventKey in ipairs(DB.EventOrder) do
		local tab = data.Index[eventKey]
		if tab then
			local count = 0
			for _ in pairs(tab) do
				count = count + 1
			end
			if count >= DB.CharacterCount then
				bonus = bonus + INDEX_BONUS_PER_TAB
			end
		end
	end
	return bonus
end

-- Friend buff: +5% per OTHER player in the server, capped at +20%.
local function friendBonus()
	local others = math.max(0, #Players:GetPlayers() - 1)
	return math.min(FRIEND_BONUS_PER_PLAYER * others, FRIEND_BONUS_CAP)
end

local function friendCount()
	return math.max(0, #Players:GetPlayers() - 1)
end

-- Player income multiplier (same formula as the income tick): Rebirth
-- (+50%/level) x Index completion (+10%/tab) x Friend buff (+5%/player,
-- cap +20%). Used for honest per-name display rates (pedestal labels
-- and model tags show the rate a brainrot REALLY pays, after the
-- multipliers — not the base rarity rate). (v7.6.6)
local function incomeMult(data)
	return (1 + REBIRTH_INCOME_BONUS * data.Rebirth.Value) * (1 + indexBonus(data)) * (1 + friendBonus())
end

-- Distinct owned names (any copy) — drives the Unlocked leaderstat.
local function ownedNameCount(data)
	local count = 0
	for _ in pairs(data.Copies) do
		count = count + 1
	end
	return count
end

local function syncUnlocked(player)
	local data = getData(player)
	if not data then
		return
	end
	data.Unlocked.Value = ownedNameCount(data)
end

-- Total copies owned of one name, across all event tabs.
local function totalCopies(data, name)
	local copies = data.Copies[name]
	if not copies then
		return 0
	end
	local total = 0
	for _, c in pairs(copies) do
		total = total + c
	end
	return total
end

local function toolNameFor(name)
	local ch = DB.GetCharacter(name)
	return name .. " • " .. (ch and ch.Rarity:upper() or "")
end

local function notify(player, text, color)
	if player then
		ClientFX:FireClient(player, "Notify", { Text = text, Color = color })
	else
		ClientFX:FireAllClients("Notify", { Text = text, Color = color })
	end
end

-- Forward declaration: bestEventKey is defined below grantCopy, but
-- giveTool (used by grantCopy) needs it. Luau resolves locals lexically,
-- so the local must exist before giveTool's body references it.
local bestEventKey
local trySteal -- forward-declared: the steal prompt in refreshBase fires it

--------------------------------------------------------------------------------
-- Backpack Tools: every owned copy is a Tool named "Name • RARITY".
-- The model is welded to a Handle that floats 1 stud below the model's
-- feet, so the brainrot hovers just above the hand when equipped
-- (hotbar 1, 2, 3...). Tools are rebuilt from the save on join/respawn
-- and kept in sync on every roll and sale — the Backpack holds them all
-- now; there is no in-game collection panel anymore.
--------------------------------------------------------------------------------

local function giveTool(player, name)
	local ch = DB.GetCharacter(name)
	if not ch then
		return false
	end
	local data = getData(player)
	if not data then
		return false
	end
	local okBuild, model = pcall(DB.BuildModel, name, bestEventKey(data, name), incomeMult(data))
	if not okBuild or not model then
		warn("[Plaza] BuildModel failed for tool " .. tostring(name))
		return false
	end
	-- v7.6.4: held models are 0.5x (see HELD_MODEL_SCALE) so the tool
	-- in the hand reads the same size on screen as the 2x base display.
	pcall(function()
		model:ScaleTo(HELD_MODEL_SCALE)
	end)
	-- v7.6.4: ScaleTo shrinks the model but NOT the Tag's offset (tag()
	-- computed it from the ORIGINAL height) — the label would float
	-- far above a 0.5x model. Recompute from the scaled height.
	local tagGui = model:FindFirstChild("Tag")
	if tagGui and tagGui:IsA("BillboardGui") then
		tagGui.StudsOffsetWorldSpace = Vector3.new(0, ch.Height * HELD_MODEL_SCALE + 0.9, 0)
	end
	local tool = Instance.new("Tool")
	tool.Name = toolNameFor(name)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	local cf, size = model:GetBoundingBox()
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = 1
	handle.Anchored = false
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.TopSurface = Enum.SurfaceType.Smooth
	handle.BottomSurface = Enum.SurfaceType.Smooth
	handle.CFrame = CFrame.new(cf.X, cf.Y - size.Y / 2 - 1, cf.Z)
	handle.Parent = tool
	model.Parent = tool
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = model.PrimaryPart
	weld.Parent = tool
	tool.Parent = player.Backpack
	return true
end

local function countTools(player, name)
	local want = toolNameFor(name)
	local n = 0
	local function scan(parent)
		if not parent then
			return
		end
		for _, inst in ipairs(parent:GetChildren()) do
			if inst:IsA("Tool") and inst.Name == want then
				n = n + 1
			end
		end
	end
	scan(player.Backpack)
	if player.Character then
		scan(player.Character)
	end
	return n
end

local function removeTool(player, name)
	local want = toolNameFor(name)
	-- Prefer the equipped one (in the character) so the hand empties first.
	local character = player.Character
	if character then
		local t = character:FindFirstChild(want)
		if t and t:IsA("Tool") then
			t:Destroy()
			return true
		end
	end
	local t = player.Backpack:FindFirstChild(want)
	if t then
		t:Destroy()
		return true
	end
	return false
end

-- v7.4 INVENTORY: per-name hold choice. data.Unheld[name] = true means
-- the player STORED that brainrot (in the inventory panel only — no
-- Backpack Tool). Absent (nil) = HELD, the v7.3 behaviour: every copy is
-- a Tool. Only unheld names are stored, so old saves (no Unheld field)
-- behave exactly as before: everything held.
local function isHeld(data, name)
	return not (data.Unheld and data.Unheld[name])
end

-- Reconcile the Backpack with the save: one Tool per owned copy — but
-- only for HELD names (v7.4). Stored names keep their copies, base
-- display and income, just no Tool in the hotbar.
local function syncTools(player)
	local data = getData(player)
	if not data then
		return
	end
	for name in pairs(data.Copies) do
		local have = countTools(player, name)
		local want = isHeld(data, name) and totalCopies(data, name) or 0
		while have < want do
			if not giveTool(player, name) then
				break
			end
			have = have + 1
		end
		while have > want do
			if not removeTool(player, name) then
				break
			end
			have = have - 1
		end
	end
	-- Defensive sweep: drop Tools for names the player no longer owns.
	local function sweep(parent)
		if not parent then
			return
		end
		for _, inst in ipairs(parent:GetChildren()) do
			if inst:IsA("Tool") then
				local baseName = inst.Name:match("^(.-) • ")
				if baseName and totalCopies(data, baseName) == 0 then
					inst:Destroy()
				end
			end
		end
	end
	sweep(player.Backpack)
	if player.Character then
		sweep(player.Character)
	end
end

-- Grant one copy of a character from the given event tab. Returns isNew
-- (first time this name appears in THIS event's Index tab). The copy also
-- becomes a Backpack Tool immediately — unless the player STORED this
-- name in the inventory (v7.4), in which case no Tool is given.
local function grantCopy(player, name, eventKey)
	local data = getData(player)
	if not data then
		return false
	end
	data.Copies[name] = data.Copies[name] or {}
	data.Copies[name][eventKey] = (data.Copies[name][eventKey] or 0) + 1
	data.Index[eventKey] = data.Index[eventKey] or {}
	local isNew = not data.Index[eventKey][name]
	data.Index[eventKey][name] = true
	syncUnlocked(player)
	if isHeld(data, name) then
		giveTool(player, name)
	end
	return isNew
end

-- Event tab of the most valuable copy the player owns (base models show
-- their best mutation aura).
bestEventKey = function(data, name)
	local copies = data.Copies[name]
	if not copies then
		return "Basic"
	end
	local bestKey, bestValue = "Basic", -1
	for eventKey in pairs(copies) do
		local ch = DB.GetCharacter(name)
		if ch then
			local value = DB.ValueOf(ch, eventKey)
			if value > bestValue then
				bestValue = value
				bestKey = eventKey
			end
		end
	end
	return bestKey
end

--------------------------------------------------------------------------------
-- Base display: build / destroy / spin the standing models
--------------------------------------------------------------------------------

-- Anchor every part of a display model. Anchored models never fall, so the
-- slow spin below can PivotTo them every frame with zero jitter — the
-- exact opposite of the v5 follow bug (unanchored + PivotTo per frame).
local function anchorModel(model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.Massless = true
		end
	end
end

-- Bottom offset of a model relative to its pivot, from the bounding box
-- (robust to any pivot semantics — the v4.1 lesson).
local function bottomOffsetOf(model)
	local cf, size = model:GetBoundingBox()
	return (cf.Y - size.Y / 2) - model:GetPivot().Y
end

local function placeOnGround(model, x, groundY, z)
	local pivotY = groundY - bottomOffsetOf(model)
	return CFrame.new(x, pivotY, z)
end

-- How many base slots are open at a rebirth level: 4 at R0, +1 per
-- rebirth, all 10 at R6 (R7 adds nothing more).
local function openSlotCount(rebirthLevel)
	return math.min(BASE_SLOTS_OPEN_AT_START + (rebirthLevel or 0), BASE_SLOTS)
end

-- Owned names sorted by Aura/s, best first — the top 10 get pedestals.
local function sortedOwnedNames(data)
	local names = {}
	for name in pairs(data.Copies) do
		table.insert(names, name)
	end
	table.sort(names, function(a, b)
		return auraPerSec(a) > auraPerSec(b)
	end)
	return names
end

local function clearSlot(slot)
	if slot.model then
		slot.model:Destroy()
		slot.model = nil
	end
	if slot.label then
		slot.label:Destroy()
		slot.label = nil
	end
	slot.cframe = nil
end

-- One small two-line pedestal label, adored to a part: line 1 + line 2.
local function pedestalLabel(adornee, offsetY, line1, line1Color, line1Size, line2, line2Color)
	local gui = Instance.new("BillboardGui")
	gui.Name = "SlotLabel"
	gui.Size = UDim2.fromOffset(150, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = false
	gui.Adornee = adornee
	gui.Parent = adornee
	local l1 = Instance.new("TextLabel")
	l1.Size = UDim2.new(1, 0, 0, 24)
	l1.BackgroundTransparency = 1
	l1.Font = Enum.Font.FredokaOne
	l1.TextSize = line1Size or 15
	l1.TextColor3 = line1Color or Color3.fromRGB(255, 255, 255)
	l1.TextStrokeTransparency = 0.3
	l1.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	l1.Text = line1
	l1.Parent = gui
	if line2 then
		local l2 = Instance.new("TextLabel")
		l2.Size = UDim2.new(1, 0, 0, 18)
		l2.Position = UDim2.new(0, 0, 0, 24)
		l2.BackgroundTransparency = 1
		l2.Font = Enum.Font.GothamBold
		l2.TextSize = 12
		l2.TextColor3 = line2Color or Color3.fromRGB(255, 220, 60)
		l2.TextStrokeTransparency = 0.3
		l2.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		l2.Text = line2
		l2.Parent = gui
	end
	return gui
end

-- Rebuild a whole base display after a roll, a sale, a rebirth, or a load.
-- Slot i (1..10): locked if i > open slots; otherwise the i-th best owned
-- brainrot, or "???" if the player owns fewer than i distinct brainrots.
local function refreshBase(player)
	local data = getData(player)
	if not data or data.BaseIndex <= 0 then
		return
	end
	local base = Bases[data.BaseIndex]
	if not base then
		return
	end
	local open = openSlotCount(data.Rebirth.Value)
	local names = sortedOwnedNames(data)
	for i, slot in ipairs(base.slots) do
		clearSlot(slot)
		if i > open then
			-- Locked slot: padlock + the rebirth that opens it.
			slot.label = pedestalLabel(slot.pedestal, 2.6, "🔒", Color3.fromRGB(200, 200, 210), 18, "Rebirth " .. tostring(i - BASE_SLOTS_OPEN_AT_START), Color3.fromRGB(200, 200, 210))
		elseif i <= #names then
			local name = names[i]
			local count = totalCopies(data, name)
			-- BuildModel is pcall-wrapped (the v4.1 lesson): one bad builder
			-- must never break the base. Fallback is the humble Pipi Kiwi.
			local okBuild, model = pcall(DB.BuildModel, name, bestEventKey(data, name), incomeMult(data))
			if not okBuild or not model then
				warn("[Plaza] BuildModel failed for " .. tostring(name) .. "; falling back to Pipi Kiwi")
				okBuild, model = pcall(DB.BuildModel, "Pipi Kiwi", "Basic", incomeMult(data))
			end
			if okBuild and model then
				-- 2x display size (v7). pcall-guarded: a ScaleTo failure
				-- just leaves the model at 1x, never breaks the base.
				pcall(function()
					model:ScaleTo(BASE_MODEL_SCALE)
				end)
				-- Drop the database's own name tag: the pedestal label
				-- below is the single label, so tags can never double up.
				local dbTag = model:FindFirstChild("Tag")
				if dbTag then
					dbTag:Destroy()
				end
				anchorModel(model)
				local cf = placeOnGround(model, slot.pos.X, slot.groundY, slot.pos.Z)
				model:PivotTo(cf)
				model.Parent = base.folder
				slot.model = model
				slot.cframe = cf
				local ch = DB.GetCharacter(name)
				local height = ch and (ch.Height * BASE_MODEL_SCALE) or 4
				slot.label = pedestalLabel(model.PrimaryPart, height + 1.2,
					name .. "  ×" .. tostring(count),
					(ch and DB.RarityColors[ch.Rarity]) or Color3.fromRGB(255, 255, 255), 15,
					-- v7.6.6: show the rate this brainrot REALLY pays — base
					-- rate x the player's income multiplier — so the label
					-- agrees with the model tag and the HUD total.
					"+" .. tostring(math.floor(auraPerSec(name) * incomeMult(data) + 0.5)) .. " Aura/s")
				-- v7.3 STEAL: a hold-E prompt on the displayed brainrot.
				-- The prompt fires trySteal (owner / lock / cooldown /
				-- copies are all re-validated there, so a stale prompt
				-- can never steal a brainrot that is gone).
				local stealEventKey = bestEventKey(data, name)
				local stealPrompt = Instance.new("ProximityPrompt")
				stealPrompt.Name = "StealPrompt"
				stealPrompt.ActionText = "Steal " .. name
				stealPrompt.ObjectText = player.DisplayName or player.Name
				stealPrompt.HoldDuration = 1.5
				stealPrompt.MaxActivationDistance = 12
				stealPrompt.RequiresLineOfSight = false
				stealPrompt.Parent = model.PrimaryPart
				stealPrompt.Triggered:Connect(function(thief)
					trySteal(thief, player, name, stealEventKey)
				end)
			end
		else
			-- Open but empty.
			slot.label = pedestalLabel(slot.pedestal, 2.6, "???", Color3.fromRGB(160, 160, 180), 15)
		end
	end
end

local function assignBase(player)
	for i, base in ipairs(Bases) do
		if not base.owner then
			base.owner = player
			local data = getData(player)
			if data then
				data.BaseIndex = i
			end
			setBaseSign(i, "BASE " .. tostring(i), player.DisplayName or player.Name)
			return i
		end
	end
	return 0
end

local function freeBase(player)
	local data = getData(player)
	if data and data.BaseIndex > 0 then
		local base = Bases[data.BaseIndex]
		if base and base.owner == player then
			for _, slot in ipairs(base.slots) do
				clearSlot(slot)
			end
			base.owner = nil
			-- v7.3: a freed base loses its lock + lock visual (the flag
			-- name is reset by setBaseSign below).
			base.lockUntil = 0
			base.lockCooldownUntil = 0
			base.lockVisualShown = false
			if base.lockBarrier then
				base.lockBarrier.Transparency = 1
			end
			if base.lockGui then
				base.lockGui.Enabled = false
			end
			setBaseSign(data.BaseIndex, "BASE " .. tostring(data.BaseIndex), "Unclaimed")
		end
		data.BaseIndex = 0
	end
end

local function animateAltar()
	-- Orb pulse + lid lift, then settle back. Purely visual.
	-- v7.1: no-op if the altar never built (section 9 failed).
	if not altarOrb or not altarLid or not altarLidClosed then
		return
	end
	local pulse = TweenService:Create(altarOrb, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.new(5.5, 5.5, 5.5) })
	pulse:Play()
	pulse.Completed:Connect(function()
		local shrink = TweenService:Create(altarOrb, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Size = Vector3.new(4, 4, 4) })
		shrink:Play()
	end)
	local open = TweenService:Create(altarLid, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = altarLidClosed * CFrame.new(0, 3, 0) })
	open:Play()
	open.Completed:Connect(function()
		task.wait(0.8)
		local close = TweenService:Create(altarLid, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { CFrame = altarLidClosed })
		close:Play()
	end)
end

--------------------------------------------------------------------------------
-- Weather / mutation events (ported from Meteor, reworked v7).
-- Basic is the calm default (x1, no buff, vaporwave plaza lighting) — it
-- is NEVER picked as an event. Buff events are picked RANDOMLY from
-- {Summer, Rainy, Cold, Gothic, Void}, never the same twice in a row:
-- first buff 2-4 min after server start, then one buff runs exactly 60s,
-- then 3-5 min of Basic, then the next random buff. Each buff has its own
-- Lighting + particles + (Summer) a glowing sun ball, so the event reads
-- from anywhere in the plaza. Gothic / Void stay bright enough to play.
--------------------------------------------------------------------------------

local PLAZA_LIGHTING = {
	Basic = {
		ClockTime = 17.6, Ambient = Color3.fromRGB(115, 64, 140),
		OutdoorAmbient = Color3.fromRGB(179, 115, 204),
		FogColor = Color3.fromRGB(230, 115, 191), FogStart = 200, FogEnd = 900,
		Brightness = 2, Gravity = 196.2, Particle = "None",
		AtmosphereColor = Color3.fromRGB(217, 115, 204), AtmosphereDensity = 0.32,
	},
	Summer = {
		ClockTime = 15, Ambient = Color3.fromRGB(240, 170, 90),
		OutdoorAmbient = Color3.fromRGB(255, 210, 130),
		FogColor = Color3.fromRGB(255, 190, 100), FogStart = 200, FogEnd = 900,
		Brightness = 2.8, Gravity = 196.2, Particle = "Ember",
		AtmosphereColor = Color3.fromRGB(255, 190, 100), AtmosphereDensity = 0.4,
	},
	Rainy = {
		ClockTime = 13, Ambient = Color3.fromRGB(70, 85, 130),
		OutdoorAmbient = Color3.fromRGB(100, 120, 165),
		FogColor = Color3.fromRGB(90, 105, 145), FogStart = 150, FogEnd = 700,
		Brightness = 1.3, Gravity = 196.2, Particle = "Rain",
		AtmosphereColor = Color3.fromRGB(90, 105, 145), AtmosphereDensity = 0.45,
	},
	Cold = {
		ClockTime = 11, Ambient = Color3.fromRGB(179, 217, 230),
		OutdoorAmbient = Color3.fromRGB(200, 225, 240),
		FogColor = Color3.fromRGB(204, 230, 255), FogStart = 150, FogEnd = 500,
		Brightness = 1.6, Gravity = 196.2, Particle = "Snow",
		AtmosphereColor = Color3.fromRGB(204, 230, 255), AtmosphereDensity = 0.4,
	},
	Gothic = {
		ClockTime = 20, Ambient = Color3.fromRGB(120, 35, 45),
		OutdoorAmbient = Color3.fromRGB(100, 40, 55),
		FogColor = Color3.fromRGB(60, 15, 35), FogStart = 80, FogEnd = 350,
		Brightness = 1.3, Gravity = 196.2, Particle = "Wisp",
		AtmosphereColor = Color3.fromRGB(60, 15, 35), AtmosphereDensity = 0.5,
	},
	Void = {
		ClockTime = 0, Ambient = Color3.fromRGB(45, 25, 90),
		OutdoorAmbient = Color3.fromRGB(60, 35, 115),
		FogColor = Color3.fromRGB(20, 10, 55), FogStart = 150, FogEnd = 600,
		Brightness = 1.2, Gravity = 150, Particle = "Star",
		AtmosphereColor = Color3.fromRGB(20, 10, 55), AtmosphereDensity = 0.55,
	},
}

local currentEvent = "Basic"
local lastBuffEvent = nil
local eventEndsAt = os.time() + 180

local function applyEvent(eventKey, secondsLeft)
	currentEvent = eventKey
	local event = DB.Events[eventKey]
	local light = PLAZA_LIGHTING[eventKey] or PLAZA_LIGHTING.Basic
	Lighting.ClockTime = light.ClockTime
	Lighting.Ambient = light.Ambient
	Lighting.OutdoorAmbient = light.OutdoorAmbient
	Lighting.FogColor = light.FogColor
	Lighting.FogStart = light.FogStart
	Lighting.FogEnd = light.FogEnd
	Lighting.Brightness = light.Brightness
	workspace.Gravity = light.Gravity
	local atmosphere = Lighting:FindFirstChild("Atmosphere")
	if atmosphere then
		atmosphere.Color = light.AtmosphereColor
		atmosphere.Density = light.AtmosphereDensity
	end
	local want = {
		Rain = "RainEmitter", Snow = "SnowEmitter", Ember = "EmberEmitter",
		Star = "StarEmitter", Wisp = "WispEmitter",
	}
	-- v7.1: guard — if section 10 failed, WeatherPart is nil and the
	-- emitter loop would error (killing the event scheduler thread).
	if WeatherPart then
		for _, child in ipairs(WeatherPart:GetChildren()) do
			if child:IsA("ParticleEmitter") then
				child.Enabled = (want[light.Particle] == child.Name)
			end
		end
	end
	-- The summer sun only shines during Summer.
	-- v7.1: guards — if section 10 failed, WeatherPart/SunBall are nil.
	if SunBall then
		SunBall.Visible = (eventKey == "Summer")
	end
	eventEndsAt = os.time() + (secondsLeft or EVENT_DURATION)
	ClientFX:FireAllClients("Weather", {
		Event = eventKey, Mult = event.Mult, SecondsLeft = secondsLeft or EVENT_DURATION,
	})
end

local function pickNextBuffEvent()
	local pool = {}
	for _, key in ipairs(BUFF_EVENTS) do
		if key ~= lastBuffEvent then
			table.insert(pool, key)
		end
	end
	return pool[rng:NextInteger(1, #pool)]
end

-- Random event scheduler (v7.6: mutations are RARE): first buff 4-6 min
-- after start, then 60s of buff, 5-8 min of Basic — and only ~25% of
-- cycles get a buff at all (the rest stay Basic for another full gap).
-- Never the same buff twice in a row. The weather bar shows "Basic x1"
-- with the countdown during the long calm gaps.
task.spawn(function()
	local firstDelay = math.floor(rng:NextNumber(EVENT_FIRST_DELAY_MIN, EVENT_FIRST_DELAY_MAX))
	applyEvent("Basic", firstDelay)
	task.wait(firstDelay)
	while true do
		if rng:NextNumber() < MUTATION_CHANCE then
			local nextEvent = pickNextBuffEvent()
			lastBuffEvent = nextEvent
			applyEvent(nextEvent, EVENT_DURATION)
			task.wait(EVENT_DURATION)
		end
		local gap = math.floor(rng:NextNumber(EVENT_GAP_MIN, EVENT_GAP_MAX))
		applyEvent("Basic", gap)
		task.wait(gap)
	end
end)

--------------------------------------------------------------------------------
-- DataStore (pcall-wrapped: Studio without API access just keeps defaults).
--------------------------------------------------------------------------------
local store = nil
pcall(function()
	store = DataStoreService:GetDataStore("PlazaDelDelirio_v2")
end)

local function saveData(player)
	local data = PlayerData[player]
	if not data or not store then
		return
	end
	local snapshot = {
		dollar = data.Dollar.Value, luck = data.Luck.Value,
		rebirth = data.Rebirth.Value,
		index = data.Index, copies = data.Copies,
		unheld = data.Unheld, -- v7.4: stored (not held) names
	}
	pcall(function()
		store:SetAsync("player_" .. tostring(player.UserId), snapshot)
	end)
	data.lastSave = os.time()
end

local function loadData(player)
	local data = getData(player)
	if not data then
		return
	end
	if store then
		local ok, saved = pcall(function()
			return store:GetAsync("player_" .. tostring(player.UserId))
		end)
		if ok and type(saved) == "table" then
			data.Dollar.Value = saved.dollar or 0
			data.Luck.Value = saved.luck or 0
			data.Rebirth.Value = saved.rebirth or 0
			data.Index = saved.index or {}
			data.Copies = saved.copies or {}
			data.Unheld = saved.unheld or {} -- v7.4: nil = everything held
		end
	end
	syncUnlocked(player)
end

--------------------------------------------------------------------------------
-- Dice rolling, Rebirth, Sell + Luck
--------------------------------------------------------------------------------

-- Tumble the die so the roll is VISIBLE from the middle of the plaza:
-- ~1.2s of multi-axis spin (6 / 4 / 5 full turns) + a 4-stud hop, a
-- rarity-coloured Highlight while it spins, and a sparkle burst when it
-- lands. The die is one anchored Model, so PivotTo moves cube + pips
-- together with zero physics fight. (v6's gentle yaw + small hop was
-- too subtle — Yami asked for the roll to actually show.)
local function animateDie(die)
	if not die or die.busy then
		return
	end
	die.busy = true
	task.spawn(function()
		local highlight = Instance.new("Highlight")
		highlight.Name = "RollHighlight"
		highlight.FillColor = DB.RarityColors[die.tier] or Color3.fromRGB(255, 220, 60)
		highlight.FillTransparency = 0.6
		highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
		highlight.OutlineTransparency = 0
		highlight.Parent = die.model
		local steps = 36
		for i = 1, steps do
			local progress = i / steps
			local hop = math.sin(progress * math.pi) * 4
			die.model:PivotTo(die.baseCFrame * CFrame.new(0, hop, 0) * CFrame.Angles(progress * math.pi * 6, progress * math.pi * 4, progress * math.pi * 5))
			task.wait(1.2 / steps)
		end
		die.model:PivotTo(die.baseCFrame)
		highlight:Destroy()
		-- Sparkle burst on landing.
		local burst = Instance.new("Part")
		burst.Name = "DiceBurst"
		burst.Size = Vector3.new(1, 1, 1)
		burst.Transparency = 1
		burst.Anchored = true
		burst.CanCollide = false
		burst.CanQuery = false
		burst.CanTouch = false
		burst.CFrame = die.baseCFrame * CFrame.new(0, 3, 0)
		burst.Parent = World
		local emit = Instance.new("ParticleEmitter")
		emit.Color = ColorSequence.new(DB.RarityColors[die.tier] or Color3.fromRGB(255, 220, 60))
		emit.Size = NumberSequence.new(0.6)
		emit.Lifetime = NumberRange.new(0.5, 0.9)
		emit.Speed = NumberRange.new(8, 16)
		emit.SpreadAngle = Vector2.new(180, 180)
		emit.Parent = burst
		emit:Emit(40)
		Debris:AddItem(burst, 1.5)
		die.busy = false
	end)
end

-- Roll one die. Returns a result table for the client card (or ok=false).
-- The roll itself is pcall-wrapped: a bad roll must never break the game.
local function rollDie(player, tier)
	local data = getData(player)
	if not data then
		return { ok = false, reason = "no data" }
	end
	local rank = DB.RarityRank[tier]
	if not rank then
		return { ok = false, reason = "bad tier" }
	end
	if data.Rebirth.Value < rank - 1 then
		notify(player, "🔒 " .. tier .. " Dice needs Rebirth " .. tostring(rank - 1) .. "!", Color3.fromRGB(255, 120, 120))
		return { ok = false, reason = "locked" }
	end
	local cost = DICE_COSTS[tier]
	if data.Aura.Value < cost then
		notify(player, "Not enough Aura — need " .. formatMoney(cost) .. ".", Color3.fromRGB(255, 120, 120))
		return { ok = false, reason = "need aura" }
	end
	local die = Dice[tier]
	if die and die.busy then
		return { ok = false, reason = "die busy" }
	end
	data.Aura.Value = data.Aura.Value - cost
	-- Lucky Roll: +2% per Luck level, the result jumps ONE tier up
	-- (never past Godly).
	local lucky = false
	local resultTier = tier
	if rank < 8 and rng:NextNumber() < LUCKY_ROLL_PER_LEVEL * data.Luck.Value then
		lucky = true
		resultTier = DB.RarityOrder[rank + 1]
	end
	-- Weighted pick inside the result tier.
	local pool = {}
	for _, ch in ipairs(DB.Characters) do
		if ch.Rarity == resultTier then
			table.insert(pool, ch)
		end
	end
	local total = 0
	for _, ch in ipairs(pool) do
		total = total + ch.Weight
	end
	local picked = pool[1]
	local okRoll, rolled = pcall(function()
		local roll = rng:NextNumber() * total
		for _, ch in ipairs(pool) do
			roll = roll - ch.Weight
			if roll <= 0 then
				return ch
			end
		end
		return pool[1]
	end)
	if okRoll and rolled then
		picked = rolled
	end
	if die then
		animateDie(die)
		task.wait(1.2)
	end
	local isNew = grantCopy(player, picked.Name, currentEvent)
	refreshBase(player)
	if DB.RarityRank[picked.Rarity] >= 4 then
		ClientFX:FireAllClients("Announce", {
			PlayerName = player.Name,
			CharacterName = picked.Name,
			Rarity = picked.Rarity,
			AuraPerSec = auraPerSec(picked.Name),
		})
	end
	return {
		ok = true,
		Name = picked.Name,
		Rarity = picked.Rarity,
		AuraPerSec = auraPerSec(picked.Name),
		IsNew = isNew,
		EventKey = currentEvent,
		Value = DB.ValueOf(picked, currentEvent),
		Lucky = lucky,
		Tier = tier,
	}
end

-- Rebirth: pay Aura, unlock the next dice tier AND one more base slot,
-- +50% passive Aura income (stacking). Index, Luck, Dollars and Copies
-- are NEVER touched.
local function doRebirth(player)
	local data = getData(player)
	if not data then
		return
	end
	local level = data.Rebirth.Value
	if level >= MAX_REBIRTH then
		notify(player, "Already max Rebirth — every dice tier is open!", Color3.fromRGB(255, 220, 120))
		return
	end
	local cost = REBIRTH_COSTS[level + 1]
	if data.Aura.Value < cost then
		notify(player, "Not enough Aura — Rebirth " .. tostring(level + 1) .. " needs " .. formatMoney(cost) .. ".", Color3.fromRGB(255, 120, 120))
		return
	end
	data.Aura.Value = data.Aura.Value - cost
	data.Rebirth.Value = level + 1
	animateAltar()
	refreshBase(player)
	local nextTier = DB.RarityOrder[level + 2]
	local slotsNote = ""
	if openSlotCount(level + 1) > openSlotCount(level) then
		slotsNote = " + 1 base slot (" .. tostring(openSlotCount(level + 1)) .. "/10)"
	end
	notify(player, "🔄 REBIRTH " .. tostring(level + 1) .. "! +" .. tostring(50 * (level + 1)) .. "% Aura income — " .. nextTier .. " Dice unlocked!" .. slotsNote, Color3.fromRGB(120, 255, 120))
	ClientFX:FireAllClients("Announce", {
		PlayerName = player.Name,
		CharacterName = "REBIRTH " .. tostring(level + 1),
		Rarity = nextTier,
		AuraPerSec = 0,
	})
	ClientFX:FireClient(player, "Cash", {})
	if os.time() - data.lastSave > 30 then
		saveData(player)
	end
end

-- Sell ONE copy: the most valuable copy the player owns. Pays Dollars
-- = base x event mult. The base display and the Backpack Tool are
-- updated (the Tool for the sold copy is removed).
local function sellBestCopy(player)
	local data = getData(player)
	if not data then
		return
	end
	local bestName, bestKey, bestValue = nil, nil, -1
	for name, copies in pairs(data.Copies) do
		local ch = DB.GetCharacter(name)
		if ch then
			for eventKey, count in pairs(copies) do
				if count > 0 then
					local value = DB.ValueOf(ch, eventKey)
					if value > bestValue then
						bestValue = value
						bestName = name
						bestKey = eventKey
					end
				end
			end
		end
	end
	if not bestName then
		notify(player, "Nothing to sell — roll a die first!", Color3.fromRGB(255, 220, 120))
		return
	end
	data.Copies[bestName][bestKey] = data.Copies[bestName][bestKey] - 1
	if data.Copies[bestName][bestKey] <= 0 then
		data.Copies[bestName][bestKey] = nil
	end
	if next(data.Copies[bestName]) == nil then
		data.Copies[bestName] = nil
	end
	data.Dollar.Value = data.Dollar.Value + bestValue
	syncUnlocked(player)
	removeTool(player, bestName)
	refreshBase(player)
	ClientFX:FireClient(player, "Popup", { Text = "+$" .. tostring(bestValue), Color = Color3.fromRGB(120, 255, 120) })
	notify(player, "Sold " .. bestName .. " (" .. bestKey .. ") for $" .. tostring(bestValue) .. "!", Color3.fromRGB(120, 255, 120))
	-- v7.6.6: selling can remove a name's income — re-sync the HUD rate.
	ClientFX:FireClient(player, "Cash", {})
	if os.time() - data.lastSave > 30 then
		saveData(player)
	end
end

local function buyLuck(player)
	local data = getData(player)
	if not data then
		return
	end
	local level = data.Luck.Value
	if level >= MAX_LUCK then
		notify(player, "Meteor Luck is already max level!", Color3.fromRGB(255, 220, 120))
		return
	end
	local cost = LUCK_COSTS[level + 1]
	if data.Dollar.Value < cost then
		notify(player, "Not enough $ — need $" .. tostring(cost) .. ".", Color3.fromRGB(255, 120, 120))
		return
	end
	data.Dollar.Value = data.Dollar.Value - cost
	data.Luck.Value = level + 1
	notify(player, "Meteor Luck upgraded to level " .. tostring(level + 1) .. "! +2% Lucky Roll chance.", Color3.fromRGB(120, 255, 120))
	ClientFX:FireClient(player, "Cash", {})
	if os.time() - data.lastSave > 30 then
		saveData(player)
	end
end

--------------------------------------------------------------------------------
-- STEAL & DEFEND (v7.3): steal a brainrot from an unlocked enemy base,
-- carry it home on your head, deposit it in your own base. Lock your own
-- base (L key / LOCK button) for 30s (60s cooldown) to block steals.
-- Income is per DISTINCT name, so stealing a name the victim still has
-- copies of costs them a Tool/copy but not income; stealing their last
-- copy costs the name + income + Unlocked count. The Index is permanent
-- (a steal never un-unlocks a tab).
--------------------------------------------------------------------------------

local Carrying = {} -- player -> { name, eventKey, victim, model }
local StealCooldownUntil = {} -- player -> os.time() (can't steal before this)

-- Which event tab to take a copy from: the displayed one if it still has
-- copies, otherwise any tab with copies. Returns nil if none left.
local function pickCopyKey(data, name, preferredKey)
	local copies = data.Copies[name]
	if not copies then
		return nil
	end
	if preferredKey and copies[preferredKey] and copies[preferredKey] > 0 then
		return preferredKey
	end
	for k, c in pairs(copies) do
		if c > 0 then
			return k
		end
	end
	return nil
end

-- Remove ONE copy of a brainrot (one event tab). Returns true if a copy
-- was removed. Cleans up empty tables, the Unlocked leaderstat and one
-- Backpack Tool. (sellBestCopy has its own inline copy of this logic.)
local function removeCopy(player, name, eventKey)
	local data = getData(player)
	if not data then
		return false
	end
	local copies = data.Copies[name]
	if not copies or not copies[eventKey] or copies[eventKey] <= 0 then
		return false
	end
	copies[eventKey] = copies[eventKey] - 1
	if copies[eventKey] <= 0 then
		copies[eventKey] = nil
	end
	if next(copies) == nil then
		data.Copies[name] = nil
	end
	syncUnlocked(player)
	removeTool(player, name)
	return true
end

-- Is the player standing inside their OWN base (for a steal deposit)?
local function insideOwnBase(player)
	local data = getData(player)
	if not data or data.BaseIndex <= 0 then
		return false
	end
	local base = Bases[data.BaseIndex]
	if not base then
		return false
	end
	local character = player.Character
	if not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local dx = math.abs(root.Position.X - base.centerX)
	local dz = math.abs(root.Position.Z - base.centerZ)
	return dx <= BASE_HALF_W and dz <= BASE_HALF_D
end

-- Is a base locked right now?
local function baseLocked(base)
	return base and base.lockUntil and os.time() < base.lockUntil
end

-- Show / hide the red lock barrier + LOCKED sign on a base.
local function updateLockVisual(baseIndex)
	local base = Bases[baseIndex]
	if not base or not base.lockBarrier then
		return
	end
	local locked = baseLocked(base)
	base.lockBarrier.Transparency = locked and 0.45 or 1
	if base.lockGui then
		base.lockGui.Enabled = locked
	end
	base.lockVisualShown = locked
end

-- Lock your own base for LOCK_DURATION seconds (then LOCK_COOLDOWN).
local function tryLockBase(player)
	local data = getData(player)
	if not data or data.BaseIndex <= 0 then
		notify(player, "You don't have a base to lock yet!", Color3.fromRGB(255, 120, 120))
		return
	end
	local base = Bases[data.BaseIndex]
	if not base then
		return
	end
	local now = os.time()
	if baseLocked(base) then
		notify(player, "🔒 Your base is already locked (" .. tostring(base.lockUntil - now) .. "s left)!", Color3.fromRGB(255, 220, 120))
		return
	end
	if now < (base.lockCooldownUntil or 0) then
		notify(player, "🔒 Lock is on cooldown — " .. tostring(base.lockCooldownUntil - now) .. "s left.", Color3.fromRGB(255, 120, 120))
		return
	end
	base.lockUntil = now + LOCK_DURATION
	base.lockCooldownUntil = base.lockUntil + LOCK_COOLDOWN
	updateLockVisual(data.BaseIndex)
	notify(player, "🔒 Base LOCKED for " .. tostring(LOCK_DURATION) .. "s! Nobody can steal from you.", Color3.fromRGB(120, 255, 120))
	ClientFX:FireClient(player, "Cash", {})
end

-- Lock expiry watcher: hide the barrier + tell the owner when a lock ends.
task.spawn(function()
	while true do
		task.wait(1)
		for i, base in ipairs(Bases) do
			if base.owner and base.lockVisualShown and not baseLocked(base) then
				updateLockVisual(i)
				notify(base.owner, "🔓 Your base lock expired — lock again with L!", Color3.fromRGB(255, 220, 120))
			end
		end
	end
end)

-- Weld a brainrot model above the thief's head (carry). Parts are
-- unanchored + massless + non-colliding BEFORE the weld (the v4.1
-- lesson: a weld with an identity C0 glues the model onto the face).
local function attachCarryModel(player, model)
	local character = player.Character
	if not character then
		return false
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return false
	end
	-- v7.6.4: carried models are 0.5x like Tools (HELD_MODEL_SCALE) —
	-- a 1x model above the head looms as large as a held Tool did.
	pcall(function()
		model:ScaleTo(HELD_MODEL_SCALE)
	end)
	-- v7.6.4: same Tag-offset fix as giveTool — ScaleTo shrinks the
	-- model but not the label offset, so the name would float far above
	-- the carried brainrot. Recompute from the scaled height.
	local carryCh = DB.GetCharacter(model.Name)
	local carryTag = model:FindFirstChild("Tag")
	if carryCh and carryTag and carryTag:IsA("BillboardGui") then
		carryTag.StudsOffsetWorldSpace = Vector3.new(0, carryCh.Height * HELD_MODEL_SCALE + 0.9, 0)
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
		end
	end
	local headTop = head.Position.Y + head.Size.Y / 2
	-- Bottom of the model sits 0.5 studs above the head.
	local pivotY = headTop + 0.5 - bottomOffsetOf(model)
	model:PivotTo(CFrame.new(head.Position.X, pivotY, head.Position.Z) * head.CFrame.Rotation)
	model.Parent = character
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = head
	weld.Part1 = model.PrimaryPart
	weld.C0 = head.CFrame:ToObjectSpace(model.PrimaryPart.CFrame)
	weld.C1 = CFrame.new()
	weld.Parent = model.PrimaryPart
	return true
end

-- Steal attempt (from a base display prompt). All validation happens
-- here on the server — the prompt itself is just a button.
trySteal = function(thief, victim, name, eventKey)
	if not thief or not victim then
		return
	end
	if thief == victim then
		notify(thief, "That's your own brainrot!", Color3.fromRGB(255, 220, 120))
		return
	end
	local thiefData = getData(thief)
	local victimData = getData(victim)
	if not thiefData or not victimData then
		return
	end
	if thiefData.BaseIndex <= 0 then
		notify(thief, "You need your own base first (server is full)!", Color3.fromRGB(255, 120, 120))
		return
	end
	if Carrying[thief] then
		notify(thief, "You're already carrying a brainrot — bring it to your base first!", Color3.fromRGB(255, 220, 120))
		return
	end
	local now = os.time()
	if now < (StealCooldownUntil[thief] or 0) then
		notify(thief, "Steal cooldown — " .. tostring(StealCooldownUntil[thief] - now) .. "s left.", Color3.fromRGB(255, 120, 120))
		return
	end
	if victimData.BaseIndex <= 0 then
		notify(thief, "That brainrot has no base anymore.", Color3.fromRGB(255, 120, 120))
		return
	end
	local victimBase = Bases[victimData.BaseIndex]
	if not victimBase then
		notify(thief, "That brainrot has no base anymore.", Color3.fromRGB(255, 120, 120))
		return
	end
	if baseLocked(victimBase) then
		notify(thief, "🔒 " .. victim.DisplayName .. "'s base is LOCKED! Try again later.", Color3.fromRGB(255, 120, 120))
		return
	end
	local actualKey = pickCopyKey(victimData, name, eventKey)
	if not actualKey then
		notify(thief, "That brainrot is already gone!", Color3.fromRGB(255, 120, 120))
		return
	end
	-- Build the carried model FIRST (if it fails, nothing is taken).
	local okBuild, model = pcall(DB.BuildModel, name, actualKey, incomeMult(thiefData))
	if not okBuild or not model then
		warn("[Plaza] BuildModel failed for steal " .. tostring(name))
		return
	end
	-- Take ONE copy from the victim (the displayed event tab, or any).
	if not removeCopy(victim, name, actualKey) then
		model:Destroy()
		notify(thief, "That brainrot is already gone!", Color3.fromRGB(255, 120, 120))
		return
	end
	refreshBase(victim)
	-- v7.6.6: the victim just lost income (maybe their last copy of this
	-- name) — tell their client to re-sync so the HUD rate stays honest.
	ClientFX:FireClient(victim, "Cash", {})
	-- Carry it: weld above the thief's head. If the weld fails, give it back.
	if not attachCarryModel(thief, model) then
		model:Destroy()
		grantCopy(victim, name, actualKey)
		refreshBase(victim)
		notify(thief, "Steal failed — try again!", Color3.fromRGB(255, 120, 120))
		return
	end
	Carrying[thief] = { name = name, eventKey = actualKey, victim = victim, model = model }
	StealCooldownUntil[thief] = now + STEAL_COOLDOWN
	notify(thief, "🎒 You stole " .. name .. " from " .. victim.DisplayName .. "! Bring it to YOUR base!", Color3.fromRGB(255, 220, 80))
	notify(victim, "🚨 " .. thief.DisplayName .. " is stealing your " .. name .. "! Chase them!", Color3.fromRGB(255, 80, 80))
	local ch = DB.GetCharacter(name)
	if ch and (DB.RarityRank[ch.Rarity] or 0) >= 5 then
		ClientFX:FireAllClients("Announce", {
			PlayerName = thief.Name,
			CharacterName = "STOLE " .. name .. " from " .. victim.Name,
			Rarity = ch.Rarity,
			AuraPerSec = auraPerSec(name),
		})
	end
	saveData(victim)
	saveData(thief)
end

-- Deposit a carried brainrot in the thief's own base (called by the
-- deposit loop when the carrier steps inside their base).
local function depositCarry(player)
	local carry = Carrying[player]
	if not carry then
		return
	end
	local name, eventKey, victim = carry.name, carry.eventKey, carry.victim
	if carry.model then
		pcall(function() carry.model:Destroy() end)
	end
	Carrying[player] = nil
	grantCopy(player, name, eventKey)
	refreshBase(player)
	notify(player, "✅ " .. name .. " is yours now! It stands in your base.", Color3.fromRGB(120, 255, 120))
	-- v7.6.6: the thief just gained income — re-sync their HUD rate.
	ClientFX:FireClient(player, "Cash", {})
	if victim and victim.Parent then
		notify(victim, "💔 Your " .. name .. " was stolen by " .. player.DisplayName .. "!", Color3.fromRGB(255, 80, 80))
	end
	saveData(player)
	if victim then
		saveData(victim)
	end
end

-- Give a carried brainrot back to its victim (carrier died / left /
-- reset). The copy is restored, so nobody ever loses a brainrot to a
-- crash or a reset — the v4 anti-loss rule.
local function returnCarry(player)
	local carry = Carrying[player]
	if not carry then
		return
	end
	local name, eventKey, victim = carry.name, carry.eventKey, carry.victim
	if carry.model then
		pcall(function() carry.model:Destroy() end)
	end
	Carrying[player] = nil
	if victim and victim.Parent and getData(victim) then
		grantCopy(victim, name, eventKey)
		refreshBase(victim)
		notify(victim, "🛡️ Your " .. name .. " is back in your base!", Color3.fromRGB(120, 255, 120))
		-- v7.6.6: the victim's income is restored — re-sync their HUD rate.
		ClientFX:FireClient(victim, "Cash", {})
		saveData(victim)
	end
	notify(player, "The stolen brainrot returned to its owner.", Color3.fromRGB(255, 220, 120))
end

-- Deposit watcher: every 0.5s, any carrier standing inside their own
-- base deposits the stolen brainrot there.
task.spawn(function()
	while true do
		task.wait(0.5)
		for player in pairs(Carrying) do
			if player.Parent and insideOwnBase(player) then
				local ok, err = pcall(depositCarry, player)
				if not ok then
					warn("[Plaza] depositCarry failed: " .. tostring(err))
				end
			end
		end
	end
end)

--------------------------------------------------------------------------------
-- Remote handlers
--------------------------------------------------------------------------------

RollDie.OnServerInvoke = function(player, tier)
	return rollDie(player, tier)
end

GetState.OnServerInvoke = function(player)
	local data = getData(player)
	if not data then
		return { Owned = {}, Aura = 0, Dollar = 0, Luck = 0, Unlocked = 0, Rebirth = 0, Base = 0, Index = {}, Copies = {}, Unheld = {}, Event = "Basic", EventLeft = 0, IndexBonus = 0, Friends = 0, LockUntil = 0, LockCooldownUntil = 0 }
	end
	local ownedList = {}
	for name in pairs(data.Copies) do
		table.insert(ownedList, name)
	end
	-- v7.3: the client's LOCK button countdown reads these.
	local lockUntil, lockCooldownUntil = 0, 0
	if data.BaseIndex > 0 then
		local base = Bases[data.BaseIndex]
		if base then
			lockUntil = base.lockUntil or 0
			lockCooldownUntil = base.lockCooldownUntil or 0
		end
	end
	return {
		Owned = ownedList,
		Aura = data.Aura.Value,
		Dollar = data.Dollar.Value,
		Luck = data.Luck.Value,
		Unlocked = data.Unlocked.Value,
		Rebirth = data.Rebirth.Value,
		Base = data.BaseIndex,
		Index = data.Index,
		Copies = data.Copies,
		Unheld = data.Unheld, -- v7.4: stored names (no Tool)
		Event = currentEvent,
		EventLeft = math.max(0, eventEndsAt - os.time()),
		IndexBonus = indexBonus(data),
		Friends = friendCount(),
		LockUntil = lockUntil,
		LockCooldownUntil = lockCooldownUntil,
	}
end

DoRebirth.OnServerEvent:Connect(function(player)
	doRebirth(player)
end)

LockBase.OnServerEvent:Connect(function(player)
	tryLockBase(player)
end)

-- v7.4 INVENTORY: the client toggles hold/equip for one owned name.
-- held = true → Tools back in the backpack (default); held = false →
-- stored in the inventory only (copies, base display and income are
-- untouched). Validated server-side: the name must exist in the
-- database and the player must own at least one copy of it.
SetHeld.OnServerEvent:Connect(function(player, name, held)
	local data = getData(player)
	if not data or type(name) ~= "string" or type(held) ~= "boolean" then
		return
	end
	if not DB.GetCharacter(name) then
		return
	end
	if totalCopies(data, name) <= 0 then
		return
	end
	if held then
		data.Unheld[name] = nil
	else
		data.Unheld[name] = true
	end
	syncTools(player)
	if os.time() - data.lastSave > 30 then
		saveData(player)
	end
end)

ClickAura.OnServerEvent:Connect(function(player)
	local data = getData(player)
	if not data then
		return
	end
	local now = os.clock()
	if now - data.LastClick < CLICK_COOLDOWN then
		return
	end
	data.LastClick = now
	data.Aura.Value = data.Aura.Value + CLICK_AURA
end)

SellCopy.OnServerEvent:Connect(function(player)
	sellBestCopy(player)
end)

BuyLuck.OnServerEvent:Connect(function(player)
	buyLuck(player)
end)

-- v7.1: clients report server-not-responding waits here (see waitChild in
-- BrainrotUI) so a silent client hang shows up in the server log too.
ClientError.OnServerEvent:Connect(function(player, message)
	warn("[Plaza] Client " .. player.Name .. " reports: " .. tostring(message))
end)

-- Shop prompts: the Sell Zone sells on hold; the Luck Zone opens the shop UI.
local function connectShopPrompts()
	local sell = Zones:FindFirstChild("SellZone")
	if sell then
		local pr = sell:FindFirstChildOfClass("ProximityPrompt")
		if pr then
			pr.Triggered:Connect(sellBestCopy)
		end
	end
	local luck = Zones:FindFirstChild("LuckZone")
	if luck then
		local pr = luck:FindFirstChildOfClass("ProximityPrompt")
		if pr then
			pr.Triggered:Connect(function(player)
				ShopOpen:FireClient(player, "luck")
			end)
		end
	end
	-- Dice prompts: hold E on a die to roll it.
	for tier, die in pairs(Dice) do
		local cube = die.model.PrimaryPart
		if cube then
			local pr = cube:FindFirstChildOfClass("ProximityPrompt")
			if pr then
				pr.Triggered:Connect(function(player)
					local result = rollDie(player, tier)
					if result.ok then
						ClientFX:FireClient(player, "RollResult", result)
					end
				end)
			end
		end
	end
	-- Rebirth Altar prompt: hold E on the chest to rebirth.
	-- v7.1: guard — if section 9 failed, altarChest is nil, and an
	-- unguarded prompt() here would kill the script before PlayerAdded
	-- is connected. No altar = no rebirth prompt, but the game still runs.
	if altarChest then
		local rebirthPrompt = prompt(altarChest, "Rebirth", 0.5)
		rebirthPrompt.Triggered:Connect(function(player)
			doRebirth(player)
		end)
	end
end
connectShopPrompts()

--------------------------------------------------------------------------------
-- Player lifecycle
--------------------------------------------------------------------------------

local function onPlayerAdded(player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local aura = Instance.new("IntValue")
	aura.Name = "Aura"
	aura.Value = STARTING_AURA
	aura.Parent = leaderstats
	local dollar = Instance.new("IntValue")
	dollar.Name = "Dollar"
	dollar.Value = 0
	dollar.Parent = leaderstats
	local luck = Instance.new("IntValue")
	luck.Name = "Luck"
	luck.Value = 0
	luck.Parent = leaderstats
	local unlocked = Instance.new("IntValue")
	unlocked.Name = "Unlocked"
	unlocked.Value = 0
	unlocked.Parent = leaderstats
	local rebirth = Instance.new("IntValue")
	rebirth.Name = "Rebirth"
	rebirth.Value = 0
	rebirth.Parent = leaderstats

	PlayerData[player] = {
		Aura = aura,
		Dollar = dollar,
		Luck = luck,
		Unlocked = unlocked,
		Rebirth = rebirth,
		Copies = {},
		Index = {},
		Unheld = {}, -- v7.4: names stored in the inventory (no Tool)
		BaseIndex = 0,
		LastClick = 0,
		lastSave = 0,
	}

	-- v7.1: the post-join setup is pcall-wrapped so one bad step can never
	-- kill leaderstats for this player (or the next joins). leaderstats
	-- above are created WITHOUT pcall — they must always exist.
	local okLoad, errLoad = pcall(loadData, player)
	if not okLoad then
		warn("[Plaza] loadData failed for " .. player.Name .. ": " .. tostring(errLoad))
	end

	-- Claim a base (first free of 10); rebuild its display + the Backpack
	-- Tools from the save.
	local baseIndex = 0
	local okBase, errBase = pcall(function()
		baseIndex = assignBase(player)
	end)
	if not okBase then
		warn("[Plaza] assignBase failed for " .. player.Name .. ": " .. tostring(errBase))
	elseif baseIndex == 0 then
		notify(player, "Server is full — all 10 bases are taken. You can still walk around and roll, but your brainrots have no base to stand on.", Color3.fromRGB(255, 120, 120))
	else
		local okRefresh, errRefresh = pcall(refreshBase, player)
		if not okRefresh then
			warn("[Plaza] refreshBase failed for " .. player.Name .. ": " .. tostring(errRefresh))
		end
	end
	local okTools, errTools = pcall(syncTools, player)
	if not okTools then
		warn("[Plaza] syncTools failed for " .. player.Name .. ": " .. tostring(errTools))
	end

	player.CharacterAdded:Connect(function(_character)
		-- Fast feet on every spawn (WalkSpeed 26, v7) + rebuild any Tool
		-- lost to death (an equipped Tool is destroyed when the
		-- character dies).
		-- v7.3: dying while carrying returns the stolen brainrot to its
		-- victim (the old character, and the weld, are already gone).
		returnCarry(player)
		setSpeed(player, NORMAL_SPEED)
		syncTools(player)
	end)
end

local function onPlayerRemoving(player)
	-- v7.3: if this player is carrying a stolen brainrot, give it back
	-- to its victim BEFORE the save (so the victim never loses it to a
	-- carrier leaving). And if anyone is carrying THIS player's
	-- brainrot, return it first so the victim's save keeps the copy.
	returnCarry(player)
	local toReturn = {}
	for carrier, carry in pairs(Carrying) do
		if carry.victim == player then
			table.insert(toReturn, carrier)
		end
	end
	for _, carrier in ipairs(toReturn) do
		returnCarry(carrier)
	end
	local data = getData(player)
	if data then
		freeBase(player)
		saveData(player)
	end
	PlayerData[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

--------------------------------------------------------------------------------
-- Loops: passive income, base spin, orb bob
--------------------------------------------------------------------------------

-- Passive income, once a second: EVERY distinct brainrot the player owns
-- pays its rarity Aura/s (not per copy — one slot per character).
-- Multiplied by Rebirth (+50% per level), the Index completion bonus
-- (+10% per completed tab) and the Friend buff (+5% per other player,
-- cap +20%), plus a shrine bonus for anyone standing inside a glowing
-- Aura Shrine.
task.spawn(function()
	while true do
		task.wait(1)
		for player, data in pairs(PlayerData) do
			local character = player.Character
			local inShrine = false
			if character then
				local root = character:FindFirstChild("HumanoidRootPart")
				if root then
					for _, center in ipairs(ShrineCenters) do
						local dx = root.Position.X - center.X
						local dz = root.Position.Z - center.Z
						if dx * dx + dz * dz < 81 then
							inShrine = true
							break
						end
					end
				end
			end
			local gain = 0
			for name in pairs(data.Copies) do
				gain = gain + auraPerSec(name)
			end
			if inShrine then
				gain = gain + SHRINE_AURA_PER_SEC
			end
			if gain > 0 then
				gain = math.floor(gain * (1 + REBIRTH_INCOME_BONUS * data.Rebirth.Value) * (1 + indexBonus(data)) * (1 + friendBonus()) + 0.5)
				data.Aura.Value = data.Aura.Value + gain
			end
			if os.time() - data.lastSave > 180 then
				saveData(player)
			end
		end
	end
end)

-- Base spin: every displayed brainrot slowly rotates on its pedestal.
-- All display models are ANCHORED, so PivotTo per frame is perfectly
-- stable — no gravity, no jitter, no flicker (the v5 follow bug, gone).
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for _, base in ipairs(Bases) do
		for _, slot in ipairs(base.slots) do
			if slot.model and slot.cframe then
				slot.model:PivotTo(slot.cframe * CFrame.Angles(0, now * 0.6 + slot.phase, 0))
			end
		end
	end
end)

-- The altar orb slowly bobs and spins so the centre of the plaza reads as
-- alive even when nobody is rebirthing.
-- v7.1: guard — if section 9 failed, altarOrb is nil; without this the
-- callback would error every single heartbeat.
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if altarOrb then
		altarOrb.CFrame = CFrame.new(0, 10 + math.sin(now * 1.2) * 0.5, 0) * CFrame.Angles(0, now * 0.4, 0)
	end
end)

--------------------------------------------------------------------------------
-- Tour hooks (driven by TOUR.json so reviewers can reach every screenshot)
--------------------------------------------------------------------------------

local TourDice = Instance.new("BindableEvent")
TourDice.Name = "TourDice"
TourDice.Parent = ServerScriptService

local TourBase = Instance.new("BindableEvent")
TourBase.Name = "TourBase"
TourBase.Parent = ServerScriptService

local TourWeather = Instance.new("BindableEvent")
TourWeather.Name = "TourWeather"
TourWeather.Parent = ServerScriptService

local TourIndex = Instance.new("BindableEvent")
TourIndex.Name = "TourIndex"
TourIndex.Parent = ServerScriptService

local TourRebirth = Instance.new("BindableEvent")
TourRebirth.Name = "TourRebirth"
TourRebirth.Parent = ServerScriptService

TourDice.Event:Connect(function(player)
	local data = getData(player)
	if not data then
		return
	end
	data.Aura.Value = math.max(data.Aura.Value, 10000)
	local result = rollDie(player, "Common")
	if result.ok then
		ClientFX:FireClient(player, "RollResult", result)
	end
	-- A couple of extra copies so the base reads as populated on camera.
	grantCopy(player, "Lirili Larila", currentEvent)
	grantCopy(player, "Frigo Camelo", currentEvent)
	refreshBase(player)
end)

TourBase.Event:Connect(function(player)
	local data = getData(player)
	if not data then
		return
	end
	-- The top 4 by Aura/s show (only 4 slots open at Rebirth 0); the
	-- Godly Bombardiro Crocodilo (100000/s) is #1 and the v7.3 MEME LEGEND
	-- Tralalero Tralala (5000/s) #2, so the tour base shows the biggest
	-- meme brainrots front and centre.
	grantCopy(player, "Pipi Kiwi", "Basic")
	grantCopy(player, "Lirili Larila", "Basic")
	grantCopy(player, "Frigo Camelo", "Basic")
	grantCopy(player, "Bombardiro Crocodilo", "Basic")
	grantCopy(player, "Tralalero Tralala", "Basic")
	refreshBase(player)
	notify(player, "Tour: your base now shows brainrots — including a giant Tralalero Tralala!", Color3.fromRGB(120, 255, 120))
end)

TourWeather.Event:Connect(function(player)
	-- Force a RANDOM buff event (never the current one, never Basic),
	-- so reviewers see a real 60-second buff with its visuals.
	local pick = pickNextBuffEvent()
	lastBuffEvent = pick
	applyEvent(pick, EVENT_DURATION)
	if player then
		notify(player, "Tour: " .. pick .. " event forced (x" .. tostring(DB.Events[pick].Mult) .. " value, 60s)!", Color3.fromRGB(255, 200, 80))
	end
end)

TourIndex.Event:Connect(function(player)
	local data = getData(player)
	if not data then
		return
	end
	applyEvent("Summer", EVENT_DURATION)
	local unlocks = {
		{ "Basic", "Pipi Kiwi" }, { "Basic", "Pot Hotspot" },
		{ "Basic", "Bombardiro Crocodilo" }, { "Summer", "Bombardiro Crocodilo" },
		{ "Summer", "Tralalero Tralala" }, { "Summer", "Lirili Larila" },
	}
	for _, u in ipairs(unlocks) do
		data.Index[u[1]] = data.Index[u[1]] or {}
		data.Index[u[1]][u[2]] = true
		grantCopy(player, u[2], u[1])
	end
	refreshBase(player)
	syncUnlocked(player)
	ClientFX:FireClient(player, "OpenIndex", {})
end)

TourRebirth.Event:Connect(function(player)
	local data = getData(player)
	if not data then
		return
	end
	data.Aura.Value = math.max(data.Aura.Value, 100000)
	ClientFX:FireClient(player, "OpenRebirth", {})
end)
