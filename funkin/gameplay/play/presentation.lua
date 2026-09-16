local Presentation = {}

function Presentation.createCameras(self)
	self.camNotes = Camera() --Camera will be changed to ActorCamera once that class is done
	self.camHUD = Camera()
	self.camOther = Camera()
	game.cameras.add(self.camHUD, false)
	game.cameras.add(self.camNotes, false)
	game.cameras.add(self.camOther, false)

	self.camHUD.bgColor[4] = ClientPrefs.data.backgroundDim / 100

	self.cameraOffset = Point()
end

function Presentation.prepareCamera(self, PlayState, conductor)
	game.camera.zoom, self.camZoom,
	self.camZoomSpeed, self.camSpeed, self.camTarget =
		self.stage.camZoom, self.stage.camZoom,
		self.stage.camZoomSpeed, self.stage.camSpeed

	self.zoomRate = conductor.timeSignNum
	self.hudZoomIntensity = 0.03
	self.camZoomIntensity = 1.015
	self.camZoomMult = 1

	if PlayState.prevCamFollow then
		self.camFollow = PlayState.prevCamFollow
		PlayState.prevCamFollow = nil
	else
		self.camFollow = Point()
		self.camFollow.tweening = false
		self.camTarget = self.dad or self.boyfriend or self.gf
		if self.camTarget then
			self.camFollow:set(self:getCameraPosition(self.camTarget))
		end
	end
end

function Presentation.update(self, dt)
	self.camZoomMult = util.coolLerp(self.camZoomMult, 1, 3, dt * self.camZoomSpeed)
	local zoomPlusBop = self.camZoom * self.camZoomMult
	game.camera.zoom = zoomPlusBop

	self.camHUD.zoom = util.coolLerp(self.camHUD.zoom, 1, 3, dt * self.camZoomSpeed)
	self.camNotes.zoom = self.camHUD.zoom
end

function Presentation.positionNotefields(self)
	local playerNF, enemyNF = self.playerNotefield, self.enemyNotefield
	if self.middleScroll then
		local splitWidth = ClientPrefs.data.splitReceptors and ClientPrefs.data.splitWidth or nil
		playerNF:setWidth(splitWidth, ClientPrefs.data.noteWidth)
		playerNF:screenCenter("x")

		enemyNF.groupScale:set(0.5, 0.5)
		enemyNF:setPosition(game.width * 0.086, game.height * (self.downScroll and 0.1 or 1.8))
		enemyNF:hideNotes(true)
	else
		local x = 44
		enemyNF.groupScale:set(1, 1)
		enemyNF:hideNotes(false)
		enemyNF:setPosition(x, game.height / 2)

		playerNF:setWidth()
		playerNF.x = x + game.width / 2
	end
end

function Presentation.positionText(self)
	self.scoreText.x, self.scoreText.y = self.healthBar.x + self.healthBar.bg.width - 190, self.healthBar.y + 30
end

function Presentation.getCameraPosition(self, char)
	if not char then char = self.dad end
	local camX, camY = char:getMidpoint()
	if char == self.gf then
		camX, camY = camX - char.cameraPosition.x + self.stage.gfCam.x,
			camY - char.cameraPosition.y + self.stage.gfCam.y
	elseif char.isPlayer then
		camX, camY = camX - char.cameraPosition.x + self.stage.boyfriendCam.x,
			camY + char.cameraPosition.y + self.stage.boyfriendCam.y
	else
		camX, camY = camX + char.cameraPosition.x + self.stage.dadCam.x,
			camY + char.cameraPosition.y + self.stage.dadCam.y
	end
	return camX, camY
end

function Presentation.cameraMovement(self, ox, oy, easing, time)
	local event = self.scripts:event("onCameraMove", Events.CameraMove(self.camTarget))
	local camX, camY = (ox or 0) + event.offset.x, (oy or 0) + event.offset.y
	if self.camPosTween then
		self.camPosTween:cancel()
	end
	camX, camY = camX - self.cameraOffset.x, camY - self.cameraOffset.y

	if easing then
		if game.camera.followLerp then
			game.camera:follow(self.camFollow, nil)
		end
		self.camPosTween = self.tween:tween(self.camFollow, {x = camX, y = camY}, time, {
			ease = Ease[easing],
			onComplete = function()
				self.camFollow.tweening = false
			end
		})
	else
		if not game.camera.followLerp then
			game.camera:follow(self.camFollow, nil, 2.4 * self.camSpeed)
		end
		self.camPosTween = nil
		self.camFollow:set(camX, camY)
	end
end

return Presentation
