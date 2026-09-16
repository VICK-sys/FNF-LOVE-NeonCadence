local Input = {}
local PauseButton = require "funkin.gameplay.ui.pausebutton"

function Input.createControls(self, skin)
	if love.system.getDevice() == "Mobile" then
		local pad = ClientPrefs.data.margin
		local w, h = (game.width - pad * 2) / 4, game.height

		self.buttons = VirtualPadGroup()
		self.pauseButton = PauseButton(game.width - 130 - ClientPrefs.data.margin, 20, skin)
		self:add(self.pauseButton)
		self.buttons.cameras = {self.camOther}
		self.pauseButton.cameras = self.buttons.cameras

		local left = VirtualPad("left", pad, 0, w, h, Color.PURPLE)
		local down = VirtualPad("down", pad + w, 0, w, h, Color.BLUE)
		local up = VirtualPad("up", pad + w * 2, 0, w, h, Color.LIME)
		local right = VirtualPad("right", pad + w * 3, 0, w, h, Color.RED)

		self.buttons:add(left)
		self.buttons:add(down)
		self.buttons:add(up)
		self.buttons:add(right)
		self.buttons:set({
			fill = "line",
			lined = false,
			blend = "add",
			releasedAlpha = 0,
			config = {round = {0, 0}}
		})
	end
	if self.buttons then self.buttons:disable() end
end

function Input.updateShortcuts(self, PlayState)
	if self.startedCountdown then
		if controls:pressed("debug_1") then
			game.camera:unfollow()
			self:pauseSong()
			game.switchState(ChartingState())
		end

		if controls:pressed("debug_2") then
			game.camera:unfollow()
			game.sound.music:pause()
			self:pauseSong()
			CharacterEditor.onPlayState = true
			game.switchState(CharacterEditor())
		end

		if not self.isDead and controls:pressed("reset") then self:tryGameOver() end
	end

	if Project.DEBUG_MODE then
		if game.keys.justPressed.ONE then self.playerNotefield.bot = not self.playerNotefield.bot end
		if game.keys.justPressed.TWO then self:endSong() end
		if game.keys.justPressed.THREE and not self.startingSong then
			local time, vocals = (PlayState.conductor.time +
				PlayState.conductor.crotchet * (game.keys.pressed.SHIFT and 8 or 4)) / 1000
			self.skipConductor, PlayState.conductor.time = true, time * 1000
			game.sound.music.time = time
			for _, notefield in pairs(self.notefields) do
				vocals = notefield.vocals
				if vocals then vocals.time = time end
			end
		end
	end
end

function Input.onSettingChange(self, category, setting)
	game.camera.freezed = false
	self.camNotes.freezed = false
	self.camHUD.freezed = false

	if category == "gameplay" then
		switch(setting, {
			["downScroll"] = function()
				local downscroll = ClientPrefs.data.downScroll
				for _, notefield in pairs(self.notefields) do
					if notefield.is then notefield.downscroll = downscroll end
				end

				self.healthBar.y = game.height * (downscroll and 0.1 or 0.9)
				self:positionText()
				self.downScroll = downscroll
				self:positionNotefields()
			end,
			[{"middleScroll", "splitReceptors", "noteWidth", "splitWidth"}] = function()
				self.middleScroll = ClientPrefs.data.middleScroll
				self:positionNotefields()
			end,
			["botplayMode"] = function()
				self.playerNotefield.bot = ClientPrefs.data.botplayMode
				self:recalculateRating()
				self.usedBotplay = true
			end,
			["backgroundDim"] = function()
				self.camHUD.bgColor[4] = ClientPrefs.data.backgroundDim / 100
			end,
			["playback"] = function()
				self:setPlayback(ClientPrefs.data.playback)
			end
		})

		game.sound.music.volume = ClientPrefs.data.musicVolume / 100
		local volume, vocals = ClientPrefs.data.vocalVolume / 100
		for _, notefield in pairs(self.notefields) do
			vocals = notefield.vocals
			if vocals then vocals.volume = volume end
		end
	elseif category == "controls" then
		controls:unbindPress(self.bindedKeyPress)
		controls:unbindRelease(self.bindedKeyRelease)

		self.bindedKeyPress = bind(self, self.onKeyPress)
		controls:bindPress(self.bindedKeyPress)

		self.bindedKeyRelease = bind(self, self.onKeyRelease)
		controls:bindRelease(self.bindedKeyRelease)
	end

	self.scripts:call("onSettingChange", category, setting)
end

function Input.getKeyFromEvent(self, PlayState, controls)
	for _, control in pairs(controls) do
		local dir = PlayState.inputDirections[control]
		if dir ~= nil then return dir end
	end
	return -1
end

function Input.onKeyPress(self, key, type, scancode, isrepeat, time)
	if self.substate and not self.persistentUpdate then return end
	local controls = controls:getControlsFromSource(type .. ":" .. key)
	local ghostTap = ClientPrefs.data.ghostTap and self.ghostTime <= 0

	if not controls then return end
	key = self:getKeyFromEvent(controls)
	if key < 0 then return end

	local fixedKey, offset = key + 1,
		(time - self.lastTick) * game.sound.music:getActualPitch()
	for _, notefield in pairs(self.notefields) do
		if notefield.is and not notefield.bot then
			time = notefield.time + offset
			local hitNotes, hasSustain = notefield:getNotes(time, key)
			local l = #hitNotes

			if l == 0 then
				local receptor = notefield.receptors[fixedKey]
				if receptor then
					receptor:play(hasSustain and "confirm" or "pressed")
				end
				if not hasSustain and not ghostTap then
					self:miss(notefield, key)
				end
			else
				-- remove stacked notes (this is dedicated to spam songs)
				local i, firstNote, note = 2, hitNotes[1]
				while i <= l do
					note = hitNotes[i]
					if note and math.abs(note.time - firstNote.time) < 0.01 then
						notefield:removeNote(note)
					else
						break
					end
					i = i + 1
				end
				self:goodNoteHit(firstNote, time)
				self.ghostTime = 0.17
			end
		end
	end
end

function Input.onKeyRelease(self, key, type, scancode, time)
	if self.substate and not self.persistentUpdate then return end
	local controls = controls:getControlsFromSource(type .. ":" .. key)

	if not controls then return end
	key = self:getKeyFromEvent(controls)

	if key < 0 then return end

	local fixedKey = key + 1
	for _, notefield in pairs(self.notefields) do
		if notefield.is and not notefield.bot then
			self:resetStroke(notefield, key)
		end
	end
end

return Input
