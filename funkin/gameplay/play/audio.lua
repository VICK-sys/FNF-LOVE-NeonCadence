local Audio = {}

function Audio.loadMusic(self, songName, difficulty)
	if game.sound.music then game.sound.music:reset(true) end
	game.sound.loadMusic(paths.getInst(songName, difficulty, true)
		or paths.getInst(songName, nil, true))
	game.sound.music.looped = false
	game.sound.music.volume = ClientPrefs.data.musicVolume / 100
	game.sound.music.onComplete = bind(self, self.endSong)
end

function Audio.loadVocals(self, PlayState, songName, difficulty)
	local volume = ClientPrefs.data.vocalVolume / 100
	local function getVocals(char, fallback, n)
		local shortChar = char:match("^[^%-]*")
		local file = (paths.getVoices(songName, char .. "-" .. difficulty)
				or paths.getVoices(songName, shortChar .. "-" .. difficulty)
				or paths.getVoices(songName, difficulty)
				or paths.getVoices(songName, char, true)
				or paths.getVoices(songName, shortChar, true))
			or (fallback and paths.getVoices(songName, fallback, true) or nil)
			or (n and paths.getVoices(songName, nil))
		if file then
			local vocal = game.sound.load(file)
			vocal.volume, vocal.looped = volume, false
			return vocal
		end
	end

	local p1, p2 = self.boyfriend and self.boyfriend.voiceSuffix or self.SONG.player1,
		self.dad and self.dad.voiceSuffix or PlayState.SONG.player2
	local playerVocals = getVocals(p1 or "Player", "Player", true)
	local enemyVocals = getVocals(p2 or "Opponent", "Opponent") or playerVocals
	return playerVocals, enemyVocals
end

function Audio.setPlayback(self, playback)
	playback = playback or self.playback
	game.sound.music.pitch = playback

	local lastVocals
	for _, notefield in pairs(self.notefields) do
		if notefield.vocals and lastVocals ~= notefield.vocals then
			notefield.vocals.pitch = playback
			lastVocals = notefield.vocals
		end
	end
	lastVocals = nil

	self.playback = playback
	self.timer.timeScale = playback
	self.tween.timeScale = playback
end

function Audio.playSong(self, PlayState, daTime)
	self:updateDiscordRPC()
	self:setPlayback(self.playback)

	if daTime then game.sound.music.time = daTime end
	game.sound.music:play()

	local time, lastVocals = game.sound.music.time
	for _, notefield in pairs(self.notefields) do
		if notefield.vocals and lastVocals ~= notefield.vocals then
			notefield.vocals.time = time
			notefield.vocals:play()
			lastVocals = notefield.vocals
		end
	end
	lastVocals = nil
	PlayState.conductor:update(time * 1000)

	self.paused = false
end

function Audio.pauseSong(self)
	game.sound.music:pause()
	self:updateDiscordRPC(true)
	local lastVocals
	for _, notefield in pairs(self.notefields) do
		if notefield.vocals and lastVocals ~= notefield.vocals then
			notefield.vocals:pause()
			lastVocals = notefield.vocals
		end
	end
	lastVocals = nil

	self.paused = true
end

function Audio.resyncSong(self, PlayState)
	local time, rate = game.sound.music.time, math.max(self.playback, 1)
	if math.abs(time - self.conductor.time / 1000) > 0.015 * rate then
		PlayState.conductor:update(time * 1000)
	end
	local maxDelay, vocals, lastVocals = 0.009262 * rate
	for _, notefield in pairs(self.notefields) do
		vocals = notefield.vocals
		if vocals and lastVocals ~= vocals and vocals:isPlaying()
			and vocals.time > 0.8 and math.abs(time - vocals.time) > maxDelay then
			vocals:pause()
			vocals.time = time
			vocals:play()
			lastVocals = vocals
		end
	end
	lastVocals = nil
end

function Audio.updateDiscordRPC(self, PlayState, paused)
	if not Discord then return end

	local detailsText = "Freeplay"
	if PlayState.storyMode then detailsText = "Story Mode: " .. PlayState.storyWeek end

	local diff = PlayState.defaultDifficulty

	if paused then
		Discord.changePresence({
			details = "Paused - " .. detailsText,
			state = PlayState.SONG.song .. ' - [' .. diff .. ']'
		})
		return
	end

	if self.startingSong or not game.sound.music or not game.sound.music:isPlaying() then
		Discord.changePresence({
			details = detailsText,
			state = PlayState.SONG.song .. ' - [' .. diff .. ']'
		})
	else
		local startTimestamp = os.time() * 1000
		local endTimestamp = startTimestamp + game.sound.music.duration * 1000
		Discord.changePresence({
			details = detailsText,
			state = PlayState.SONG.song .. ' - [' .. diff .. ']',
			timestamps = {
				start = math.floor(startTimestamp),
				["end"] = math.floor(endTimestamp)
			}
		})
	end
end

return Audio
