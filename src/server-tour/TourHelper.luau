-- PLAZA DEL DELIRIO — DICE + BASE + REBIRTH (REBUILD v7) — TourHelper
-- (ServerScriptService/TourHelper). Called by the entry's TOUR.json so
-- make.fun reviewers can drive the game to each screenshot: the dice row
-- (roll + base + backpack Tools), a populated base, a random 60-second
-- buff event, the 6-tab Index, and the Rebirth panel. Every function runs
-- on the server and only fires the BindableEvents WorldAndSystems created
-- at startup. (v7: no speed-burst button, no in-game collection panel — the Backpack is
-- the Backpack holds every brainrot now; weather forces a random buff event, never Basic.)
-- v7.1: every handler warns when its BindableEvent is not found after 10s
-- (instead of failing silently) — so a tour step that does nothing leaves
-- a visible trace in the Output window.

local ServerScriptService = game:GetService("ServerScriptService")

local TourHelper = {}

function TourHelper.dice(player, _arg)
	local event = ServerScriptService:WaitForChild("TourDice", 10)
	if event then
		event:Fire(player)
	else
		warn("[Plaza] TourHelper.dice: TourDice not found after 10s (server may not have started it).")
	end
end

function TourHelper.base(player, _arg)
	local event = ServerScriptService:WaitForChild("TourBase", 10)
	if event then
		event:Fire(player)
	else
		warn("[Plaza] TourHelper.base: TourBase not found after 10s (server may not have started it).")
	end
end

function TourHelper.weather(player, _arg)
	local event = ServerScriptService:WaitForChild("TourWeather", 10)
	if event then
		event:Fire(player)
	else
		warn("[Plaza] TourHelper.weather: TourWeather not found after 10s (server may not have started it).")
	end
end

function TourHelper.index(player, _arg)
	local event = ServerScriptService:WaitForChild("TourIndex", 10)
	if event then
		event:Fire(player)
	else
		warn("[Plaza] TourHelper.index: TourIndex not found after 10s (server may not have started it).")
	end
end

function TourHelper.rebirth(player, _arg)
	local event = ServerScriptService:WaitForChild("TourRebirth", 10)
	if event then
		event:Fire(player)
	else
		warn("[Plaza] TourHelper.rebirth: TourRebirth not found after 10s (server may not have started it).")
	end
end

return TourHelper
