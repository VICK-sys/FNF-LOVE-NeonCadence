local FreeplayState = require "funkin.states.freeplay"
local tests = 0
local function equal(actual, expected)
	assert(actual == expected, "expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function test(name, callback)
	callback()
	tests = tests + 1
	print("PASS " .. name)
end
local function newState(configure)
	resetFreeplayFixtures()
	FreeplayState.lastSong = nil
	FreeplayState.preferredDifficulty = "normal"
	FreeplayState.curDifficulty = 2
	if configure then configure() end
	local state = FreeplayState()
	state:enter()
	return state
end
local function selectSong(state, name)
	for index, song in ipairs(state.songs.members) do
		if song.songName == name then
			state.songs:setSelection(index, true)
			return song
		end
	end
	error("song not found: " .. name)
end
local function selectedDifficulty(state)
	return state.songs:getSelected().diffs[FreeplayState.curDifficulty]:lower()
end
local function meta(song, difficulties)
	return {song = song, displayName = song, difficulties = difficulties,
		icon = "face", color = Color.WHITE, previewStart = 5000, previewEnd = 15000,
		ratings = {}, bpm = 100, composer = "unknown", charter = "unknown", instrumental = ""}
end

test("song lists trim blank lines and deduplicate song identifiers", function()
	local state = newState(function()
		freeplayFixtures.texts.freeplayList = " \r\n alpha \r\n\t\nbeta\r\nalpha\n \n"
	end)
	equal(#state.entries, 2)
	equal(state.entries[1].songName, "alpha")
	equal(state.entries[2].songName, "beta")
	for _, name in ipairs(freeplayFixtures.metaRequests) do
		assert(name:match("%S"), "blank lines must not be passed to the parser")
		equal(name, name:trim())
	end
	equal(#state.songs.members, 3)
	equal(state.songs.members[1].isRandom, true)
end)

test("legacy song lists remain supported", function()
	local state = newState(function()
		freeplayFixtures.texts = {freeplaySonglist = "alpha\n\nbeta\n"}
	end)
	equal(#state.entries, 2)
	equal(state.entries[2].songName, "beta")
end)

test("week lists ignore missing and hidden weeks and accept tuple song names", function()
	local state = newState(function()
		freeplayFixtures.texts = {weekList = "\n week-one \r\nmissing\nhidden\nweek-two\n"}
		freeplayFixtures.json["data/weeks/weeks/week-one"] = {songs = {"alpha", {"beta", "dad"}}}
		freeplayFixtures.json["data/weeks/weeks/hidden"] = {songs = {"hidden"}, hide_fm = true}
		freeplayFixtures.json["data/weeks/weeks/week-two"] = {songs = {"beta", "gamma"}}
	end)
	equal(#state.entries, 3)
	equal(state.entries[1].songName, "alpha")
	equal(state.entries[2].songName, "beta")
	equal(state.entries[3].songName, "gamma")
end)

test("songs without usable difficulties are excluded and difficulty duplicates collapse", function()
	local state = newState(function()
		freeplayFixtures.metas.alpha = meta("alpha", {})
		freeplayFixtures.metas.beta = meta("beta", {"Normal", "normal", "", false, "Expert"})
		freeplayFixtures.metas.gamma = meta("gamma", false)
	end)
	equal(#state.entries, 1)
	equal(state.entries[1].songName, "beta")
	equal(#state.entries[1].diffs, 2)
	equal(state.entries[1].diffs[2], "Expert")
end)

test("empty song lists allow difficulty input and exit without launching", function()
	local state = newState(function() freeplayFixtures.texts.freeplayList = "\r\n \n" end)
	equal(#state.entries, 0)
	equal(#state.songs.members, 0)
	state:changeDiff(1)
	state:openSong(state.songs:getSelected())
	equal(game.nextState, nil)
	controls.actions = {back = true}
	state:update(0.01)
	equal(game.nextState, nil)
	state:update(0.5)
	equal(game.nextState.name, "main-menu")
end)

test("difficulty preference follows names across reordered custom difficulties", function()
	local state = newState(function()
		freeplayFixtures.metas.alpha = meta("alpha", {"Easy", "Normal", "EXPERT"})
		freeplayFixtures.metas.beta = meta("beta", {"expert", "NORMAL"})
		freeplayFixtures.metas.gamma = meta("gamma", {"EASY", "HARD"})
	end)
	selectSong(state, "alpha")
	equal(selectedDifficulty(state), "normal")
	state:changeDiff(1)
	equal(selectedDifficulty(state), "expert")
	selectSong(state, "beta")
	equal(selectedDifficulty(state), "expert")
	selectSong(state, "gamma")
	equal(selectedDifficulty(state), "easy")
	selectSong(state, "beta")
	equal(selectedDifficulty(state), "expert")
	state:openSong(state.songs:getSelected())
	state:update(1.25)
	equal(game.nextState.destination.songName, "beta")
	equal(game.nextState.destination.difficulty:lower(), "expert")
end)

test("rebuilding and revisiting freeplay retain the selected song", function()
	local state = newState()
	selectSong(state, "beta")
	state:rebuildSongs("beta")
	equal(state.songs:getSelected().songName, "beta")
	state:leave()
	local returned = FreeplayState()
	returned:enter()
	equal(returned.songs:getSelected().songName, "beta")
end)

test("filter navigation wraps in carousel order and alphabetizes display names", function()
	local state = newState(function()
		freeplayFixtures.texts.freeplayList = "beta\nalpha\nfirst\ngamma"
		freeplayFixtures.metas.beta = meta("beta", {"normal"})
		freeplayFixtures.metas.beta.displayName = "Banana"
		freeplayFixtures.metas.alpha = meta("alpha", {"normal"})
		freeplayFixtures.metas.alpha.displayName = "apricot"
		freeplayFixtures.metas.first = meta("first", {"normal"})
		freeplayFixtures.metas.first.displayName = "1st Song"
	end)
	equal(state.songs.members[2].songName, "beta")
	selectSong(state, "beta")
	state:toggleFavorite()
	state:changeFilter(1)
	equal(state.filter, "A-B")
	equal(#state.songs.members, 3)
	equal(state.songs.members[2].songName, "alpha")
	equal(state.songs.members[3].songName, "beta")
	equal(state.songs:getSelected().songName, "beta")
	for _, expected in ipairs({"C-D", "E-H", "I-L", "M-N", "O-R", "S", "T", "U-Z", "#"}) do
		state:changeFilter(1)
		equal(state.filter, expected)
	end
	equal(#state.songs.members, 2)
	equal(state.songs.members[2].songName, "first")
	state:changeFilter(1)
	equal(state.filter, "favorites")
	equal(#state.songs.members, 2)
	equal(state.songs.members[2].songName, "beta")
	state:changeFilter(1)
	equal(state.filter, "all")
	equal(state.songs.members[2].songName, "beta")
	state:changeFilter(-1)
	equal(state.filter, "favorites")
end)

test("favorites persist and an empty favorites list has no random entry", function()
	local state = newState()
	selectSong(state, "beta")
	state:toggleFavorite()
	equal(state.favorites.beta, true)
	assert(game.save.data.freeplayFavorites)
	state.filter = "favorites"
	state:rebuildSongs("beta")
	equal(#state.songs.members, 2)
	equal(state.songs:getSelected().songName, "beta")
	state:toggleFavorite()
	equal(state.favorites.beta, nil)
	equal(#state.songs.members, 0)
	state:changeDiff(-1)
	state:openSong(state.songs:getSelected())
	equal(game.nextState, nil)
end)

test("favorites survive reentry without leaking between mods", function()
	local state = newState()
	selectSong(state, "beta")
	state:toggleFavorite()
	state:leave()
	local returned = FreeplayState()
	returned:enter()
	equal(returned.favorites.beta, true)
	equal(returned.favorites, game.save.data.freeplayFavorites.__base)
	returned:leave()
	Mods.currentMod = "test-mod"
	local modState = FreeplayState()
	modState:enter()
	equal(modState.favorites.beta, nil)
	selectSong(modState, "alpha")
	modState:toggleFavorite()
	equal(game.save.data.freeplayFavorites["test-mod"].alpha, true)
	equal(game.save.data.freeplayFavorites.__base.alpha, nil)
end)

test("random launches a real song from the current filtered list", function()
	local state = newState()
	selectSong(state, "beta")
	state:toggleFavorite()
	state.filter = "favorites"
	state:rebuildSongs()
	local random = state.songs.members[1]
	equal(random.isRandom, true)
	state.songs:setSelection(1, true)
	state:openSong(random)
	state:update(1.25)
	equal(game.nextState.destination.songName, "beta")
	equal(game.nextState.destination.difficulty:lower(), "normal")
	equal(PlayState.META.song, "beta")
	equal(PlayState.storyMode, false)
end)

test("random excludes songs lacking the chosen difficulty", function()
	local state = newState(function()
		freeplayFixtures.metas.alpha = meta("alpha", {"easy", "normal"})
		freeplayFixtures.metas.beta = meta("beta", {"NORMAL", "EXPERT"})
		freeplayFixtures.metas.gamma = meta("gamma", {"normal", "hard"})
	end)
	selectSong(state, "beta")
	state:changeDiff(1)
	state.songs:setSelection(1, true)
	equal(selectedDifficulty(state), "expert")
	state:openSong(state.songs:getSelected())
	state:update(1.25)
	equal(game.nextState.destination.songName, "beta")
	equal(game.nextState.destination.difficulty:lower(), "expert")
end)

test("shift enter opens the selected difficulty in the chart editor", function()
	local state = newState()
	selectSong(state, "alpha")
	state:changeDiff(1)
	game.keys.pressed.SHIFT = true
	state:openSong(state.songs:getSelected())
	equal(game.nextState.name, "charting")
	equal(PlayState.loaded.songName, "alpha")
	equal(PlayState.loaded.difficulty:lower(), "hard")
end)

test("confirmation keeps the chosen song fixed and starts gameplay only once", function()
	local state = newState()
	local row = selectSong(state, "beta")
	state:updatePreview(1)
	local preview = state.previewSource
	local transitions, switchState = 0, game.switchState
	game.switchState = function(destination)
		transitions = transitions + 1
		switchState(destination)
	end
	state:openSong(row)
	equal(game.nextState, nil)
	equal(row.confirmed, true)
	equal(preview.released, true)
	equal(state.previewSource, nil)
	state:openSong(state.songs.members[2])
	game.keys.justPressed = {F = true, E = true, END = true, P = true}
	game.mouse.wheel = 1
	controls.actions = {accept = true, back = true}
	state.throttles.right.check = function() return true end
	state.songs.throttles[1].check = function() return true end
	state:update(0.8)
	equal(game.nextState, nil)
	equal(state.songs:getSelected(), row)
	equal(state.filter, "all")
	equal(state.favorites.beta, nil)
	equal(state.previewEnabled, true)
	equal(state.difficulty:lower(), "normal")
	state:update(0.45)
	equal(game.nextState.destination.songName, "beta")
	equal(game.nextState.destination.difficulty:lower(), "normal")
	equal(transitions, 1)
	state:update(1)
	equal(transitions, 1)
	equal(state.previewSource, nil)
end)

test("back transition locks selection and releases previews before returning", function()
	local state = newState()
	local row = selectSong(state, "alpha")
	state:updatePreview(1)
	local preview = state.previewSource
	controls.actions = {back = true}
	state:update(0.01)
	equal(game.nextState, nil)
	equal(preview.released, true)
	equal(state.songs.lock, true)
	controls.actions = {accept = true}
	game.keys.justPressed.E = true
	game.mouse.wheel = 1
	state:update(0.25)
	equal(state.songs:getSelected(), row)
	equal(state.filter, "all")
	equal(game.nextState, nil)
	state:update(0.3)
	equal(game.nextState.name, "main-menu")
	equal(freeplayFixtures.menuMusicCalls, 1)
end)

test("week capsule metadata follows explicit song lists and custom level titles", function()
	local state = newState(function()
		freeplayFixtures.items = {"week1.json", "weekend1.json", "customCollab2.json"}
		freeplayFixtures.json["data/weeks/weeks/week1"] = {songs = {"alpha"}}
		freeplayFixtures.json["data/weeks/weeks/weekend1"] = {songs = {{"beta", "pico"}}}
		freeplayFixtures.json["data/weeks/weeks/customCollab2"] = {
			songs = {"gamma"}, capsule = {name = "SP. COLLAB 2", offsets = {3, -2}}
		}
	end)
	equal(selectSong(state, "alpha").weekName, "week 1")
	equal(selectSong(state, "beta").weekName, "weekend 1")
	local custom = selectSong(state, "gamma")
	equal(custom.weekName, "SP. COLLAB 2")
	equal(custom.weekOffsets[1], 3)
	equal(custom.weekOffsets[2], -2)
end)

test("main menu opens and resumes the same menu without a state transition", function()
	resetFreeplayFixtures()
	local MainMenu = require "funkin.states.mainmenu"
	local previousFreeplay, previousFlicker, previousTween = _G.FreeplayState, Flicker, Tween
	_G.FreeplayState = FreeplayState
	local flickers = {}
	Flicker = function(_, _, _, _, _, callback)
		local flicker = {completionCallback = callback}
		flickers[#flickers + 1] = flicker
		return flicker
	end
	Tween = {tween = function() error("Main menu items must stay visible below Freeplay") end}
	local menu = MainMenu()
	menu.menuBg = {loadTexture = function() end}
	menu.menuList = MenuList(nil, false)
	menu.menuList:add({ID = 1, alpha = 1})
	menu.menuList:add({ID = 2, alpha = 1})
	menu.menuList.curSelected = 2
	menu:enterSelection("freeplay")
	flickers[1].completionCallback()
	flickers[2].completionCallback()
	local freeplay = menu.substate
	assert(freeplay and freeplay.parent == menu)
	equal(game.nextState, nil)
	equal(menu.persistentDraw, true)
	equal(menu.persistentUpdate, false)
	equal(menu.menuList.lock, true)
	equal(#game.cameras.list, 1)
	freeplay.bg.ready = true
	freeplay:update(0)
	equal(menu.persistentDraw, false)
	controls.actions = {back = true}
	freeplay:update(0.1)
	equal(menu.persistentDraw, true)
	equal(menu.substate, freeplay)
	controls.actions = {}
	freeplay:update(0.5)
	equal(menu.substate, nil)
	equal(menu.menuList.lock, false)
	equal(menu.selectedSomethin, false)
	equal(menu.menuList.curSelected, 2)
	equal(freeplay.script.closed, true)
	equal(#game.cameras.list, 0)
	equal(game.nextState, nil)
	_G.FreeplayState, Flicker, Tween = previousFreeplay, previousFlicker, previousTween
end)

test("launching from the overlay bypasses its parent's default wipe", function()
	local state = newState()
	state.parent = {persistentDraw = true, skipTransOut = false}
	state:openSong(selectSong(state, "beta"))
	state:update(1.25)
	equal(state.parent.skipTransOut, true)
	equal(game.nextState.destination.songName, "beta")
	local editor = newState()
	editor.parent = {skipTransOut = false}
	game.keys.pressed.SHIFT = true
	editor:openSong(selectSong(editor, "alpha"))
	equal(editor.parent.skipTransOut, true)
	equal(game.nextState.name, "charting")
end)

test("preview debounce drops superseded selections and loops the metadata range", function()
	local state = newState()
	selectSong(state, "alpha")
	local before = #freeplayFixtures.loadedMusic
	state:updatePreview(0.1)
	equal(#freeplayFixtures.loadedMusic, before)
	selectSong(state, "beta")
	state:updatePreview(0.2)
	equal(#freeplayFixtures.loadedMusic, before)
	state:updatePreview(0.1)
	equal(#freeplayFixtures.loadedMusic, before + 1)
	assert(game.sound.music.asset.name:match("^beta"))
	equal(game.sound.music.playing, true)
	equal(game.sound.music.time, 5)
	game.sound.music.time = 16
	state:updatePreview(0.1)
	equal(game.sound.music.time, 5)
end)

test("preview toggles release cloned sources while keeping cached audio intact", function()
	local state = newState()
	selectSong(state, "alpha")
	state:updatePreview(1)
	local preview, music = freeplayFixtures.clones[1], game.sound.music
	game.keys.justPressed.P = true
	state:update(0)
	equal(preview.stopped, true)
	equal(preview.released, true)
	equal(preview.original.released, nil)
	equal(music.playing, false)
	equal(state.previewEnabled, false)
	game.keys.justPressed.P = nil
	selectSong(state, "beta")
	state:updatePreview(1)
	equal(#freeplayFixtures.clones, 1)
	game.keys.justPressed.P = true
	state:update(1)
	equal(#freeplayFixtures.clones, 2)
	equal(game.sound.music.asset.name, "beta")
end)

test("missing preview audio leaves song selection usable", function()
	local state = newState(function() freeplayFixtures.audio.alpha = false end)
	selectSong(state, "alpha")
	state:updatePreview(1)
	equal(#freeplayFixtures.clones, 0)
	selectSong(state, "beta")
	state:updatePreview(1)
	equal(#freeplayFixtures.clones, 1)
	equal(game.sound.music.asset.name, "beta")
end)

test("leave never stops replacement gameplay music", function()
	local state = newState()
	selectSong(state, "alpha")
	state:updatePreview(1)
	local preview = freeplayFixtures.clones[1]
	game.sound.playMusic("gameplay", 1, false)
	state:leave()
	equal(preview.released, true)
	equal(game.sound.music.asset, "gameplay")
	equal(game.sound.music.playing, true)
	equal(freeplayFixtures.menuMusicCalls, 0)
end)

test("leaving releases preview and all keyed throttles", function()
	local state = newState()
	selectSong(state, "alpha")
	state:updatePreview(1)
	local preview = game.sound.music
	local throttles = state.throttles
	local songThrottles = state.songs.throttles
	state:leave()
	equal(preview.playing, false)
	equal(state.script.closed, true)
	for _, throttle in pairs(throttles) do equal(throttle.destroyed, true) end
	for _, throttle in pairs(songThrottles) do equal(throttle.destroyed, true) end
	local loaded = #freeplayFixtures.loadedMusic
	state:updatePreview(1)
	equal(#freeplayFixtures.loadedMusic, loaded)
end)

test("cancelled scripted creation still closes the script on leave", function()
	local state = newState(function() freeplayFixtures.cancelCreate = true end)
	equal(state.notCreated, true)
	state:leave()
	equal(state.script.closed, true)
end)

test("real parser carries V-Slice metadata into song previews and gameplay", function()
	local state = newState(function()
		freeplayFixtures.texts.freeplayList = "alpha"
		freeplayFixtures.json["songs/alpha/meta"] = {
			version = "2.2.2", songName = "Alpha Song", artist = "Composer",
			timeChanges = {{t = 0, bpm = 186}},
			playData = {difficulties = {"normal", "Erect"}, ratings = {normal = 3, erect = 9},
				album = "volume2", previewStart = 7000, previewEnd = 11500,
				characters = {instrumental = "alt"}, freeplayOrder = 3}
		}
		Parser = require "funkin.backend.parser"
	end)
	local song = selectSong(state, "alpha")
	equal(song.displayName, "Alpha Song")
	equal(song.meta.album, "volume2")
	equal(song.meta.composer, "Composer")
	equal(song.meta.ratings.erect, 9)
	equal(song.meta.bpm, 186)
	equal(song.meta.freeplayOrder, 3)
	state:updatePreview(1)
	equal(game.sound.music.asset.name, "alpha-alt")
	equal(game.sound.music.time, 7)
	game.sound.music.time = 12
	state:updatePreview(0)
	equal(game.sound.music.time, 7)
	state:changeDiff(1)
	state:openSong(song)
	state:update(1.25)
	equal(game.nextState.destination.difficulty:lower(), "erect")
	equal(PlayState.META, song.meta)
end)

test("real parser preserves legacy fields and supplies missing preview defaults", function()
	local state = newState(function()
		freeplayFixtures.texts.freeplayList = "alpha\nbeta"
		freeplayFixtures.json["songs/alpha/meta"] = {
			displayName = "Legacy Song", difficulties = {"Normal"}, composer = "Legacy Composer",
			album = "volume1", ratings = {normal = 4}, instrumental = "legacy", bpm = 123
		}
		Parser = require "funkin.backend.parser"
	end)
	local song = selectSong(state, "alpha")
	equal(song.meta.album, "volume1")
	equal(song.meta.composer, "Legacy Composer")
	equal(song.meta.ratings.normal, 4)
	equal(song.meta.bpm, 123)
	state:updatePreview(1)
	equal(game.sound.music.asset.name, "alpha-legacy")
	equal(game.sound.music.time, 0)
	local fallback = selectSong(state, "beta")
	equal(fallback.meta.previewStart, 0)
	equal(fallback.meta.previewEnd, 15000)
	equal(fallback.meta.instrumental, "")
	equal(fallback.meta.bpm, 100)
	equal(type(fallback.meta.ratings), "table")
end)

test("real throttles release keyed freeplay controls and can be reused", function()
	local graphics = love.graphics
	love.graphics = graphics or {}
	require "loxel.lib.override"
	love.graphics = graphics
	local realThrottle = require "funkin.backend.throttle"
	local state = newState(function() Throttle = realThrottle end)
	equal(#realThrottle.list, 4)
	assert(state.throttles.left and state.throttles.right)
	state:leave()
	equal(#realThrottle.list, 0)
	local input = {held = true}
	local reused = realThrottle:make({function(owner, action)
		equal(action, "ui_left")
		return owner.held
	end, input, "ui_left"})
	equal(#realThrottle.list, 1)
	equal(realThrottle.list[1], reused)
	realThrottle:update(0.1)
	equal(reused:check(), true)
	input.held = false
	realThrottle:update(0.1)
	equal(reused:check(), false)
	reused:destroy()
	equal(#realThrottle.list, 0)
end)

test("legacy numeric highscores load without invented clear data", function()
	newState()
	local highscore = require "funkin.backend.gameplay.highscore"
	game.save.data.scores = {songs = {["alpha-normal"] = 9000}, weeks = {["week1-normal"] = 25000}}
	highscore.load()
	equal(highscore.getScore("alpha", "Normal"), 9000)
	equal(highscore.getWeekScore("week1", "Normal"), 25000)
	equal(highscore.getCompletion("alpha", "normal"), 0)
	equal(highscore.getRank("alpha", "normal"), nil)
	highscore.saveScore("alpha", 8000, "normal")
	equal(highscore.getScore("alpha", "normal"), 9000)
	equal(highscore.getRank("alpha", "normal"), nil)
	equal(game.save.data.scores.songs["alpha-normal"], 9000)
end)

test("clear percentages and ranks match base game judgement thresholds", function()
	newState()
	local highscore = require "funkin.backend.gameplay.highscore"
	game.save.data.scores = {songs = {}, weeks = {}}
	highscore.load()
	local cases = {
		{100, 0, 0, 1, "PERFECT_GOLD"},
		{99, 1, 0, 1, "PERFECT"},
		{90, 1, 1, 0.9, "EXCELLENT"},
		{90, 0, 1, 0.89, "GREAT"},
		{80, 0, 0, 0.8, "GREAT"},
		{79, 0, 0, 0.79, "GOOD"},
		{60, 0, 0, 0.6, "GOOD"},
		{59, 0, 0, 0.59, "SHIT"},
		{0, 0, 100, 0, "SHIT"}
	}
	for index, case in ipairs(cases) do
		local song = "rank-" .. index
		highscore.saveScore(song, index, "normal", {
			sick = case[1], good = case[2], missed = case[3], totalNotes = 100
		})
		equal(highscore.getCompletion(song, "normal"), case[4])
		equal(highscore.getRank(song, "normal"), case[5])
	end
end)

test("best rank and completion persist independently of the numeric score", function()
	newState()
	local highscore = require "funkin.backend.gameplay.highscore"
	game.save.data.scores = {songs = {}, weeks = {}}
	highscore.load()
	highscore.saveScore("alpha", 10000, "normal", {sick = 80, totalNotes = 100})
	local improved = {sick = 95, totalNotes = 100}
	highscore.saveScore("alpha", 9000, "normal", improved)
	improved.sick = 0
	equal(highscore.getScore("alpha", "normal"), 10000)
	equal(highscore.getCompletion("alpha", "normal"), 0.95)
	equal(highscore.getRank("alpha", "normal"), "EXCELLENT")
	highscore.saveScore("alpha", 12000, "normal", {sick = 90, totalNotes = 100})
	equal(highscore.getScore("alpha", "normal"), 12000)
	equal(highscore.getCompletion("alpha", "normal"), 0.95)
	highscore.saveScore("alpha", 12000, "normal", {sick = 100, totalNotes = 100})
	equal(highscore.getRank("alpha", "normal"), "PERFECT_GOLD")
	highscore.saveScore("alpha", 13000, "normal", {sick = 90, good = 10, totalNotes = 100})
	equal(highscore.getRank("alpha", "normal"), "PERFECT_GOLD")
	equal(highscore.getScore("alpha", "normal"), 13000)
	equal(highscore.getRank("alpha", "hard"), nil)
	highscore.load()
	equal(highscore.getRank("alpha", "normal"), "PERFECT_GOLD")
end)

test("empty and invalid tallies cannot generate ranks or replace real clears", function()
	newState()
	local highscore = require "funkin.backend.gameplay.highscore"
	game.save.data.scores = {songs = {}, weeks = {}}
	highscore.load()
	highscore.saveScore("empty", 0, "normal", {totalNotes = 0})
	equal(highscore.getCompletion("empty", "normal"), 0)
	equal(highscore.getRank("empty", "normal"), nil)
	highscore.saveScore("alpha", 2000, "normal", {sick = 20, totalNotes = 20})
	for _, invalid in ipairs({{totalNotes = 0}, {totalNotes = -1},
		{totalNotes = math.huge}, {totalNotes = 20, sick = -1}, {totalNotes = 20, sick = 0 / 0}}) do
		highscore.saveScore("alpha", 2001, "normal", invalid)
		equal(highscore.getRank("alpha", "normal"), "PERFECT_GOLD")
	end
	equal(highscore.getScore("alpha", "normal"), 2001)
end)

print(tests .. " FreeplayState regression checks passed")
