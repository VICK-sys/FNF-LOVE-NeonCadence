local Setup = {}

function Setup.preload(self, PlayState)
	local skin = PlayState.SONG.skin or "default"
	if type(skin) == "string" then
		PlayState.SONG.skin = paths.getSkin(PlayState.SONG.skin or "default")
		skin = PlayState.SONG.skin
	end

	local function skinPath(type, name) return {type, skin:getPath(name, type)} end
	local song = paths.formatToSongPath(PlayState.SONG.song)
	local diff, async = PlayState.songDifficulty:lower(), paths.async

	local function getVocals(suffix, fallback, skip)
		local shortSuffix = suffix:match("^[^%-]*")
		return async.getVoices(song, suffix .. "-" .. diff)
			or async.getVoices(song, diff)
			or async.getVoices(song, shortSuffix .. "-" .. diff)
			or async.getVoices(song, shortSuffix)
			or async.getVoices(song, suffix)
			or (fallback and async.getVoices(song, fallback) or nil)
			or (not skip and async.getVoices(song, nil) or nil)
	end

	local p1, p2 = PlayState.SONG.player1, PlayState.SONG.player2
	local playerVocals, enemyVocals =
		getVocals(p1 or "Player", "Player"),
		getVocals(p2 or "Opponent", "Opponent", true)
	if not async.getInst(song, diff) then
		async.getInst(song)
	end

	local list = {
		skinPath("image", "ready"), skinPath("image", "set"), skinPath("image", "go"),
		skinPath("sound", "intro3"), skinPath("sound", "intro2"), skinPath("sound", "intro1"),
		skinPath("sound", "introGo"), {"sound", "hitsound"}
	}

	local path, sprite = "skins/" .. PlayState.SONG.skin.skin .. "/"
	for i, part in pairs(PlayState.SONG.skin.data) do
		sprite = part.sprite
		if part.skin then path = "skins/" .. part.skin .. "/" end
		if sprite then
			table.insert(list, {"image", path .. sprite})
		end
	end

	self.ratings = {
		{name = "sick", time = 0.045, score = 350, splash = true,  mod = 1},
		{name = "good", time = 0.090, score = 200, splash = false, mod = 0.7},
		{name = "bad",  time = 0.135, score = 100, splash = false, mod = 0.4, resetCombo = true},
		{name = "shit", time = -1,    score = 50,  splash = false, mod = 0,   resetCombo = true}
	}
	for _, rating in ipairs(self.ratings) do
		table.insert(list, skinPath("image", rating.name))
	end
	for i = 0, 9 do
		table.insert(list, skinPath("image", "num" .. i))
	end
	table.insert(list, skinPath("image", "healthBar"))
	table.insert(list, skinPath("image", "numnegative"))

	for i = 1, 3 do table.insert(list, {"sound", "gameplay/missnote" .. i}) end

	self.stage = Stage(PlayState.SONG.stage)
	for _, char in pairs({PlayState.SONG.gfVersion, PlayState.SONG.player2, PlayState.SONG.player1}) do
		if char and char ~= "" then
			local data = Parser.getCharacter(char)
			if data then
				local kind = "image"
				if paths.exists(paths.getPath(data.sprite .. "/Animation.json")) then kind = "animate" end
				table.insert(list, {kind, data.sprite})
				if data.animations and kind ~= "atlas" then
					for _, anim in pairs(data.animations) do
						local atlas = select(7, anim)
						if atlas then
							table.insert(list, {"image", atlas})
						end
					end
				end
				table.insert(list, {"image", "icons/" .. (data.icon or "face")})
			end
		end
	end
	paths.async.loadBatch(list)
end

function Setup.createScripts(self, PlayState, songName, conductor)
	self.scripts = ScriptsHandler()
	self.scripts:loadDirectory("data/scripts", "data/scripts/" .. songName, "songs/" .. songName)
	conductor.onTimeChange:add(function()
		self.scripts:set("bpm", conductor.bpm)
		self.scripts:set("crotchet", conductor.crotchet)
		self.scripts:set("stepCrotchet", conductor.stepCrotchet)
	end)
	conductor.onTimeChange:dispatch()

	self.events = table.clone(PlayState.SONG.events)
	self.eventScripts = {}

	local error
	for _, e in ipairs(self.events) do
		local scriptPath = "data/events/" .. e.e:gsub(" ", "-"):lower()
		if paths.exists(paths.getPath(scriptPath .. ".lua"), "file") then
			if not self.eventScripts[e.e] then
				self.eventScripts[e.e] = Script(scriptPath)
				self.scripts:add(self.eventScripts[e.e])
			end
		else
			if not error then
				error = "Events not found: "
			end
			if not error:find(e.e) then
				error = error .. e.e .. "; "
			end
		end
	end
	if error then Toast.error(error:sub(1, -3)) end

	self.scripts:call("create")
end

function Setup.createStage(self, PlayState)
	if not self.stage then
		self.stage = Stage(PlayState.SONG.stage)
	end

	self.stage:load()
	self:add(self.stage)
	if self.stage.script then self.scripts:add(self.stage.script) end
	self:add(self.stage.foreground)

	self.boyfriend, self.dad, self.gf =
		self.stage.boyfriend, self.stage.dad, self.stage.gf

	if self.boyfriend then self.scripts:add(self.boyfriend.script) end
	if self.gf then self.scripts:add(self.gf.script) end
	if self.dad then self.scripts:add(self.dad.script) end

	self.judgeSprites = Judgements(game.width / 3, 264, PlayState.SONG.skin)
	self:add(self.judgeSprites)
end

function Setup.createNotefields(self, PlayState, skin, playerVocals, enemyVocals)
	-- {field name, char, vocals, botplay, splash}
	self.notefields = {}
	local y, keys, speed = game.height / 2, 4, PlayState.SONG.speed
	local config = {
		{"player", self.boyfriend, playerVocals, ClientPrefs.data.botplayMode, true},
		{"enemy",  self.dad,       enemyVocals,  true},
	}
	for _, nf in ipairs(config) do
		local field, notes = nf[1] .. "Notefield", PlayState.SONG.notes[nf[1]]
		self[field] = Notefield(0, y, keys, skin, nf[2], nf[3], speed)
		local notefield = self[field]
		notefield.bot = nf[4]
		notefield.canSpawnSplash = nf[5] or false
		notefield.cameras = {self.camNotes}
		self:add(notefield)
		if notes then notefield:makeNotesFromChart(notes) end
		table.insert(self.notefields, notefield)
	end
	self:positionNotefields()
	table.insert(self.notefields, 3, {character = self.gf})

	if PlayState.canFadeInReceptors then
		for _, notefield in pairs(self.notefields) do
			if notefield.is then
				for _, receptor in ipairs(notefield.receptors) do
					receptor.alpha = 0
				end
			end
		end
	end

	local notefield
	for i, event in ipairs(self.events) do
		if event.t > 10 then
			break
		elseif event.e == "FocusCamera" then
			self:executeEvent(event)
			table.remove(self.events, i)
			break
		end
	end
end

function Setup.createHUD(self, skin)
	self.countdown = Countdown()
	self.countdown:screenCenter()
	self:add(self.countdown)

	local isPixel = skin.isPixel
	local event = self.scripts:event("onCountdownCreation",
		Events.CountdownCreation({}, isPixel and {x = 7, y = 7} or {x = 1, y = 1}, not isPixel))
	if not event.cancelled then
		self.countdown.data = #event.data == 0 and {
			{
				sound = skin:getPath("intro3", "sound"),
			},
			{
				sound = skin:getPath("intro2", "sound"),
				image = skin:getPath("ready", "image")
			},
			{
				sound = skin:getPath("intro1", "sound"),
				image = skin:getPath("set", "image")
			},
			{
				sound = skin:getPath("introGo", "sound"),
				image = skin:getPath("go", "image")
			}
		} or event.data
		self.countdown.scale = event.scale
		self.countdown.antialiasing = event.antialiasing
	end

	self.healthBar = HealthBar(self.boyfriend and self.boyfriend.icon or nil,
		self.dad and self.dad.icon or nil, skin)
	self.healthBar:screenCenter("x").y = game.height * (self.downScroll and 0.1 or 0.9)
	self:add(self.healthBar)

	self.scoreText = Text(0, 0, "", paths.getFont("vcr.ttf", 16), Color.WHITE, "right")
	self.scoreText.outline.width = 1
	self.scoreText.antialiasing = false
	self:add(self.scoreText)

	for _, o in ipairs({
		self.judgeSprites, self.countdown, self.healthBar, self.scoreText
	}) do o.cameras = {self.camHUD} end
end

return Setup
