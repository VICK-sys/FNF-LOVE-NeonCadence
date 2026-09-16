local Capsule = require "funkin.ui.freeplay.capsule"
local Backdrop = require "funkin.ui.freeplay.backdrop"

local FreeplayState = State:extend("FreeplayState")
FreeplayState.curDifficulty = 2
FreeplayState.preferredDifficulty = "normal"
FreeplayState.lastSong = "tutorial"

local filters = {"all", "A-B", "C-D", "E-H", "I-L", "M-N", "O-R", "S", "T", "U-Z", "#", "favorites"}

local function difficultyIndex(diffs, preferred)
	for i, diff in ipairs(diffs) do
		if diff:lower() == preferred:lower() then return i end
	end
	for i, diff in ipairs(diffs) do
		if diff:lower() == "normal" then return i end
	end
	return 1
end

function FreeplayState:enter()
	Parser.clearCache()
	self.skipTransIn = true
	self.notCreated = false
	self.script = Script("data/states/freeplay", false, false, false, self)
	if self.script:call("create") == Script.Event_Cancel then
		FreeplayState.super.enter(self)
		self.notCreated = true
		self.script:call("postCreate")
		return
	end

	-- Update Presence
	if Discord then
		Discord.changePresence({details = "In the Menus", state = "Freeplay Menu"})
	end

	self.persistentUpdate, self.persistentDraw = true, true
	if self.parent then
		self.freeplayCamera = game.cameras.add(Camera(), false)
		self.cameras = {self.freeplayCamera}
	end
	self.lerpScore, self.intendedScore = 0, 0
	self.lerpCompletion, self.intendedCompletion = 0, 0
	self.difficultyIds = {"easy", "normal", "hard", "erect", "nightmare"}
	self.layoutScale = math.min(game.width / 1280, game.height / 720)
	self.layoutX = (game.width - 1280 * self.layoutScale) / 2
	self.filter, self.filterIndex = "all", 1
	self.previewEnabled = true
	self.favoriteNamespace = Mods.currentMod or "__base"
	game.save.data.freeplayFavorites = game.save.data.freeplayFavorites or {}
	local favorites = game.save.data.freeplayFavorites
	favorites[self.favoriteNamespace] = favorites[self.favoriteNamespace] or {}
	self.favorites = favorites[self.favoriteNamespace]
	self.entries = {}
	self:loadSongs()

	self.bg = Backdrop(self)
	self:add(self.bg)
	self.songs = MenuList(paths.getSound("scrollMenu"), false, function(list, row, dt, time)
		local index = row.target + 1
		local x = (270 + 60 * math.sin(index)) * self.layoutScale + self.layoutX
		local y = (120 + index * 115.6 + (index < 0 and -150 or index > 4 and 10 or 0)) * self.layoutScale
		if time == 0 and self.bg.ready == false then x = 1280 * self.layoutScale + self.layoutX end
		if row.setEntrance then row:setEntrance(self.bg.time or 1) end
		if self.exitDelay then
			x = x + 1280 * self.layoutScale * math.min(1, ((0.5 - self.exitDelay) / 0.5) ^ 3)
		end
		row.x = time == 0 and x or x + (row.x - x) * 0.01 ^ (dt / 0.256)
		row.y = time == 0 and y or y + (row.y - y) * 0.01 ^ (dt / 0.192)
	end, function(list, row)
		row:setSelected(row.target == 0)
	end)
	self.songs.changeCallback = function()
		self:changeDiff(0)
		self:schedulePreview()
		if self.bg.onSelectionChanged then self.bg:onSelectionChanged() end
	end
	self.songs.selectCallback = bind(self, self.openSong)
	self:add(self.songs)
	if self.bg.createOverlay then self:add(self.bg:createOverlay()) end
	self:rebuildSongs(FreeplayState.lastSong)

	self.throttles = {
		left = Throttle:make({controls.down, controls, "ui_left"}),
		right = Throttle:make({controls.down, controls, "ui_right"})
	}
	if love.system.getDevice() == "Mobile" then
		self.buttons = util.createButtons("lrudab")
		self.buttons:add(VirtualPad("f", game.width - 90, 120, 80, 80))
		self.buttons:add(VirtualPad("q", game.width - 180, 120, 80, 80))
		self.buttons:add(VirtualPad("e", game.width - 270, 120, 80, 80))
		self:add(self.buttons)
	end
	if game.sound.music then game.sound.music:pause() end
	FreeplayState.super.enter(self)
	self.script:call("postCreate")
end

function FreeplayState:loadSongs()
	local func = Mods.currentMod and paths.getMods or function(...)
		return paths.getPath(..., false)
	end
	local seen = {}
	local levels = {}
	for _, file in ipairs(paths.getItems("data/weeks/weeks", "file", "json",
		not Mods.currentMod, true, Mods.currentMod)) do
		local id = file:gsub("%.json$", "")
		local data = paths.getJSON("data/weeks/weeks/" .. id)
		if data then
			local title = data.capsule and data.capsule.name or data.capsuleTitle
				or id:gsub("(%l)(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2"):gsub("[_%-]", " ")
			for _, song in ipairs(data.songs or {}) do
				local name = type(song) == "table" and song[1] or song
				if type(name) == "string" then
					levels[paths.formatToSongPath(name)] = {name = title, offsets = data.capsule and data.capsule.offsets}
				end
			end
		end
	end
	local function addSong(name)
		if type(name) == "table" then name = name[1] end
		if type(name) ~= "string" then return end
		name = name:match("^%s*(.-)%s*$")
		if name == "" then return end
		local meta = Parser.getMeta(name)
		if not meta or seen[meta.song] then return end
		local diffs, diffSeen = {}, {}
		for _, diff in ipairs(type(meta.difficulties) == "table" and meta.difficulties or {}) do
			if type(diff) == "string" and diff ~= "" and not diffSeen[diff:lower()] then
				diffs[#diffs + 1] = diff
				diffSeen[diff:lower()] = true
			end
		end
		if #diffs == 0 then return end
		seen[meta.song] = true
		local level = levels[meta.song]
		self.entries[#self.entries + 1] = {
			songName = meta.song, displayName = meta.displayName, diffs = diffs, meta = meta,
			weekName = level and level.name, weekOffsets = level and level.offsets
		}
		for _, diff in ipairs(diffs) do
			local exists = false
			for _, id in ipairs(self.difficultyIds) do if id == diff:lower() then exists = true; break end end
			if not exists then self.difficultyIds[#self.difficultyIds + 1] = diff:lower() end
		end
	end
	local listData
	if paths.exists(func("data/freeplayList.txt"), "file") then
		listData = paths.getText("freeplayList")
	elseif paths.exists(func("data/freeplaySonglist.txt"), "file") then
		listData = paths.getText("freeplaySonglist")
	end
	if listData then
		for line in (listData .. "\n"):gmatch("([^\n]*)\n") do addSong(line) end
		return
	end
	local weeks = {}
	if paths.exists(func("data/weekList.txt"), "file") then
		for line in ((paths.getText("weekList") or "") .. "\n"):gmatch("([^\n]*)\n") do
			line = line:match("^%s*(.-)%s*$")
			if line ~= "" then weeks[#weeks + 1] = line end
		end
	else
		for _, name in ipairs(paths.getItems("data/weeks/weeks", "file", "json",
			not Mods.currentMod, true, Mods.currentMod)) do
			weeks[#weeks + 1] = name:gsub("%.json$", "")
		end
		table.sort(weeks)
	end
	for _, week in ipairs(weeks) do
		local data = paths.getJSON("data/weeks/weeks/" .. week)
		if data and not data.hide_fm then
			for _, song in ipairs(data.songs or {}) do addSong(song) end
		end
	end
end

function FreeplayState:matchesFilter(entry)
	if self.filter == "all" then return true end
	if self.filter == "favorites" then return self.favorites[entry.songName] == true end
	local first = entry.displayName:upper():sub(1, 1)
	if self.filter == "#" then return not first:match("[A-Z]") end
	local low, high = self.filter:sub(1, 1), self.filter:sub(-1)
	return first >= low and first <= high
end

function FreeplayState:rebuildSongs(preferredSong)
	for _, row in ipairs(self.songs.members) do row:destroy() end
	self.songs:clear()
	self.filteredEntries = {}
	local diffs, seen = {}, {}
	for _, entry in ipairs(self.entries) do
		if self:matchesFilter(entry) then
			self.filteredEntries[#self.filteredEntries + 1] = entry
			for _, diff in ipairs(entry.diffs) do
				if not seen[diff:lower()] then
					diffs[#diffs + 1], seen[diff:lower()] = diff, true
				end
			end
		end
	end
	if self.filter ~= "all" and self.filter ~= "favorites" then
		table.sort(self.filteredEntries, function(a, b)
			return a.displayName:lower() < b.displayName:lower()
		end)
	end
	local selected = 1
	if #self.filteredEntries > 0 then
		self.songs:add(Capsule({displayName = "Random", isRandom = true, diffs = diffs, meta = {}}))
		for _, entry in ipairs(self.filteredEntries) do
			local row = Capsule(entry)
			row.favorite = self.favorites[entry.songName] == true
			self.songs:add(row)
			if entry.songName == preferredSong then selected = #self.songs.members end
		end
	end
	for _, row in ipairs(self.songs.members) do row.scale:set(self.layoutScale, self.layoutScale) end
	self.songs.curSelected = selected
	self.songs:changeSelection(0, true)
	self.songs:updatePositions(0, 0)
	if #self.songs.members == 0 then
		self.intendedScore, self.difficulty = 0, nil
		self.intendedCompletion = 0
		self:stopPreview()
	end
end

function FreeplayState:changeFilter(change)
	local selected = self.songs:getSelected()
	self.filterIndex = (self.filterIndex - 1 + change) % #filters + 1
	self.filter = filters[self.filterIndex]
	self:rebuildSongs(selected and selected.songName)
	util.playSfx(paths.getSound("scrollMenu"))
end

function FreeplayState:toggleFavorite()
	local song = self.songs:getSelected()
	if not song or song.isRandom then return end
	self.favorites[song.songName] = not self.favorites[song.songName] or nil
	song.favorite = self.favorites[song.songName] == true
	game.save.bind("funkin")
	util.playSfx(paths.getSound("scrollMenu"))
	if self.filter == "favorites" then self:rebuildSongs(song.songName) end
end

function FreeplayState:changeDiff(change)
	local song = self.songs:getSelected()
	if not song or #song.diffs == 0 then return end
	local index = difficultyIndex(song.diffs, FreeplayState.preferredDifficulty)
	self.difficultyDirection = change or 0
	if change and change ~= 0 then
		index = ((FreeplayState.curDifficulty or index) - 1 + change) % #song.diffs + 1
		FreeplayState.preferredDifficulty = song.diffs[index]:lower()
		util.playSfx(paths.getSound("scrollMenu"))
	end
	if self.bg.onSelectionChanged then self.bg:onSelectionChanged() end
	FreeplayState.curDifficulty = index
	self.difficulty = song.diffs[index]
	self.intendedScore = song.isRandom and 0 or Highscore.getScore(song.songName, self.difficulty)
	self.intendedCompletion = song.isRandom and 0 or Highscore.getCompletion(song.songName, self.difficulty)
	FreeplayState.lastSong = song.songName
	for _, row in ipairs(self.songs.members) do
		row:setDifficulty(self.difficulty)
		row:setRank(not row.isRandom and Highscore.getRank(row.songName, self.difficulty) or nil)
	end
end

function FreeplayState:openSong(song)
	if not song or self.launching then return end
	local selected = song
	local diff = self.difficulty
	if song.isRandom then
		local candidates = {}
		for _, entry in ipairs(self.filteredEntries) do
			for _, available in ipairs(entry.diffs) do
				if available:lower() == diff:lower() then candidates[#candidates + 1] = entry; break end
			end
		end
		if #candidates == 0 then return end
		song = candidates[love.math.random(#candidates)]
	end
	diff = song.diffs[difficultyIndex(song.diffs, diff or FreeplayState.preferredDifficulty)]
	self.launching, self.songs.lock = true, true
	FreeplayState.lastSong = song.songName
	self:stopPreview()
	util.playSfx(paths.getSound("confirmMenu"))
	if game.keys.pressed.SHIFT then
		PlayState.storyMode, PlayState.META = false, song.meta
		PlayState.loadSong(song.songName, diff)
		PlayState.storyDifficulty = diff
		if self.parent then self.parent.skipTransOut = true end
		game.switchState(ChartingState())
	else
		self.pendingSong, self.pendingDifficulty, self.launchDelay = song, diff, 1.2
		if self.bg.startConfirm then self.bg:startConfirm() end
		if selected.confirm then selected:confirm() end
	end
end

function FreeplayState:schedulePreview()
	self:stopPreview()
	if self.previewEnabled then self.previewDelay = 0.25 end
end

function FreeplayState:stopPreview()
	self.previewDelay = nil
	if self.previewSource then
		if game.sound.music and game.sound.music._source == self.previewSource then
			game.sound.music:cleanup()
		end
		self.previewSource:stop()
		self.previewSource:release()
		self.previewSource = nil
	end
end

function FreeplayState:updatePreview(dt)
	if self.previewDelay then
		self.previewDelay = self.previewDelay - dt
		if self.previewDelay > 0 then return end
		self.previewDelay = nil
		local song = self.songs:getSelected()
		if not song then return end
		local source
		local ok = pcall(function()
			if song.isRandom then
				source = paths.getMusic("freeplayRandom")
			else
				local suffix = song.meta.instrumental
				source = paths.getInst(song.songName, suffix ~= "" and suffix or nil, true)
			end
			if source then self.previewSource = source:clone() end
		end)
		if not ok or not self.previewSource then self:stopPreview(); return end
		local duration = self.previewSource:getDuration()
		local startTime = math.max(0, (tonumber(song.meta.previewStart) or 0) / 1000)
		local endTime = (tonumber(song.meta.previewEnd) or 15000) / 1000
		if startTime >= duration then startTime = 0 end
		if endTime <= startTime then endTime = startTime + 15 end
		self.previewStart = startTime
		self.previewEnd = song.isRandom and duration or math.min(duration, endTime)
		local music = game.sound.playMusic(self.previewSource, 0, true)
		music.time = self.previewStart
		music:fade(0.25, 0, ClientPrefs.data.menuMusicVolume / 100)
	end
	if self.previewSource and game.sound.music and game.sound.music._source == self.previewSource
		and game.sound.music.time >= self.previewEnd then
		game.sound.music.time = self.previewStart
	end
end

function FreeplayState:update(dt)
	self.script:call("update", dt)
	if self.notCreated then
		FreeplayState.super.update(self, dt)
		self.script:call("postUpdate", dt)
		return
	end
	self.songs.lock = self.launching or self.exitDelay ~= nil or self.bg.ready == false
	if not self.songs.lock then
		if controls:pressed("back") then
			self.songs.lock = true
			self:stopPreview()
			util.playSfx(paths.getSound("cancelMenu"))
			self.exitDelay = 0.5
			if self.parent then self.parent.persistentDraw = true end
			if self.bg.startExit then self.bg:startExit() end
		else
			if self.throttles.left:check() then self:changeDiff(-1) end
			if self.throttles.right:check() then self:changeDiff(1) end
			if game.keys.justPressed.F then self:toggleFavorite() end
			if game.keys.justPressed.Q then self:changeFilter(-1) end
			if game.keys.justPressed.E then self:changeFilter(1) end
			if game.keys.justPressed.P then
				self.previewEnabled = not self.previewEnabled
				self:schedulePreview()
			end
			if game.mouse.wheel ~= 0 then self.songs:changeSelection(-game.mouse.wheel) end
			if game.keys.justPressed.HOME then self.songs:setSelection(1) end
			if game.keys.justPressed.END then self.songs:setSelection(#self.songs.members) end
		end
	end
	FreeplayState.super.update(self, dt)
	if self.parent and self.bg.ready and not self.exitDelay then self.parent.persistentDraw = false end
	self.lerpScore = util.coolLerp(self.lerpScore, self.intendedScore, 24, dt)
	if math.abs(self.lerpScore - self.intendedScore) <= 10 then self.lerpScore = self.intendedScore end
	self.lerpCompletion = util.coolLerp(self.lerpCompletion, self.intendedCompletion, 24, dt)
	if math.abs(self.lerpCompletion - self.intendedCompletion) <= 0.001 then self.lerpCompletion = self.intendedCompletion end
	if not self.songs.lock then self:updatePreview(dt) end
	if self.launchDelay then
		self.launchDelay = self.launchDelay - dt
		if self.launchDelay <= 0 then
			self.launchDelay = nil
			self.skipTransOut = true
			if self.parent then self.parent.skipTransOut = true end
			PlayState.storyMode, PlayState.META = false, self.pendingSong.meta
			game.switchState(LoadState(PlayState(nil, self.pendingSong.songName, self.pendingDifficulty)))
		end
	elseif self.exitDelay then
		self.exitDelay = self.exitDelay - dt
		if self.exitDelay <= 0 then
			self.exitDelay = nil
			self.skipTransOut = true
			util.playMenuMusic(true)
			if self.parent then self.parent:closeSubstate()
			else game.switchState(MainMenuState()) end
		end
	end
	self.script:call("postUpdate", dt)
end

function FreeplayState:draw()
	if self.parent and self.parent.persistentDraw then self.parent:draw() end
	FreeplayState.super.draw(self)
end

function FreeplayState:leave()
	self.script:call("leave")
	self:stopPreview()
	for _, throttle in pairs(self.throttles or {}) do throttle:destroy() end
	if self.songs then
		for _, throttle in pairs(self.songs.throttles or {}) do throttle:destroy() end
	end
	self.throttles = nil
	if self.freeplayCamera then
		if self.freeplayCamera.exists then game.cameras.remove(self.freeplayCamera) end
		self.freeplayCamera, self.cameras = nil, nil
	end
	self.script:call("postLeave")
	self.script:close()
end

return FreeplayState
