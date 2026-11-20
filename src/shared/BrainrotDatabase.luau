-- PLAZA DEL DELIRIO — BrainrotDatabase (ReplicatedStorage/BrainrotDatabase).
-- The single source of truth for the game's cast: all 37 viral meme
-- characters (Italian brainrot, built procedurally from Parts — never a copy
-- of another game's assets), their 8 rarity tiers, base Dollar values, spawn
-- weights,
-- the 6 weather/mutation events, plus BuildModel() and the Custom Model
-- Override loader. Required by the server (WorldAndSystems) and the
-- client (BrainrotUI) for names, colors, values and the Index UI.
-- v7.1 HARDENING: ValueOf() guards a nil character (returns 0 instead of
-- erroring and killing its caller).
-- v7.5: roster replaced with the 37 viral characters from the Brainrot37
-- package (Bombardiro Crocodilo is Godly; the 3 v7.3 legends keep their
-- rarity + Value); builders ported from the package, adapted to this
-- file's finish(model, body, ch, eventKey).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotDatabase = {}

-- Rarity tiers, weakest to strongest. Rank is used for spawn boosts, the
-- Index UI and the Legendary+ server announcements.
BrainrotDatabase.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Godly" }

BrainrotDatabase.RarityRank = {
	Common = 1, Uncommon = 2, Rare = 3, Epic = 4,
	Legendary = 5, Mythic = 6, Secret = 7, Godly = 8,
}

BrainrotDatabase.RarityColors = {
	Common = Color3.fromRGB(190, 190, 190),
	Uncommon = Color3.fromRGB(110, 220, 110),
	Rare = Color3.fromRGB(80, 170, 255),
	Epic = Color3.fromRGB(170, 80, 255),
	Legendary = Color3.fromRGB(255, 170, 0),
	Mythic = Color3.fromRGB(255, 70, 130),
	Secret = Color3.fromRGB(0, 220, 220),
	Godly = Color3.fromRGB(255, 220, 60),
}

-- Weather / mutation events. A buff event lasts 60 seconds (v7 — was 10
-- minutes). Basic is NOT an event: it is the calm default (x1, no buff,
-- no particles). The server picks buff events RANDOMLY from
-- {Summer, Rainy, Cold, Gothic, Void}, never the same twice in a row.
-- v7.6: mutations are RARE — first buff 4-6 min after start, then 5-8
-- min of Basic between cycles, and only ~25% of cycles get a buff at
-- all (the rest stay Basic). Mult multiplies the Dollar value of every
-- brainrot rescued while the event is active, and the Index records the
-- rescue under that event's tab. Gravity is Workspace.Gravity while the
-- event runs.
BrainrotDatabase.Events = {
	Basic = {
		Name = "Basic", Mult = 1,
		ClockTime = 10, Ambient = Color3.fromRGB(178, 178, 191),
		OutdoorAmbient = Color3.fromRGB(204, 204, 217),
		FogColor = Color3.fromRGB(191, 204, 230), FogStart = 300, FogEnd = 1500,
		Brightness = 2, Gravity = 196.2,
		Particle = "None", ParticleColor = Color3.fromRGB(255, 255, 255),
	},
	Summer = {
		Name = "Summer", Mult = 4,
		ClockTime = 16, Ambient = Color3.fromRGB(230, 153, 77),
		OutdoorAmbient = Color3.fromRGB(255, 200, 120),
		FogColor = Color3.fromRGB(255, 179, 89), FogStart = 200, FogEnd = 900,
		Brightness = 2.5, Gravity = 196.2,
		Particle = "Ember", ParticleColor = Color3.fromRGB(255, 200, 80),
	},
	Rainy = {
		Name = "Rainy", Mult = 6,
		ClockTime = 13, Ambient = Color3.fromRGB(64, 77, 115),
		OutdoorAmbient = Color3.fromRGB(90, 110, 150),
		FogColor = Color3.fromRGB(77, 89, 128), FogStart = 150, FogEnd = 600,
		Brightness = 1.2, Gravity = 196.2,
		Particle = "Rain", ParticleColor = Color3.fromRGB(140, 180, 255),
	},
	Cold = {
		Name = "Cold", Mult = 8,
		ClockTime = 11, Ambient = Color3.fromRGB(179, 217, 230),
		OutdoorAmbient = Color3.fromRGB(200, 225, 240),
		FogColor = Color3.fromRGB(204, 230, 255), FogStart = 150, FogEnd = 500,
		Brightness = 1.6, Gravity = 196.2,
		Particle = "Snow", ParticleColor = Color3.fromRGB(255, 255, 255),
	},
	Gothic = {
		Name = "Gothic", Mult = 10,
		ClockTime = 20, Ambient = Color3.fromRGB(102, 13, 20),
		OutdoorAmbient = Color3.fromRGB(70, 10, 15),
		FogColor = Color3.fromRGB(38, 5, 13), FogStart = 100, FogEnd = 400,
		Brightness = 1, Gravity = 196.2,
		Particle = "Wisp", ParticleColor = Color3.fromRGB(170, 90, 255),
	},
	Void = {
		Name = "Void", Mult = 12,
		ClockTime = 0, Ambient = Color3.fromRGB(26, 13, 64),
		OutdoorAmbient = Color3.fromRGB(40, 20, 90),
		FogColor = Color3.fromRGB(13, 5, 38), FogStart = 150, FogEnd = 800,
		Brightness = 1.5, Gravity = 150,
		Particle = "Star", ParticleColor = Color3.fromRGB(190, 130, 255),
	},
}

BrainrotDatabase.EventOrder = { "Basic", "Summer", "Rainy", "Cold", "Gothic", "Void" }
-- How long one buff event runs (seconds), and the random gaps around it.
-- v7.6: mutations are rare — long Basic gaps and only a ~25% chance a
-- cycle gets a buff at all (mirrors the server's scheduler constants).
BrainrotDatabase.EventDuration = 60
BrainrotDatabase.EventFirstDelayMin = 240
BrainrotDatabase.EventFirstDelayMax = 360
BrainrotDatabase.EventGapMin = 300
BrainrotDatabase.EventGapMax = 480
BrainrotDatabase.MutationChance = 0.25

-- The full roster: 37 characters, zero truncation. Value is the base Dollar
-- price (before the active event multiplier and the Index-completion bonus).
-- Weight is the spawn weight inside its tier (dice pick inside one tier);
-- Meteor Luck multiplies Epic+ weights.
-- Height is the model's total height in studs (used for the name tag and
-- for placing models on base pedestals). Primary/Accent are {r,g,b}.
BrainrotDatabase.Characters = {
	-- Common (8) — $10 to $25.
	{ Name = "Pipi Kiwi", Rarity = "Common", Value = 10, Weight = 100, Build = "KiwiBird", Face = "o_o", Height = 2.0, Primary = {150, 110, 70}, Accent = {255, 180, 60}, Blurb = "A tiny brown kiwi bird with a very long beak." },
	{ Name = "Boneca Ambalabu", Rarity = "Common", Value = 12, Weight = 100, Build = "FrogTire", Face = "^_^", Height = 2.4, Primary = {90, 200, 90}, Accent = {40, 40, 45}, Blurb = "A green frog riding a black tire. Ribbit on wheels." },
	{ Name = "Pipi Popcorn", Rarity = "Common", Value = 15, Weight = 100, Build = "PopcornBucket", Face = "o_o", Height = 2.4, Primary = {220, 50, 50}, Accent = {255, 240, 200}, Blurb = "A red popcorn bucket with a face. Freshly popped." },
	{ Name = "Pot Hotspot", Rarity = "Common", Value = 15, Weight = 100, Build = "HotPot", Face = ">_<", Height = 2.6, Primary = {220, 50, 40}, Accent = {255, 150, 40}, Blurb = "A boiling red pot with chilies. Do not touch." },
	{ Name = "Trippi Troppi", Rarity = "Common", Value = 18, Weight = 100, Build = "FishBear", Face = "o_o", Height = 2.6, Primary = {230, 140, 90}, Accent = {150, 110, 70}, Blurb = "A trout with bear ears. Half fish, half hug." },
	{ Name = "Los Crocodillitos", Rarity = "Common", Value = 20, Weight = 100, Build = "BabyCrocs", Face = "^_^", Height = 2.0, Primary = {60, 230, 90}, Accent = {245, 245, 245}, Blurb = "Three baby crocodiles. Triple the trouble." },
	{ Name = "Trulimero Trulichina", Rarity = "Common", Value = 22, Weight = 100, Build = "CatFish", Face = "o_o", Height = 2.4, Primary = {240, 150, 60}, Accent = {90, 140, 200}, Blurb = "An orange cat with a fish tail. Meow, splash." },
	{ Name = "Frulli Frulla", Rarity = "Common", Value = 25, Weight = 100, Build = "PenguinBlender", Face = ":-)", Height = 2.4, Primary = {40, 40, 55}, Accent = {255, 210, 90}, Blurb = "A penguin with a blender. Smoothies all day." },
	-- Uncommon (7) — $60 to $120.
	{ Name = "Lirili Larila", Rarity = "Uncommon", Value = 60, Weight = 45, Build = "CactusElephant", Face = "o_o", Height = 3.0, Primary = {70, 200, 90}, Accent = {255, 220, 130}, Blurb = "A cactus with an elephant trunk, in flip-flops." },
	{ Name = "Bananita Dolphinita", Rarity = "Uncommon", Value = 70, Weight = 45, Build = "BananaDolphin", Face = "^_^", Height = 2.6, Primary = {255, 220, 60}, Accent = {255, 240, 180}, Blurb = "A banana dolphin. Potassium with fins." },
	{ Name = "Graipuss Medussi", Rarity = "Uncommon", Value = 80, Weight = 45, Build = "GrapeJellyfish", Face = "o_o", Height = 3.0, Primary = {150, 70, 200}, Accent = {220, 160, 255}, Blurb = "A grape jellyfish with six tentacles. Stings sweet." },
	{ Name = "Los Orcalitos", Rarity = "Uncommon", Value = 90, Weight = 45, Build = "BabyOrcas", Face = "^_^", Height = 2.2, Primary = {30, 30, 40}, Accent = {245, 245, 245}, Blurb = "Three baby orcas. Black, white and adorable." },
	{ Name = "Zibra Zubra Zibralini", Rarity = "Uncommon", Value = 100, Weight = 45, Build = "Zebra", Face = "o_o", Height = 3.0, Primary = {245, 245, 245}, Accent = {30, 30, 35}, Blurb = "A striped zebra. Very serious about stripes." },
	{ Name = "Il Cacto Hipopotamo", Rarity = "Uncommon", Value = 110, Weight = 45, Build = "CactusHippo", Face = "-_-", Height = 2.8, Primary = {70, 200, 90}, Accent = {180, 230, 130}, Blurb = "A cactus hippo. Prickly outside, chill inside." },
	{ Name = "Karkerkar Kurkur", Rarity = "Uncommon", Value = 120, Weight = 45, Build = "CrowKing", Face = ">:)", Height = 2.6, Primary = {30, 30, 35}, Accent = {255, 210, 60}, Blurb = "A black crow king with a golden crown." },
	-- Rare (6) — $300 to $600.
	{ Name = "Chicletera Bicicleteira", Rarity = "Rare", Value = 300, Weight = 20, Build = "GumBike", Face = ":-)", Height = 2.8, Primary = {255, 120, 180}, Accent = {60, 60, 70}, Blurb = "A pink gum creature riding a bicycle." },
	{ Name = "Rhyno Toasterino", Rarity = "Rare", Value = 350, Weight = 20, Build = "RhinoToaster", Face = "o_o", Height = 3.0, Primary = {150, 150, 155}, Accent = {200, 200, 210}, Blurb = "A grey rhino with a toaster on its back. Toast pops!" },
	{ Name = "Tigrrullini Watermellini", Rarity = "Rare", Value = 400, Weight = 20, Build = "TigerWatermelon", Face = ">:)", Height = 2.8, Primary = {240, 140, 40}, Accent = {60, 200, 90}, Blurb = "An orange tiger with a watermelon belly." },
	{ Name = "Blueberrinni Octopussini", Rarity = "Rare", Value = 450, Weight = 20, Build = "BlueberryOctopus", Face = "o_o", Height = 2.6, Primary = {60, 100, 230}, Accent = {140, 180, 255}, Blurb = "A blueberry octopus with eight tentacles." },
	{ Name = "Svinino Bombondino", Rarity = "Rare", Value = 500, Weight = 20, Build = "PigBomber", Face = "o_O", Height = 2.6, Primary = {255, 170, 200}, Accent = {90, 120, 80}, Blurb = "A pink pig in a bomber helmet, holding a bomb." },
	{ Name = "Orangutini Ananasini", Rarity = "Rare", Value = 600, Weight = 20, Build = "OrangutanPineapple", Face = "^_^", Height = 3.0, Primary = {230, 120, 50}, Accent = {255, 220, 60}, Blurb = "An orange orangutan with a pineapple on its head." },
	-- Epic (5) — $1,500 to $3,000.
	{ Name = "Frigo Camelo", Rarity = "Epic", Value = 1500, Weight = 8, Build = "FridgeCamel", Face = "o_o", Height = 3.2, Primary = {190, 150, 100}, Accent = {0, 255, 220}, Blurb = "A camel with a glowing fridge on its back." },
	{ Name = "Giraffa Celeste", Rarity = "Epic", Value = 2000, Weight = 8, Build = "SkyGiraffe", Face = "^_^", Height = 3.5, Primary = {140, 190, 255}, Accent = {255, 240, 150}, Blurb = "A sky-blue giraffe with star spots and a long neck." },
	{ Name = "Bombombini Gusini", Rarity = "Epic", Value = 2500, Weight = 8, Build = "GooseBomber", Face = "B)", Height = 3.0, Primary = {245, 245, 240}, Accent = {255, 150, 40}, Blurb = "A white goose with bomber wings and pilot goggles." },
	{ Name = "Los Tralaleritos", Rarity = "Epic", Value = 2800, Weight = 8, Build = "BabySharks", Face = "^_^", Height = 2.2, Primary = {70, 140, 255}, Accent = {245, 245, 245}, Blurb = "Three baby sharks in sneakers. Small but speedy." },
	{ Name = "Las Tralaleritas", Rarity = "Epic", Value = 3000, Weight = 8, Build = "BabySharksPink", Face = "^_^", Height = 2.2, Primary = {255, 140, 200}, Accent = {245, 245, 245}, Blurb = "Three pink baby sharks with bows. Cuter than cute." },
	-- Legendary (4) — $8,000 to $20,000.
	{ Name = "Brr Brr Patapim", Rarity = "Legendary", Value = 8000, Weight = 3, Build = "ProboscisMonkey", Face = "o_o", Height = 3.2, Primary = {120, 90, 60}, Accent = {200, 160, 110}, Blurb = "A brown proboscis monkey with a giant nose." },
	{ Name = "Chimpanzini Bananini", Rarity = "Legendary", Value = 12000, Weight = 3, Build = "ChimpBanana", Face = "o_O", Height = 2.8, Primary = {220, 170, 60}, Accent = {170, 90, 255}, Blurb = "A chimp napping inside a giant banana peel." },
	{ Name = "Cappuccino Assassino", Rarity = "Legendary", Value = 15000, Weight = 3, Build = "CupAssassin", Face = ">:)", Height = 3.0, Primary = {120, 80, 50}, Accent = {40, 40, 45}, Blurb = "A cappuccino cup with a katana and a black headband." },
	{ Name = "Tung Tung Tung Sahur", Rarity = "Legendary", Value = 20000, Weight = 2.5, Build = "TungTung", Face = "o_o", Height = 5.0, Primary = {150, 105, 60}, Accent = {240, 220, 180}, Blurb = "A giant wooden kentungan with a baseball bat. Tung tung tung sahur!" },
	-- Mythic (3) — $60,000 to $120,000.
	{ Name = "La Vaca Saturno Saturnita", Rarity = "Mythic", Value = 60000, Weight = 1.2, Build = "SaturnCow", Face = "o_o", Height = 3.2, Primary = {245, 245, 240}, Accent = {255, 200, 80}, Blurb = "A white cow ringed by Saturn. Moo, but cosmic." },
	{ Name = "Chef Crabracadabra", Rarity = "Mythic", Value = 90000, Weight = 1.2, Build = "ChefCrab", Face = ":-)", Height = 2.8, Primary = {230, 80, 60}, Accent = {255, 255, 255}, Blurb = "A red chef crab with a tall hat and a magic wand." },
	{ Name = "Tralalero Tralala", Rarity = "Mythic", Value = 120000, Weight = 0.8, Build = "TralalaShark", Face = ">:)", Height = 5.0, Primary = {70, 140, 255}, Accent = {245, 245, 245}, Blurb = "A giant blue shark in white sneakers. Tralalero tralala!" },
	-- Secret (3) — $300,000 to $500,000.
	{ Name = "Ballerina Cappuccina", Rarity = "Secret", Value = 300000, Weight = 0.35, Build = "BallerinaCup", Face = "^_^", Height = 5.0, Primary = {200, 160, 120}, Accent = {255, 255, 255}, Blurb = "A ballerina whose head is a cappuccino cup with foam. Pirouette!" },
	{ Name = "Cappuccino Ballerino", Rarity = "Secret", Value = 400000, Weight = 0.4, Build = "CupBallerino", Face = ":-)", Height = 3.2, Primary = {120, 80, 50}, Accent = {245, 245, 245}, Blurb = "A tuxedo cappuccino dancing ballet. Very fancy." },
	{ Name = "La Grande Combinazione", Rarity = "Secret", Value = 500000, Weight = 0.4, Build = "GoldSafe", Face = "o_o", Height = 2.6, Primary = {255, 210, 60}, Accent = {120, 90, 20}, Blurb = "A golden safe with three combination dials. The grand prize." },
	-- Godly (1) — $2,500,000.
	{ Name = "Bombardiro Crocodilo", Rarity = "Godly", Value = 2500000, Weight = 0.08, Build = "BomberCroc", Face = ">:)", Height = 3.4, Primary = {70, 90, 80}, Accent = {230, 200, 60}, Blurb = "A bomber plane with a crocodile head. The most iconic brainrot of all." },
}

BrainrotDatabase.CharacterCount = #BrainrotDatabase.Characters

-- Lookup by exact name.
function BrainrotDatabase.GetCharacter(name)
	for _, ch in ipairs(BrainrotDatabase.Characters) do
		if ch.Name == name then
			return ch
		end
	end
	return nil
end

-- Spawn weight for one character at a given Meteor Luck level. Epic and
-- above get +12% weight per luck level; Secret and Godly get another +15%.
local function weightOf(ch, luckLevel)
	local w = ch.Weight
	local rank = BrainrotDatabase.RarityRank[ch.Rarity]
	if rank >= 4 then
		w = w * (1 + 0.12 * luckLevel)
	end
	if rank >= 7 then
		w = w * (1 + 0.15 * luckLevel)
	end
	return w
end

-- Weighted random pick. rng is a Random instance; luckLevel is the server's
-- best Meteor Luck level (the highest among online players).
function BrainrotDatabase.RollCharacter(rng, luckLevel)
	luckLevel = luckLevel or 0
	local total = 0
	for _, ch in ipairs(BrainrotDatabase.Characters) do
		total = total + weightOf(ch, luckLevel)
	end
	local roll = rng:NextNumber() * total
	for _, ch in ipairs(BrainrotDatabase.Characters) do
		roll = roll - weightOf(ch, luckLevel)
		if roll <= 0 then
			return ch
		end
	end
	return BrainrotDatabase.Characters[1]
end

-- Dollar value of a character rescued during the given event.
function BrainrotDatabase.ValueOf(ch, eventKey)
	-- v7.1: defensive guard — a nil character (bad save / bad call) used
	-- to error here and kill the caller; it now just pays 0.
	if not ch then
		return 0
	end
	local event = BrainrotDatabase.Events[eventKey] or BrainrotDatabase.Events.Basic
	return math.floor(ch.Value * event.Mult + 0.5)
end

-- Passive Aura/s by rarity (same table as the server/client mirrors).
-- The world tag shows the BASE rarity rate — the exact rate the server
-- pays per second in the income tick. It does NOT multiply by the event
-- multiplier: a mutated brainrot's $Value is higher (ValueOf multiplies),
-- but its income rate is the same as a Basic one, so the tag never
-- promises Aura it does not pay.
BrainrotDatabase.AuraPerSecByRarity = {
	Common = 5, Uncommon = 20, Rare = 75, Epic = 250,
	Legendary = 1000, Mythic = 5000, Secret = 25000, Godly = 100000,
}

function BrainrotDatabase.AuraPerSec(ch, eventKey)
	if not ch then
		return 0
	end
	-- eventKey is accepted (callers pass it) but deliberately ignored:
	-- income is the base rarity rate, whatever the active mutation is.
	return BrainrotDatabase.AuraPerSecByRarity[ch.Rarity] or 5
end

-- ---------------------------------------------------------------------------
-- Procedural 3D builder. Every model is built with its origin at the ground
-- (y = 0 is the feet): the body's centre sits at bodyH/2, extras are placed
-- relative to the body, everything is welded to the body (the PrimaryPart),
-- and the name tag floats above the head. Standing height is never a fixed
-- constant — it is computed from each character's own Height, so no model
-- ever sinks into the floor (the bug that sank models in v1/v2).
-- ---------------------------------------------------------------------------

local function C(rgb)
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- One part, positioned in model space. Anchored is false (the server anchors
-- whole models when they stand in a meteor circle, and welds them to a
-- player's head while carried); CanCollide is false so carried stacks never
-- snag on doorways.
local function P(model, name, size, pos, color, shape, mat, trans)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(pos)
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Transparency = trans or 0
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function W(model, a, b)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = model
end

-- Optional SpecialMesh on a part (smooth sphere / wedge looks).
local function mesh(part, meshType, scale)
	local m = Instance.new("SpecialMesh")
	m.MeshType = meshType
	m.Scale = scale or Vector3.new(1, 1, 1)
	m.Parent = part
	return m
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

-- Name tag: name (rarity colour) + Dollar value and Aura/s. v7.6: the
-- face emoji is GONE (Yami: it read as gibberish) — the second line now
-- shows "$Value  •  +X Aura/s", where the Aura/s is the character's
-- rarity rate times the active event multiplier. Small on purpose
-- (200x46) so tags never pile up into a wall of text from spawn.
-- incomeMult (optional, default 1): the owner's income multiplier
-- (Rebirth/Index/Friends). The tag shows the rate this brainrot REALLY
-- pays per second — base rarity rate x the multiplier — so the floating
-- tag agrees with the pedestal label and the HUD total. (v7.6.6)
local function tag(model, body, ch, eventKey, incomeMult)
	incomeMult = incomeMult or 1
	local event = BrainrotDatabase.Events[eventKey] or BrainrotDatabase.Events.Basic
	local g = Instance.new("BillboardGui")
	g.Name = "Tag"
	g.Size = UDim2.fromOffset(200, 46)
	g.StudsOffsetWorldSpace = Vector3.new(0, ch.Height + 0.9, 0)
	g.AlwaysOnTop = false
	g.Adornee = body
	g.Parent = model
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 13
	nameLabel.TextColor3 = BrainrotDatabase.RarityColors[ch.Rarity]
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.Text = ch.Name
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	nameLabel.Parent = g
	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, 0, 0.45, 0)
	sub.Position = UDim2.new(0, 0, 0.55, 0)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 11
	sub.TextColor3 = Color3.fromRGB(255, 255, 255)
	sub.TextStrokeTransparency = 0.4
	sub.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	sub.Text = "$" .. formatMoney(BrainrotDatabase.ValueOf(ch, eventKey)) .. "  •  +" .. formatMoney(math.floor(BrainrotDatabase.AuraPerSec(ch, eventKey) * incomeMult + 0.5)) .. " Aura/s"
	sub.TextTruncate = Enum.TextTruncate.AtEnd
	sub.Parent = g
	return g
end

-- Mutation aura for non-Basic events: a coloured point light and drifting
-- particles in the event's colour.
local function aura(model, body, eventKey)
	if eventKey == "Basic" then
		return
	end
	local event = BrainrotDatabase.Events[eventKey]
	local light = Instance.new("PointLight")
	light.Color = event.ParticleColor
	light.Range = 9
	light.Brightness = 1.5
	light.Parent = body
	local emit = Instance.new("ParticleEmitter")
	emit.Color = ColorSequence.new(event.ParticleColor)
	emit.Rate = 12
	emit.Lifetime = NumberRange.new(0.8, 1.4)
	emit.Speed = NumberRange.new(1, 2.5)
	emit.Size = NumberSequence.new(0.4)
	emit.Transparency = NumberSequence.new(0.2, 0.9)
	emit.Parent = body
end

-- Finish a model: weld every part to the body, set the PrimaryPart, add the
-- tag and the mutation aura. Returns the model.
local function finish(model, body, ch, eventKey)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= body then
			W(model, body, d)
		end
	end
	model.PrimaryPart = body
	tag(model, body, ch, eventKey)
	aura(model, body, eventKey)
	return model
end

-- ---------------------------------------------------------------------------
-- Procedural 3D builders (v7.5: ported from the Brainrot37 package,
-- ~/workspace/makefun/roblox-brainrot-37-chars/src/shared/Brainrot37.luau).
-- Same Part + SpecialMesh + WeldConstraint pattern as before; each builder
-- finishes with finish(model, body, ch, "Basic") and BuildModel re-tags
-- with the real event. The package's Anchored=true is NOT ported: this
-- file's P() leaves parts unanchored (the server anchors base models and
-- welds carried ones).
-- ---------------------------------------------------------------------------

local Builders = {}

-- 1. Tralalero Tralala — hiu biru raksasa, 3 kaki, sneakers putih (v7.3).
Builders.TralalaShark = function(model, ch)
	local blue = C(ch.Primary)
	local darkBlue = Color3.fromRGB(40, 90, 200)
	local white = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(2.6, 2.4, 2.6), Vector3.new(0, 3.4, 0), blue, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(1, 0.95, 2.0))
	local tailFin = P(model, "TailFin", Vector3.new(0.3, 1.8, 1.2), Vector3.new(0, 3.8, -2.8), blue, Enum.PartType.Wedge)
	local tailFluke = P(model, "TailFluke", Vector3.new(2.0, 0.3, 1.0), Vector3.new(0, 3.4, -3.1), blue)
	local dorsal = P(model, "DorsalFin", Vector3.new(0.3, 1.6, 1.4), Vector3.new(0, 4.8, -0.3), blue, Enum.PartType.Wedge)
	local jaw = P(model, "Jaw", Vector3.new(1.6, 0.5, 1.2), Vector3.new(0, 2.4, 2.2), darkBlue)
	local toothL = P(model, "ToothL", Vector3.new(0.25, 0.4, 0.25), Vector3.new(-0.6, 2.6, 2.5), white)
	local toothR = P(model, "ToothR", Vector3.new(0.25, 0.4, 0.25), Vector3.new(0.6, 2.6, 2.5), white)
	local eyeL = P(model, "EyeL", Vector3.new(0.55, 0.55, 0.55), Vector3.new(-0.7, 4.2, 2.2), white, Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.55, 0.55, 0.55), Vector3.new(0.7, 4.2, 2.2), white, Enum.PartType.Ball)
	local pupilL = P(model, "PupilL", Vector3.new(0.28, 0.28, 0.28), Vector3.new(-0.7, 4.2, 2.45), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local pupilR = P(model, "PupilR", Vector3.new(0.28, 0.28, 0.28), Vector3.new(0.7, 4.2, 2.45), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	for i, legZ in ipairs({ 1.4, 0, -1.4 }) do
		local leg = P(model, "Leg" .. tostring(i), Vector3.new(0.5, 1.8, 0.5), Vector3.new(0, 1.4, legZ), darkBlue, Enum.PartType.Cylinder)
		leg.CFrame = CFrame.new(0, 1.4, legZ) * CFrame.Angles(0, 0, math.pi / 2)
		local shoe = P(model, "Shoe" .. tostring(i), Vector3.new(1.0, 0.5, 1.6), Vector3.new(0, 0.25, legZ), white)
	end
	return finish(model, body, ch, "Basic")
end

-- 2. Tung Tung Tung Sahur — kentungan kayu raksasa + tongkat baseball (v7.3).
Builders.TungTung = function(model, ch)
	local wood = C(ch.Primary)
	local darkWood = Color3.fromRGB(120, 85, 50)
	local body = P(model, "Body", Vector3.new(2.2, 4.6, 2.2), Vector3.new(0, 2.3, 0), wood, Enum.PartType.Cylinder)
	body.CFrame = CFrame.new(0, 2.3, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local cap = P(model, "Cap", Vector3.new(2.3, 0.3, 2.3), Vector3.new(0, 4.7, 0), darkWood, Enum.PartType.Cylinder)
	cap.CFrame = CFrame.new(0, 4.7, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local eyeL = P(model, "EyeL", Vector3.new(0.45, 0.45, 0.45), Vector3.new(-0.45, 3.5, 1.15), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.45, 0.45, 0.45), Vector3.new(0.45, 3.5, 1.15), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local pupilL = P(model, "PupilL", Vector3.new(0.22, 0.22, 0.22), Vector3.new(-0.45, 3.5, 1.32), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local pupilR = P(model, "PupilR", Vector3.new(0.22, 0.22, 0.22), Vector3.new(0.45, 3.5, 1.32), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local mouth = P(model, "Mouth", Vector3.new(0.9, 0.25, 0.15), Vector3.new(0, 2.9, 1.12), Color3.fromRGB(60, 35, 20))
	local moustache = P(model, "Moustache", Vector3.new(0.9, 0.2, 0.15), Vector3.new(0, 3.15, 1.12), Color3.fromRGB(40, 25, 15))
	local armL = P(model, "ArmL", Vector3.new(0.45, 1.6, 0.45), Vector3.new(-1.25, 2.4, 0.3), darkWood, Enum.PartType.Cylinder)
	armL.CFrame = CFrame.new(-1.25, 2.4, 0.3) * CFrame.Angles(0, 0, math.pi / 2 + 0.6)
	local armR = P(model, "ArmR", Vector3.new(0.45, 1.6, 0.45), Vector3.new(1.25, 2.9, 0.3), darkWood, Enum.PartType.Cylinder)
	armR.CFrame = CFrame.new(1.25, 2.9, 0.3) * CFrame.Angles(0, 0, math.pi / 2 - 0.6)
	local legL = P(model, "LegL", Vector3.new(0.5, 1.0, 0.5), Vector3.new(-0.5, 0.5, 0), darkWood, Enum.PartType.Cylinder)
	legL.CFrame = CFrame.new(-0.5, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local legR = P(model, "LegR", Vector3.new(0.5, 1.0, 0.5), Vector3.new(0.5, 0.5, 0), darkWood, Enum.PartType.Cylinder)
	legR.CFrame = CFrame.new(0.5, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local footL = P(model, "FootL", Vector3.new(0.7, 0.3, 1.0), Vector3.new(-0.5, 0.15, 0.2), darkWood)
	local footR = P(model, "FootR", Vector3.new(0.7, 0.3, 1.0), Vector3.new(0.5, 0.15, 0.2), darkWood)
	local batWood = Color3.fromRGB(220, 180, 130)
	local bat = P(model, "Bat", Vector3.new(0.55, 2.4, 0.55), Vector3.new(2.2, 4.4, 0.3), batWood, Enum.PartType.Cylinder)
	bat.CFrame = CFrame.new(2.2, 4.4, 0.3) * CFrame.Angles(0, 0, math.pi / 2 - 0.6)
	local knob = P(model, "BatKnob", Vector3.new(0.4, 0.4, 0.4), Vector3.new(1.53, 3.4, 0.3), darkWood, Enum.PartType.Ball)
	return finish(model, body, ch, "Basic")
end

-- 3. Ballerina Cappuccina — kepala cangkir cappuccino, tutu putih (v7.3).
Builders.BallerinaCup = function(model, ch)
	local cupBrown = C(ch.Primary)
	local white = C(ch.Accent)
	local pink = Color3.fromRGB(255, 180, 200)
	local skin = Color3.fromRGB(240, 210, 180)
	local legL = P(model, "LegL", Vector3.new(0.35, 2.2, 0.35), Vector3.new(-0.35, 1.1, 0), skin, Enum.PartType.Cylinder)
	legL.CFrame = CFrame.new(-0.35, 1.1, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local legR = P(model, "LegR", Vector3.new(0.35, 2.2, 0.35), Vector3.new(0.35, 1.1, 0), skin, Enum.PartType.Cylinder)
	legR.CFrame = CFrame.new(0.35, 1.1, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local shoeL = P(model, "ShoeL", Vector3.new(0.5, 0.3, 0.9), Vector3.new(-0.35, 0.15, 0.15), pink)
	local shoeR = P(model, "ShoeR", Vector3.new(0.5, 0.3, 0.9), Vector3.new(0.35, 0.15, 0.15), pink)
	local tutu1 = P(model, "Tutu1", Vector3.new(3.6, 0.25, 3.6), Vector3.new(0, 2.55, 0), white, Enum.PartType.Cylinder)
	tutu1.CFrame = CFrame.new(0, 2.55, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local tutu2 = P(model, "Tutu2", Vector3.new(3.0, 0.25, 3.0), Vector3.new(0, 2.35, 0), white, Enum.PartType.Cylinder)
	tutu2.CFrame = CFrame.new(0, 2.35, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local body = P(model, "Body", Vector3.new(1.1, 1.2, 1.1), Vector3.new(0, 3.1, 0), pink, Enum.PartType.Cylinder)
	body.CFrame = CFrame.new(0, 3.1, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local armL = P(model, "ArmL", Vector3.new(0.3, 1.4, 0.3), Vector3.new(-0.75, 3.9, 0), skin, Enum.PartType.Cylinder)
	armL.CFrame = CFrame.new(-0.75, 3.9, 0) * CFrame.Angles(0, 0, math.pi / 2 + 0.8)
	local armR = P(model, "ArmR", Vector3.new(0.3, 1.4, 0.3), Vector3.new(0.75, 4.1, 0), skin, Enum.PartType.Cylinder)
	armR.CFrame = CFrame.new(0.75, 4.1, 0) * CFrame.Angles(0, 0, math.pi / 2 - 0.8)
	local cup = P(model, "Cup", Vector3.new(1.7, 1.3, 1.7), Vector3.new(0, 4.4, 0), cupBrown, Enum.PartType.Cylinder)
	cup.CFrame = CFrame.new(0, 4.4, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local foam = P(model, "Foam", Vector3.new(1.5, 1.5, 1.5), Vector3.new(0, 5.15, 0), Color3.fromRGB(250, 240, 220), Enum.PartType.Ball)
	mesh(foam, Enum.MeshType.Sphere, Vector3.new(1, 0.6, 1))
	local foamDot = P(model, "FoamDot", Vector3.new(0.7, 0.7, 0.7), Vector3.new(0.5, 5.45, 0.3), Color3.fromRGB(250, 240, 220), Enum.PartType.Ball)
	local handle = P(model, "Handle", Vector3.new(0.3, 0.8, 0.3), Vector3.new(0.95, 4.4, 0), white)
	local eyeL = P(model, "EyeL", Vector3.new(0.2, 0.2, 0.2), Vector3.new(-0.35, 4.5, 0.85), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0.35, 4.5, 0.85), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local smile = P(model, "Smile", Vector3.new(0.5, 0.15, 0.15), Vector3.new(0, 4.2, 0.85), Color3.fromRGB(60, 30, 20))
	return finish(model, body, ch, "Basic")
end

-- 4. Bombardiro Crocodilo — kepala buaya di badan pesawat bomber.
Builders.BomberCroc = function(model, ch)
	local green = Color3.fromRGB(60, 230, 90)
	local dark = C(ch.Primary)
	local gold = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.2, 1.0, 2.6), Vector3.new(0, 1.4, 0), dark, Enum.PartType.Cylinder)
	body.CFrame = CFrame.new(0, 1.4, 0) * CFrame.Angles(math.pi / 2, 0, 0)
	local head = P(model, "Head", Vector3.new(1.1, 0.8, 1.1), Vector3.new(0, 1.5, 1.5), green, Enum.PartType.Ball)
	mesh(head, Enum.MeshType.Sphere)
	local snout = P(model, "Snout", Vector3.new(0.9, 0.45, 0.9), Vector3.new(0, 1.35, 2.2), green)
	local tooth1 = P(model, "Tooth1", Vector3.new(0.15, 0.25, 0.15), Vector3.new(-0.3, 1.55, 2.5), Color3.fromRGB(255, 255, 255))
	local tooth2 = P(model, "Tooth2", Vector3.new(0.15, 0.25, 0.15), Vector3.new(0.3, 1.55, 2.5), Color3.fromRGB(255, 255, 255))
	local eyeL = P(model, "EyeL", Vector3.new(0.3, 0.3, 0.3), Vector3.new(-0.35, 1.95, 1.9), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.3, 0.3, 0.3), Vector3.new(0.35, 1.95, 1.9), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local wingL = P(model, "WingL", Vector3.new(2.2, 0.15, 1.0), Vector3.new(-1.6, 1.5, 0), gold)
	local wingR = P(model, "WingR", Vector3.new(2.2, 0.15, 1.0), Vector3.new(1.6, 1.5, 0), gold)
	local tailFin = P(model, "TailFin", Vector3.new(0.2, 0.9, 0.8), Vector3.new(0, 2.0, -1.3), dark, Enum.PartType.Wedge)
	local bombL = P(model, "BombL", Vector3.new(0.6, 0.6, 0.9), Vector3.new(-1.4, 0.8, 0.2), Color3.fromRGB(40, 40, 45), Enum.PartType.Ball)
	local bombR = P(model, "BombR", Vector3.new(0.6, 0.6, 0.9), Vector3.new(1.4, 0.8, 0.2), Color3.fromRGB(40, 40, 45), Enum.PartType.Ball)
	local bombTipL = P(model, "BombTipL", Vector3.new(0.3, 0.3, 0.3), Vector3.new(-1.4, 0.8, 0.75), gold, Enum.PartType.Ball)
	local bombTipR = P(model, "BombTipR", Vector3.new(0.3, 0.3, 0.3), Vector3.new(1.4, 0.8, 0.75), gold, Enum.PartType.Ball)
	return finish(model, body, ch, "Basic")
end

-- 5. Lirili Larila — kaktus hijau + kepala/belalai gajah, sandal jepit.
Builders.CactusElephant = function(model, ch)
	local green = C(ch.Primary)
	local sand = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.1, 2.0, 1.1), Vector3.new(0, 1.0, 0), green, Enum.PartType.Cylinder)
	body.CFrame = CFrame.new(0, 1.0, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local armL = P(model, "ArmL", Vector3.new(0.35, 0.8, 0.35), Vector3.new(-0.7, 1.2, 0), green)
	local armR = P(model, "ArmR", Vector3.new(0.35, 0.8, 0.35), Vector3.new(0.7, 1.2, 0), green)
	local earL = P(model, "EarL", Vector3.new(0.7, 0.9, 0.2), Vector3.new(-0.65, 1.9, 0), Color3.fromRGB(60, 180, 80), Enum.PartType.Ball)
	local earR = P(model, "EarR", Vector3.new(0.7, 0.9, 0.2), Vector3.new(0.65, 1.9, 0), Color3.fromRGB(60, 180, 80), Enum.PartType.Ball)
	local trunk1 = P(model, "Trunk1", Vector3.new(0.35, 0.9, 0.35), Vector3.new(0, 1.7, 0.65), green, Enum.PartType.Cylinder)
	trunk1.CFrame = CFrame.new(0, 1.7, 0.65) * CFrame.Angles(0.5, 0, 0)
	local trunk2 = P(model, "Trunk2", Vector3.new(0.3, 0.8, 0.3), Vector3.new(0, 1.15, 0.85), green, Enum.PartType.Cylinder)
	trunk2.CFrame = CFrame.new(0, 1.15, 0.85) * CFrame.Angles(0.2, 0, 0)
	local eyeL = P(model, "EyeL", Vector3.new(0.22, 0.22, 0.22), Vector3.new(-0.3, 2.0, 0.55), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.22, 0.22, 0.22), Vector3.new(0.3, 2.0, 0.55), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local spike1 = P(model, "Spike1", Vector3.new(0.15, 0.3, 0.15), Vector3.new(-0.5, 1.4, 0.45), Color3.fromRGB(220, 255, 200))
	local spike2 = P(model, "Spike2", Vector3.new(0.15, 0.3, 0.15), Vector3.new(0.5, 0.9, -0.45), Color3.fromRGB(220, 255, 200))
	local spike3 = P(model, "Spike3", Vector3.new(0.15, 0.3, 0.15), Vector3.new(0, 1.6, -0.55), Color3.fromRGB(220, 255, 200))
	local sandalL = P(model, "SandalL", Vector3.new(0.5, 0.15, 0.9), Vector3.new(-0.3, 0.08, 0.1), sand)
	local sandalR = P(model, "SandalR", Vector3.new(0.5, 0.15, 0.9), Vector3.new(0.3, 0.08, 0.1), sand)
	return finish(model, body, ch, "Basic")
end

-- 6. Brr Brr Patapim — monyet proboscis coklat, hidung besar, kaki besar.
Builders.ProboscisMonkey = function(model, ch)
	local brown = C(ch.Primary)
	local tan = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.8, 2.2, 1.4), Vector3.new(0, 1.1, 0), brown, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(1.1, 1.3, 0.85))
	local nose = P(model, "Nose", Vector3.new(0.7, 0.9, 0.6), Vector3.new(0, 1.4, 0.85), tan, Enum.PartType.Ball)
	mesh(nose, Enum.MeshType.Sphere)
	local eyeL = P(model, "EyeL", Vector3.new(0.25, 0.25, 0.25), Vector3.new(-0.35, 1.75, 0.65), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.25, 0.25, 0.25), Vector3.new(0.35, 1.75, 0.65), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local pupilL = P(model, "PupilL", Vector3.new(0.12, 0.12, 0.12), Vector3.new(-0.35, 1.75, 0.85), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local pupilR = P(model, "PupilR", Vector3.new(0.12, 0.12, 0.12), Vector3.new(0.35, 1.75, 0.85), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local armL = P(model, "ArmL", Vector3.new(0.35, 1.5, 0.35), Vector3.new(-1.0, 1.0, 0), brown, Enum.PartType.Cylinder)
	armL.CFrame = CFrame.new(-1.0, 1.0, 0) * CFrame.Angles(0, 0, 0.3)
	local armR = P(model, "ArmR", Vector3.new(0.35, 1.5, 0.35), Vector3.new(1.0, 1.0, 0), brown, Enum.PartType.Cylinder)
	armR.CFrame = CFrame.new(1.0, 1.0, 0) * CFrame.Angles(0, 0, -0.3)
	local footL = P(model, "FootL", Vector3.new(0.8, 0.4, 1.2), Vector3.new(-0.5, 0.2, 0.2), tan)
	local footR = P(model, "FootR", Vector3.new(0.8, 0.4, 1.2), Vector3.new(0.5, 0.2, 0.2), tan)
	local tail = P(model, "Tail", Vector3.new(0.2, 0.2, 1.0), Vector3.new(0, 1.2, -0.95), brown)
	tail.CFrame = CFrame.new(0, 1.4, -0.95) * CFrame.Angles(0.8, 0, 0)
	return finish(model, body, ch, "Basic")
end

-- 7. Chimpanzini Bananini — simpanse di dalam kulit pisang raksasa.
Builders.ChimpBanana = function(model, ch)
	local fur = Color3.fromRGB(150, 110, 70)
	local yellow = C(ch.Primary)
	local body = P(model, "Body", Vector3.new(1.3, 1.3, 1.3), Vector3.new(0, 1.1, 0), fur, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere)
	local face = P(model, "Face", Vector3.new(0.9, 0.8, 0.3), Vector3.new(0, 1.15, 0.6), C(ch.Accent), Enum.PartType.Ball)
	local eyeL = P(model, "EyeL", Vector3.new(0.2, 0.2, 0.2), Vector3.new(-0.25, 1.35, 0.7), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0.25, 1.35, 0.7), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local peelL = P(model, "PeelL", Vector3.new(0.4, 1.6, 0.4), Vector3.new(-0.7, 0.8, 0), yellow)
	peelL.CFrame = CFrame.new(-0.7, 0.8, 0) * CFrame.Angles(0, 0, 0.5)
	local peelR = P(model, "PeelR", Vector3.new(0.4, 1.6, 0.4), Vector3.new(0.7, 0.8, 0), yellow)
	peelR.CFrame = CFrame.new(0.7, 0.8, 0) * CFrame.Angles(0, 0, -0.5)
	local peelB = P(model, "PeelB", Vector3.new(0.4, 1.6, 0.4), Vector3.new(0, 0.8, -0.7), yellow)
	peelB.CFrame = CFrame.new(0, 0.8, -0.7) * CFrame.Angles(0.5, 0, 0)
	local peelBase = P(model, "PeelBase", Vector3.new(1.6, 0.35, 1.6), Vector3.new(0, 0.18, 0), yellow, Enum.PartType.Cylinder)
	peelBase.CFrame = CFrame.new(0, 0.18, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local ring = P(model, "Ring", Vector3.new(2.2, 0.15, 2.2), Vector3.new(0, 1.6, 0), C(ch.Accent), Enum.PartType.Cylinder, Enum.Material.Neon, 0.2)
	ring.CFrame = CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2)
	return finish(model, body, ch, "Basic")
end

-- 8. Cappuccino Assassino — cangkir cappuccino bawa katana, mata marah.
Builders.CupAssassin = function(model, ch)
	local brown = C(ch.Primary)
	local black = C(ch.Accent)
	local silver = Color3.fromRGB(200, 200, 210)
	local body = P(model, "Body", Vector3.new(1.2, 1.5, 1.2), Vector3.new(0, 1.15, 0), brown, Enum.PartType.Cylinder)
	body.CFrame = CFrame.new(0, 1.15, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local foam = P(model, "Foam", Vector3.new(1.1, 0.4, 1.1), Vector3.new(0, 1.95, 0), Color3.fromRGB(250, 240, 220), Enum.PartType.Cylinder)
	foam.CFrame = CFrame.new(0, 1.95, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local band = P(model, "Headband", Vector3.new(1.3, 0.25, 1.3), Vector3.new(0, 1.75, 0), black, Enum.PartType.Cylinder)
	band.CFrame = CFrame.new(0, 1.75, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local knot = P(model, "Knot", Vector3.new(0.4, 0.3, 0.3), Vector3.new(-0.7, 1.75, 0), black)
	local browL = P(model, "BrowL", Vector3.new(0.45, 0.12, 0.12), Vector3.new(-0.3, 1.35, 0.62), black)
	browL.CFrame = CFrame.new(-0.3, 1.35, 0.62) * CFrame.Angles(0, 0, -0.5)
	local browR = P(model, "BrowR", Vector3.new(0.45, 0.12, 0.12), Vector3.new(0.3, 1.35, 0.62), black)
	browR.CFrame = CFrame.new(0.3, 1.35, 0.62) * CFrame.Angles(0, 0, 0.5)
	local eyeL = P(model, "EyeL", Vector3.new(0.18, 0.18, 0.18), Vector3.new(-0.3, 1.15, 0.62), Color3.fromRGB(255, 60, 60), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.18, 0.18, 0.18), Vector3.new(0.3, 1.15, 0.62), Color3.fromRGB(255, 60, 60), Enum.PartType.Ball)
	local armL = P(model, "ArmL", Vector3.new(0.3, 0.9, 0.3), Vector3.new(-0.7, 1.1, 0.3), brown, Enum.PartType.Cylinder)
	armL.CFrame = CFrame.new(-0.7, 1.1, 0.3) * CFrame.Angles(0, 0, 0.5)
	local armR = P(model, "ArmR", Vector3.new(0.3, 0.9, 0.3), Vector3.new(0.7, 1.1, 0.3), brown, Enum.PartType.Cylinder)
	armR.CFrame = CFrame.new(0.7, 1.1, 0.3) * CFrame.Angles(0, 0, -0.5)
	local legL = P(model, "LegL", Vector3.new(0.3, 0.4, 0.3), Vector3.new(-0.3, 0.2, 0), black)
	local legR = P(model, "LegR", Vector3.new(0.3, 0.4, 0.3), Vector3.new(0.3, 0.2, 0), black)
	local blade = P(model, "Katana", Vector3.new(0.12, 2.4, 0.35), Vector3.new(1.35, 1.9, 0.5), silver)
	blade.CFrame = CFrame.new(1.35, 1.9, 0.5) * CFrame.Angles(0.4, 0, 0.5)
	local grip = P(model, "KatanaGrip", Vector3.new(0.18, 0.5, 0.18), Vector3.new(0.95, 0.95, 0.35), black)
	grip.CFrame = CFrame.new(0.95, 0.95, 0.35) * CFrame.Angles(0.4, 0, 0.5)
	return finish(model, body, ch, "Basic")
end

-- 9. Trippi Troppi — ikan trout + beruang (badan ikan, kepala/telinga beruang).
Builders.FishBear = function(model, ch)
	local salmon = C(ch.Primary)
	local bearBrown = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.2, 1.0, 2.2), Vector3.new(0, 1.0, 0), salmon, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(0.9, 0.75, 1.6))
	local head = P(model, "Head", Vector3.new(1.0, 0.9, 1.0), Vector3.new(0, 1.5, 1.1), bearBrown, Enum.PartType.Ball)
	mesh(head, Enum.MeshType.Sphere)
	local earL = P(model, "EarL", Vector3.new(0.35, 0.35, 0.35), Vector3.new(-0.4, 2.0, 1.1), bearBrown, Enum.PartType.Ball)
	local earR = P(model, "EarR", Vector3.new(0.35, 0.35, 0.35), Vector3.new(0.4, 2.0, 1.1), bearBrown, Enum.PartType.Ball)
	local muzzle = P(model, "Muzzle", Vector3.new(0.6, 0.4, 0.3), Vector3.new(0, 1.35, 1.6), Color3.fromRGB(230, 200, 160), Enum.PartType.Ball)
	local tail = P(model, "TailFin", Vector3.new(0.25, 1.0, 0.8), Vector3.new(0, 1.1, -1.5), salmon, Enum.PartType.Wedge)
	local finL = P(model, "FinL", Vector3.new(0.15, 0.5, 0.7), Vector3.new(-0.65, 0.9, 0.2), salmon)
	local finR = P(model, "FinR", Vector3.new(0.15, 0.5, 0.7), Vector3.new(0.65, 0.9, 0.2), salmon)
	local dorsal = P(model, "Dorsal", Vector3.new(0.2, 0.6, 1.0), Vector3.new(0, 1.6, -0.3), salmon, Enum.PartType.Wedge)
	local spot1 = P(model, "Spot1", Vector3.new(0.25, 0.15, 0.25), Vector3.new(-0.3, 1.45, 0.3), Color3.fromRGB(180, 60, 60), Enum.PartType.Ball)
	local spot2 = P(model, "Spot2", Vector3.new(0.25, 0.15, 0.25), Vector3.new(0.35, 1.3, -0.4), Color3.fromRGB(180, 60, 60), Enum.PartType.Ball)
	return finish(model, body, ch, "Basic")
end

-- 10. Boneca Ambalabu — katak hijau duduk di atas ban hitam.
Builders.FrogTire = function(model, ch)
	local green = C(ch.Primary)
	local black = C(ch.Accent)
	local tire = P(model, "Body", Vector3.new(2.4, 0.7, 2.4), Vector3.new(0, 0.35, 0), black, Enum.PartType.Cylinder)
	tire.CFrame = CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local hub = P(model, "Hub", Vector3.new(1.2, 0.75, 1.2), Vector3.new(0, 0.35, 0), Color3.fromRGB(90, 90, 95), Enum.PartType.Cylinder)
	hub.CFrame = CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local frogBody = P(model, "FrogBody", Vector3.new(1.3, 0.9, 1.2), Vector3.new(0, 1.15, 0), green, Enum.PartType.Ball)
	mesh(frogBody, Enum.MeshType.Sphere)
	local head = P(model, "Head", Vector3.new(1.0, 0.7, 0.9), Vector3.new(0, 1.65, 0.2), green, Enum.PartType.Ball)
	mesh(head, Enum.MeshType.Sphere)
	local eyeL = P(model, "EyeL", Vector3.new(0.35, 0.35, 0.35), Vector3.new(-0.35, 2.05, 0.35), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.35, 0.35, 0.35), Vector3.new(0.35, 2.05, 0.35), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local pupilL = P(model, "PupilL", Vector3.new(0.18, 0.18, 0.18), Vector3.new(-0.35, 2.05, 0.55), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local pupilR = P(model, "PupilR", Vector3.new(0.18, 0.18, 0.18), Vector3.new(0.35, 2.05, 0.55), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local legL = P(model, "LegL", Vector3.new(0.4, 0.3, 0.8), Vector3.new(-0.7, 0.85, 0.3), green)
	local legR = P(model, "LegR", Vector3.new(0.4, 0.3, 0.8), Vector3.new(0.7, 0.85, 0.3), green)
	local belly = P(model, "Belly", Vector3.new(0.8, 0.6, 0.3), Vector3.new(0, 1.05, 0.55), Color3.fromRGB(220, 255, 200), Enum.PartType.Ball)
	return finish(model, tire, ch, "Basic")
end

-- 11. Frigo Camelo — unta dengan kulkas di punggung.
Builders.FridgeCamel = function(model, ch)
	local tan = C(ch.Primary)
	local cyan = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.3, 1.2, 2.2), Vector3.new(0, 1.3, 0), tan, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(0.85, 0.8, 1.45))
	local neck = P(model, "Neck", Vector3.new(0.5, 1.2, 0.5), Vector3.new(0, 2.2, 0.9), tan, Enum.PartType.Cylinder)
	neck.CFrame = CFrame.new(0, 2.2, 0.9) * CFrame.Angles(0.3, 0, 0)
	local head = P(model, "Head", Vector3.new(0.6, 0.5, 0.9), Vector3.new(0, 2.8, 1.2), tan, Enum.PartType.Ball)
	local muzzle = P(model, "Muzzle", Vector3.new(0.5, 0.35, 0.4), Vector3.new(0, 2.7, 1.65), Color3.fromRGB(220, 190, 150), Enum.PartType.Ball)
	local hump = P(model, "Hump", Vector3.new(0.9, 0.6, 0.9), Vector3.new(0, 1.95, -0.2), tan, Enum.PartType.Ball)
	local fridge = P(model, "Fridge", Vector3.new(1.1, 1.3, 1.0), Vector3.new(0, 2.5, -0.5), cyan, Enum.PartType.Block, Enum.Material.Neon, 0.15)
	local fridgeDoor = P(model, "FridgeDoor", Vector3.new(0.9, 0.5, 0.1), Vector3.new(0, 2.7, 0.05), Color3.fromRGB(220, 255, 250))
	local fridgeHandle = P(model, "FridgeHandle", Vector3.new(0.12, 0.5, 0.12), Vector3.new(0.4, 2.7, 0.12), Color3.fromRGB(60, 60, 70))
	local legL = P(model, "LegL", Vector3.new(0.3, 1.0, 0.3), Vector3.new(-0.45, 0.5, 0.7), tan)
	local legR = P(model, "LegR", Vector3.new(0.3, 1.0, 0.3), Vector3.new(0.45, 0.5, 0.7), tan)
	local legBL = P(model, "LegBL", Vector3.new(0.3, 1.0, 0.3), Vector3.new(-0.45, 0.5, -0.7), tan)
	local legBR = P(model, "LegBR", Vector3.new(0.3, 1.0, 0.3), Vector3.new(0.45, 0.5, -0.7), tan)
	local tail = P(model, "Tail", Vector3.new(0.2, 0.8, 0.2), Vector3.new(0, 1.4, -1.25), tan)
	return finish(model, body, ch, "Basic")
end

-- 12. La Vaca Saturno Saturnita — sapi putih + cincin planet Saturnus.
Builders.SaturnCow = function(model, ch)
	local white = C(ch.Primary)
	local gold = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.5, 1.3, 2.0), Vector3.new(0, 0.65, 0), white, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(1.05, 0.9, 1.4))
	local spot = P(model, "Spot", Vector3.new(0.7, 0.5, 0.5), Vector3.new(-0.4, 0.9, 0.6), Color3.fromRGB(30, 30, 35), Enum.PartType.Ball)
	local spot2 = P(model, "Spot2", Vector3.new(0.5, 0.4, 0.4), Vector3.new(0.5, 0.7, -0.7), Color3.fromRGB(30, 30, 35), Enum.PartType.Ball)
	local ring = P(model, "Ring", Vector3.new(3.6, 0.18, 3.6), Vector3.new(0, 0.9, 0), gold, Enum.PartType.Cylinder, Enum.Material.Neon, 0.1)
	ring.CFrame = CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(0.35, 0, 0)
	local ring2 = P(model, "Ring2", Vector3.new(3.0, 0.12, 3.0), Vector3.new(0, 0.9, 0), Color3.fromRGB(255, 230, 150), Enum.PartType.Cylinder, Enum.Material.Neon, 0.1)
	ring2.CFrame = CFrame.new(0, 0.9, 0) * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(0.35, 0, 0)
	local head = P(model, "Head", Vector3.new(1.0, 0.9, 1.0), Vector3.new(0, 1.0, 1.2), white, Enum.PartType.Ball)
	local muzzle = P(model, "Muzzle", Vector3.new(0.8, 0.5, 0.4), Vector3.new(0, 0.8, 1.7), Color3.fromRGB(255, 200, 200), Enum.PartType.Ball)
	local hornL = P(model, "HornL", Vector3.new(0.2, 0.6, 0.2), Vector3.new(-0.6, 1.6, 1.1), Color3.fromRGB(240, 220, 180))
	hornL.CFrame = CFrame.new(-0.6, 1.6, 1.1) * CFrame.Angles(0, 0, 0.5)
	local hornR = P(model, "HornR", Vector3.new(0.2, 0.6, 0.2), Vector3.new(0.6, 1.6, 1.1), Color3.fromRGB(240, 220, 180))
	hornR.CFrame = CFrame.new(0.6, 1.6, 1.1) * CFrame.Angles(0, 0, -0.5)
	local legL = P(model, "LegL", Vector3.new(0.3, 0.6, 0.3), Vector3.new(-0.5, 0.3, 0.7), white)
	local legR = P(model, "LegR", Vector3.new(0.3, 0.6, 0.3), Vector3.new(0.5, 0.3, 0.7), white)
	local star = P(model, "Star", Vector3.new(0.3, 0.3, 0.3), Vector3.new(1.5, 1.6, 0.8), gold, Enum.PartType.Ball, Enum.Material.Neon)
	return finish(model, body, ch, "Basic")
end

-- 13. Giraffa Celeste — jerapah tinggi bermotif langit/bintang, leher panjang.
Builders.SkyGiraffe = function(model, ch)
	local sky = C(ch.Primary)
	local star = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.2, 1.4, 2.0), Vector3.new(0, 0.9, 0), sky, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(0.85, 1.0, 1.4))
	local neck = P(model, "Neck", Vector3.new(0.45, 2.0, 0.45), Vector3.new(0, 2.2, 0.8), sky, Enum.PartType.Cylinder)
	neck.CFrame = CFrame.new(0, 2.2, 0.8) * CFrame.Angles(0.25, 0, 0)
	local head = P(model, "Head", Vector3.new(0.6, 0.5, 0.9), Vector3.new(0, 3.25, 1.05), sky, Enum.PartType.Ball)
	local ossL = P(model, "OssL", Vector3.new(0.15, 0.4, 0.15), Vector3.new(-0.2, 3.6, 1.0), star)
	local ossR = P(model, "OssR", Vector3.new(0.15, 0.4, 0.15), Vector3.new(0.2, 3.6, 1.0), star)
	local knobL = P(model, "KnobL", Vector3.new(0.25, 0.25, 0.25), Vector3.new(-0.2, 3.85, 1.0), star, Enum.PartType.Ball)
	local knobR = P(model, "KnobR", Vector3.new(0.25, 0.25, 0.25), Vector3.new(0.2, 3.85, 1.0), star, Enum.PartType.Ball)
	local muzzle = P(model, "Muzzle", Vector3.new(0.5, 0.35, 0.35), Vector3.new(0, 3.15, 1.5), Color3.fromRGB(220, 230, 255), Enum.PartType.Ball)
	local mane = P(model, "Mane", Vector3.new(0.25, 1.8, 0.3), Vector3.new(0, 2.3, 0.45), Color3.fromRGB(40, 60, 120))
	mane.CFrame = CFrame.new(0, 2.3, 0.45) * CFrame.Angles(0.25, 0, 0)
	local spot1 = P(model, "Spot1", Vector3.new(0.35, 0.2, 0.35), Vector3.new(-0.4, 1.4, 0.5), star, Enum.PartType.Ball, Enum.Material.Neon, 0.2)
	local spot2 = P(model, "Spot2", Vector3.new(0.3, 0.2, 0.3), Vector3.new(0.35, 1.1, -0.5), star, Enum.PartType.Ball, Enum.Material.Neon, 0.2)
	local spot3 = P(model, "Spot3", Vector3.new(0.25, 0.2, 0.25), Vector3.new(0, 1.5, -0.8), star, Enum.PartType.Ball, Enum.Material.Neon, 0.2)
	local legL = P(model, "LegL", Vector3.new(0.3, 0.9, 0.3), Vector3.new(-0.4, 0.45, 0.7), sky)
	local legR = P(model, "LegR", Vector3.new(0.3, 0.9, 0.3), Vector3.new(0.4, 0.45, 0.7), sky)
	local legBL = P(model, "LegBL", Vector3.new(0.3, 0.9, 0.3), Vector3.new(-0.4, 0.45, -0.7), sky)
	local legBR = P(model, "LegBR", Vector3.new(0.3, 0.9, 0.3), Vector3.new(0.4, 0.45, -0.7), sky)
	local tail = P(model, "Tail", Vector3.new(0.15, 1.0, 0.15), Vector3.new(0, 1.2, -1.15), sky)
	local tuft = P(model, "Tuft", Vector3.new(0.3, 0.4, 0.3), Vector3.new(0, 0.65, -1.2), Color3.fromRGB(40, 60, 120), Enum.PartType.Ball)
	return finish(model, body, ch, "Basic")
end

-- 14. Bombombini Gusini — angsa putih bersayap pesawat bomber, kacamata pilot.
Builders.GooseBomber = function(model, ch)
	local white = C(ch.Primary)
	local orange = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.1, 1.0, 1.8), Vector3.new(0, 1.0, 0), white, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(0.85, 0.75, 1.35))
	local neck = P(model, "Neck", Vector3.new(0.35, 1.2, 0.35), Vector3.new(0, 1.9, 0.8), white, Enum.PartType.Cylinder)
	neck.CFrame = CFrame.new(0, 1.9, 0.8) * CFrame.Angles(0.3, 0, 0)
	local head = P(model, "Head", Vector3.new(0.55, 0.5, 0.7), Vector3.new(0, 2.55, 1.05), white, Enum.PartType.Ball)
	local beak = P(model, "Beak", Vector3.new(0.4, 0.2, 0.6), Vector3.new(0, 2.5, 1.5), orange, Enum.PartType.Wedge)
	local goggleL = P(model, "GoggleL", Vector3.new(0.3, 0.3, 0.15), Vector3.new(-0.18, 2.65, 1.25), Color3.fromRGB(40, 60, 90), Enum.PartType.Cylinder)
	goggleL.CFrame = CFrame.new(-0.18, 2.65, 1.25) * CFrame.Angles(math.pi / 2, 0, 0)
	local goggleR = P(model, "GoggleR", Vector3.new(0.3, 0.3, 0.15), Vector3.new(0.18, 2.65, 1.25), Color3.fromRGB(40, 60, 90), Enum.PartType.Cylinder)
	goggleR.CFrame = CFrame.new(0.18, 2.65, 1.25) * CFrame.Angles(math.pi / 2, 0, 0)
	local strap = P(model, "Strap", Vector3.new(0.6, 0.15, 0.15), Vector3.new(0, 2.65, 0.95), Color3.fromRGB(120, 80, 40))
	local wingL = P(model, "WingL", Vector3.new(1.8, 0.15, 0.9), Vector3.new(-1.4, 1.2, 0), Color3.fromRGB(220, 220, 225))
	local wingR = P(model, "WingR", Vector3.new(1.8, 0.15, 0.9), Vector3.new(1.4, 1.2, 0), Color3.fromRGB(220, 220, 225))
	local tail = P(model, "Tail", Vector3.new(0.7, 0.15, 0.8), Vector3.new(0, 1.15, -1.1), white)
	local footL = P(model, "FootL", Vector3.new(0.4, 0.15, 0.7), Vector3.new(-0.3, 0.08, 0.2), orange)
	local footR = P(model, "FootR", Vector3.new(0.4, 0.15, 0.7), Vector3.new(0.3, 0.08, 0.2), orange)
	return finish(model, body, ch, "Basic")
end

-- Helper lokal: satu hiu bayi (dipakai Los Tralaleritos & Las Tralaleritas).
local function babyShark(model, prefix, x, bodyColor, shoeColor, bowColor)
	local body = P(model, prefix .. "Body", Vector3.new(0.9, 0.8, 1.4), Vector3.new(x, 0.9, 0), bodyColor, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(0.9, 0.8, 1.4))
	local dorsal = P(model, prefix .. "Dorsal", Vector3.new(0.15, 0.5, 0.5), Vector3.new(x, 1.45, -0.2), bodyColor, Enum.PartType.Wedge)
	local tail = P(model, prefix .. "Tail", Vector3.new(0.15, 0.6, 0.5), Vector3.new(x, 0.9, -0.85), bodyColor, Enum.PartType.Wedge)
	local eyeL = P(model, prefix .. "EyeL", Vector3.new(0.2, 0.2, 0.2), Vector3.new(x - 0.25, 1.1, 0.65), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local eyeR = P(model, prefix .. "EyeR", Vector3.new(0.2, 0.2, 0.2), Vector3.new(x + 0.25, 1.1, 0.65), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local shoeL = P(model, prefix .. "ShoeL", Vector3.new(0.35, 0.2, 0.5), Vector3.new(x - 0.25, 0.1, 0.1), shoeColor)
	local shoeR = P(model, prefix .. "ShoeR", Vector3.new(0.35, 0.2, 0.5), Vector3.new(x + 0.25, 0.1, 0.1), shoeColor)
	if bowColor then
		local bowL = P(model, prefix .. "BowL", Vector3.new(0.3, 0.2, 0.15), Vector3.new(x - 0.2, 1.35, 0.2), bowColor)
		bowL.CFrame = CFrame.new(x - 0.2, 1.35, 0.2) * CFrame.Angles(0, 0, 0.5)
		local bowR = P(model, prefix .. "BowR", Vector3.new(0.3, 0.2, 0.15), Vector3.new(x + 0.2, 1.35, 0.2), bowColor)
		bowR.CFrame = CFrame.new(x + 0.2, 1.35, 0.2) * CFrame.Angles(0, 0, -0.5)
		local bowC = P(model, prefix .. "BowC", Vector3.new(0.2, 0.2, 0.2), Vector3.new(x, 1.35, 0.2), bowColor, Enum.PartType.Ball)
	end
	return body
end

-- 15. Los Tralaleritos — 3 hiu bayi kecil bersepatu sneakers.
Builders.BabySharks = function(model, ch)
	local blue = C(ch.Primary)
	local white = C(ch.Accent)
	local mid = babyShark(model, "Mid", 0, blue, white, nil)
	babyShark(model, "Left", -1.3, blue, white, nil)
	babyShark(model, "Right", 1.3, blue, white, nil)
	return finish(model, mid, ch, "Basic")
end

-- 16. Las Tralaleritas — 3 hiu bayi kecil pink berpita.
Builders.BabySharksPink = function(model, ch)
	local pink = C(ch.Primary)
	local white = C(ch.Accent)
	local bow = Color3.fromRGB(255, 60, 140)
	local mid = babyShark(model, "Mid", 0, pink, white, bow)
	babyShark(model, "Left", -1.3, pink, white, bow)
	babyShark(model, "Right", 1.3, pink, white, bow)
	return finish(model, mid, ch, "Basic")
end

-- 17. Graipuss Medussi — ubur-ubur anggur ungu, tentakel.
Builders.GrapeJellyfish = function(model, ch)
	local purple = C(ch.Primary)
	local light = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(2.0, 1.4, 2.0), Vector3.new(0, 1.9, 0), purple, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(1, 0.7, 1))
	local bump1 = P(model, "Bump1", Vector3.new(0.5, 0.5, 0.5), Vector3.new(-0.6, 2.5, 0.5), light, Enum.PartType.Ball)
	local bump2 = P(model, "Bump2", Vector3.new(0.5, 0.5, 0.5), Vector3.new(0.6, 2.5, -0.4), light, Enum.PartType.Ball)
	local bump3 = P(model, "Bump3", Vector3.new(0.45, 0.45, 0.45), Vector3.new(0, 2.6, 0.6), light, Enum.PartType.Ball)
	local eyeL = P(model, "EyeL", Vector3.new(0.25, 0.25, 0.25), Vector3.new(-0.35, 1.9, 0.95), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.25, 0.25, 0.25), Vector3.new(0.35, 1.9, 0.95), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local smile = P(model, "Smile", Vector3.new(0.4, 0.12, 0.12), Vector3.new(0, 1.65, 0.95), Color3.fromRGB(40, 10, 60))
	for i = 1, 6 do
		local angle = (i - 1) * (math.pi * 2 / 6)
		local tx = math.cos(angle) * 0.7
		local tz = math.sin(angle) * 0.7
		local tent = P(model, "Tentacle" .. tostring(i), Vector3.new(0.18, 1.3, 0.18), Vector3.new(tx, 0.75, tz), (i % 2 == 0) and light or purple, Enum.PartType.Cylinder)
		tent.CFrame = CFrame.new(tx, 0.75, tz) * CFrame.Angles(0, 0, math.pi / 2)
		local tip = P(model, "Tip" .. tostring(i), Vector3.new(0.25, 0.25, 0.25), Vector3.new(tx * 1.1, 0.12, tz * 1.1), light, Enum.PartType.Ball)
	end
	return finish(model, body, ch, "Basic")
end

-- 18. Pot Hotspot — panci panas merah, cabai, uap/api.
Builders.HotPot = function(model, ch)
	local red = C(ch.Primary)
	local orange = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.8, 1.2, 1.8), Vector3.new(0, 0.6, 0), red, Enum.PartType.Cylinder)
	body.CFrame = CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local rim = P(model, "Rim", Vector3.new(1.9, 0.2, 1.9), Vector3.new(0, 1.2, 0), Color3.fromRGB(180, 30, 25), Enum.PartType.Cylinder)
	rim.CFrame = CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local broth = P(model, "Broth", Vector3.new(1.6, 0.15, 1.6), Vector3.new(0, 1.25, 0), orange, Enum.PartType.Cylinder)
	broth.CFrame = CFrame.new(0, 1.25, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local chili1 = P(model, "Chili1", Vector3.new(0.2, 0.2, 0.8), Vector3.new(-0.4, 1.4, 0.2), Color3.fromRGB(200, 20, 20), Enum.PartType.Cylinder)
	chili1.CFrame = CFrame.new(-0.4, 1.4, 0.2) * CFrame.Angles(0.4, 0, 1.2)
	local chili2 = P(model, "Chili2", Vector3.new(0.2, 0.2, 0.8), Vector3.new(0.4, 1.4, -0.2), Color3.fromRGB(200, 20, 20), Enum.PartType.Cylinder)
	chili2.CFrame = CFrame.new(0.4, 1.4, -0.2) * CFrame.Angles(-0.3, 0, -1.0)
	local handleL = P(model, "HandleL", Vector3.new(0.5, 0.2, 0.2), Vector3.new(-1.1, 0.7, 0), Color3.fromRGB(60, 60, 65))
	local handleR = P(model, "HandleR", Vector3.new(0.5, 0.2, 0.2), Vector3.new(1.1, 0.7, 0), Color3.fromRGB(60, 60, 65))
	local eyeL = P(model, "EyeL", Vector3.new(0.2, 0.2, 0.2), Vector3.new(-0.35, 0.7, 0.92), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0.35, 0.7, 0.92), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local flame1 = P(model, "Flame1", Vector3.new(0.5, 0.7, 0.5), Vector3.new(-0.5, 1.7, 0.3), orange, Enum.PartType.Ball, Enum.Material.Neon, 0.1)
	local flame2 = P(model, "Flame2", Vector3.new(0.4, 0.55, 0.4), Vector3.new(0.4, 1.6, -0.3), Color3.fromRGB(255, 220, 60), Enum.PartType.Ball, Enum.Material.Neon, 0.1)
	local steam1 = P(model, "Steam1", Vector3.new(0.4, 0.4, 0.4), Vector3.new(-0.2, 2.1, 0), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball, nil, 0.5)
	local steam2 = P(model, "Steam2", Vector3.new(0.35, 0.35, 0.35), Vector3.new(0.3, 2.4, 0.1), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball, nil, 0.6)
	return finish(model, body, ch, "Basic")
end

-- Helper lokal: satu buaya bayi (dipakai Los Crocodillitos).
local function babyCroc(model, prefix, x, green, white)
	local body = P(model, prefix .. "Body", Vector3.new(0.7, 0.4, 1.4), Vector3.new(x, 0.45, 0), green)
	local snout = P(model, prefix .. "Snout", Vector3.new(0.5, 0.25, 0.5), Vector3.new(x, 0.4, 0.85), green)
	local tooth = P(model, prefix .. "Tooth", Vector3.new(0.12, 0.2, 0.12), Vector3.new(x + 0.15, 0.55, 1.0), white)
	local eyeL = P(model, prefix .. "EyeL", Vector3.new(0.2, 0.2, 0.2), Vector3.new(x - 0.2, 0.75, 0.5), white, Enum.PartType.Ball)
	local eyeR = P(model, prefix .. "EyeR", Vector3.new(0.2, 0.2, 0.2), Vector3.new(x + 0.2, 0.75, 0.5), white, Enum.PartType.Ball)
	local tail = P(model, prefix .. "Tail", Vector3.new(0.2, 0.3, 0.8), Vector3.new(x, 0.4, -1.0), green, Enum.PartType.Wedge)
	local legL = P(model, prefix .. "LegL", Vector3.new(0.15, 0.3, 0.3), Vector3.new(x - 0.4, 0.15, 0.3), green)
	local legR = P(model, prefix .. "LegR", Vector3.new(0.15, 0.3, 0.3), Vector3.new(x + 0.4, 0.15, 0.3), green)
	return body
end

-- 19. Los Crocodillitos — 3 buaya bayi kecil hijau.
Builders.BabyCrocs = function(model, ch)
	local green = C(ch.Primary)
	local white = C(ch.Accent)
	local mid = babyCroc(model, "Mid", 0, green, white)
	babyCroc(model, "Left", -1.2, green, white)
	babyCroc(model, "Right", 1.2, green, white)
	return finish(model, mid, ch, "Basic")
end

-- 20. Orangutini Ananasini — orangutan oranye, nanas di kepala.
Builders.OrangutanPineapple = function(model, ch)
	local orange = C(ch.Primary)
	local yellow = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.4, 1.6, 1.2), Vector3.new(0, 0.9, 0), orange, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere)
	local face = P(model, "Face", Vector3.new(0.9, 0.8, 0.3), Vector3.new(0, 1.2, 0.55), Color3.fromRGB(240, 200, 150), Enum.PartType.Ball)
	local eyeL = P(model, "EyeL", Vector3.new(0.18, 0.18, 0.18), Vector3.new(-0.25, 1.35, 0.7), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.18, 0.18, 0.18), Vector3.new(0.25, 1.35, 0.7), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local armL = P(model, "ArmL", Vector3.new(0.35, 1.6, 0.35), Vector3.new(-0.85, 0.9, 0.1), orange, Enum.PartType.Cylinder)
	armL.CFrame = CFrame.new(-0.85, 0.9, 0.1) * CFrame.Angles(0, 0, 0.15)
	local armR = P(model, "ArmR", Vector3.new(0.35, 1.6, 0.35), Vector3.new(0.85, 0.9, 0.1), orange, Enum.PartType.Cylinder)
	armR.CFrame = CFrame.new(0.85, 0.9, 0.1) * CFrame.Angles(0, 0, -0.15)
	local legL = P(model, "LegL", Vector3.new(0.4, 0.5, 0.4), Vector3.new(-0.35, 0.25, 0), orange)
	local legR = P(model, "LegR", Vector3.new(0.4, 0.5, 0.4), Vector3.new(0.35, 0.25, 0), orange)
	local pineapple = P(model, "Pineapple", Vector3.new(0.8, 0.8, 0.8), Vector3.new(0, 1.95, 0), yellow, Enum.PartType.Ball)
	mesh(pineapple, Enum.MeshType.Sphere)
	local leaf1 = P(model, "Leaf1", Vector3.new(0.25, 0.7, 0.25), Vector3.new(-0.2, 2.5, 0), Color3.fromRGB(60, 180, 80))
	leaf1.CFrame = CFrame.new(-0.2, 2.5, 0) * CFrame.Angles(0, 0, 0.4)
	local leaf2 = P(model, "Leaf2", Vector3.new(0.25, 0.7, 0.25), Vector3.new(0.2, 2.5, 0), Color3.fromRGB(60, 180, 80))
	leaf2.CFrame = CFrame.new(0.2, 2.5, 0) * CFrame.Angles(0, 0, -0.4)
	local leaf3 = P(model, "Leaf3", Vector3.new(0.25, 0.6, 0.25), Vector3.new(0, 2.55, 0), Color3.fromRGB(80, 200, 100))
	return finish(model, body, ch, "Basic")
end

-- 21. Rhyno Toasterino — badak abu-abu, pemanggang roti di punggung, roti melompat.
Builders.RhinoToaster = function(model, ch)
	local grey = C(ch.Primary)
	local silver = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.4, 1.2, 2.2), Vector3.new(0, 0.8, 0), grey, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(1, 0.85, 1.55))
	local head = P(model, "Head", Vector3.new(1.0, 0.9, 1.0), Vector3.new(0, 1.0, 1.2), grey, Enum.PartType.Ball)
	local horn = P(model, "Horn", Vector3.new(0.3, 0.9, 0.3), Vector3.new(0, 1.6, 1.6), Color3.fromRGB(240, 230, 210), Enum.PartType.Wedge)
	local horn2 = P(model, "Horn2", Vector3.new(0.2, 0.5, 0.2), Vector3.new(0, 1.5, 1.1), Color3.fromRGB(240, 230, 210), Enum.PartType.Wedge)
	local earL = P(model, "EarL", Vector3.new(0.3, 0.4, 0.2), Vector3.new(-0.5, 1.4, 1.0), grey)
	local earR = P(model, "EarR", Vector3.new(0.3, 0.4, 0.2), Vector3.new(0.5, 1.4, 1.0), grey)
	local eyeL = P(model, "EyeL", Vector3.new(0.18, 0.18, 0.18), Vector3.new(-0.3, 1.15, 1.65), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.18, 0.18, 0.18), Vector3.new(0.3, 1.15, 1.65), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local legL = P(model, "LegL", Vector3.new(0.35, 0.6, 0.35), Vector3.new(-0.5, 0.3, 0.7), grey, Enum.PartType.Cylinder)
	legL.CFrame = CFrame.new(-0.5, 0.3, 0.7) * CFrame.Angles(0, 0, math.pi / 2)
	local legR = P(model, "LegR", Vector3.new(0.35, 0.6, 0.35), Vector3.new(0.5, 0.3, 0.7), grey, Enum.PartType.Cylinder)
	legR.CFrame = CFrame.new(0.5, 0.3, 0.7) * CFrame.Angles(0, 0, math.pi / 2)
	local legBL = P(model, "LegBL", Vector3.new(0.35, 0.6, 0.35), Vector3.new(-0.5, 0.3, -0.7), grey, Enum.PartType.Cylinder)
	legBL.CFrame = CFrame.new(-0.5, 0.3, -0.7) * CFrame.Angles(0, 0, math.pi / 2)
	local legBR = P(model, "LegBR", Vector3.new(0.35, 0.6, 0.35), Vector3.new(0.5, 0.3, -0.7), grey, Enum.PartType.Cylinder)
	legBR.CFrame = CFrame.new(0.5, 0.3, -0.7) * CFrame.Angles(0, 0, math.pi / 2)
	local toaster = P(model, "Toaster", Vector3.new(1.0, 0.7, 1.2), Vector3.new(0, 1.75, -0.2), silver)
	local slot1 = P(model, "Slot1", Vector3.new(0.7, 0.1, 0.2), Vector3.new(0, 2.12, -0.5), Color3.fromRGB(30, 30, 35))
	local slot2 = P(model, "Slot2", Vector3.new(0.7, 0.1, 0.2), Vector3.new(0, 2.12, 0.1), Color3.fromRGB(30, 30, 35))
	local toast1 = P(model, "Toast1", Vector3.new(0.6, 0.6, 0.15), Vector3.new(-0.25, 2.6, -0.5), Color3.fromRGB(230, 190, 130))
	toast1.CFrame = CFrame.new(-0.25, 2.6, -0.5) * CFrame.Angles(0.3, 0, 0.2)
	local toast2 = P(model, "Toast2", Vector3.new(0.6, 0.6, 0.15), Vector3.new(0.3, 2.7, 0.1), Color3.fromRGB(230, 190, 130))
	toast2.CFrame = CFrame.new(0.3, 2.7, 0.1) * CFrame.Angles(-0.2, 0, -0.3)
	local lever = P(model, "Lever", Vector3.new(0.15, 0.15, 0.4), Vector3.new(0.55, 1.8, -0.2), Color3.fromRGB(40, 40, 45))
	return finish(model, body, ch, "Basic")
end

-- 22. Tigrrullini Watermellini — harimau oranye belang, perut hijau semangka.
Builders.TigerWatermelon = function(model, ch)
	local orange = C(ch.Primary)
	local green = C(ch.Accent)
	local black = Color3.fromRGB(25, 25, 30)
	local body = P(model, "Body", Vector3.new(1.3, 1.2, 2.0), Vector3.new(0, 0.8, 0), orange, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(0.95, 0.85, 1.45))
	local head = P(model, "Head", Vector3.new(1.0, 0.9, 0.9), Vector3.new(0, 1.1, 1.2), orange, Enum.PartType.Ball)
	local earL = P(model, "EarL", Vector3.new(0.35, 0.35, 0.3), Vector3.new(-0.35, 1.6, 1.2), orange, Enum.PartType.Wedge)
	local earR = P(model, "EarR", Vector3.new(0.35, 0.35, 0.3), Vector3.new(0.35, 1.6, 1.2), orange, Enum.PartType.Wedge)
	local muzzle = P(model, "Muzzle", Vector3.new(0.6, 0.4, 0.3), Vector3.new(0, 0.95, 1.65), Color3.fromRGB(255, 230, 200), Enum.PartType.Ball)
	local belly = P(model, "Belly", Vector3.new(0.9, 0.8, 0.4), Vector3.new(0, 0.65, 0.85), green, Enum.PartType.Ball)
	mesh(belly, Enum.MeshType.Sphere)
	local stripe1 = P(model, "Stripe1", Vector3.new(1.35, 0.12, 0.3), Vector3.new(0, 1.3, 0.3), black)
	local stripe2 = P(model, "Stripe2", Vector3.new(1.35, 0.12, 0.3), Vector3.new(0, 1.3, -0.4), black)
	local stripe3 = P(model, "Stripe3", Vector3.new(1.35, 0.12, 0.3), Vector3.new(0, 1.1, 0.9), black)
	local tail = P(model, "Tail", Vector3.new(0.25, 0.25, 1.2), Vector3.new(0, 0.9, -1.5), orange, Enum.PartType.Cylinder)
	tail.CFrame = CFrame.new(0, 0.9, -1.5) * CFrame.Angles(math.pi / 2, 0, 0)
	local tailTip = P(model, "TailTip", Vector3.new(0.28, 0.28, 0.3), Vector3.new(0, 0.9, -2.1), black, Enum.PartType.Ball)
	local legL = P(model, "LegL", Vector3.new(0.3, 0.6, 0.3), Vector3.new(-0.45, 0.3, 0.7), orange)
	local legR = P(model, "LegR", Vector3.new(0.3, 0.6, 0.3), Vector3.new(0.45, 0.3, 0.7), orange)
	local legBL = P(model, "LegBL", Vector3.new(0.3, 0.6, 0.3), Vector3.new(-0.45, 0.3, -0.7), orange)
	local legBR = P(model, "LegBR", Vector3.new(0.3, 0.6, 0.3), Vector3.new(0.45, 0.3, -0.7), orange)
	return finish(model, body, ch, "Basic")
end

-- 23. Blueberrinni Octopussini — gurita blueberry biru, 8 tentakel.
Builders.BlueberryOctopus = function(model, ch)
	local blue = C(ch.Primary)
	local light = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.8, 1.6, 1.8), Vector3.new(0, 1.6, 0), blue, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere)
	local dot1 = P(model, "Dot1", Vector3.new(0.3, 0.3, 0.3), Vector3.new(-0.5, 2.2, 0.6), light, Enum.PartType.Ball)
	local dot2 = P(model, "Dot2", Vector3.new(0.3, 0.3, 0.3), Vector3.new(0.5, 2.3, -0.3), light, Enum.PartType.Ball)
	local dot3 = P(model, "Dot3", Vector3.new(0.25, 0.25, 0.25), Vector3.new(0, 2.4, 0.5), light, Enum.PartType.Ball)
	local eyeL = P(model, "EyeL", Vector3.new(0.4, 0.4, 0.4), Vector3.new(-0.4, 1.8, 0.8), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.4, 0.4, 0.4), Vector3.new(0.4, 1.8, 0.8), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local pupilL = P(model, "PupilL", Vector3.new(0.2, 0.2, 0.2), Vector3.new(-0.4, 1.8, 1.0), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local pupilR = P(model, "PupilR", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0.4, 1.8, 1.0), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local leaf = P(model, "Leaf", Vector3.new(0.3, 0.5, 0.15), Vector3.new(0.4, 2.55, 0), Color3.fromRGB(60, 180, 80))
	leaf.CFrame = CFrame.new(0.4, 2.55, 0) * CFrame.Angles(0, 0, -0.6)
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi * 2 / 8)
		local tx = math.cos(angle) * 0.75
		local tz = math.sin(angle) * 0.75
		local tent = P(model, "Tentacle" .. tostring(i), Vector3.new(0.3, 1.0, 0.3), Vector3.new(tx, 0.5, tz), (i % 2 == 0) and light or blue, Enum.PartType.Cylinder)
		tent.CFrame = CFrame.new(tx, 0.5, tz) * CFrame.Angles(0, 0, math.pi / 2)
		tent.CFrame = CFrame.new(tx, 0.5, tz) * CFrame.Angles(math.cos(angle) * 0.4, 0, math.sin(angle) * 0.4)
		local tip = P(model, "Tip" .. tostring(i), Vector3.new(0.35, 0.35, 0.35), Vector3.new(tx * 1.25, 0.18, tz * 1.25), light, Enum.PartType.Ball)
	end
	return finish(model, body, ch, "Basic")
end

-- 24. Svinino Bombondino — babi pink berhelm bomber, bom.
Builders.PigBomber = function(model, ch)
	local pink = C(ch.Primary)
	local olive = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.4, 1.2, 1.6), Vector3.new(0, 0.7, 0), pink, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(1.05, 0.9, 1.2))
	local head = P(model, "Head", Vector3.new(1.0, 0.9, 1.0), Vector3.new(0, 1.1, 0.8), pink, Enum.PartType.Ball)
	local snout = P(model, "Snout", Vector3.new(0.5, 0.35, 0.25), Vector3.new(0, 1.0, 1.35), Color3.fromRGB(255, 130, 170), Enum.PartType.Cylinder)
	snout.CFrame = CFrame.new(0, 1.0, 1.35) * CFrame.Angles(math.pi / 2, 0, 0)
	local earL = P(model, "EarL", Vector3.new(0.35, 0.4, 0.2), Vector3.new(-0.4, 1.65, 0.8), pink, Enum.PartType.Wedge)
	local earR = P(model, "EarR", Vector3.new(0.35, 0.4, 0.2), Vector3.new(0.4, 1.65, 0.8), pink, Enum.PartType.Wedge)
	local helmet = P(model, "Helmet", Vector3.new(1.1, 0.6, 1.1), Vector3.new(0, 1.65, 0.8), olive, Enum.PartType.Ball)
	mesh(helmet, Enum.MeshType.Sphere, Vector3.new(1, 0.55, 1))
	local goggleL = P(model, "GoggleL", Vector3.new(0.3, 0.25, 0.15), Vector3.new(-0.25, 1.35, 1.25), Color3.fromRGB(60, 60, 70), Enum.PartType.Cylinder)
	goggleL.CFrame = CFrame.new(-0.25, 1.35, 1.25) * CFrame.Angles(math.pi / 2, 0, 0)
	local goggleR = P(model, "GoggleR", Vector3.new(0.3, 0.25, 0.15), Vector3.new(0.25, 1.35, 1.25), Color3.fromRGB(60, 60, 70), Enum.PartType.Cylinder)
	goggleR.CFrame = CFrame.new(0.25, 1.35, 1.25) * CFrame.Angles(math.pi / 2, 0, 0)
	local bomb = P(model, "Bomb", Vector3.new(0.7, 0.7, 0.7), Vector3.new(0.9, 0.7, 0.4), Color3.fromRGB(40, 40, 45), Enum.PartType.Ball)
	local fuse = P(model, "Fuse", Vector3.new(0.1, 0.4, 0.1), Vector3.new(0.9, 1.2, 0.4), Color3.fromRGB(120, 90, 50))
	local spark = P(model, "Spark", Vector3.new(0.25, 0.25, 0.25), Vector3.new(0.9, 1.45, 0.4), Color3.fromRGB(255, 200, 60), Enum.PartType.Ball, Enum.Material.Neon)
	local legL = P(model, "LegL", Vector3.new(0.3, 0.4, 0.3), Vector3.new(-0.45, 0.2, 0.5), pink)
	local legR = P(model, "LegR", Vector3.new(0.3, 0.4, 0.3), Vector3.new(0.45, 0.2, 0.5), pink)
	local tail = P(model, "Tail", Vector3.new(0.12, 0.12, 0.5), Vector3.new(0, 0.8, -0.95), pink, Enum.PartType.Cylinder)
	tail.CFrame = CFrame.new(0, 0.8, -0.95) * CFrame.Angles(0.8, 0, 0)
	return finish(model, body, ch, "Basic")
end

-- 25. Chicletera Bicicleteira — makhluk permen karet pink naik sepeda.
Builders.GumBike = function(model, ch)
	local pink = C(ch.Primary)
	local dark = C(ch.Accent)
	local wheelF = P(model, "WheelF", Vector3.new(0.15, 1.0, 1.0), Vector3.new(0, 0.5, 0.9), dark, Enum.PartType.Cylinder)
	local wheelB = P(model, "WheelB", Vector3.new(0.15, 1.0, 1.0), Vector3.new(0, 0.5, -0.9), dark, Enum.PartType.Cylinder)
	local hubF = P(model, "HubF", Vector3.new(0.2, 0.3, 0.3), Vector3.new(0, 0.5, 0.9), Color3.fromRGB(200, 200, 210), Enum.PartType.Cylinder)
	local hubB = P(model, "HubB", Vector3.new(0.2, 0.3, 0.3), Vector3.new(0, 0.5, -0.9), Color3.fromRGB(200, 200, 210), Enum.PartType.Cylinder)
	local frame = P(model, "Frame", Vector3.new(0.12, 0.12, 1.8), Vector3.new(0, 0.8, 0), Color3.fromRGB(255, 220, 60))
	frame.CFrame = CFrame.new(0, 0.8, 0) * CFrame.Angles(0.15, 0, 0)
	local bar = P(model, "Handlebar", Vector3.new(0.7, 0.12, 0.12), Vector3.new(0, 1.25, 0.95), dark)
	local seat = P(model, "Seat", Vector3.new(0.5, 0.12, 0.35), Vector3.new(0, 1.15, -0.75), dark)
	local body = P(model, "Body", Vector3.new(1.0, 1.0, 1.0), Vector3.new(0, 1.7, -0.5), pink, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere)
	local eyeL = P(model, "EyeL", Vector3.new(0.2, 0.2, 0.2), Vector3.new(-0.25, 1.95, 0.05), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0.25, 1.95, 0.05), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local bubble = P(model, "Bubble", Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, 1.6, 0.35), Color3.fromRGB(255, 160, 200), Enum.PartType.Ball, Enum.Material.Glass, 0.3)
	local armL = P(model, "ArmL", Vector3.new(0.2, 0.7, 0.2), Vector3.new(-0.5, 1.6, 0.2), pink, Enum.PartType.Cylinder)
	armL.CFrame = CFrame.new(-0.5, 1.6, 0.2) * CFrame.Angles(0.7, 0, 0.3)
	local armR = P(model, "ArmR", Vector3.new(0.2, 0.7, 0.2), Vector3.new(0.5, 1.6, 0.2), pink, Enum.PartType.Cylinder)
	armR.CFrame = CFrame.new(0.5, 1.6, 0.2) * CFrame.Angles(0.7, 0, -0.3)
	local legL = P(model, "LegL", Vector3.new(0.2, 0.6, 0.2), Vector3.new(-0.3, 1.0, -0.3), pink, Enum.PartType.Cylinder)
	legL.CFrame = CFrame.new(-0.3, 1.0, -0.3) * CFrame.Angles(0.5, 0, 0)
	local legR = P(model, "LegR", Vector3.new(0.2, 0.6, 0.2), Vector3.new(0.3, 1.0, -0.3), pink, Enum.PartType.Cylinder)
	legR.CFrame = CFrame.new(0.3, 1.0, -0.3) * CFrame.Angles(0.5, 0, 0)
	return finish(model, body, ch, "Basic")
end

-- 26. La Grande Combinazione — brankas emas dengan 3 dial kombinasi.
Builders.GoldSafe = function(model, ch)
	local gold = C(ch.Primary)
	local darkGold = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.8, 2.0, 1.4), Vector3.new(0, 1.0, 0), gold)
	local door = P(model, "Door", Vector3.new(1.5, 1.7, 0.15), Vector3.new(0, 1.0, 0.72), darkGold)
	local dial1 = P(model, "Dial1", Vector3.new(0.35, 0.35, 0.2), Vector3.new(-0.45, 1.5, 0.82), Color3.fromRGB(245, 245, 245), Enum.PartType.Cylinder)
	dial1.CFrame = CFrame.new(-0.45, 1.5, 0.82) * CFrame.Angles(0, math.pi / 2, 0)
	local dial2 = P(model, "Dial2", Vector3.new(0.35, 0.35, 0.2), Vector3.new(0, 1.5, 0.82), Color3.fromRGB(245, 245, 245), Enum.PartType.Cylinder)
	dial2.CFrame = CFrame.new(0, 1.5, 0.82) * CFrame.Angles(0, math.pi / 2, 0)
	local dial3 = P(model, "Dial3", Vector3.new(0.35, 0.35, 0.2), Vector3.new(0.45, 1.5, 0.82), Color3.fromRGB(245, 245, 245), Enum.PartType.Cylinder)
	dial3.CFrame = CFrame.new(0.45, 1.5, 0.82) * CFrame.Angles(0, math.pi / 2, 0)
	local mark1 = P(model, "Mark1", Vector3.new(0.08, 0.2, 0.05), Vector3.new(-0.45, 1.62, 0.92), Color3.fromRGB(200, 40, 40))
	local mark2 = P(model, "Mark2", Vector3.new(0.08, 0.2, 0.05), Vector3.new(0, 1.62, 0.92), Color3.fromRGB(200, 40, 40))
	local mark3 = P(model, "Mark3", Vector3.new(0.08, 0.2, 0.05), Vector3.new(0.45, 1.62, 0.92), Color3.fromRGB(200, 40, 40))
	local handle = P(model, "Handle", Vector3.new(0.15, 0.6, 0.15), Vector3.new(0.45, 0.8, 0.82), Color3.fromRGB(60, 60, 65))
	handle.CFrame = CFrame.new(0.45, 0.8, 0.82) * CFrame.Angles(0, 0, 0.6)
	local keyhole = P(model, "Keyhole", Vector3.new(0.15, 0.25, 0.1), Vector3.new(-0.45, 0.8, 0.82), Color3.fromRGB(30, 30, 35))
	local footL = P(model, "FootL", Vector3.new(0.3, 0.2, 0.3), Vector3.new(-0.6, 0.1, 0.4), darkGold)
	local footR = P(model, "FootR", Vector3.new(0.3, 0.2, 0.3), Vector3.new(0.6, 0.1, 0.4), darkGold)
	local eyeL = P(model, "EyeL", Vector3.new(0.15, 0.15, 0.15), Vector3.new(-0.2, 1.15, 0.82), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.15, 0.15, 0.15), Vector3.new(0.2, 1.15, 0.82), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	return finish(model, body, ch, "Basic")
end

-- 27. Pipi Kiwi — burung kiwi kecil coklat, paruh panjang.
Builders.KiwiBird = function(model, ch)
	local brown = C(ch.Primary)
	local orange = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.0, 1.0, 1.3), Vector3.new(0, 0.6, 0), brown, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(0.8, 0.8, 1.05))
	local beak = P(model, "Beak", Vector3.new(0.15, 0.15, 1.0), Vector3.new(0, 0.75, 1.05), orange, Enum.PartType.Cylinder)
	beak.CFrame = CFrame.new(0, 0.75, 1.05) * CFrame.Angles(0.9, 0, 0)
	local wingL = P(model, "WingL", Vector3.new(0.15, 0.5, 0.6), Vector3.new(-0.5, 0.65, 0), brown)
	local wingR = P(model, "WingR", Vector3.new(0.15, 0.5, 0.6), Vector3.new(0.5, 0.65, 0), brown)
	local eyeL = P(model, "EyeL", Vector3.new(0.15, 0.15, 0.15), Vector3.new(-0.25, 0.85, 0.55), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.15, 0.15, 0.15), Vector3.new(0.25, 0.85, 0.55), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local legL = P(model, "LegL", Vector3.new(0.12, 0.4, 0.12), Vector3.new(-0.2, 0.2, 0), orange)
	local legR = P(model, "LegR", Vector3.new(0.12, 0.4, 0.12), Vector3.new(0.2, 0.2, 0), orange)
	local footL = P(model, "FootL", Vector3.new(0.3, 0.08, 0.4), Vector3.new(-0.2, 0.04, 0.1), orange)
	local footR = P(model, "FootR", Vector3.new(0.3, 0.08, 0.4), Vector3.new(0.2, 0.04, 0.1), orange)
	return finish(model, body, ch, "Basic")
end

-- Helper lokal: satu orca bayi (dipakai Los Orcalitos).
local function babyOrca(model, prefix, x, black, white)
	local body = P(model, prefix .. "Body", Vector3.new(0.8, 0.7, 1.4), Vector3.new(x, 0.8, 0), black, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(0.85, 0.75, 1.5))
	local belly = P(model, prefix .. "Belly", Vector3.new(0.6, 0.4, 1.0), Vector3.new(x, 0.55, 0.1), white, Enum.PartType.Ball)
	local patchL = P(model, prefix .. "PatchL", Vector3.new(0.2, 0.15, 0.2), Vector3.new(x - 0.25, 0.95, 0.55), white, Enum.PartType.Ball)
	local patchR = P(model, prefix .. "PatchR", Vector3.new(0.2, 0.15, 0.2), Vector3.new(x + 0.25, 0.95, 0.55), white, Enum.PartType.Ball)
	local dorsal = P(model, prefix .. "Dorsal", Vector3.new(0.15, 0.5, 0.5), Vector3.new(x, 1.3, -0.2), black, Enum.PartType.Wedge)
	local tail = P(model, prefix .. "Tail", Vector3.new(0.8, 0.15, 0.5), Vector3.new(x, 0.8, -0.9), black)
	local finL = P(model, prefix .. "FinL", Vector3.new(0.15, 0.3, 0.5), Vector3.new(x - 0.45, 0.6, 0.2), black)
	local finR = P(model, prefix .. "FinR", Vector3.new(0.15, 0.3, 0.5), Vector3.new(x + 0.45, 0.6, 0.2), black)
	return body
end

-- 28. Los Orcalitos — 3 orca bayi kecil hitam-putih.
Builders.BabyOrcas = function(model, ch)
	local black = C(ch.Primary)
	local white = C(ch.Accent)
	local mid = babyOrca(model, "Mid", 0, black, white)
	babyOrca(model, "Left", -1.2, black, white)
	babyOrca(model, "Right", 1.2, black, white)
	return finish(model, mid, ch, "Basic")
end

-- 29. Trulimero Trulichina — kucing oranye berekor ikan.
Builders.CatFish = function(model, ch)
	local orange = C(ch.Primary)
	local blue = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.2, 1.1, 1.4), Vector3.new(0, 0.7, 0), orange, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere)
	local head = P(model, "Head", Vector3.new(0.9, 0.8, 0.9), Vector3.new(0, 1.4, 0.5), orange, Enum.PartType.Ball)
	local earL = P(model, "EarL", Vector3.new(0.35, 0.4, 0.25), Vector3.new(-0.35, 1.85, 0.5), orange, Enum.PartType.Wedge)
	local earR = P(model, "EarR", Vector3.new(0.35, 0.4, 0.25), Vector3.new(0.35, 1.85, 0.5), orange, Enum.PartType.Wedge)
	local muzzle = P(model, "Muzzle", Vector3.new(0.5, 0.3, 0.25), Vector3.new(0, 1.25, 0.95), Color3.fromRGB(255, 230, 200), Enum.PartType.Ball)
	local whiskL = P(model, "WhiskL", Vector3.new(0.5, 0.05, 0.05), Vector3.new(-0.6, 1.3, 0.9), Color3.fromRGB(255, 255, 255))
	local whiskR = P(model, "WhiskR", Vector3.new(0.5, 0.05, 0.05), Vector3.new(0.6, 1.3, 0.9), Color3.fromRGB(255, 255, 255))
	local fishTail = P(model, "FishTail", Vector3.new(0.2, 1.0, 0.7), Vector3.new(0, 0.9, -1.0), blue, Enum.PartType.Wedge)
	local tailFin = P(model, "TailFin", Vector3.new(0.9, 0.2, 0.5), Vector3.new(0, 1.0, -1.4), blue)
	local legL = P(model, "LegL", Vector3.new(0.25, 0.5, 0.25), Vector3.new(-0.35, 0.25, 0.4), orange)
	local legR = P(model, "LegR", Vector3.new(0.25, 0.5, 0.25), Vector3.new(0.35, 0.25, 0.4), orange)
	local scale1 = P(model, "Scale1", Vector3.new(0.2, 0.15, 0.2), Vector3.new(-0.3, 1.0, 0.6), blue, Enum.PartType.Ball)
	local scale2 = P(model, "Scale2", Vector3.new(0.2, 0.15, 0.2), Vector3.new(0.3, 0.85, -0.3), blue, Enum.PartType.Ball)
	return finish(model, body, ch, "Basic")
end

-- 30. Frulli Frulla — penguin bawa blender.
Builders.PenguinBlender = function(model, ch)
	local black = C(ch.Primary)
	local yellow = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.1, 1.4, 1.0), Vector3.new(0, 0.8, 0), black, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(0.85, 1.05, 0.8))
	local belly = P(model, "Belly", Vector3.new(0.7, 0.9, 0.3), Vector3.new(0, 0.7, 0.45), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local beak = P(model, "Beak", Vector3.new(0.4, 0.2, 0.4), Vector3.new(0, 1.25, 0.55), Color3.fromRGB(255, 150, 40), Enum.PartType.Wedge)
	local eyeL = P(model, "EyeL", Vector3.new(0.18, 0.18, 0.18), Vector3.new(-0.25, 1.45, 0.45), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.18, 0.18, 0.18), Vector3.new(0.25, 1.45, 0.45), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local flipL = P(model, "FlipL", Vector3.new(0.2, 0.8, 0.5), Vector3.new(-0.65, 0.9, 0), black)
	local flipR = P(model, "FlipR", Vector3.new(0.2, 0.8, 0.5), Vector3.new(0.65, 0.9, 0), black)
	local footL = P(model, "FootL", Vector3.new(0.35, 0.12, 0.6), Vector3.new(-0.25, 0.06, 0.15), Color3.fromRGB(255, 150, 40))
	local footR = P(model, "FootR", Vector3.new(0.35, 0.12, 0.6), Vector3.new(0.25, 0.06, 0.15), Color3.fromRGB(255, 150, 40))
	local blenderBase = P(model, "BlenderBase", Vector3.new(0.6, 0.5, 0.6), Vector3.new(0.95, 0.75, 0.2), Color3.fromRGB(120, 120, 130))
	local blenderJar = P(model, "BlenderJar", Vector3.new(0.5, 0.8, 0.5), Vector3.new(0.95, 1.4, 0.2), Color3.fromRGB(200, 230, 255), Enum.PartType.Cylinder, Enum.Material.Glass, 0.3)
	blenderJar.CFrame = CFrame.new(0.95, 1.4, 0.2) * CFrame.Angles(0, 0, math.pi / 2)
	local blenderLid = P(model, "BlenderLid", Vector3.new(0.55, 0.15, 0.55), Vector3.new(0.95, 1.85, 0.2), Color3.fromRGB(60, 60, 65))
	local juice = P(model, "Juice", Vector3.new(0.4, 0.4, 0.4), Vector3.new(0.95, 1.25, 0.2), yellow, Enum.PartType.Cylinder)
	juice.CFrame = CFrame.new(0.95, 1.25, 0.2) * CFrame.Angles(0, 0, math.pi / 2)
	return finish(model, body, ch, "Basic")
end

-- 31. Bananita Dolphinita — lumba-lumba pisang kuning.
Builders.BananaDolphin = function(model, ch)
	local yellow = C(ch.Primary)
	local cream = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.0, 0.9, 2.0), Vector3.new(0, 1.0, 0), yellow, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(0.85, 0.75, 1.7))
	local belly = P(model, "Belly", Vector3.new(0.7, 0.5, 1.4), Vector3.new(0, 0.7, 0.1), cream, Enum.PartType.Ball)
	local snout = P(model, "Snout", Vector3.new(0.4, 0.3, 0.7), Vector3.new(0, 1.05, 1.35), yellow, Enum.PartType.Ball)
	local dorsal = P(model, "Dorsal", Vector3.new(0.2, 0.7, 0.8), Vector3.new(0, 1.6, -0.2), yellow, Enum.PartType.Wedge)
	local flukeL = P(model, "FlukeL", Vector3.new(0.7, 0.15, 0.5), Vector3.new(-0.35, 1.0, -1.35), yellow)
	local flukeR = P(model, "FlukeR", Vector3.new(0.7, 0.15, 0.5), Vector3.new(0.35, 1.0, -1.35), yellow)
	local finL = P(model, "FinL", Vector3.new(0.15, 0.4, 0.6), Vector3.new(-0.55, 0.8, 0.4), yellow)
	local finR = P(model, "FinR", Vector3.new(0.15, 0.4, 0.6), Vector3.new(0.55, 0.8, 0.4), yellow)
	local peelL = P(model, "PeelL", Vector3.new(0.3, 1.2, 0.3), Vector3.new(-0.55, 1.2, -0.6), yellow)
	peelL.CFrame = CFrame.new(-0.55, 1.2, -0.6) * CFrame.Angles(0, 0, 0.5)
	local peelR = P(model, "PeelR", Vector3.new(0.3, 1.2, 0.3), Vector3.new(0.55, 1.2, -0.6), yellow)
	peelR.CFrame = CFrame.new(0.55, 1.2, -0.6) * CFrame.Angles(0, 0, -0.5)
	local eyeL = P(model, "EyeL", Vector3.new(0.18, 0.18, 0.18), Vector3.new(-0.25, 1.25, 1.0), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.18, 0.18, 0.18), Vector3.new(0.25, 1.25, 1.0), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	return finish(model, body, ch, "Basic")
end

-- 32. Chef Crabracadabra — kepiting merah koki, topi koki, tongkat sulap.
Builders.ChefCrab = function(model, ch)
	local red = C(ch.Primary)
	local white = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.6, 0.9, 1.2), Vector3.new(0, 0.6, 0), red, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(1.2, 0.7, 0.9))
	local clawL = P(model, "ClawL", Vector3.new(0.6, 0.5, 0.5), Vector3.new(-1.1, 0.7, 0.3), red, Enum.PartType.Ball)
	local clawR = P(model, "ClawR", Vector3.new(0.6, 0.5, 0.5), Vector3.new(1.1, 0.7, 0.3), red, Enum.PartType.Ball)
	local pincerL = P(model, "PincerL", Vector3.new(0.25, 0.25, 0.4), Vector3.new(-1.35, 0.85, 0.5), red, Enum.PartType.Wedge)
	local pincerR = P(model, "PincerR", Vector3.new(0.25, 0.25, 0.4), Vector3.new(1.35, 0.85, 0.5), red, Enum.PartType.Wedge)
	local stalkL = P(model, "StalkL", Vector3.new(0.12, 0.5, 0.12), Vector3.new(-0.35, 1.25, 0.3), red)
	local stalkR = P(model, "StalkR", Vector3.new(0.12, 0.5, 0.12), Vector3.new(0.35, 1.25, 0.3), red)
	local eyeL = P(model, "EyeL", Vector3.new(0.3, 0.3, 0.3), Vector3.new(-0.35, 1.55, 0.3), white, Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.3, 0.3, 0.3), Vector3.new(0.35, 1.55, 0.3), white, Enum.PartType.Ball)
	local hatBase = P(model, "HatBase", Vector3.new(1.0, 0.3, 1.0), Vector3.new(0, 1.35, 0), white, Enum.PartType.Cylinder)
	hatBase.CFrame = CFrame.new(0, 1.35, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local hatPuff = P(model, "HatPuff", Vector3.new(1.1, 0.8, 1.1), Vector3.new(0, 1.85, 0), white, Enum.PartType.Ball)
	mesh(hatPuff, Enum.MeshType.Sphere, Vector3.new(1, 0.7, 1))
	local wand = P(model, "Wand", Vector3.new(0.12, 1.2, 0.12), Vector3.new(1.3, 1.4, 0.5), Color3.fromRGB(30, 30, 35), Enum.PartType.Cylinder)
	wand.CFrame = CFrame.new(1.3, 1.4, 0.5) * CFrame.Angles(0.4, 0, 0.4)
	local star = P(model, "Star", Vector3.new(0.35, 0.35, 0.35), Vector3.new(1.5, 2.0, 0.7), Color3.fromRGB(255, 220, 60), Enum.PartType.Ball, Enum.Material.Neon)
	for i = 1, 3 do
		local legL = P(model, "LegL" .. tostring(i), Vector3.new(0.12, 0.6, 0.12), Vector3.new(-0.9, 0.35, -0.3 + i * 0.3), red)
		legL.CFrame = CFrame.new(-0.9, 0.35, -0.3 + i * 0.3) * CFrame.Angles(0, 0, 0.6)
		local legR = P(model, "LegR" .. tostring(i), Vector3.new(0.12, 0.6, 0.12), Vector3.new(0.9, 0.35, -0.3 + i * 0.3), red)
		legR.CFrame = CFrame.new(0.9, 0.35, -0.3 + i * 0.3) * CFrame.Angles(0, 0, -0.6)
	end
	return finish(model, body, ch, "Basic")
end

-- 33. Zibra Zubra Zibralini — zebra belang hitam-putih.
Builders.Zebra = function(model, ch)
	local white = C(ch.Primary)
	local black = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.2, 1.2, 2.0), Vector3.new(0, 0.9, 0), white, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(0.85, 0.85, 1.4))
	local stripe1 = P(model, "Stripe1", Vector3.new(1.25, 0.15, 0.3), Vector3.new(0, 1.25, 0.4), black)
	local stripe2 = P(model, "Stripe2", Vector3.new(1.25, 0.15, 0.3), Vector3.new(0, 1.25, -0.3), black)
	local stripe3 = P(model, "Stripe3", Vector3.new(1.25, 0.15, 0.3), Vector3.new(0, 1.1, -0.8), black)
	local neck = P(model, "Neck", Vector3.new(0.5, 1.2, 0.5), Vector3.new(0, 1.7, 0.85), white, Enum.PartType.Cylinder)
	neck.CFrame = CFrame.new(0, 1.7, 0.85) * CFrame.Angles(0.4, 0, 0)
	local mane = P(model, "Mane", Vector3.new(0.2, 1.2, 0.35), Vector3.new(0, 1.8, 0.55), black)
	mane.CFrame = CFrame.new(0, 1.8, 0.55) * CFrame.Angles(0.4, 0, 0)
	local head = P(model, "Head", Vector3.new(0.55, 0.5, 0.9), Vector3.new(0, 2.35, 1.15), white, Enum.PartType.Ball)
	local muzzle = P(model, "Muzzle", Vector3.new(0.45, 0.35, 0.35), Vector3.new(0, 2.25, 1.6), Color3.fromRGB(200, 200, 205), Enum.PartType.Ball)
	local earL = P(model, "EarL", Vector3.new(0.2, 0.35, 0.15), Vector3.new(-0.25, 2.65, 1.1), white)
	local earR = P(model, "EarR", Vector3.new(0.2, 0.35, 0.15), Vector3.new(0.25, 2.65, 1.1), white)
	local eyeL = P(model, "EyeL", Vector3.new(0.15, 0.15, 0.15), Vector3.new(-0.25, 2.45, 1.5), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.15, 0.15, 0.15), Vector3.new(0.25, 2.45, 1.5), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local legL = P(model, "LegL", Vector3.new(0.3, 0.9, 0.3), Vector3.new(-0.4, 0.45, 0.7), white)
	local legR = P(model, "LegR", Vector3.new(0.3, 0.9, 0.3), Vector3.new(0.4, 0.45, 0.7), white)
	local legBL = P(model, "LegBL", Vector3.new(0.3, 0.9, 0.3), Vector3.new(-0.4, 0.45, -0.7), white)
	local legBR = P(model, "LegBR", Vector3.new(0.3, 0.9, 0.3), Vector3.new(0.4, 0.45, -0.7), white)
	local hoofL = P(model, "HoofL", Vector3.new(0.32, 0.15, 0.32), Vector3.new(-0.4, 0.08, 0.7), black)
	local hoofR = P(model, "HoofR", Vector3.new(0.32, 0.15, 0.32), Vector3.new(0.4, 0.08, 0.7), black)
	local hoofBL = P(model, "HoofBL", Vector3.new(0.32, 0.15, 0.32), Vector3.new(-0.4, 0.08, -0.7), black)
	local hoofBR = P(model, "HoofBR", Vector3.new(0.32, 0.15, 0.32), Vector3.new(0.4, 0.08, -0.7), black)
	local tail = P(model, "Tail", Vector3.new(0.15, 1.0, 0.15), Vector3.new(0, 1.0, -1.15), black)
	local tuft = P(model, "Tuft", Vector3.new(0.3, 0.4, 0.3), Vector3.new(0, 0.45, -1.2), black, Enum.PartType.Ball)
	return finish(model, body, ch, "Basic")
end

-- 34. Il Cacto Hipopotamo — kuda nil kaktus hijau.
Builders.CactusHippo = function(model, ch)
	local green = C(ch.Primary)
	local light = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.8, 1.4, 2.2), Vector3.new(0, 0.8, 0), green, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(1.25, 0.95, 1.5))
	local head = P(model, "Head", Vector3.new(1.3, 1.0, 1.2), Vector3.new(0, 1.1, 1.3), green, Enum.PartType.Ball)
	local snout = P(model, "Snout", Vector3.new(1.1, 0.6, 0.6), Vector3.new(0, 0.95, 1.95), Color3.fromRGB(60, 180, 80), Enum.PartType.Ball)
	local nostrilL = P(model, "NostrilL", Vector3.new(0.15, 0.15, 0.15), Vector3.new(-0.25, 1.05, 2.25), Color3.fromRGB(20, 40, 20), Enum.PartType.Ball)
	local nostrilR = P(model, "NostrilR", Vector3.new(0.15, 0.15, 0.15), Vector3.new(0.25, 1.05, 2.25), Color3.fromRGB(20, 40, 20), Enum.PartType.Ball)
	local eyeL = P(model, "EyeL", Vector3.new(0.2, 0.2, 0.2), Vector3.new(-0.4, 1.55, 1.6), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0.4, 1.55, 1.6), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local earL = P(model, "EarL", Vector3.new(0.3, 0.3, 0.2), Vector3.new(-0.55, 1.6, 1.2), green, Enum.PartType.Ball)
	local earR = P(model, "EarR", Vector3.new(0.3, 0.3, 0.2), Vector3.new(0.55, 1.6, 1.2), green, Enum.PartType.Ball)
	local spine1 = P(model, "Spine1", Vector3.new(0.15, 0.4, 0.15), Vector3.new(-0.5, 1.6, 0), light)
	local spine2 = P(model, "Spine2", Vector3.new(0.15, 0.4, 0.15), Vector3.new(0.4, 1.65, -0.6), light)
	local spine3 = P(model, "Spine3", Vector3.new(0.15, 0.4, 0.15), Vector3.new(0, 1.6, 0.7), light)
	local spine4 = P(model, "Spine4", Vector3.new(0.15, 0.4, 0.15), Vector3.new(0.6, 1.5, 0.4), light)
	local legL = P(model, "LegL", Vector3.new(0.45, 0.6, 0.45), Vector3.new(-0.6, 0.3, 0.7), green, Enum.PartType.Cylinder)
	legL.CFrame = CFrame.new(-0.6, 0.3, 0.7) * CFrame.Angles(0, 0, math.pi / 2)
	local legR = P(model, "LegR", Vector3.new(0.45, 0.6, 0.45), Vector3.new(0.6, 0.3, 0.7), green, Enum.PartType.Cylinder)
	legR.CFrame = CFrame.new(0.6, 0.3, 0.7) * CFrame.Angles(0, 0, math.pi / 2)
	local legBL = P(model, "LegBL", Vector3.new(0.45, 0.6, 0.45), Vector3.new(-0.6, 0.3, -0.7), green, Enum.PartType.Cylinder)
	legBL.CFrame = CFrame.new(-0.6, 0.3, -0.7) * CFrame.Angles(0, 0, math.pi / 2)
	local legBR = P(model, "LegBR", Vector3.new(0.45, 0.6, 0.45), Vector3.new(0.6, 0.3, -0.7), green, Enum.PartType.Cylinder)
	legBR.CFrame = CFrame.new(0.6, 0.3, -0.7) * CFrame.Angles(0, 0, math.pi / 2)
	local tail = P(model, "Tail", Vector3.new(0.15, 0.4, 0.15), Vector3.new(0, 0.9, -1.25), green)
	return finish(model, body, ch, "Basic")
end

-- 35. Karkerkar Kurkur — burung gagak hitam bermahkota.
Builders.CrowKing = function(model, ch)
	local black = C(ch.Primary)
	local gold = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.1, 1.2, 1.3), Vector3.new(0, 0.8, 0), black, Enum.PartType.Ball)
	mesh(body, Enum.MeshType.Sphere, Vector3.new(0.85, 0.95, 1.0))
	local wingL = P(model, "WingL", Vector3.new(0.2, 0.8, 1.0), Vector3.new(-0.6, 0.9, 0), black)
	local wingR = P(model, "WingR", Vector3.new(0.2, 0.8, 1.0), Vector3.new(0.6, 0.9, 0), black)
	local beak = P(model, "Beak", Vector3.new(0.3, 0.25, 0.7), Vector3.new(0, 1.05, 0.85), Color3.fromRGB(255, 180, 40), Enum.PartType.Wedge)
	local eyeL = P(model, "EyeL", Vector3.new(0.2, 0.2, 0.2), Vector3.new(-0.3, 1.25, 0.55), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0.3, 1.25, 0.55), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
	local crownBand = P(model, "CrownBand", Vector3.new(0.9, 0.25, 0.9), Vector3.new(0, 1.6, 0.2), gold, Enum.PartType.Cylinder, Enum.Material.Neon, 0.1)
	crownBand.CFrame = CFrame.new(0, 1.6, 0.2) * CFrame.Angles(0, 0, math.pi / 2)
	local point1 = P(model, "Point1", Vector3.new(0.2, 0.4, 0.2), Vector3.new(-0.3, 1.9, 0.2), gold, Enum.PartType.Wedge)
	local point2 = P(model, "Point2", Vector3.new(0.2, 0.5, 0.2), Vector3.new(0, 1.95, 0.2), gold, Enum.PartType.Wedge)
	local point3 = P(model, "Point3", Vector3.new(0.2, 0.4, 0.2), Vector3.new(0.3, 1.9, 0.2), gold, Enum.PartType.Wedge)
	local jewel = P(model, "Jewel", Vector3.new(0.25, 0.25, 0.25), Vector3.new(0, 1.6, 0.68), Color3.fromRGB(255, 60, 80), Enum.PartType.Ball, Enum.Material.Neon)
	local tail1 = P(model, "Tail1", Vector3.new(0.3, 0.15, 0.9), Vector3.new(-0.2, 0.7, -0.9), black)
	local tail2 = P(model, "Tail2", Vector3.new(0.3, 0.15, 0.9), Vector3.new(0.2, 0.7, -0.9), black)
	local legL = P(model, "LegL", Vector3.new(0.12, 0.5, 0.12), Vector3.new(-0.2, 0.25, 0), Color3.fromRGB(255, 150, 40))
	local legR = P(model, "LegR", Vector3.new(0.12, 0.5, 0.12), Vector3.new(0.2, 0.25, 0), Color3.fromRGB(255, 150, 40))
	return finish(model, body, ch, "Basic")
end

-- 36. Pipi Popcorn — ember popcorn dengan wajah.
Builders.PopcornBucket = function(model, ch)
	local red = C(ch.Primary)
	local cream = C(ch.Accent)
	local body = P(model, "Body", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 0.7, 0), red, Enum.PartType.Cylinder)
	body.CFrame = CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local stripe1 = P(model, "Stripe1", Vector3.new(1.45, 1.4, 0.25), Vector3.new(0, 0.7, 0), Color3.fromRGB(255, 255, 255))
	local stripe2 = P(model, "Stripe2", Vector3.new(0.25, 1.4, 1.45), Vector3.new(0, 0.7, 0), Color3.fromRGB(255, 255, 255))
	local rim = P(model, "Rim", Vector3.new(1.5, 0.2, 1.5), Vector3.new(0, 1.45, 0), Color3.fromRGB(200, 30, 30), Enum.PartType.Cylinder)
	rim.CFrame = CFrame.new(0, 1.45, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local pop1 = P(model, "Pop1", Vector3.new(0.5, 0.5, 0.5), Vector3.new(-0.4, 1.7, 0.2), cream, Enum.PartType.Ball)
	local pop2 = P(model, "Pop2", Vector3.new(0.55, 0.55, 0.55), Vector3.new(0.3, 1.75, -0.2), cream, Enum.PartType.Ball)
	local pop3 = P(model, "Pop3", Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, 1.9, 0.3), cream, Enum.PartType.Ball)
	local pop4 = P(model, "Pop4", Vector3.new(0.45, 0.45, 0.45), Vector3.new(0.45, 1.65, 0.35), cream, Enum.PartType.Ball)
	local pop5 = P(model, "Pop5", Vector3.new(0.45, 0.45, 0.45), Vector3.new(-0.1, 1.65, -0.45), cream, Enum.PartType.Ball)
	local eyeL = P(model, "EyeL", Vector3.new(0.2, 0.2, 0.2), Vector3.new(-0.3, 0.85, 0.72), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.2, 0.2, 0.2), Vector3.new(0.3, 0.85, 0.72), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local smile = P(model, "Smile", Vector3.new(0.45, 0.12, 0.12), Vector3.new(0, 0.55, 0.72), Color3.fromRGB(60, 20, 20))
	local footL = P(model, "FootL", Vector3.new(0.35, 0.15, 0.5), Vector3.new(-0.3, 0.08, 0.1), Color3.fromRGB(60, 60, 65))
	local footR = P(model, "FootR", Vector3.new(0.35, 0.15, 0.5), Vector3.new(0.3, 0.08, 0.1), Color3.fromRGB(60, 60, 65))
	return finish(model, body, ch, "Basic")
end

-- 37. Cappuccino Ballerino — cangkir cappuccino pria bertuksedo menari balet.
Builders.CupBallerino = function(model, ch)
	local brown = C(ch.Primary)
	local white = C(ch.Accent)
	local black = Color3.fromRGB(30, 30, 35)
	local skin = Color3.fromRGB(240, 210, 180)
	local legL = P(model, "LegL", Vector3.new(0.3, 1.4, 0.3), Vector3.new(-0.3, 0.7, 0), skin, Enum.PartType.Cylinder)
	legL.CFrame = CFrame.new(-0.3, 0.7, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local legR = P(model, "LegR", Vector3.new(0.3, 1.4, 0.3), Vector3.new(0.35, 0.9, 0.3), skin, Enum.PartType.Cylinder)
	legR.CFrame = CFrame.new(0.35, 0.9, 0.3) * CFrame.Angles(0.7, 0, 0.4)
	local shoeL = P(model, "ShoeL", Vector3.new(0.4, 0.25, 0.7), Vector3.new(-0.3, 0.12, 0.1), black)
	local shoeR = P(model, "ShoeR", Vector3.new(0.4, 0.25, 0.7), Vector3.new(0.5, 0.5, 0.7), black)
	shoeR.CFrame = CFrame.new(0.5, 0.5, 0.7) * CFrame.Angles(0.7, 0, 0)
	local body = P(model, "Body", Vector3.new(1.3, 1.6, 1.3), Vector3.new(0, 2.2, 0), brown, Enum.PartType.Cylinder)
	body.CFrame = CFrame.new(0, 2.2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local cummerbund = P(model, "Cummerbund", Vector3.new(1.35, 0.3, 1.35), Vector3.new(0, 1.6, 0), black, Enum.PartType.Cylinder)
	cummerbund.CFrame = CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local shirt = P(model, "Shirt", Vector3.new(0.5, 0.8, 0.12), Vector3.new(0, 2.5, 0.66), white)
	local bowL = P(model, "BowL", Vector3.new(0.3, 0.2, 0.12), Vector3.new(-0.18, 2.85, 0.66), black)
	bowL.CFrame = CFrame.new(-0.18, 2.85, 0.66) * CFrame.Angles(0, 0, 0.5)
	local bowR = P(model, "BowR", Vector3.new(0.3, 0.2, 0.12), Vector3.new(0.18, 2.85, 0.66), black)
	bowR.CFrame = CFrame.new(0.18, 2.85, 0.66) * CFrame.Angles(0, 0, -0.5)
	local foam = P(model, "Foam", Vector3.new(1.2, 0.4, 1.2), Vector3.new(0, 3.05, 0), Color3.fromRGB(250, 240, 220), Enum.PartType.Cylinder)
	foam.CFrame = CFrame.new(0, 3.05, 0) * CFrame.Angles(0, 0, math.pi / 2)
	local handle = P(model, "Handle", Vector3.new(0.25, 0.7, 0.25), Vector3.new(0.72, 2.2, 0), white)
	local armL = P(model, "ArmL", Vector3.new(0.25, 1.2, 0.25), Vector3.new(-0.7, 2.8, 0), skin, Enum.PartType.Cylinder)
	armL.CFrame = CFrame.new(-0.7, 2.8, 0) * CFrame.Angles(0, 0, math.pi / 2 + 0.9)
	local armR = P(model, "ArmR", Vector3.new(0.25, 1.2, 0.25), Vector3.new(0.7, 2.9, 0), skin, Enum.PartType.Cylinder)
	armR.CFrame = CFrame.new(0.7, 2.9, 0) * CFrame.Angles(0, 0, math.pi / 2 - 0.9)
	local eyeL = P(model, "EyeL", Vector3.new(0.18, 0.18, 0.18), Vector3.new(-0.28, 2.4, 0.66), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local eyeR = P(model, "EyeR", Vector3.new(0.18, 0.18, 0.18), Vector3.new(0.28, 2.4, 0.66), Color3.fromRGB(20, 20, 20), Enum.PartType.Ball)
	local moustache = P(model, "Moustache", Vector3.new(0.5, 0.12, 0.12), Vector3.new(0, 2.2, 0.66), black)
	return finish(model, body, ch, "Basic")
end

-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- Custom Model Override: if the player (or the owner) drops their own Model
-- into ReplicatedStorage.CustomModels with the character's exact name and a
-- PrimaryPart set, that model is used instead of the procedural build. If the
-- folder is empty or the model is missing/invalid, the procedural build runs
-- and the game stays 100% playable.
-- ---------------------------------------------------------------------------

local function getCustomModel(name)
	local folder = ReplicatedStorage:FindFirstChild("CustomModels")
	if not folder then
		return nil
	end
	local found = folder:FindFirstChild(name)
	if found and found:IsA("Model") and found.PrimaryPart then
		local clone = found:Clone()
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
			end
		end
		return clone
	end
	return nil
end

-- Build a brainrot model for the given character name and active event.
-- Returns a Model whose PrimaryPart is the body; the model origin is at the
-- ground (y = 0 is the feet), so PivotTo(CFrame.new(pos)) stands it on the
-- floor without sinking.
function BrainrotDatabase.BuildModel(name, eventKey, incomeMult)
	eventKey = eventKey or "Basic"
	incomeMult = incomeMult or 1
	local ch = BrainrotDatabase.GetCharacter(name)
	if not ch then
		return nil
	end
	local custom = getCustomModel(name)
	if custom then
		custom.Name = name
		-- Tag + aura on the custom model too, so it reads as a brainrot.
		tag(custom, custom.PrimaryPart, ch, eventKey, incomeMult)
		aura(custom, custom.PrimaryPart, eventKey)
		return custom
	end
	local model = Instance.new("Model")
	model.Name = name
	local builder = Builders[ch.Build]
	if builder then
		builder(model, ch)
	else
		-- Fallback: a plain neon cube, so a bad Build key can never break
		-- the game.
		local body = P(model, "Body", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 0.7, 0), C(ch.Primary), Enum.PartType.Block, Enum.Material.Neon)
		finish(model, body, ch, eventKey)
	end
	-- Re-tag with the real event (builders tag with "Basic" by default).
	local oldTag = model:FindFirstChild("Tag")
	if oldTag then
		oldTag:Destroy()
	end
	tag(model, model.PrimaryPart, ch, eventKey, incomeMult)
	aura(model, model.PrimaryPart, eventKey)
	return model
end

return BrainrotDatabase
