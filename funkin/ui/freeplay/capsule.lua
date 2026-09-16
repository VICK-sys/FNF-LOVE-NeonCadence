local Capsule = Object:extend("FreeplayCapsule")
local glowShader
local entranceScales = {1.7, 1.8, 0.85, 0.85, 0.97, 0.97, 1}
local digitNames = {"ZERO", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE"}
local rankNames = {
	PERFECT_GOLD = "PERFECTSICK", PERFECTSICK = "PERFECTSICK", PERFECT = "PERFECT",
	EXCELLENT = "EXCELLENT", GREAT = "GREAT", GOOD = "GOOD", SHIT = "LOSS", LOSS = "LOSS"
}
local iconNames = {
	["parents"] = "parents-christmas",
	["senpai-pixel"] = "senpai",
	["senpai-angry-pixel"] = "senpai",
	["spirit-pixel"] = "spirit",
	["bf-pixel"] = "bf"
}

function Capsule:new(entry)
	Capsule.super.new(self, 0, 0)
	self.width, self.height = 612, 132
	self.songName = entry.songName
	self.displayName = entry.displayName or entry.songName or "Random"
	self.diffs = entry.diffs or {}
	self.meta = entry.meta or {}
	self.bgColor = self.meta.color or Color.WHITE
	self.isRandom = entry.isRandom == true
	self.favorite = entry.favorite == true
	self.selected = false
	self.parts = {}
	self.titleTime = 0
	self.titleOffset = 0

	self.capsule = self:addPart(Sprite())
	self.capsule:setFrames(paths.getSparrowAtlas("menus/freeplay/freeplayCapsule/capsule/freeplayCapsule"))
	self.capsule.animation:addByPrefix("selected", "mp3 capsule w backing0", 24, true)
	self.capsule.animation:addByPrefix("idle", "mp3 capsule w backing NOT SELECTED", 24, true)
	self.capsule.animation:play("idle")
	self.capsule.scale:set(0.8, 0.8)
	self.capsule.origin:set(306, 66)

	local font = paths.getFont("5by7.ttf", 32) or paths.getFont("vcr.ttf", 32)
	if not self.isRandom then
		local iconName = self.meta.icon or HealthIcon.defaultIcon
		local pixelName = iconNames[iconName] or iconName
		local iconPath = "menus/freeplay/icons/" .. pixelName .. "pixel"
		if paths.exists(paths.getPath("images/" .. iconPath .. ".xml"), "file") then
			self.icon = self:addPart(Sprite(160, 35))
			self.icon:setFrames(paths.getSparrowAtlas(iconPath))
			self.icon.animation:addByPrefix("idle", "idle0", 10, true)
			self.icon.animation:addByPrefix("confirm", "confirm0", 10, false)
			self.icon.animation:addByPrefix("confirm-hold", "confirm-hold0", 10, true)
			self.icon.animation.onFinish:add(function(name)
				if name == "confirm" and self.icon.animation:has("confirm-hold") then
					self.icon.animation:play("confirm-hold")
				end
			end)
			self.icon.animation:play("idle")
			self.icon.scale:set(2, 2)
			self.icon.origin:set(pixelName == "parents-christmas" and 140
				or pixelName == "sserafim-kazuha" and 195 or 100,
				self.icon:getFrameHeight() / 2)
			self.icon.antialiasing = false
		else
			self.icon = self:addPart(HealthIcon(iconName))
			local size = math.max(self.icon:getFrameWidth() * self.icon.zoom.x,
				self.icon:getFrameHeight() * self.icon.zoom.y)
			self.icon.scale:set(76 / size, 76 / size)
			self.icon.origin:set()
			self.icon.offset:set()
			self.icon:setPosition(76, 19)
		end

		self.bpmLabel = self:addPart(Sprite(144, 87,
			paths.getImage("menus/freeplay/freeplayCapsule/bpmtext")))
		self.diffLabel = self:addPart(Sprite(414, 87,
			paths.getImage("menus/freeplay/freeplayCapsule/difficultytext")))
		for _, label in ipairs({self.bpmLabel, self.diffLabel}) do
			label:setGraphicSize(math.floor(label:getFrameWidth() * 0.9))
			label:centerOrigin()
		end
		local week = entry.weekName or self.meta.weekName or entry.levelId or self.meta.levelId
		if type(week) == "string" and week ~= "" then
			if not entry.weekName and not self.meta.weekName then
				week = week:gsub("(%l)(%u)", "%1 %2"):gsub("(%a)(%d)", "%1 %2")
					:gsub("(%d)(%a)", "%1 %2")
			end
			self.week = self:addPart(Text(293, 89, week,
				paths.getFont("YoureGone-Regular.otf", 20), {33 / 255, 36 / 255, 46 / 255}))
			self.week.scale:set(0.9, 0.9)
			self.week:centerOrigin()
			local offsets = entry.weekOffsets or self.meta.weekOffsets
			if type(offsets) == "table" then
				self.week.offset:set(tonumber(offsets[1]) or 0, tonumber(offsets[2]) or 0)
			end
		end
		self.bpmDigits = self:createDigits("smallnumbers", 3, 185, 88.5, 11)
		self.ratingDigits = self:createDigits("bignumbers", 2, 466, 32, 30)
		self.unknownRating = self:addPart(Text(476, 43, "--", font))
		self.unknownRating.antialiasing = false

		self.ranking = self:addPart(Sprite(420, 41))
		self.ranking:setFrames(paths.getSparrowAtlas("menus/freeplay/rankbadges"))
		for _, name in ipairs({"PERFECT", "EXCELLENT", "GOOD", "GREAT", "LOSS"}) do
			self.ranking.animation:addByPrefix(name, name .. " rank0", 24, false)
		end
		self.ranking.animation:addByPrefix("PERFECTSICK", "PERFECT rank GOLD", 24, false)
		self.ranking.scale:set(0.9, 0.9)
		self.ranking.blend = "add"
		self.ranking.visible = false
		self.sparkle = self:addPart(Sprite(420, 41))
		self.sparkle:setFrames(paths.getSparrowAtlas("menus/freeplay/sparkle"))
		self.sparkle.animation:addByPrefix("sparkle", "sparkle Export0", 24, false)
		self.sparkle.animation:play("sparkle")
		self.sparkle.scale:set(0.8, 0.8)
		self.sparkle.blend = "add"
		self.sparkle.alpha = 0.7
		self.sparkle.visible = false
		self.heartGlow = self:addPart(Sprite(405, 40))
		self.heart = self:addPart(Sprite(405, 40))
		for _, heart in ipairs({self.heartGlow, self.heart}) do
			heart:setFrames(paths.getSparrowAtlas("menus/freeplay/favHeart"))
			heart.animation:addByPrefix("favorite", "favorite heart", 24, false)
			heart.animation:play("favorite")
			heart.animation:finish()
			heart:setGraphicSize(50, 50)
			heart.antialiasing = false
			heart.blend = "add"
			heart.visible = self.favorite
		end
		self:setBPM(math.floor(tonumber(self.meta.bpm) or 100))
	end
	self:createTitleGlow(font)
	self.title = self:addPart(Text(159.12, 45, self.displayName, font))
	self.title:setOutline("normal", 1, nil, {0, 0.8, 1, 0.2})
	self.title.antialiasing = true
	self.title.outline.precision = 4
	self:setRank(entry.rank)
	self:setDifficulty(self.diffs[2] or self.diffs[1])
	self:setSelected(false)
end

function Capsule:createTitleGlow(font)
	if not glowShader then
		glowShader = love.graphics.newShader([[
			// Modified version of a tilt shift shader from Martin Jonasson (http://grapefrukt.com/)
			// Read http://notes.underscorediscovery.com/ for context on shaders and this file
			// License : MIT
			extern vec2 pixelSize;
			float blur(Image texture, vec2 uv, vec2 direction) {
				float alpha = Texel(texture, uv).a * 0.1964825501511404;
				alpha += (Texel(texture, uv + direction * 1.411764705882353).a
					+ Texel(texture, uv - direction * 1.411764705882353).a) * 0.2969069646728344;
				alpha += (Texel(texture, uv + direction * 3.2941176470588234).a
					+ Texel(texture, uv - direction * 3.2941176470588234).a) * 0.09447039785044732;
				alpha += (Texel(texture, uv + direction * 5.176470588235294).a
					+ Texel(texture, uv - direction * 5.176470588235294).a) * 0.010381362401148057;
				return alpha;
			}
			vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
				float alpha = (blur(texture, uv, vec2(pixelSize.x * 2.0, 0.0))
					+ blur(texture, uv, vec2(0.0, pixelSize.y * 2.0))) * 0.5;
				return vec4(color.rgb, color.a * alpha);
			}
		]])
	end
	self.glowCanvas = love.graphics.newCanvas(math.max(1, math.ceil(font:getWidth(self.displayName))) + 24,
		font:getHeight() + 24)
	local scissorX, scissorY, scissorW, scissorH = love.graphics.getScissor()
	love.graphics.push("all")
	love.graphics.setCanvas(self.glowCanvas)
	love.graphics.origin()
	love.graphics.setScissor()
	love.graphics.setShader()
	love.graphics.clear()
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(font)
	love.graphics.print(self.displayName, 12, 12)
	love.graphics.pop()
	love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)
	self.titleGlow = self:addPart(Sprite(159.12 - 12, 45 - 12, self.glowCanvas))
	self.titleGlow.color = {0, 0.8, 1}
	self.titleGlow.shader = glowShader
	self.titleGlow.antialiasing = true
end

function Capsule:addPart(part)
	part.scrollFactor:set()
	table.insert(self.parts, part)
	return part
end

function Capsule:createDigits(atlas, count, x, y, spacing)
	local digits = {}
	for i = 1, count do
		local digit = self:addPart(Sprite(x + (i - 1) * spacing, y))
		digit:setFrames(paths.getSparrowAtlas("menus/freeplay/freeplayCapsule/" .. atlas))
		for number, name in ipairs(digitNames) do
			digit.animation:addByPrefix(tostring(number - 1), name, 0, false)
		end
		digit.animation:play("0")
		digit:setGraphicSize(math.floor(digit:getFrameWidth() * 0.9))
		digit:updateHitbox()
		digit.antialiasing = false
		digits[i] = digit
	end
	return digits
end

function Capsule:setNumber(digits, number)
	local text = string.format("%0" .. #digits .. "d", math.max(0,
		math.min(10 ^ #digits - 1, number)))
	for i, digit in ipairs(digits) do
		local value = text:sub(i, i)
		digit.animation:play(value)
		digit:fixOffsets()
		if value == "1" then digit.offset.x = digit.offset.x - 4 end
		if value == "3" then digit.offset.x = digit.offset.x - 1 end
	end
end

function Capsule:setBPM(bpm)
	self:setNumber(self.bpmDigits, bpm)
	local x, shift = math.floor(bpm / 100) == 1 and 186 or 191, 0
	for i, digit in ipairs(self.bpmDigits) do
		if i == 2 and math.floor(bpm / 10) % 10 == 1 then shift = -4 end
		if i == 3 and bpm % 10 == 1 then shift = shift - 4 end
		digit.x = x + (i - 1) * 11 + shift
	end
end

function Capsule:setRank(rank)
	if self.isRandom then return end
	local name = type(rank) == "string" and rankNames[rank:upper()] or nil
	if self.rank == name then return end
	self.rank = name
	self.ranking.visible = name ~= nil
	self.sparkle.visible = false
	self.sparkleTime = name == "PERFECTSICK" and 1 or nil
	if name then
		self.ranking.animation:play(name, true)
		self.ranking:updateHitbox()
	end
	self.styledSelected = nil
end

function Capsule:setDifficulty(difficulty)
	self.difficulty = difficulty
	if self.isRandom then return end
	local ratings = self.meta.ratings
	local rating = type(ratings) == "table" and difficulty
		and (ratings[difficulty:lower()] or ratings[difficulty]) or nil
	rating = tonumber(rating)
	self.unknownRating.visible = rating == nil
	for _, digit in ipairs(self.ratingDigits) do digit.visible = rating ~= nil end
	if rating then self:setNumber(self.ratingDigits, math.floor(rating)) end
end

function Capsule:setSelected(selected)
	self.selected = selected == true
	if self.styledSelected == self.selected and self.styledFavorite == self.favorite then return end
	self.styledSelected, self.styledFavorite = self.selected, self.favorite
	self.capsule.animation:play(self.selected and "selected" or "idle")
	self.capsule.offset.x = self.selected and 0 or -5
	self.title.alpha = self.selected and 1 or 0.6
	self.titleGlow.visible = self.selected
	self.titleGlow.alpha = 1
	self.titleTime, self.titleOffset = 0, 0
	self.clipWidth = self.rank and self.favorite and 210 or (self.rank or self.favorite) and 245 or 290
	if self.ranking then
		self.ranking.alpha = self.selected and 1 or 0.7
		self.ranking.color = self.selected and Color.WHITE or {2 / 3, 2 / 3, 2 / 3}
		self.heart.x = self.rank and 370 or 405
		self.heartGlow.x = self.heart.x
		self.heart.alpha = self.selected and 1 or 0.6
		self.heartGlow.alpha = self.selected and 1 or 0
	end
end

function Capsule:setEntrance(elapsed)
	local frame = math.floor(elapsed * 24)
	local scale = entranceScales[math.max(1, math.min(#entranceScales, frame))]
	if frame == 0 then scale = 1 end
	self.capsule.scale:set(0.8 * scale, 0.8 / scale)
end

function Capsule:confirm()
	self.confirmTime = 0
	self.titleTime, self.titleOffset = 0, 0
	if self.icon and self.icon.animation:has("confirm") then self.icon.animation:play("confirm", true) end
end

function Capsule:update(dt)
	Capsule.super.update(self, dt)
	if self.heart then
		for _, heart in ipairs({self.heartGlow, self.heart}) do
			if self.favorite and not heart.visible then heart.animation:play("favorite", true) end
			heart.visible = self.favorite
		end
	end
	self:setSelected(self.selected)
	local overflow = self.title:getWidth() - self.clipWidth
	if self.confirmTime then
		self.confirmTime = self.confirmTime + dt
		local frame = math.min(19, math.floor(self.confirmTime * 24))
		local white = frame % 2 == 0
		self.title.color = white and Color.WHITE or {0.87, 0.87, 0.87}
		self.title.outline.color = white and Color.WHITE or {0.87, 0.87, 0.87}
		self.titleGlow.color = white and Color.WHITE or {0, 0.8, 1}
		local sx, sy = 1, 1
		if frame == 0 then sx, sy = 1.7, 0.2 elseif frame < 3 then sx, sy = 0.4, 1.4 end
		self.title.scale:set(sx, sy)
		self.titleGlow.scale:set(sx, sy)
	elseif self.selected and overflow > 0 then
		self.titleTime = self.titleTime + dt
		if self.titleTime > 0.6 then
			local phase = (self.titleTime - 0.6) % 4.6
			if phase < 2 then
				self.titleOffset = overflow * (1 - math.cos(phase / 2 * math.pi)) / 2
			elseif phase < 2.3 then self.titleOffset = overflow
			elseif phase < 4.3 then
				self.titleOffset = overflow * (1 + math.cos((phase - 2.3) / 2 * math.pi)) / 2
			else self.titleOffset = 0 end
		end
	end
	self.title.offset.x, self.titleGlow.offset.x = self.titleOffset, self.titleOffset
	if self.sparkleTime then
		self.sparkleTime = self.sparkleTime - dt
		if self.sparkleTime <= 0 then
			self.sparkle:setPosition(420 + love.math.random() * 23 - 20,
				41 + love.math.random() * 33 - 29)
			self.sparkle.visible = true
			self.sparkle.animation:play("sparkle", true)
			self.sparkleTime = 1.2 + love.math.random() * 3.3
		end
	end
	for _, part in ipairs(self.parts) do
		if part.active and part.update then part:update(dt) end
	end
end

function Capsule:getWidth() return self.width end

function Capsule:getHeight() return self.height end

function Capsule:_getBoundary()
	return self.x, self.y, self.width, self.height, self.scale.x * self.zoom.x,
		self.scale.y * self.zoom.y, self.origin.x, self.origin.y
end

function Capsule:__render(camera)
	love.graphics.push("all")
	local x, y, angle, sx, sy, ox, oy, kx, ky = self:setupDrawLogic(camera)
	love.graphics.translate(x, y)
	love.graphics.rotate(angle)
	love.graphics.scale(sx, sy)
	love.graphics.shear(kx, ky)
	love.graphics.translate(-ox, -oy)
	for _, part in ipairs(self.parts) do
		if part.visible then
			if part == self.titleGlow then
				glowShader:send("pixelSize", {1 / self.glowCanvas:getWidth(), 1 / self.glowCanvas:getHeight()})
			end
			local titlePart = part == self.title or part == self.titleGlow
			local scissorX, scissorY, scissorW, scissorH
			if titlePart then
				scissorX, scissorY, scissorW, scissorH = love.graphics.getScissor()
				love.graphics.push("all")
				local left, top = x + (self.title.x - 4 - ox) * sx, y + (self.title.y - 5 - oy) * sy
				local right, bottom = x + (self.title.x + self.clipWidth - ox) * sx,
					y + (self.title.y + self.title:getHeight() + 5 - oy) * sy
				love.graphics.intersectScissor(math.min(left, right), math.min(top, bottom),
					math.abs(right - left), math.abs(bottom - top))
			end
			local alpha = part.alpha
			part.alpha = alpha * self.alpha
			part:__render(camera)
			part.alpha = alpha
			if titlePart then
				love.graphics.pop()
				love.graphics.setScissor(scissorX, scissorY, scissorW, scissorH)
			end
		end
	end
	love.graphics.pop()
end

function Capsule:destroy()
	for _, part in ipairs(self.parts) do part:destroy() end
	if self.glowCanvas then self.glowCanvas:release(); self.glowCanvas = nil end
	self.parts = {}
	Capsule.super.destroy(self)
end

return Capsule
