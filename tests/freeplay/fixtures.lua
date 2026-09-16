local function noop() end
Classic = require "loxel.lib.classic"
Object = Classic:extend("Object")
State = Classic:extend("State")
function State:new() self.members = {} end
function State:add(member) table.insert(self.members, member); return member end
function State:remove(member)
	for i, value in ipairs(self.members) do
		if value == member then table.remove(self.members, i); return member end
	end
end
function State:enter() self.entered = true end
function State:update(dt)
	for _, member in ipairs(self.members) do
		if member.update and member.active ~= false then member:update(dt) end
	end
end
function State:openSubstate(substate)
	self.substate, substate.parent = substate, self
	substate:enter()
end
function State:closeSubstate()
	if self.substate then self.substate:leave() end
	self.substate = nil
end
function State:leave() self.left = true end
SpriteGroup = State:extend("SpriteGroup")
function SpriteGroup:new(x, y)
	SpriteGroup.super.new(self)
	self.x, self.y = x or 0, y or 0
	self.width, self.height = 0, 0
	self.scale, self.offset, self.origin = {x = 1, y = 1}, {x = 0, y = 0}, {x = 0, y = 0}
end
function SpriteGroup:clear() self.members = {} end
function SpriteGroup:destroy() self.destroyed = true end

function bind(owner, fn) return function(...) return fn(owner, ...) end end
function switch(value, cases)
	for key, callback in pairs(cases) do
		if key == value then return callback() end
		if type(key) == "table" then
			for _, option in ipairs(key) do if option == value then return callback() end end
		end
	end
end
function math.clamp(value, low, high) return math.max(low, math.min(value, high)) end
function math.remapToRange(value, low, high, start, finish)
	return start + (value - low) / (high - low) * (finish - start)
end
function table.clear(t) for key in pairs(t) do t[key] = nil end end
function table.clone(t)
	local result = {}
	for key, value in pairs(t) do result[key] = value end
	return result
end
function string:split(separator)
	local result, start = {}, 1
	while true do
		local first, last = self:find(separator, start, true)
		if not first then table.insert(result, self:sub(start)); return result end
		table.insert(result, self:sub(start, first - 1))
		start = last + 1
	end
end
function string:trim() return self:match("^%s*(.-)%s*$") end
function string:withoutExt() return self:gsub("%.[^%.]+$", "") end

local function sprite(x, y, content)
	return {
		x = x or 0, y = y or 0, content = content or "", width = 200, height = 50,
		active = true, scale = {x = 1, y = 1, set = function(self, sx, sy) self.x, self.y = sx, sy end},
		origin = {x = 0, y = 0}, alpha = 1,
		update = noop, updateHitbox = noop, setGraphicSize = noop, setScrollFactor = noop,
		screenCenter = function(self) return self end,
		setPosition = function(self, px, py) self.x, self.y = px, py end,
		getWidth = function(self) return self.width end,
		getHeight = function(self) return self.height end,
		destroy = function(self) self.destroyed = true end
	}
end
Sprite, Text, AtlasText, Graphic = sprite, sprite, sprite, sprite
HealthIcon = setmetatable({defaultIcon = "face"}, {__call = function(_, icon)
	local result = sprite()
	result.icon = icon
	return result
end})
package.loaded["funkin.ui.freeplay.capsule"] = function(entry)
	local result = sprite()
	for key, value in pairs(entry) do result[key] = value end
	result.entry = entry
	result.setSelected = function(self, selected) self.selected = selected end
	result.setDifficulty = function(self, difficulty) self.difficulty = difficulty end
	result.setRank = function(self, rank) self.rank = rank end
	result.confirm = function(self) self.confirmed = true end
	return result
end
package.loaded["funkin.ui.freeplay.backdrop"] = function(state)
	local result = sprite()
	result.state = state
	return result
end
Color = {WHITE = {1, 1, 1}, BLACK = {0, 0, 0},
	lerpDelta = function(_, target) return target end}
Throttle = {make = function()
	local result = {check = function() return false end,
		destroy = function(self) self.destroyed = true end}
	table.insert(freeplayFixtures.throttles, result)
	return result
end}
MenuList = require "funkin.ui.menulist"
Script = setmetatable({Event_Cancel = {}}, {__call = function()
	local result = {calls = {}, hooks = {}, close = function(self) self.closed = true end}
	result.call = function(self, name, ...)
		table.insert(self.calls, name)
		if self.hooks[name] then return self.hooks[name](...) end
	end
	if freeplayFixtures.cancelCreate then result.hooks.create = function() return Script.Event_Cancel end end
	return result
end})
LoadState = function(state) return {destination = state} end
ChartingState = function() return {name = "charting"} end
MainMenuState = function() return {name = "main-menu"} end

local function source(name)
	return {
		name = name, duration = 120,
		clone = function(self)
			local result = source(self.name)
			result.original, result.duration = self, self.duration
			table.insert(freeplayFixtures.clones, result)
			return result
		end,
		getDuration = function(self) return self.duration end,
		stop = function(self) self.stopped = true end,
		release = function(self) self.released = true end
	}
end
local function sound(asset)
	return {
		asset = asset, _source = asset, time = 0, duration = 120, playing = false, volume = 0.8,
		play = function(self, volume, looped)
			self.playing, self.volume, self.looped = true, volume or self.volume, looped
			self.plays = (self.plays or 0) + 1
			return self
		end,
		pause = function(self) self.playing = false; self.paused = true; return self end,
		stop = function(self) self.playing = false; self.stopped = true; return self end,
		cleanup = function(self) self.playing = false; self.cleaned = true end,
		reset = function(self) self.playing = false; self.reset = true end,
		fade = function(self, _, _, volume) self.volume = volume end,
		cancelFade = noop,
		isPlaying = function(self) return self.playing end
	}
end

function resetFreeplayFixtures()
	freeplayFixtures = {texts = {freeplayList = "alpha\nbeta\ngamma"}, json = {},
		metas = {}, metaRequests = {}, audio = {}, loadedMusic = {}, clones = {}, throttles = {},
		scoreRequests = {}, menuMusicCalls = 0}
	ClientPrefs = {data = {musicVolume = 80, menuMusicVolume = 80}}
	Mods = {}
	game = {width = 1280, height = 720, dt = 0, keys = {pressed = {}, justPressed = {}}, mouse = {wheel = 0},
		getState = function() return "freeplay" end,
		save = {data = {}, bind = noop, flush = function(self) self.flushes = (self.flushes or 0) + 1 end},
		sound = {music = sound("menu"), play = noop}, touch = {}}
	game.sound.loadMusic = function(asset)
		game.sound.music = sound(asset)
		table.insert(freeplayFixtures.loadedMusic, game.sound.music)
		return game.sound.music
	end
	Camera = function() return {exists = true} end
	game.cameras = {list = {}}
	game.cameras.add = function(camera)
		table.insert(game.cameras.list, camera)
		return camera
	end
	game.cameras.remove = function(camera)
		camera.exists = false
		for i, value in ipairs(game.cameras.list) do
			if value == camera then table.remove(game.cameras.list, i); return end
		end
	end
	game.sound.playMusic = function(asset, volume, looped)
		game.sound.loadMusic(asset)
		return game.sound.music:play(volume, looped)
	end
	game.switchState = function(state) game.nextState = state end
	controls = {pressed = function(self, action) return self.actions and self.actions[action] end,
		down = function() return false end}
	util = {coolLerp = function(_, target) return target end, playSfx = noop,
		formatNumber = tostring, responsiveBG = function(value) return value end,
		createButtons = function() return sprite() end,
		playMenuMusic = function() freeplayFixtures.menuMusicCalls = freeplayFixtures.menuMusicCalls + 1 end}
	paths = {
		getPath = function(path) return path end,
		getMods = function(path) return "mods/" .. path end,
		formatToSongPath = function(name) return name:lower():gsub(" ", "-") end,
		exists = function(path)
			local key = path:match("data/(.-)%.txt$")
			return key and freeplayFixtures.texts[key] ~= nil or false
		end,
		getText = function(key) return freeplayFixtures.texts[key] end,
		getJSON = function(key) return freeplayFixtures.json[key] end,
		getItems = function() return freeplayFixtures.items or {} end,
		getSound = function(name) return name end,
		getMusic = source,
		getFont = noop, getImage = noop,
		getInst = function(song, suffix)
			local key = song .. (suffix and "-" .. suffix or "")
			local asset = freeplayFixtures.audio[key]
			if asset == false then return nil end
			return asset or source(key)
		end
	}
	Parser = {clearCache = noop, getMeta = function(name)
		table.insert(freeplayFixtures.metaRequests, name)
		return freeplayFixtures.metas[name] or {
			song = paths.formatToSongPath(name), displayName = name,
			difficulties = {"easy", "normal", "hard"}, icon = "face", color = Color.WHITE,
			previewStart = 5000, previewEnd = 15000, ratings = {}, bpm = 100,
			composer = "unknown", charter = "unknown", instrumental = ""
		}
	end}
	Highscore = {getCompletion = function() return 0 end, getRank = noop,
		getScore = function(song, difficulty)
		table.insert(freeplayFixtures.scoreRequests, {song = song, difficulty = difficulty})
		return 12345
	end}
	PlayState = setmetatable({loadSong = function(song, difficulty)
		PlayState.loaded = {songName = song, difficulty = difficulty}
	end}, {__call = function(_, _, song, difficulty) return {songName = song, difficulty = difficulty} end})
	MenuList.selectionCache = {}
	love.system.getDevice = function() return "Desktop" end
end
