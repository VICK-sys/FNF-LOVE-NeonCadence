local Spraycan = require "spraycan"
local cans, explosions, pile
local gunCocked = 0

function postCreate()
	pile = state.stage.spraycanPile
	if not pile then return end
	cans, explosions = Group(), Group()
	state.stage.foreground:insert(state.stage.foreground:indexOf(pile), cans)
	state.stage.foreground:add(explosions)
	paths.getAnimateAtlas("stages/phillyStreets/spraycanAtlas")
	paths.getSparrowAtlas("stages/phillyStreets/SpraypaintExplosion")
	paths.getSparrowAtlas("stages/phillyStreets/spraypaintExplosionEZ")
end

local function nextCan()
	for _, can in ipairs(cans.members) do
		if can.exists and can.currentState == "arcing" then return can end
	end
end

function onNoteHit(event)
	if not cans or event.cancelled or event.note.wasGoodHit then return end
	local kind = event.note.type
	if kind == "weekend-1-kickcan" and event.character == state.dad then
		cans:add(Spraycan(pile.x - 10, pile.y - 550, function(explosion)
			explosions:add(explosion)
		end))
	elseif event.character == state.boyfriend then
		if kind == "weekend-1-cockgun" then
			gunCocked = 1
		elseif kind == "weekend-1-firegun" then
			if gunCocked > 0 then
				local can = nextCan()
				if can then can:shoot() end
			else
				event:cancel()
			end
		end
	end
end

function onNoteMiss(event)
	if not cans or event.cancelled or event.note.tooLate or event.character ~= state.boyfriend then return end
	if event.note.type == "weekend-1-firegun" then
		gunCocked = 0
		local can = nextCan()
		if can then can:miss() end
	end
end

function update(dt)
	gunCocked = math.max(0, gunCocked - dt)
end

local function removeFinished(group)
	for index = #group.members, 1, -1 do
		local member = group.members[index]
		if not member.exists then group:remove(member):destroy() end
	end
end

function postUpdate()
	if not cans then return end
	removeFinished(cans)
	removeFinished(explosions)
end

function leave()
	if not cans then return end
	cans:kill()
	explosions:kill()
	postUpdate()
	gunCocked = 0
end
