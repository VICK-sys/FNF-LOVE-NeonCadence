local Highscore = {
	scores = {
		songs = {},
		weeks = {},
		tallies = {}
	}
}

local rankValues = {SHIT = 0, GOOD = 1, GREAT = 2, EXCELLENT = 3, PERFECT = 4, PERFECT_GOLD = 5}

local function completion(tallies)
	if not tallies or not tallies.totalNotes or tallies.totalNotes <= 0 then return 0 end
	return math.max(0, math.min(1, (tallies.sick + tallies.good - tallies.missed) / tallies.totalNotes))
end

local function rank(tallies)
	if not tallies or not tallies.totalNotes or tallies.totalNotes <= 0 then return nil end
	if tallies.sick == tallies.totalNotes then return "PERFECT_GOLD" end
	local amount = completion(tallies)
	if amount == 1 then return "PERFECT" end
	if amount >= 0.9 then return "EXCELLENT" end
	if amount >= 0.8 then return "GREAT" end
	if amount >= 0.6 then return "GOOD" end
	return "SHIT"
end

local function copyTallies(tallies)
	if type(tallies) ~= "table" then return nil end
	local result = {}
	for _, field in ipairs({"sick", "good", "bad", "shit", "missed", "totalNotes", "totalNotesHit"}) do
		local value = tonumber(tallies[field]) or 0
		if value ~= value or value == math.huge or value < 0 then return nil end
		result[field] = math.floor(value)
	end
	if result.totalNotes <= 0 then return nil end
	return result
end

function Highscore.saveScore(song, score, diff, tallies)
	local formatSong = paths.formatToSongPath(song) .. '-' .. diff:lower()

	if Highscore.scores.songs[formatSong] then
		if Highscore.scores.songs[formatSong] < score then
			Highscore.scores.songs[formatSong] = score
		end
	else
		Highscore.scores.songs[formatSong] = score
	end
	Highscore.scores.tallies = Highscore.scores.tallies or {}
	local newTallies = copyTallies(tallies)
	if newTallies then
		local previous = Highscore.scores.tallies[formatSong]
		local previousRank = rank(previous)
		if not previousRank or (rankValues[rank(newTallies)] >= rankValues[previousRank]
			and completion(newTallies) >= completion(previous)) then
			Highscore.scores.tallies[formatSong] = newTallies
		end
	end
	game.save.data.scores = Highscore.scores
end

function Highscore.saveWeekScore(week, score, diff)
	local formatWeek = week .. '-' .. diff:lower()

	if Highscore.scores.weeks[formatWeek] then
		if Highscore.scores.weeks[formatWeek] < score then
			Highscore.scores.weeks[formatWeek] = score
		end
	else
		Highscore.scores.weeks[formatWeek] = score
	end
	game.save.data.scores = Highscore.scores
end

function Highscore.getScore(song, diff)
	local formatSong = paths.formatToSongPath(song) .. '-' .. diff:lower()

	if Highscore.scores.songs[formatSong] == nil then
		Highscore.scores.songs[formatSong] = 0
	end

	return Highscore.scores.songs[formatSong]
end

function Highscore.getWeekScore(week, diff)
	local formatWeek = week .. '-' .. diff:lower()

	if Highscore.scores.weeks[formatWeek] == nil then
		Highscore.scores.weeks[formatWeek] = 0
	end

	return Highscore.scores.weeks[formatWeek]
end

function Highscore.getCompletion(song, diff)
	local key = paths.formatToSongPath(song) .. '-' .. diff:lower()
	return completion(Highscore.scores.tallies and Highscore.scores.tallies[key])
end

function Highscore.getRank(song, diff)
	local key = paths.formatToSongPath(song) .. '-' .. diff:lower()
	return rank(Highscore.scores.tallies and Highscore.scores.tallies[key])
end

function Highscore.load()
	if game.save.data.scores then
		Highscore.scores = game.save.data.scores
	end
	Highscore.scores.songs = Highscore.scores.songs or {}
	Highscore.scores.weeks = Highscore.scores.weeks or {}
	Highscore.scores.tallies = Highscore.scores.tallies or {}
	for key, tallies in pairs(Highscore.scores.tallies) do
		Highscore.scores.tallies[key] = copyTallies(tallies)
	end
end

return Highscore
