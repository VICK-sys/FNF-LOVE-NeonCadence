local Album = Object:extend("FreeplayAlbum")
local prefix = "menus/freeplay/"
local camera = {scroll = {x = 0, y = 0}, pixelPerfect = false}
local boundsCache = setmetatable({}, {__mode = "k"})
local titleOffsets = {
	volume1 = {8, 0}, volume2 = {8, -7}, volume3 = {8, -7}, volume4 = {8, -7},
	expansion1 = {-22, -3}, expansion2 = {-22, -3}, spaghetti = {-35, 0}
}

local function textureAtlas(key, x, y)
	local library = paths.getAnimateAtlas(prefix .. key)
	local sprite = AnimateAtlas(x, y, library)
	local bounds = boundsCache[library]
	if not bounds then
		local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
		for frame = 0, library:getLength() - 1 do
			sprite.frame = frame
			local left, top = sprite:getBoundTopLeft()
			local width, height = sprite:getBoundDimensions()
			if width > 0 and height > 0 then
				minX, minY = math.min(minX, left), math.min(minY, top)
				maxX, maxY = math.max(maxX, left + width), math.max(maxY, top + height)
			end
		end
		bounds = minX == math.huge and {0, 0, 0, 0} or {minX, minY, maxX - minX, maxY - minY}
		boundsCache[library] = bounds
	end
	sprite.frame = 0
	sprite.origin:set()
	sprite.offset:set(bounds[1], bounds[2])
	sprite.width, sprite.height = bounds[3], bounds[4]
	sprite.antialiasing = true
	return sprite
end

function Album:new(x, y)
	Album.super.new(self, x or 920, y or 220)
	self.width, self.height = 320, 380
	self.scrollFactor:set()
	self.visible = false
	self.started = false
	self.time = 0
	self.rating = 0
	self.titles = {}
	self.covers = {}
	self.roll = textureAtlas("albumRoll/freeplayAlbum", 0, 0)
	self.roll.animation:addFromLibrary("intro", "intro", "", 24, false)
	self.roll.animation:addFromLibrary("switch", "switch", "", 24, false)
	self.roll.animation:addFromLibrary("idle", "idle", "", 24, true)
	self.roll.animation:play("idle")
	self.roll.library = setmetatable({spritemaps = {{
		data = self.roll.library.spritemaps[1].data,
		texture = self.roll.library.spritemaps[1].texture
	}}}, {__index = self.roll.library})
	self.stars = textureAtlas("freeplayStars", 30, -11)
	for difficulty = 0, 15 do
		local first = difficulty == 0 and 1500 or (difficulty - 1) * 100
		self.stars.animation:addByRange(tostring(difficulty), "", first,
			difficulty == 0 and first or first + 99, 24, true)
	end
	self.stars.animation:play("0")
	self.flames = {}
	for i = 1, 5 do
		local flame = Sprite(-7 + 29 * (i - 1), -129 + 6 * (i - 1))
		flame:setFrames(paths.getSparrowAtlas(prefix .. "freeplayFlame"))
		flame.animation:addByPrefix("flame", "fire loop full instance 1", 22 + i % 3 + 1, false)
		flame.animation:play("flame")
		flame.visible = false
		flame.antialiasing = true
		self.flames[i] = flame
	end
end

function Album:setAlbum(albumId)
	if albumId == self.albumId then return end
	self.albumId = albumId
	self.visible = albumId ~= nil and titleOffsets[albumId] ~= nil and self.started
	self.title = nil
	if not albumId or not titleOffsets[albumId] then return end
	local cover = self.covers[albumId]
	if not cover then
		cover = paths.getImage(prefix .. "albumRoll/" .. albumId)
		self.covers[albumId] = cover
	end
	self.roll.library.spritemaps[1].texture = cover
	local title = self.titles[albumId]
	if not title then
		local offsets = titleOffsets[albumId]
		title = Sprite(5 + offsets[1], 280 + offsets[2])
		title:setFrames(paths.getSparrowAtlas(prefix .. "albumRoll/" .. albumId .. "-text"))
		title.animation:addByPrefix("idle", "idle0", 24, true)
		title.animation:addByPrefix("switch", "switch0", 24, false)
		title.antialiasing = true
		self.titles[albumId] = title
	end
	self.title = title
	title.animation:play("switch", true)
	if self.started and self.roll.animation.name ~= "intro" then self:skipIntro() end
end

function Album:setRating(rating)
	rating = math.max(0, math.min(15, math.floor(tonumber(rating) or 0)))
	if self.rating == rating then return end
	self.rating = rating
	self.stars.animation:play(tostring(rating), true)
	self:refreshFlames()
end

function Album:refreshFlames()
	local pending = 0
	for i, flame in ipairs(self.flames) do
		flame.delay = nil
		if i <= self.rating - 10 and self.detailsVisible then
			if not flame.visible then
				flame.delay = pending * 0.25
				pending = pending + 1
			end
		else
			flame.visible = false
		end
	end
end

function Album:playIntro()
	self.started = true
	self.visible = self.albumId ~= nil and titleOffsets[self.albumId] ~= nil
	self.time = 0
	self.detailsVisible = false
	self.introDelay = 0.75
	self.roll.animation:play("intro", true)
	self:refreshFlames()
end

function Album:skipIntro()
	self.started = true
	self.visible = self.albumId ~= nil and titleOffsets[self.albumId] ~= nil
	self.introDelay = nil
	self.detailsVisible = true
	self.roll.animation:play("switch", true)
	if self.title then self.title.animation:play("switch", true) end
	self:refreshFlames()
end

function Album:show()
	self:skipIntro()
end

function Album:hide()
	self.visible = false
end

function Album:update(dt)
	Album.super.update(self, dt)
	self.time = self.time + dt
	self.roll:update(dt)
	if self.roll.animation.finished and self.roll.animation.name ~= "idle" then
		self.roll.animation:play("idle")
	end
	if self.introDelay then
		self.introDelay = self.introDelay - dt
		if self.introDelay <= 0 then
			self.introDelay = nil
			self.detailsVisible = true
			if self.title then self.title.animation:play("switch", true) end
			self:refreshFlames()
		end
	end
	self.stars:update(dt)
	if self.title then
		self.title:update(dt)
		if self.title.animation.finished then self.title.animation:play("idle") end
	end
	for _, flame in ipairs(self.flames) do
		if flame.delay then
			flame.delay = flame.delay - dt
			if flame.delay <= 0 then
				flame.delay = nil
				flame.visible = true
				flame.animation:play("flame", true)
			end
		end
		flame:update(dt)
		if flame.animation.finished then
			flame.animation:play("flame", true)
			flame.animation.curAnim.frame = 3
		end
	end
end

function Album:__render(c)
	if not self.visible then return end
	love.graphics.push("all")
	love.graphics.translate(self.x, self.y)
	self.roll.alpha = self.alpha
	self.roll:__render(camera)
	if self.detailsVisible then
		for _, flame in ipairs(self.flames) do
			if flame.visible then
				flame.alpha = self.alpha
				flame:__render(camera)
			end
		end
		self.stars.alpha = self.alpha
		self.stars:__render(camera)
		if self.title then
			self.title.alpha = self.alpha
			self.title:__render(camera)
		end
	end
	love.graphics.pop()
end

function Album:destroy()
	self.roll:destroy()
	self.stars:destroy()
	for _, flame in ipairs(self.flames) do flame:destroy() end
	for _, title in pairs(self.titles) do title:destroy() end
	Album.super.destroy(self)
end

return Album
