local Carousel = Object:extend("FreeplayCarousel")

local symbols = {"ALL move", "AB move", "CD move", "EH move", "IL move", "MN move",
	"OR move", "S move", "T move", "UZ move", "# move", "fav move"}
local offsets = {-10, -22, 2, 0}
local boundsCache = setmetatable({}, {__mode = "k"})

local function getBounds(sprite, symbol)
	local library = sprite.library
	boundsCache[library] = boundsCache[library] or {}
	if boundsCache[library][symbol] then return boundsCache[library][symbol] end
	local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
	local oldFrame, oldSymbol = sprite.frame, sprite.symbol
	sprite.symbol = symbol
	for frame = 0, library:getTimelineLength(library:getSymbolTimeline(symbol)) - 1 do
		sprite.frame = frame
		local width, height = sprite:getBoundDimensions()
		if width > 0 and height > 0 then
			local x, y = sprite:getBoundTopLeft()
			minX, minY = math.min(minX, x), math.min(minY, y)
			maxX, maxY = math.max(maxX, x + width), math.max(maxY, y + height)
		end
	end
	sprite.frame, sprite.symbol = oldFrame, oldSymbol
	local bounds = minX == math.huge and {x = 0, y = 0, width = 0, height = 0}
		or {x = minX, y = minY, width = maxX - minX, height = maxY - minY}
	boundsCache[library][symbol] = bounds
	return bounds
end

function Carousel:new()
	Carousel.super.new(self)
	self.width, self.height = 1280, 190
	self.scrollFactor:set()
	self.arrow = paths.getImage("menus/freeplay/miniArrow")
	self.separator = paths.getImage("menus/freeplay/seperator")
	self.letters = {}
	self.filter, self.bounceTime, self.direction = nil, 1, 0
	local library = paths.getAnimateAtlas("menus/freeplay/sortedLetters")
	for slot = 0, 4 do
		local sprite = AnimateAtlas(0, 0, library)
		sprite.origin:set()
		sprite.offset:set()
		sprite.scrollFactor:set()
		sprite.antialiasing = true
		for _, symbol in ipairs(symbols) do sprite.animation:add(symbol, symbol, 24, true) end
		sprite.scale:set(slot == 2 and 1 or 0.8, slot == 2 and 1 or 0.8)
		local tint = 1 - math.max(math.abs(slot - 2) / 6, 0.01)
		sprite.color = {tint, tint, tint}
		self.letters[slot + 1] = sprite
	end
	self:setFilter(1)
	self:update(0)
end

function Carousel:setFilter(index)
	index = ((index or 1) - 1) % #symbols + 1
	if index == self.filter then return end
	if self.filter then
		local delta = (index - self.filter + #symbols / 2) % #symbols - #symbols / 2
		self.direction = delta > 0 and 1 or -1
		self.bounceTime = 0
	end
	self.filter = index
	for slot, sprite in ipairs(self.letters) do
		local symbol = symbols[(index + slot - 4) % #symbols + 1]
		sprite.animation:play(symbol, true)
		sprite.bounds = getBounds(sprite, symbol)
		if slot ~= 3 then sprite.animation.curAnim:pause() end
	end
end

function Carousel:update(dt)
	self.bounceTime = self.bounceTime + dt
	local phase = math.min(4, math.floor(self.bounceTime * 24) + 1)
	local offset = offsets[phase] * self.direction
	for slot, sprite in ipairs(self.letters) do
		local scale = sprite.scale.x
		sprite.x = 400 + (slot - 1) * 80 - offset
			+ (1 - scale) * sprite.bounds.width / 2 - sprite.bounds.x * scale
		sprite.y = 65 + (1 - scale) * sprite.bounds.height / 2 - sprite.bounds.y * scale
		sprite.visible = slot ~= 1 or phase ~= 2
		sprite:update(dt)
	end
end

function Carousel:__render(camera)
	love.graphics.push("all")
	love.graphics.setShader()
	love.graphics.setColor(1, 1, 1, self.alpha)
	local arrowOffset = self.bounceTime < 2 / 24 and 3 * self.direction or 0
	love.graphics.draw(self.arrow, 395 - (self.direction < 0 and arrowOffset or 0), 90, 0, -1, 1)
	love.graphics.draw(self.arrow, 780 - (self.direction > 0 and arrowOffset or 0), 90)
	local phase = math.min(4, math.floor(self.bounceTime * 24) + 1)
	local offset = offsets[phase] * self.direction
	for slot = 0, 3 do
		local tint = 1 - math.max(math.abs(slot - 2) / 6, 0.01)
		love.graphics.setColor(tint, tint, tint, self.alpha)
		love.graphics.draw(self.separator, 460 + slot * 80 - offset, 95)
	end
	for _, sprite in ipairs(self.letters) do
		if sprite.visible then
			sprite.alpha = self.alpha
			sprite:__render(camera)
		end
	end
	love.graphics.pop()
end

function Carousel:destroy()
	for _, sprite in ipairs(self.letters) do sprite:destroy() end
	self.letters = {}
	Carousel.super.destroy(self)
end

return Carousel
