local Cutscene = {}

function Cutscene.getCutscene(PlayState, isEnd)
	local name = paths.formatToSongPath(PlayState.SONG.song)
	if isEnd then name = name .. "-end" end

	for _, path in ipairs({
		paths.getPath("data/cutscenes/" .. name .. ".lua"),
		paths.getPath("data/cutscenes/" .. name .. ".json")
	}) do
		if paths.exists(path, "file") then
			return name, path:ext() == "lua" and 1 or 2
		end
	end
end

function Cutscene.executeCutscene(self, PlayState, name, type, onComplete)
	PlayState.seenCutscene = true
	if type == 1 then
		local cutsceneScript = Script("data/cutscenes/" .. name)
		cutsceneScript.errorCallback:add(function()
			print("Cutscene returned a error. Skipping")
			cutsceneScript:close()
		end)
		cutsceneScript.closeCallback:add(function()
			if onComplete then onComplete() end
			onComplete = nil
		end)

		cutsceneScript:call("create")
		if isEnd then cutsceneScript:call("postCreate") end

		self.scripts:add(cutsceneScript)
	else
		local s, data = pcall(paths.getJSON, "data/cutscenes/" .. name)
		if not s then
			print("JSON cutscene returned a error. Skipping;", data)
			if onComplete then onComplete() end
			return
		end

		for _, e in ipairs(data.cutscene) do
			Timer():start(e.time / 1000, function()
				self:executeCutsceneEvent(e.event, onComplete)
			end)
		end
	end
end

function Cutscene.executeCutsceneEvent(self, event, onComplete)
	switch(event.name, {
		['Camera Position'] = function()
			local xCam, yCam = event.params[1], event.params[2]
			local isTweening = event.params[3]
			local time = event.params[4]
			local ease = event.params[5]
			if isTweening then
				game.camera:follow(self.camFollow, nil)
				Tween.tween(self.camFollow, {x = xCam, y = yCam}, time, {ease = Ease[ease]})
			else
				self.state.camFollow:set(xCam, yCam)
				game.camera:follow(self.camFollow, nil, 2.4 * self.camSpeed)
			end
		end,
		['Camera Zoom'] = function()
			local zoomCam = event.params[1]
			local isTweening = event.params[2]
			local time = event.params[3]
			local ease = event.params[4]
			if isTweening then
				Tween.tween(game.camera, {zoom = zoomCam}, time, {ease = Ease[ease]})
			else
				game.camera.zoom = zoomCam
			end
		end,
		["Play Sound"] = function()
			local soundPath = event.params[1]
			local volume = event.params[2]
			local isFading = event.params[3]
			local time = event.params[4]
			local volStart, volEnd = event.params[5], event.params[6]

			local sound = util.playSfx(paths.getSound(soundPath), volume)
			if isFading then sound:fade(time, volStart, volEnd) end
		end,
		["Play Animation"] = function()
			local character, nf, anim = nil, self.notefields, event.params[2]
			switch(event.params[1], {
				[{"bf", "boyfriend", "player"}] = function() character = nf[1].character end,
				[{"gf", "girlfriend", "bystander"}] = function() character = nf[3].character end,
				[{"dad", "enemy", "opponent"}] = function() character = nf[2].character end
			})
			if character then character:playAnim(anim, true) end
		end,
		["End Cutscene"] = function()
			game.camera:follow(self.state.camFollow, nil, 2.4 * self.camSpeed)
			if onComplete then onComplete(event) end
		end
	})
end

return Cutscene
