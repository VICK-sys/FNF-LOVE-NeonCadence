local Notes = {}

function Notes.update(self, PlayState)
	local time = PlayState.conductor.time / 1000
	local missOffset = time - Note.safeZoneOffset / 1.25
	local shouldRecalculateRating = false
	for _, nf in pairs(self.notefields) do
		if not nf.is then goto continue end
		nf.time, nf.beat = time, PlayState.conductor.currentBeatFloat
		local isPlayer, isPNF, sustainOffset = not nf.bot, nf == self.playerNotefield, 0.25 / nf.speed

		for _, note in ipairs(nf:getNotes(time, nil, true)) do
			local hasInput = not isPlayer or controls:down(PlayState.keysControls[note.direction])
			local char = note.character or (note.gf and self.gf or nf.character)

			if note.wasGoodHit then
				if not note.lastPress or hasInput then note.lastPress = time end

				if not note.wasGoodSustainHit then
					if hasInput and isPNF then
						if not note.__lastScoreTime then note.__lastScoreTime = note.time end

						local currentCap = math.min(time, note.time + note.sustainTime)
						if currentCap > note.__lastScoreTime then
							local diff = currentCap - note.__lastScoreTime
							if diff > 0 and not PlayState.practiceMode then
								self.score = self.score + math.floor(diff * 300)

								self.ratingNeedsRecalc = true
								note.__lastScoreTime = currentCap
							end
						end
					end

					local noteEnd = note.time + note.sustainTime
					if noteEnd - sustainOffset <= note.lastPress then
						local fullHeld = noteEnd <= note.lastPress
						if fullHeld then
							note.wasFullSustainHit = true
						end
						if fullHeld or not hasInput then
							self:goodSustainHit(note, time, fullHeld)
							if hasInput and not isPlayer and char then
								char.lastHit = PlayState.conductor.time
							end
						end
					elseif not hasInput and isPlayer and note.time <= time then
						self:goodSustainHit(note, time)
						note.tooLate = true
					elseif not isPlayer and hasInput and char then
						char.lastHit = PlayState.conductor.time
					end
				end
			elseif isPlayer then
				if not note.wasGoodSustainHit and (note.lastPress or note.time) <= missOffset then
					self:miss(note)
				end
			elseif note.time <= time then
				self:goodNoteHit(note, time)
			end
		end
		::continue::
	end
end

function Notes.getRating(self, a, b)
	local diff = math.abs(a - b)
	for _, r in ipairs(self.ratings) do
		if diff <= (r.time < 0 and Note.safeZoneOffset or r.time) then return r end
	end
end

function Notes.goodNoteHit(self, note, time)
	local rating = self:getRating(note.time, time)
	self.scripts:call("goodNoteHit", note, rating)

	local notefield, dir, isSustain =
		note.parent, note.direction, note.sustain
	local event = self.scripts:event("onNoteHit",
		Events.NoteHit(notefield, note,
			note.character or (note.gf and self.gf or notefield.character), rating))

	if not event.cancelled and not note.wasGoodHit then
		note.wasGoodHit = true

		if event.unmuteVocals then
			local vocals = notefield.vocals
			if vocals then vocals.volume = ClientPrefs.data.vocalVolume / 100 end
		end

		local char = event.character
		if char and not event.cancelledAnim then
			char.waitReleaseAfterSing = not notefield.bot
			local type, lastsus = note.type ~= "alt" and nil or note.type, notefield.lastSustain
			local sustime = lastsus and lastsus.sustainTime or 0
			if (not lastsus or sustime <= 0 or note.sustainTime > sustime or
					(time - lastsus.time) / sustime >= 0.5) then
				char:sing(dir, type)
				notefield.lastSustain = note
			end
		end

		if not isSustain then
			notefield:removeNote(note)
		elseif rating.mod < 0.5 then
			note:ghost()
		end

		local receptor = notefield.receptors[dir + 1]
		if receptor then
			if not event.strumGlowCancelled and not note.strumGlowCancelled then
				receptor:play("confirm", true)
				if not note.sustain then receptor.holdTime = notefield.bot and 0.15 or 0.25 end
				if ClientPrefs.data.noteSplash and notefield.canSpawnSplash and rating.splash then
					receptor:spawnSplash()
				end
			end
			if isSustain and not event.coverSpawnCancelled and not note.coverSpawnCancelled then
				receptor:spawnCover(note)
			end
		end

		if self.playerNotefield == notefield then
			self.health = math.clamp(self.health + 0.023, 0, 2)
			self.score = self.score + rating.score
			if rating.resetCombo and self.gf then
				local drop = self.gf:getDropAnim(self.combo)
				if drop then self.gf:playAnim(drop, true, nil, true) end
			end

			self.combo = (rating.resetCombo and math.min(self.combo, 0) - 1 or
				math.max(self.combo, 0) + 1)

			if self.gf and self.gf:hasAnim("combo" .. self.combo) then
				self.gf:playAnim("combo" .. self.combo, false, nil, true)
				self.gf.lastHit = notefield.time * 1000
			end

			self:recalculateRating(rating.name)

			local hitSoundVolume = ClientPrefs.data.hitSound
			if hitSoundVolume > 0 then
				game.sound.play(paths.getSound("hitsound"), hitSoundVolume / 100)
			end
		end
	end

	self.scripts:call("postGoodNoteHit", note, rating)
end

function Notes.goodSustainHit(self, note, time, fullyHeldSustain)
	self.scripts:call("goodSustainHit", note)

	local notefield, dir, fullScore =
		note.parent, note.direction, fullyHeldSustain ~= nil
	local event = self.scripts:event("onSustainHit",
		Events.NoteHit(notefield, note,
			note.character or (note.gf and self.gf or notefield.character)))
	if not event.cancelled and not note.wasGoodSustainHit then
		note.wasGoodSustainHit = true
		if notefield.lastSustain == note then notefield.lastSustain = nil end

		if not event.cancelledAnim then
			self:resetStroke(notefield, dir, fullyHeldSustain)
		end
		if fullScore then notefield:removeNote(note) end
	end

	self.scripts:call("postGoodSustainHit", note)
end


-- dir can be nil for non-ghost-tap
function Notes.miss(self, note, dir)
	local ghostMiss = dir ~= nil
	if not ghostMiss then dir = note.direction end

	local funcParam = ghostMiss and dir or note
	self.scripts:call(ghostMiss and "miss" or "noteMiss", funcParam)

	local notefield = ghostMiss and note or note.parent
	local event = self.scripts:event(ghostMiss and "onMiss" or "onNoteMiss",
		Events.Miss(notefield, dir, ghostMiss and nil or note,
			note.character or (note.gf and self.gf or notefield.character)))
	if not event.cancelled and (ghostMiss or not note.tooLate) then
		if not ghostMiss then
			note.tooLate = true
		end

		if event.muteVocals and notefield.vocals then notefield.vocals.volume = 0 end

		if event.triggerSound then
			util.playSfx(paths.getSound("gameplay/missnote" .. love.math.random(1, 3)),
				love.math.random(1, 2) / 10)
		end

		local char = event.character
		if char and not event.cancelledAnim then
			char:sing(dir, "miss")
		end

		if notefield == self.playerNotefield then
			self.health = math.clamp(self.health - (ghostMiss and 0.04 or 0.0475), 0, 2)
			self.score, self.misses = self.score - 100, self.misses + 1
			if not ghostMiss then
				if self.gf and not event.cancelledSadGF then
					local drop = self.gf:getDropAnim(self.combo)
					if drop then self.gf:playAnim(drop, true, nil, true) end
				end
				self.combo = math.min(self.combo, 0) - 1
				self:popUpScore()
			end
			self:recalculateRating()
		end
	end
	notefield.lastSustain = nil

	self.scripts:call(ghostMiss and "postMiss" or "postNoteMiss", funcParam)
end

function Notes.recalculateRating(self, rating)
	self.scoreText.content = ClientPrefs.data.botplayMode and "Botplay Enabled" or
		"Score: " .. util.formatNumber(math.floor(self.score))
	if rating then
		local field = rating .. "s"
		self[field] = (self[field] or 0) + 1
		self:popUpScore(rating)
	end
end

function Notes.popUpScore(self, rating)
	local event = self.scripts:event('onPopUpScore', Events.PopUpScore())
	if not event.cancelled then
		self.judgeSprites.ratingVisible = not event.hideRating
		self.judgeSprites.comboNumVisible = not event.hideScore
		self.judgeSprites:spawn(rating, self.combo)
	end
end

function Notes.resetStroke(self, notefield, dir, doPress)
	local receptor = notefield.receptors[dir + 1]
	if receptor then
		receptor:play((doPress and not notefield.bot)
			and "pressed" or "static")
	end
end

return Notes
