---@class PlayState:State
local PlayState = State:extend("PlayState")
local Setup = require "funkin.gameplay.play.setup"
local Audio = require "funkin.gameplay.play.audio"
local Presentation = require "funkin.gameplay.play.presentation"
local Notes = require "funkin.gameplay.play.notes"
local Input = require "funkin.gameplay.play.input"
local Cutscene = require "funkin.gameplay.play.cutscene"
local Flow = require "funkin.gameplay.play.flow"

PlayState.defaultDifficulty = "normal"
PlayState.transIn = TransitionData(0.5)

PlayState.inputDirections = {
	note_left = 0,
	note_down = 1,
	note_up = 2,
	note_right = 3
}
PlayState.keysControls = {}
for control, key in pairs(PlayState.inputDirections) do
	PlayState.keysControls[key] = control
end

PlayState.SONG = nil
PlayState.songDifficulty = ""

PlayState.storyPlaylist = {}
PlayState.storyMode = false
PlayState.storyWeek = ""
PlayState.storyScore = 0
PlayState.storyWeekFile = ""

PlayState.seenCutscene = false
PlayState.canFadeInReceptors = true
PlayState.prevCamFollow = nil

-- Charting Stuff
PlayState.chartingMode = false
PlayState.startPos = 0

PlayState.setPlayback = Audio.setPlayback
PlayState.pauseSong = Audio.pauseSong
PlayState.positionNotefields = Presentation.positionNotefields
PlayState.positionText = Presentation.positionText
PlayState.getCameraPosition = Presentation.getCameraPosition
PlayState.cameraMovement = Presentation.cameraMovement
PlayState.getRating = Notes.getRating
PlayState.goodNoteHit = Notes.goodNoteHit
PlayState.goodSustainHit = Notes.goodSustainHit
PlayState.miss = Notes.miss
PlayState.recalculateRating = Notes.recalculateRating
PlayState.popUpScore = Notes.popUpScore
PlayState.resetStroke = Notes.resetStroke
PlayState.onSettingChange = Input.onSettingChange
PlayState.onKeyPress = Input.onKeyPress
PlayState.onKeyRelease = Input.onKeyRelease
PlayState.executeCutsceneEvent = Cutscene.executeCutsceneEvent
PlayState.doCountdown = Flow.doCountdown
PlayState.tryPause = Flow.tryPause
PlayState.tryGameOver = Flow.tryGameOver

function PlayState:preload()
	return Setup.preload(self, PlayState)
end

function PlayState:playSong(daTime)
	return Audio.playSong(self, PlayState, daTime)
end

function PlayState:resyncSong()
	return Audio.resyncSong(self, PlayState)
end

function PlayState:updateDiscordRPC(paused)
	return Audio.updateDiscordRPC(self, PlayState, paused)
end

function PlayState:getKeyFromEvent(controls)
	return Input.getKeyFromEvent(self, PlayState, controls)
end

function PlayState.getCutscene(isEnd)
	return Cutscene.getCutscene(PlayState, isEnd)
end

function PlayState:executeCutscene(name, type, onComplete)
	return Cutscene.executeCutscene(self, PlayState, name, type, onComplete)
end

function PlayState:startCountdown()
	return Flow.startCountdown(self, PlayState)
end

function PlayState:fadeReceptors()
	return Flow.fadeReceptors(self, PlayState)
end

function PlayState:endSong(skip)
	return Flow.endSong(self, PlayState, skip)
end

function PlayState.loadSong(song, diff)
	diff = diff or PlayState.defaultDifficulty
	PlayState.songDifficulty = diff

	PlayState.SONG = Parser.getChart(song, diff)

	return true
end

function PlayState:new(storyMode, song, diff)
	PlayState.super.new(self)

	if storyMode ~= nil then
		PlayState.storyMode = storyMode
		PlayState.storyWeek = ""
	end

	if song ~= nil then
		if storyMode and type(song) == "table" and #song > 0 then
			PlayState.storyPlaylist = song
			song = song[1]
		end
		if not PlayState.loadSong(song, diff) then
			setmetatable(self, TitleState)
			TitleState.new(self)
		end
	end
end

function PlayState:enter()
	if PlayState.SONG == nil then PlayState.loadSong("test") end

	local songName = paths.formatToSongPath(PlayState.SONG.song)

	if type(PlayState.SONG.skin) == "string" then
		PlayState.SONG.skin = paths.getSkin(PlayState.SONG.skin or "default")
	end
	local skin = PlayState.SONG.skin

	local difficulty = PlayState.songDifficulty:lower()
	Audio.loadMusic(self, songName, difficulty)

	local conductor = Conductor(PlayState.SONG.timeChanges)
	conductor.time = self.startPos - conductor.crotchet * 5
	conductor.onStep:add(bind(self, self.step))
	conductor.onBeat:add(bind(self, self.beat))
	conductor.onMeasure:add(bind(self, self.measure))
	PlayState.conductor = conductor

	self.skipConductor = false

	Note.defaultSustainSegments = 3
	NoteModifier.reset()

	self.timer = TimerManager()
	self.tween = Tween()
	self.camPosTween = nil

	if Discord then self:updateDiscordRPC() end

	self.startingSong = true
	self.startedCountdown = false
	self.doCountdownAtBeats = nil
	self.lastCountdownBeats = nil

	self.isDead = false

	self.usedBotPlay = ClientPrefs.data.botplayMode
	self.downScroll = ClientPrefs.data.downScroll
	self.middleScroll = ClientPrefs.data.middleScroll
	self.playback = 1
	self.timer.timeScale = 1
	self.tween.timeScale = 1

	Presentation.createCameras(self)

	self.ghostTime = 0

	Setup.createScripts(self, PlayState, songName, conductor)

	Setup.createStage(self, PlayState)

	Presentation.prepareCamera(self, PlayState, conductor)

	local playerVocals, enemyVocals = Audio.loadVocals(self, PlayState, songName, difficulty)

	Setup.createNotefields(self, PlayState, skin, playerVocals, enemyVocals)

	Setup.createHUD(self, skin)

	self.ratingNeedsRecalc = false
	self.score = 0
	self.combo = 0
	self.misses = 0
	self.health = 1
	for _, r in ipairs(self.ratings) do
		self[r.name .. "s"] = 0
	end

	Input.createControls(self, skin)

	self.lastTick = love.timer.getTime()

	self.bindedKeyPress = bind(self, self.onKeyPress)
	controls:bindPress(self.bindedKeyPress)

	self.bindedKeyRelease = bind(self, self.onKeyRelease)
	controls:bindRelease(self.bindedKeyRelease)

	if self.downScroll then
		for _, notefield in pairs(self.notefields) do
			if notefield.is then notefield.downscroll = true end
		end
	end
	self:positionText()

	if self.buttons then self:add(self.buttons) end

	if PlayState.storyMode and not PlayState.seenCutscene then
		local name, type = PlayState.getCutscene()
		if name then
			self:executeCutscene(name, type, function(event)
				local skipCountdown = event and event.params[1] or false
				if skipCountdown then
					self:startSong(self.startPos)
					self:fadeReceptors()
				else
					self:startCountdown()
				end
			end)
		else
			self:startCountdown()
		end
	else
		self:startCountdown()
	end
	self:recalculateRating()

	PlayState.super.enter(self)
	collectgarbage()

	self.scripts:call("postCreate")

	game.camera:follow(self.camFollow, nil, 2.4 * self.camSpeed)
	game.camera:snapToTarget()

	self.lastSongTime = 0

	self:update(0)
end

function PlayState:step(s)
	if self.skipConductor then return end

	if not self.startingSong then
		self:resyncSong()
	end

	self.scripts:set("curStep", s)
	self.scripts:call("step", s)
	self.scripts:call("postStep", s)
end

function PlayState:beat(b)
	if self.skipConductor then return end

	self.scripts:set("curBeat", b)
	self.scripts:call("beat", b)

	local character
	for _, notefield in pairs(self.notefields) do
		character = notefield.character
		if character then character:beat(b) end
	end

	local val, healthBar = 1.2, self.healthBar
	healthBar.iconScale = val
	if healthBar.iconP1 then
		healthBar.iconP1:setScale(val)
	end
	if healthBar.iconP2 then
		healthBar.iconP2:setScale(val)
	end

	if --[[ClientPrefs.data.zoomCamera and]] game.camera.zoom < 1.35 and
		self.zoomRate > 0 and self.conductor.currentBeat % self.zoomRate == 0 then
		self.camZoomMult = self.camZoomIntensity
		self.camHUD.zoom = 1 + self.hudZoomIntensity
	end

	self.scripts:call("postBeat", b)
end

function PlayState:measure(m)
	if self.skipConductor then return end

	self.scripts:set("curMeasure", m)
	self.scripts:call("measure", m)

	self.scripts:call("postMeasure", m)
end

function PlayState:focus(f)
	self.scripts:call("focus", f)
	if Discord and love.autoPause then self:updateDiscordRPC(not f) end
	self.scripts:call("postFocus", f)
end

function PlayState:executeEvent(event)
	if self.eventScripts[event.e] then
		self.eventScripts[event.e]:call("event", event)
	end
	self.scripts:call("onEvent", event)
end

function PlayState:pushEvent(name, params)
	if params == nil then
		Logger.log("error", "pushEvent: argument 2 must be the event parameter(s).")
		return
	end

	local path = "data/events/" .. name:gsub(" ", "-"):lower()
	if not self.eventScripts[name] then
		self.eventScripts[name] = Script(path)
		self.scripts:add(self.eventScripts[name])
	end

	self:executeEvent({e = name, v = params})
end

function PlayState:resetState()
	self.load = LoadScreen(getmetatable(game.getState())())
	self.load.cameras = {self.camOther}
	self:add(self.load)
end

function PlayState:update(dt)
	if game.keys.justPressed.F5 then
		self:resetState()
	end
	if self.load then
		self.load:update(dt)
		if paths.async.getProgress() == 1 then
			local state = self.load.nextState
			state.skipTransIn = true
			self.skipTransOut = true
			game.switchState(state)
		end
		return
	end

	if not self.paused and game.sound.music:isPlaying() and not self.skipResync then
		if dt > 1 / 18 then
			self:playSong(math.max(0, self.lastSongTime - dt / 2))
			return
		end
		self.lastSongTime = game.sound.music.time
	end

	if self.ghostTime > 0 then self.ghostTime = self.ghostTime - dt end

	self.timer:update(dt)
	self.tween:update(dt)

	dt = dt * self.playback
	self.lastTick = love.timer.getTime()

	if self.startedCountdown then
		local time = PlayState.conductor.time + 1000 * dt
		PlayState.conductor:update(time)
		if self.skipConductor then self.skipConductor = false end

		if self.startingSong and PlayState.conductor.time >= self.startPos then
			self.startingSong = false

			self:playSong(self.startPos)
			PlayState.conductor.time = self.startPos
			self.scripts:call("songStart")
		else
			local noFocus, events, e = true, self.events
			while events[1] do
				e = events[1]
				if e.t <= game.sound.music.time * 1000 then
					self:executeEvent(e)
					table.remove(events, 1)
					if e.e == "FocusCamera" then noFocus = false end
				else
					break
				end
			end
			if noFocus and self.camTarget and game.camera.followLerp then
				self:cameraMovement(self:getCameraPosition(self.camTarget))
			end
		end

		if self.startingSong and self.doCountdownAtBeats then
			self:doCountdown(math.floor(
				PlayState.conductor.currentBeatFloat - self.doCountdownAtBeats + 1
			))
		end
	end

	self.scripts:call("update", dt)
	PlayState.super.update(self, dt)

	Notes.update(self, PlayState)

	if self.ratingNeedsRecalc then
		self:recalculateRating()
		self.ratingNeedsRecalc = false
	end

	Presentation.update(self, dt)

	if self.startedCountdown and controls:pressed("pause") then
		self:tryPause()
	end

	self.healthBar.value = util.coolLerp(self.healthBar.value, self.health, 15, dt)
	if not self.isDead and self.health <= 0 then self:tryGameOver() end

	Input.updateShortcuts(self, PlayState)

	self.scripts:call("postUpdate", dt)
end

function PlayState:draw()
	self.scripts:call("draw")
	PlayState.super.draw(self)
	self.scripts:call("postDraw")
end

function PlayState:closeSubstate()
	self.scripts:call("substateClosed")
	PlayState.super.closeSubstate(self)

	game.camera:unfreeze()
	self.camNotes:unfreeze()
	self.camHUD:unfreeze()

	game.camera.target = self.camFollow

	if not self.startingSong then
		self:playSong()
		if Discord then self:updateDiscordRPC() end
	end

	if self.buttons then self:add(self.buttons) end

	self.scripts:call("postSubstateClosed")
end

function PlayState:leave()
	self.scripts:call("leave")

	PlayState.prevCamFollow = self.camFollow
	PlayState.conductor:destroy()
	PlayState.conductor = nil

	controls:unbindPress(self.bindedKeyPress)
	controls:unbindRelease(self.bindedKeyRelease)
	Parser.clearCache()

	self.scripts:call("postLeave")
	self.scripts:close()
end

return PlayState
