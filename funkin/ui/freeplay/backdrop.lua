local Album = require "funkin.ui.freeplay.album"
local Carousel = require "funkin.ui.freeplay.carousel"
local Backdrop = Object:extend("FreeplayBackdrop")
local camera = {scroll = {x = 0, y = 0}, pixelPerfect = false}
local prefix = "menus/freeplay/"
local digitNames = {"ZERO", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE"}
local introDuration = 17 / 24

local function clamp(value) return math.max(0, math.min(1, value)) end
local function quadOut(value) return 1 - (1 - clamp(value)) ^ 2 end
local function quartOut(value) return 1 - (1 - clamp(value)) ^ 4 end
local function expoOut(value) return value >= 1 and 1 or 1 - 2 ^ (-10 * math.max(0, value)) end
local function expoIn(value) return value <= 0 and 0 or 2 ^ (10 * (clamp(value) - 1)) end
local function circInOut(value)
	value = clamp(value)
	if value < 0.5 then return (1 - math.sqrt(1 - (2 * value) ^ 2)) / 2 end
	return (math.sqrt(1 - (-2 * value + 2) ^ 2) + 1) / 2
end

local function atlas(key, animation, looped)
	local sprite = Sprite()
	sprite:setFrames(paths.getSparrowAtlas(prefix .. key))
	sprite.animation:addByPrefix("idle", animation, 24, looped)
	sprite.animation:play("idle")
	return sprite
end

local function label(font, value, x, y, color, width, align)
	love.graphics.setFont(font)
	love.graphics.setColor(color or Color.WHITE)
	if width then love.graphics.printf(value, x, y, width, align or "left")
	else love.graphics.print(value, x, y) end
end

local function drawImage(image, x, y, alpha, scale, blend, shader)
	if blend then
		love.graphics.push("all")
		love.graphics.setBlendMode(blend, blend == "multiply" and "premultiplied" or "alphamultiply")
		love.graphics.setShader(shader)
	end
	love.graphics.setColor(1, 1, 1, alpha or 1)
	love.graphics.draw(image, x, y, 0, scale or 1, scale or 1)
	if blend then love.graphics.pop() end
end

function Backdrop:new(state)
	Backdrop.super.new(self)
	self.state = state
	self.width, self.height = game.width, game.height
	self.scrollFactor:set()
	self.time, self.idleTime = 0, 0
	self.ready = false
	self.background = paths.getImage(prefix .. "freeplayBGweek1-bf")
	self.card = paths.getImage(prefix .. "pinkBack")
	self.cardGlow = paths.getImage(prefix .. "cardGlow")
	self.beatGlow = paths.getImage(prefix .. "beatglow")
	self.confirmGlow = paths.getImage(prefix .. "confirmGlow")
	self.confirmGlow2 = paths.getImage(prefix .. "confirmGlow2")
	self.confirmTextGlow = paths.getImage(prefix .. "glowingText")
	self.backingText = AnimateAtlas(-320, 120, paths.getAnimateAtlas(prefix .. "backing-text-yeah"))
	self.backingText.origin:set()
	local minX, minY = math.huge, math.huge
	for frame = 0, self.backingText.library:getLength() - 1 do
		self.backingText.frame = frame
		local width, height = self.backingText:getBoundDimensions()
		if width > 0 and height > 0 then
			local x, y = self.backingText:getBoundTopLeft()
			minX, minY = math.min(minX, x), math.min(minY, y)
		end
	end
	self.backingText.offset:set(minX == math.huge and 0 or minX, minY == math.huge and 0 or minY)
	self.backingText.animation:add("confirm", "", 24, false)
	self.backingText.animation:play("confirm")
	self.backingText.animation:pause()
	self.multiplyGlow = love.graphics.newShader([[
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			vec4 pixel = Texel(texture, uv);
			return vec4(mix(vec3(1.0), pixel.rgb, pixel.a * color.a), 1.0);
		}
	]])
	self.font = paths.getFont("5by7.ttf", 32)
	self.titleFont = paths.getFont("vcr.ttf", 48)
	self.scrollFont = paths.getFont("5by7.ttf", 60)
	self.sloganFont = paths.getFont("5by7_b.ttf", 43)
	self.scrollRows = {
		{160, "HOT BLOODED IN MORE WAYS THAN ONE", self.sloganFont, 408, {1, 243 / 255, 131 / 255}},
		{220, "BOYFRIEND", self.scrollFont, -228, {1, 153 / 255, 99 / 255}},
		{285, "PROTECT YO NUTS", self.sloganFont, 210, Color.WHITE},
		{335, "BOYFRIEND", self.scrollFont, -228, {1, 153 / 255, 99 / 255}},
		{397, "HOT BLOODED IN MORE WAYS THAN ONE", self.sloganFont, 408, {1, 243 / 255, 131 / 255}},
		{450, "BOYFRIEND", self.scrollFont, -228, {254 / 255, 164 / 255, 0}}
	}
	self.angleMask = love.graphics.newShader([[
		vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
			vec4 pixel = Texel(texture, uv);
			pixel.a *= smoothstep(-0.0006, 0.0006, uv.x - uv.y * (90.0 / 821.0));
			return pixel * color;
		}
	]])
	self.difficulties = {}
	for _, diff in ipairs({"easy", "normal", "hard", "erect"}) do
		self.difficulties[diff] = Sprite(90, 80, paths.getImage(prefix .. "freeplay" .. diff))
	end
	self.difficulties.nightmare = atlas("freeplaynightmare", "idle0", true)
	self.left = atlas("freeplaySelector", "arrow pointer loop", true)
	self.right = atlas("freeplaySelector", "arrow pointer loop", true)
	self.right.flipX = true
	self.highscore = atlas("highscore", "highscore small instance 1", false)
	self.highscore:setPosition(860, 70)
	self.highscoreTimer = 12 + love.math.random() * 38
	self.digits = {}
	for i = 1, 7 do
		local digit = Sprite()
		digit:setFrames(paths.getSparrowAtlas(prefix .. "digital_numbers"))
		for value, name in ipairs(digitNames) do digit.animation:addByPrefix(tostring(value - 1), name .. " DIGITAL", 24, false) end
		digit.animation:play("0")
		digit.scale:set(55 / 138, 55 / 138)
		digit.origin:set()
		digit:setPosition(927 + (i - 1) * 45, 120)
		self.digits[i] = digit
	end
	self.clearBox = paths.getImage(prefix .. "clearBox")
	self.clearDigits = {}
	for i = 1, 3 do
		local digit = Sprite()
		digit:setFrames(paths.getSparrowAtlas(prefix .. "fonts/freeplay-clear"))
		for value = 0, 9 do digit.animation:addByPrefix(tostring(value), tostring(value) .. "0000", 0, false) end
		digit.animation:play("0")
		digit.origin:set()
		self.clearDigits[i] = digit
	end
	self.dotTexture = paths.getImage(prefix .. "seperator")
	self.carousel = Carousel()
	self.album = Album()
	self.dj = AnimateAtlas(640, 360, paths.getAnimateAtlas(prefix .. "freeplay-boyfriend"))
	self.dj.origin:set()
	self.dj.animation:addFromLibrary("intro", "Intro", "", 24, false)
	self.dj.animation:addFromLibrary("idle", "Idle", "", 24, true)
	self.dj.animation:addFromLibrary("confirm", "Confirm", "", 24, false)
	self.dj.animation:addFromLibrary("afk", "AFK", "", 24, false)
	self.dj.animation:play("intro")
end

function Backdrop:createOverlay()
	local overlay = Object()
	overlay.width, overlay.height = game.width, game.height
	overlay.scrollFactor:set()
	overlay.__render = function(_, c) self:renderOverlay(c) end
	return overlay
end

function Backdrop:startConfirm()
	self.confirmTime = 0
	self.dj.animation:play("confirm", true)
	self.backingText.animation:play("confirm", true)
end

function Backdrop:startExit()
	self.exitTime = 0
end

function Backdrop:onSelectionChanged()
	self.idleTime = 0
	if self.dj.animation.name == "afk" then self.dj.animation:play("idle", true) end
end

function Backdrop:update(dt)
	self.time = self.time + dt
	self.idleTime = self.idleTime + dt
	if self.confirmTime then
		self.confirmTime = self.confirmTime + dt
		self.backingText:update(dt)
	end
	if self.exitTime then self.exitTime = self.exitTime + dt end
	self.dj:update(dt)
	if not self.ready and self.time >= introDuration then
		self.ready = true
		self.dj.animation:play("idle")
		self.album:playIntro()
	elseif self.dj.animation.name == "afk" and self.dj.animation.finished then
		self.dj.animation:play("idle")
	elseif self.idleTime > 60 and not self.seenAFK and self.dj.animation.name == "idle" then
		self.seenAFK = true
		self.dj.animation:play("afk", true)
	end
	local state = self.state
	local song = state.songs and state.songs:getSelected()
	self.carousel:setFilter(state.filterIndex or 1)
	self.carousel:update(dt)
	local album = song and song.meta.album
	local diff = state.difficulty and state.difficulty:lower()
	local rating = song and song.meta.ratings and tonumber(song.meta.ratings[diff]) or 0
	self.album:setAlbum(album)
	self.album:setRating(rating or 0)
	self.album:update(dt)
	if diff ~= self.difficulty then
		self.previousDifficulty = self.difficulty
		self.difficulty, self.diffTime = diff, 0
		self.diffDirection = state.difficultyDirection or 0
	end
	self.diffTime = (self.diffTime or 0) + dt
	for _, sprite in pairs(self.difficulties) do sprite:update(dt) end
	self.left:update(dt)
	self.right:update(dt)
	self.highscore:update(dt)
	self.highscoreTimer = self.highscoreTimer - dt
	if self.highscoreTimer < 0 then
		self.highscore.animation:play("idle", true)
		self.highscoreTimer = 20 + love.math.random() * 40
	end
	local score = string.format("%07d", math.min(9999999, math.max(0, math.floor(state.lerpScore or 0))))
	for i, digit in ipairs(self.digits) do
		local value = score:sub(i, i)
		if digit.animation.name ~= value then
			digit.animation:play(value)
			digit.x = 927 + (i - 1) * 45 + (value == "1" and 15 or 0)
		end
		digit:update(dt)
	end
end

function Backdrop:beginScene()
	love.graphics.push("all")
	love.graphics.setShader()
	love.graphics.translate(self.state.layoutX or 0, 0)
	love.graphics.scale(self.state.layoutScale or 1, self.state.layoutScale or 1)
end

function Backdrop:__render(c)
	self:beginScene()
	if not self.state.parent then
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.rectangle("fill", -1280, 0, 3840, 720)
	end
	local reveal = math.max(0, self.time - introDuration)
	local exit = self.exitTime and expoIn(self.exitTime / 0.5) or 0
	local cardX = -self.card:getWidth() * (1 - quartOut(self.time / 0.6)) - 840 * exit
	local color = self.ready and {1, 216 / 255, 99 / 255} or {1, 212 / 255, 233 / 255}
	if self.confirmTime then color = Color.lerp({1, 208 / 255, 213 / 255}, {23 / 255, 24 / 255, 49 / 255}, quadOut(self.confirmTime / 0.33)) end
	love.graphics.setColor(color)
	love.graphics.draw(self.card, cardX, 0)
	if self.ready and not self.confirmTime and not self.exitTime then
		love.graphics.stencil(function() love.graphics.polygon("fill", 0, 0, 394, 0, 524, 760, 0, 760) end, "replace", 1)
		love.graphics.setStencilTest("equal", 1)
		love.graphics.setColor(254 / 255, 218 / 255, 0, 1)
		love.graphics.rectangle("fill", 84, 440, 524, 75)
		love.graphics.setColor(1, 212 / 255, 0, 1)
		love.graphics.rectangle("fill", 0, 440, 100, 75)
		for _, row in ipairs(self.scrollRows) do
			local spacing = row[3]:getWidth(row[2]) + 24
			local offset = (-reveal * row[4]) % spacing
			for repeatIndex = -1, math.ceil(560 / spacing) do
				label(row[3], row[2], offset + repeatIndex * spacing + 2, row[1] + 2, row[5])
			end
		end
		if ClientPrefs.data.flashingLights then
			local song = self.state.songs and self.state.songs:getSelected()
			local bpm = math.max(1, song and tonumber(song.meta.bpm) or 100)
			local frequency = 2 ^ math.min(3, math.floor((bpm or 100) / 140))
			local musicTime = game.sound.music and game.sound.music.time or self.time
			local pulse = (musicTime % (60 / (bpm or 100) * frequency))
			drawImage(self.beatGlow, -300, 330, 0.6 * quartOut(pulse / (18 / 24)), 1, "multiply", self.multiplyGlow)
			drawImage(self.beatGlow, -300, 330, 0.8 * (1 - quartOut(pulse / (16 / 24))), 1, "add")
		end
		love.graphics.setStencilTest()
	end
	if self.confirmTime then
		local t = self.confirmTime
		drawImage(self.confirmGlow2, -30, 240, t < 0.33 and 0.5 * quadOut(t / 0.33) or 0.6)
		if t >= 0.33 then
			drawImage(self.confirmGlow, -30, 240, 1 - clamp((t - 0.33) / 0.5), 1, "add")
			drawImage(self.confirmTextGlow, -8, 115, 1 - 0.6 * clamp((t - 0.33) / 0.5), 1, "add")
		end
		self.backingText:__render(camera)
	end
	if self.ready and reveal < 0.45 and ClientPrefs.data.flashingLights then
		local progress = math.sin(clamp(reveal / 0.45) * math.pi / 2)
		drawImage(self.cardGlow, -30 - self.cardGlow:getWidth() * 0.1 * progress,
			-30 - self.cardGlow:getHeight() * 0.1 * progress, 1 - progress, 1 + 0.2 * progress, "add")
	end
	self.dj.x = 640 - 1300 * exit
	self.dj:__render(camera)
	local bgX = self.card:getWidth() * 0.74 + 1550 * exit
	if self.ready then
		local tint = expoOut(reveal / 0.6)
		if self.confirmTime then
			local t = self.confirmTime
			tint = t < 0.33 and (168 - 68 * clamp(t / 0.5)) / 255
				or (205 - 120 * expoOut((t - 0.33) / 2)) / 255
		end
		love.graphics.setColor(tint, tint, tint, 1)
		love.graphics.setShader(self.angleMask)
		local scale = 721 / self.background:getHeight()
		love.graphics.draw(self.background, bgX, 0, 0, scale, scale)
		love.graphics.setShader()
	else
		local x = 1280 - (1280 - bgX) * (1 - (1 - clamp(self.time / 0.7)) ^ 5)
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.polygon("fill", x, 0, 1600, 0, 1600, 721, x + 126, 721)
	end
	love.graphics.pop()
end

function Backdrop:renderOverlay(c)
	self:beginScene()
	local state = self.state
	local reveal = math.max(0, self.time - introDuration)
	local exit = self.exitTime and expoIn(self.exitTime / 0.3) or 0
	if self.ready then
		love.graphics.push()
		local albumExit = self.exitTime and expoIn(self.exitTime / 0.4) or 0
		local albumX = self.album.x
		self.album.x = albumX + (1280 - albumX) * albumExit
		if self.album.visible then self.album:__render(camera) end
		self.album.x = albumX
		love.graphics.pop()
		local song = state.songs and state.songs:getSelected()
		local diff = state.difficulty and state.difficulty:lower()
		local sprite = self.difficulties[diff]
		local x = -300 + 390 * quartOut(reveal / 0.6) - 500 * exit
		local maskX = self.card:getWidth() * 0.74 + 1550 * (self.exitTime and expoIn(self.exitTime / 0.5) or 0)
		love.graphics.stencil(function()
			love.graphics.polygon("fill", -1280, 0, maskX, 0, maskX + 90 * 721 / self.background:getHeight(), 721, -1280, 721)
		end, "replace", 1)
		love.graphics.setStencilTest("equal", 1)
		if sprite then
			if self.previousDifficulty and self.diffDirection ~= 0 and self.diffTime < 0.2 then
				local fromX = self.diffDirection > 0 and 500 or -320
				x = fromX + (90 - fromX) * circInOut(self.diffTime / 0.2) - 500 * exit
			end
			sprite.alpha = self.previousDifficulty and self.diffDirection ~= 0 and self.diffTime < 1 / 24 and 0.5 or 1
			sprite.x, sprite.y = x, 80 - (sprite.alpha < 1 and 5 or 0)
			sprite:__render(camera)
		else label(self.font, (diff or "---"):upper(), x, 95, Color.BLACK, 230, "center") end
		love.graphics.setStencilTest()
		local dotIds = state.difficultyIds or {"easy", "normal", "hard"}
		local dotCount = #dotIds
		for i, id in ipairs(dotIds) do
			local active = false
			for _, available in ipairs(song and song.diffs or {}) do if available:lower() == id then active = true; break end end
			local color = not active and {0.07, 0.07, 0.07, 0.33} or id == diff and {0.98, 0.98, 0.98, 1} or {0.28, 0.28, 0.28, 1}
			if active and (id == "erect" or id == "nightmare") then color = id == diff and {0.76, 0.54, 1, 1} or {0.2, 0.16, 0.42, 1} end
			love.graphics.setColor(color[1], color[2], color[3], (color[4] or 1) * quartOut(reveal / 0.5))
			local dx = 260 - 14.7 * (math.min(dotCount, 8) - 1) + 30 * ((i - 1) % 8) - 75
			love.graphics.draw(self.dotTexture, dx - 500 * exit, 170 + math.floor((i - 1) / 8) * 30)
		end
		self.left:setPosition(20 - 500 * exit, 70)
		self.right:setPosition(325 - 500 * exit, 70)
		self.left:__render(camera)
		self.right:__render(camera)
		love.graphics.push()
		love.graphics.translate(0, -200 * exit)
		self.carousel:__render(camera)
		love.graphics.pop()
		if reveal >= 1 / 24 then
			love.graphics.push()
			love.graphics.translate(430 * exit, 0)
			self.highscore:__render(camera)
			for _, digit in ipairs(self.digits) do digit:__render(camera) end
			drawImage(self.clearBox, 1165, 65)
			local completion = tostring(math.floor(math.max(0, math.min(100, (state.lerpCompletion or 0) * 100))))
			local clearX = #completion == 1 and 1209 or #completion == 3 and 1175 or 1185
			for i = 1, #completion do
				local digit = self.clearDigits[i]
				digit.animation:play(completion:sub(i, i))
				digit:setPosition(clearX, 87)
				digit:__render(camera)
				clearX = clearX + digit:getFrameWidth()
			end
			love.graphics.pop()
		end
		if not song then
			label(self.font, state.filter == "favorites" and "NO FAVORITES YET" or "NO SONGS HERE", 450, 330, Color.WHITE, 600, "center")
		end
	end
	local headerY = -164 + 64 * quartOut(self.time / 0.3) - 164 * exit
	love.graphics.setColor(0, 0, 0, 1)
	love.graphics.rectangle("fill", 0, headerY, 1280, 164)
	if self.ready and reveal >= 1 / 24 then
		label(self.titleFont, "FREEPLAY", 8, 8 - 164 * exit)
		label(self.titleFont, "OFFICIAL OST", 8, 8 - 164 * exit, Color.WHITE, 1264, "right")
	end
	if self.confirmTime and self.confirmTime > 1 then
		love.graphics.setColor(0, 0, 0, clamp((self.confirmTime - 1) / 0.2))
		love.graphics.rectangle("fill", -1280, 0, 3840, 720)
	end
	love.graphics.pop()
end

function Backdrop:destroy()
	self.dj:destroy()
	self.backingText:destroy()
	self.left:destroy()
	self.right:destroy()
	self.highscore:destroy()
	self.album:destroy()
	self.carousel:destroy()
	for _, sprite in pairs(self.difficulties) do sprite:destroy() end
	for _, digit in ipairs(self.digits) do digit:destroy() end
	for _, digit in ipairs(self.clearDigits) do digit:destroy() end
	if self.angleMask then self.angleMask:release() end
	if self.multiplyGlow then self.multiplyGlow:release() end
	Backdrop.super.destroy(self)
end

return Backdrop
