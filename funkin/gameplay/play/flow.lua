local Flow = {}

function Flow.startCountdown(self, PlayState)
	if self.buttons then self:add(self.buttons) end

	local event = self.scripts:call("startCountdown")
	if event == Script.Event_Cancel then return end

	self:setPlayback(ClientPrefs.data.playback)

	if not PlayState.conductor then return end
	self.doCountdownAtBeats = PlayState.startPos / PlayState.conductor.crotchet - 4
	self.startedCountdown = true
	self.countdown.duration = PlayState.conductor.crotchet / 1000
	self.countdown.playback = 1

	self:fadeReceptors()
end

function Flow.fadeReceptors(self, PlayState)
	for _, notefield in pairs(self.notefields) do
		if notefield.is and PlayState.canFadeInReceptors then
			notefield:fadeInReceptors(self.tween)
		end
	end
	PlayState.canFadeInReceptors = false
end

function Flow.doCountdown(self, beat)
	if self.lastCountdownBeats == beat then return end
	self.lastCountdownBeats = beat

	if beat > #self.countdown.data then
		self.doCountdownAtBeats = nil
	else
		self.countdown:doCountdown(beat)
	end
end

function Flow.tryPause(self)
	local event = self.scripts:call("pause")
	if event ~= Script.Event_Cancel then
		game.camera:unfollow(false)
		game.camera:freeze()
		self.camNotes:freeze()
		self.camHUD:freeze()

		self:pauseSong()

		if self.buttons then self:remove(self.buttons) end

		local pause = PauseSubstate()
		pause.cameras = {self.camOther}
		self:openSubstate(pause)
	end
end

function Flow.tryGameOver(self)
	local event = self.scripts:event("onGameOver", Events.GameOver())
	if not event.cancelled then
		if self.buttons then self:remove(self.buttons) end

		GameOverSubstate.characterName = event.characterName
		GameOverSubstate.deathSoundName = event.deathSoundName
		GameOverSubstate.loopSoundName = event.loopSoundName
		GameOverSubstate.endSoundName = event.endSoundName
		GameOverSubstate.deaths = GameOverSubstate.deaths + 1

		local tween = Tween.tween(self, {playback = 0.001}, 1, {
			ease = Ease.quadOut,
			onUpdate = function() self:setPlayback() end
		})

		self.scripts:call("gameOverCreate")

		if GameOverSubstate.characterName ~= "" then
			local data = Parser.getCharacter(GameOverSubstate.characterName)
			if data and data.sprite then
				paths.async.getImage(data.sprite, function()
					if event.pauseSong then
						self:pauseSong()
					end
					self.paused = event.pauseGame
					tween:cancel()
					self:setPlayback(1)

					self.camHUD.visible, self.camNotes.visible = false, false
					if self.boyfriend then
						self.boyfriend.visible = false
					end
					self:openSubstate(GameOverSubstate(self.stage.boyfriendPos.x,
						self.stage.boyfriendPos.y))
					self.scripts:call("postGameOverCreate")
				end)
			end
		end

		self.isDead = true
	end
end

function Flow.endSong(self, PlayState, skip)
	if PlayState.storyMode and not skip then
		local name, type = PlayState.getCutscene(true)
		if name then
			self:executeCutscene(name, type, function()
				self:endSong(true)
			end)
			return
		end
	end
	PlayState.seenCutscene = false

	local event = self.scripts:call("endSong")
	if event == Script.Event_Cancel then return end

	game.sound.music:reset(true)
	for _, notefield in pairs(self.notefields) do
		if notefield.vocals then notefield.vocals:stop() end
	end

	if not self.usedBotPlay then
		Highscore.saveScore(PlayState.SONG.song, self.score, self.songDifficulty)
	end
	if self.chartingMode then
		game.switchState(ChartingState())
		return
	end

	if PlayState.storyMode then
		PlayState.canFadeInReceptors = false
		if not self.usedBotPlay then
			PlayState.storyScore = PlayState.storyScore + self.score
		end

		table.remove(PlayState.storyPlaylist, 1)
		if #PlayState.storyPlaylist > 0 then
			game.sound.music:stop()

			if Discord then
				local detailsText = "Freeplay"
				if PlayState.storyMode then detailsText = "Story Mode: " .. PlayState.storyWeek end

				Discord.changePresence({
					details = detailsText,
					state = 'Loading next song..'
				})
			end

			PlayState.loadSong(PlayState.storyPlaylist[1], PlayState.songDifficulty)
			self:resetState()
		else
			GameOverSubstate.deaths = 0
			PlayState.canFadeInReceptors = true
			if not self.usedBotPlay then
				Highscore.saveWeekScore(self.storyWeekFile, self.storyScore, self.songDifficulty)
			end

			local stickers = Stickers(nil, StoryMenuState())
			self:add(stickers)

			util.playMenuMusic()
		end
		Parser.clearCache()
	else
		GameOverSubstate.deaths = 0
		PlayState.canFadeInReceptors = true
		game.camera:unfollow()

		local stickers = Stickers(nil, FreeplayState())
		self:add(stickers)

		util.playMenuMusic()
	end
	controls:unbindPress(self.bindedKeyPress)
	controls:unbindRelease(self.bindedKeyRelease)
	game.sound.music.onComplete = nil
	self.skipResync = true

	self.scripts:call("postEndSong")
end

return Flow
