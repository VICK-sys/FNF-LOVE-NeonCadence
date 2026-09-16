local animations = {
	["weekend-1-cockgun"] = "cock",
	["weekend-1-firegun"] = "shoot"
}
local specialAnimations = {cock = true, shoot = true, shootMISS = true}

local function playSpecial(event, name)
	event:cancelAnim()
	self.lastHit = -math.huge
	self:playAnim(name, true, nil, true)
end

function onNoteHit(event)
	if event.cancelled or event.character ~= self or event.note.wasGoodHit then return end
	local name = animations[event.note.type]
	if name then
		playSpecial(event, name)
	elseif self.waitingFinish and specialAnimations[self.anim.curAnim.name] then
		event:cancelAnim()
	end
end

function onNoteMiss(event)
	if event.cancelled or event.character ~= self or event.note.tooLate then return end
	if event.note.type == "weekend-1-firegun" then
		playSpecial(event, "shootMISS")
	elseif event.note.type == "weekend-1-cockgun" or
		(self.waitingFinish and specialAnimations[self.anim.curAnim.name]) then
		event:cancelAnim()
	end
end
