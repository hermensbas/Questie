-- addon/folder name
QuestieCompat.addonName = "Questie-335"

QuestieCompat.NOOP = function() end
QuestieCompat.NOOP_MT = {__index = function() return QuestieCompat.NOOP end}

QuestieCompat.frame = CreateFrame("Frame")
QuestieCompat.frame:RegisterEvent("ADDON_LOADED")
QuestieCompat.frame:SetScript("OnEvent", function(self, event, ...)
    QuestieCompat[event](self, event, ...)
end)

-- current expansion level (https://wowpedia.fandom.com/wiki/WOW_PROJECT_ID)
QuestieCompat.WOW_PROJECT_CLASSIC = 2
QuestieCompat.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
QuestieCompat.WOW_PROJECT_WRATH_CLASSIC = 11
QuestieCompat.WOW_PROJECT_ID = QuestieCompat.WOW_PROJECT_WRATH_CLASSIC

-- check for a specific type of group
QuestieCompat.LE_PARTY_CATEGORY_HOME = 1 -- home-realm parties
QuestieCompat.LE_PARTY_CATEGORY_INSTANCE = 2 -- instance-specific groups

-- Date stuff
QuestieCompat.CALENDAR_WEEKDAY_NAMES = {
	WEEKDAY_SUNDAY,
	WEEKDAY_MONDAY,
	WEEKDAY_TUESDAY,
	WEEKDAY_WEDNESDAY,
	WEEKDAY_THURSDAY,
	WEEKDAY_FRIDAY,
	WEEKDAY_SATURDAY,
};

-- month names show up differently for full date displays in some languages
QuestieCompat.CALENDAR_FULLDATE_MONTH_NAMES = {
	FULLDATE_MONTH_JANUARY,
	FULLDATE_MONTH_FEBRUARY,
	FULLDATE_MONTH_MARCH,
	FULLDATE_MONTH_APRIL,
	FULLDATE_MONTH_MAY,
	FULLDATE_MONTH_JUNE,
	FULLDATE_MONTH_JULY,
	FULLDATE_MONTH_AUGUST,
	FULLDATE_MONTH_SEPTEMBER,
	FULLDATE_MONTH_OCTOBER,
	FULLDATE_MONTH_NOVEMBER,
	FULLDATE_MONTH_DECEMBER,
};

-- https://wago.tools/db2/ChrRaces?build=3.4.3.52237
QuestieCompat.ChrRaces = {
	Human = 1,
	Orc = 2,
	Dwarf = 3,
	NightElf = 4,
	Scourge = 5,
	Tauren = 6,
	Gnome = 7,
	Troll = 8,
	Goblin = 9,
	BloodElf = 10,
	Draenei = 11,
	FelOrc = 12,
	Naga_ = 13,
	Broken = 14,
	Skeleton = 15,
	Vrykul = 16,
	Tuskarr = 17,
	ForestTroll = 18,
	Taunka = 19,
	NorthrendSkeleton = 20,
	IceTroll = 21,
}

-- https://wago.tools/db2/ChrClasses?build=3.4.3.52237
QuestieCompat.ChrClasses = {
	WARRIOR = 1,
	PALADIN = 2,
	HUNTER = 3,
	ROGUE = 4,
	PRIEST = 5,
	DEATHKNIGHT = 6,
	SHAMAN = 7,
	MAGE = 8,
	WARLOCK = 9,
	DRUID = 11,
}

local inactiveTimers = {}

local function timerCancel(self)
    if not inactiveTimers[self] then
        self:GetParent():Stop()
        inactiveTimers[self] = true
    end
end

local function timerOnFinished(self)
    local id = self.id
    self.callback(self)

    --Make sure timer wasn't cancelled during the callback and used again
    if id == self.id then
        if self.iterations > 0 then
            self.iterations = self.iterations - 1
            if self.iterations == 0 then
                self:Cancel()
            end
        end
    end
end

QuestieCompat.C_Timer = {
    -- Schedules a (repeating) timer that can be canceled. (https://wowpedia.fandom.com/wiki/API_C_Timer.NewTimer)
    NewTicker = function(duration, callback, iterations)
        local timer = next(inactiveTimers)
        if timer then
        	inactiveTimers[timer] = nil
        else
        	local anim = QuestieCompat.frame:CreateAnimationGroup()
        	timer = anim:CreateAnimation()
            timer.Cancel = timerCancel
        	timer:SetScript("OnFinished", timerOnFinished)
        end

        if duration < 0.01 then duration = 0.01 end
        timer:SetDuration(duration)

        timer.callback = callback
        timer.iterations = iterations or -1
        timer.id = debugprofilestop()

        local anim = timer:GetParent()
        anim:SetLooping("REPEAT")
        anim:Play()

        return timer
    end,
    -- Schedules a timer. (https://wowpedia.fandom.com/wiki/API_C_Timer.After)
    After = function(duration, callback)
        return QuestieCompat.C_Timer.NewTicker(duration, callback, 1)
    end
}

local mapIdToUiMapId = {}
for uiMapId, data in pairs(QuestieCompat.UiMapData) do
    mapIdToUiMapId[data.mapID] = uiMapId
end

function QuestieCompat.GetCurrentUiMapID()
    local mapID = GetCurrentMapAreaID()
    if mapID == 0 then -- both the "Cosmic" and "Azeroth" maps return a mapID of 0
        mapID = GetCurrentMapContinent()
    end
    return mapIdToUiMapId[mapID + GetCurrentMapDungeonLevel()/10]
end

function QuestieCompat.GetCurrentPlayerPosition()
	local x, y = GetPlayerMapPosition("player");
	if ( x <= 0 and y <= 0 ) then
		if ( WorldMapFrame:IsVisible() ) then
			-- we know there is a visible world map, so don't cause
			-- WORLD_MAP_UPDATE events by changing map zoom
			return;
		end
		SetMapToCurrentZone();
		x, y = GetPlayerMapPosition("player");
		if ( x <= 0 and y <= 0 ) then
			-- attempt to zoom out once - logic copied from WorldMapZoomOutButton_OnClick()
				if ( ZoomOut() ) then
					-- do nothing
				elseif ( GetCurrentMapZone() ~= WORLDMAP_WORLD_ID ) then
					SetMapZoom(GetCurrentMapContinent());
				else
					SetMapZoom(WORLDMAP_WORLD_ID);
				end
			x, y = GetPlayerMapPosition("player");
			if ( x <= 0 and y <= 0 ) then
				-- we are in an instance without a map or otherwise off map
				return;
			end
		end
	end
	return QuestieCompat.GetCurrentUiMapID(), x, y;
end

QuestieCompat.C_Map = {
    -- Returns map information.
	-- https://wowpedia.fandom.com/wiki/API_C_Map.GetMapInfo
	GetMapInfo = function(uiMapID)
        if QuestieCompat.UiMapData[uiMapID] then
            return QuestieCompat.UiMapData[uiMapID]
        end
	end,
    -- Returns a map subzone name.
    -- https://wowpedia.fandom.com/wiki/API_C_Map.GetAreaInfo
	GetAreaInfo = function(areaID)
        return
	end,
    -- Returns the current UI map for the given unit.
    -- https://wowpedia.fandom.com/wiki/API_C_Map.GetBestMapForUnit
	GetBestMapForUnit = function(unit)
        if unit == "player" then
            return QuestieCompat.GetCurrentPlayerPosition()
        end
	end,
    -- Translates a map position to a world map position.
    -- https://wowpedia.fandom.com/wiki/API_C_Map.GetWorldPosFromMapPos
	GetWorldPosFromMapPos = function(uiMapID, mapPos)
        local x, y, instanceID = QuestieCompat.HBD:GetWorldCoordinatesFromZone(mapPos.x, mapPos.y, uiMapID)
        return instanceID, {x = x, y = y}
	end,
}

QuestieCompat.C_Calendar = {
    -- Returns information about the calendar month by offset.
	-- https://wowpedia.fandom.com/wiki/API_C_Calendar.GetMonthInfo
	GetMonthInfo = function(offsetMonths)
		local month, year, numdays, firstday = CalendarGetMonth(offsetMonth);
		return {
			month = month,
			year = year,
			numDays = numdays,
			firstWeekday = firstday,
		}
	end,
}

QuestieCompat.C_DateAndTime = {
    -- Returns the realm's current date and time.
	-- https://wowpedia.fandom.com/wiki/API_C_DateAndTime.GetCurrentCalendarTime
	GetCurrentCalendarTime = function()
		local weekday, month, day, year = CalendarGetDate();
		local hours, minutes = GetGameTime()
		return {
			year = year,
			month = month,
			monthDay = day,
			weekday = weekday,
			hour = hours,
			minute = minutes
		}
	end
}

QuestieCompat.C_QuestLog = {
	-- Returns info for the objectives of a quest. (https://wowpedia.fandom.com/wiki/API_C_QuestLog.GetQuestObjectives)
	GetQuestObjectives = function(questID, questLogIndex)
		local questObjectives = {}
        if questLogIndex then
		    local numObjectives = GetNumQuestLeaderBoards(questLogIndex);
		    for i = 1, numObjectives do
		    	-- https://wowpedia.fandom.com/wiki/API_GetQuestLogLeaderBoard
		    	local description, objectiveType, isCompleted = GetQuestLogLeaderBoard(i, questLogIndex);
		    	local objectiveName, numFulfilled, numRequired = string.match(description, "(.*):%s*([%d]+)%s*/%s*([%d]+)");
		    	table.insert(questObjectives, {
		    		text = description,
		    		type = objectiveType,
		    		finished = isCompleted and true or false,
		    		numFulfilled = tonumber(numFulfilled),
		    		numRequired = tonumber(numRequired),
		    	})
		    end
        end
		return questObjectives -- can be empty for quests without objectives
	end,
    GetMaxNumQuestsCanAccept = function()
        return MAX_QUESTLOG_QUESTS
    end,
}

-- Can't find anything about this function.
-- Apparently, it returns true when quest data is ready to be queried.
function QuestieCompat.HaveQuestData(questID)
	return true
end

-- https://wowpedia.fandom.com/wiki/API_GetQuestLogTitle?oldid=2214753
-- Returns information about a quest in your quest log.
-- Patch 6.0.2 (2014-10-14): Removed returns 'questTag'.
function QuestieCompat.GetQuestLogTitle(questLogIndex)
    local questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed,
        isComplete, isDaily, questID = GetQuestLogTitle(questLogIndex);
    return questTitle, level, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily and 2 or 1, questID
end

local MAX_QUEST_LOG_INDEX = 75
-- Returns the current quest log index of a quest by its ID.
-- https://wowpedia.fandom.com/wiki/API_GetQuestLogIndexByID
function QuestieCompat.GetQuestLogIndexByID(questId)
    for questLogIndex = 1, MAX_QUEST_LOG_INDEX do
        local title, _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(questLogIndex)
        if (not title) then
            break -- We exceeded the valid quest log entries
        end
        if (not isHeader) then
            if (questId == id) then
                return questLogIndex
            end
        end
    end
end

-- https://wowpedia.fandom.com/wiki/API_GetQuestLogRewardMoney
-- Returns the amount of money rewarded for a quest.
function QuestieCompat.GetQuestLogRewardMoney(questID)
    local rewardMoney = QuestieCompat.RewardMoney[questID] or 0
	local rewardMoneyDifficulty = QuestieCompat.RewardMoneyDifficulty[questID] or 0

    if rewardMoney < 0 then -- required money
        return rewardMoney
    end

    local QuestiePlayer = QuestieLoader:ImportModule("QuestiePlayer")
    local playerLevel = QuestiePlayer.GetPlayerLevel()
    if playerLevel > 0 and rewardMoneyDifficulty > 0 then
        rewardMoney = QuestieCompat.QuestMoneyReward[playerLevel][rewardMoneyDifficulty]
    end

    -- https://wowpedia.fandom.com/wiki/Quest?oldid=1035002 Formula is XP gained * 6c
    if QuestiePlayer.IsMaxLevel() then
        local QuestXP = QuestieLoader:ImportModule("QuestXP")
        local xpReward = QuestXP:GetQuestLogRewardXP(questID, true)
        if xpReward > 0 then
            rewardMoney = rewardMoney + xpReward*6
        end
    end

    return rewardMoney
end

-- Returns a list of quests the character has completed in its lifetime.
-- https://wowpedia.fandom.com/wiki/API_GetQuestsCompleted
function QuestieCompat.GetQuestsCompleted()
    if not Questie.db.char.complete then
        Questie.db.char.complete = {}
    end
    QueryQuestsCompleted()
    return Questie.db.char.complete
end

-- Fires when the data requested by QueryQuestsCompleted() is available.
-- https://wowpedia.fandom.com/wiki/QUEST_QUERY_COMPLETE
function QuestieCompat:QUEST_QUERY_COMPLETE(event)
    GetQuestsCompleted(Questie.db.char.complete)
end

-- https://wowpedia.fandom.com/wiki/API_IsQuestFlaggedCompleted
-- Determine if a quest has been completed.
function QuestieCompat.IsQuestFlaggedCompleted(questID)
	return Questie.db.char.complete[questID] or false
end

local questTagIdToName = {
	[1] = "Group",
	[41] = "PvP",
	[62] = "Raid",
	[81] = "Dungeon",
	[82] = "World Event",
	[83] = "Legendary",
	[84] = "Escort",
	[85] = "Heroic",
}

-- Retrieves tag information about the quest.
-- https://wowpedia.fandom.com/wiki/API_GetQuestTagInfo
function QuestieCompat.GetQuestTagInfo(questId)
    local tagId = QuestieCompat.QuestTagId[questId]
	if tagId then
		return tagId, questTagIdToName[tagId]
	end
end

-- https://wowpedia.fandom.com/wiki/API_UnitAura?oldid=2681338
-- Returns the buffs/debuffs for the unit.
-- an alias for UnitAura(unit, index, "HELPFUL"), returning only buffs.
-- Patch 8.0.1 (2018-07-17): Removed 'rank' return value.
function QuestieCompat.UnitBuff(unit, index)
    local name, rank, icon, count, debuffType, duration, expirationTime,
        unitCaster, isStealable, shouldConsolidate, spellId = UnitBuff(unit, index)
    return name, icon, count, debuffType, duration, expirationTime, unitCaster, isStealable, shouldConsolidate, spellId
end

function QuestieCompat.GetMaxPlayerLevel()
	return QuestieCompat.MAX_PLAYER_LEVEL or 80
end

-- Returns the race of the unit.
-- https://wowpedia.fandom.com/wiki/API_UnitRace
function QuestieCompat.UnitRace(unit)
    local raceName, raceFile = UnitRace(unit)
    return raceName, raceFile, QuestieCompat.ChrRaces[raceFile]
end

-- Returns the class of the unit.
-- https://wowpedia.fandom.com/wiki/API_UnitClass
-- Patch 5.0.4 (2012-08-28): Added classId return value.
function QuestieCompat.UnitClass(unit)
    local className, classFile = UnitClass(unit)
    return className, classFile, QuestieCompat.ChrClasses[classFile]
end

-- Returns info for a faction.
-- https://wowpedia.fandom.com/wiki/API_GetFactionInfo
-- Patch 5.0.4 (2012-08-28): Added new return value: factionID
-- TODO: localize factions name(https://www.curseforge.com/wow/addons/libbabble-faction-3-0)
function QuestieCompat.GetFactionInfo(factionIndex)
    local name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
        canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild = GetFactionInfo(factionIndex)

    return name, description, standingId, bottomValue, topValue, earnedValue, atWarWith,
        canToggleAtWar, isHeader, isCollapsed, hasRep, isWatched, isChild, QuestieCompat.FactionId[name:trim()]
end

-- Returns true if the player is in a group.
-- https://wowpedia.fandom.com/wiki/API_IsInGroup
function QuestieCompat.IsInGroup(groupType)
    if groupType then return false end
    return UnitInParty("player") and GetNumPartyMembers() > 0
end

-- Returns true if the player is in a raid.
-- https://wowpedia.fandom.com/wiki/API_IsInRaid
function QuestieCompat.IsInRaid(groupType)
    if groupType then return false end
    return UnitInRaid("player") and GetNumRaidMembers() > 0
end

-- Returns names of characters in your home (non-instance) party.
-- https://wowpedia.fandom.com/wiki/API_GetHomePartyInfo
function QuestieCompat.GetHomePartyInfo(homePlayers)
	if UnitInParty("player") then
		homePlayers = homePlayers or {}
		for i=1, MAX_PARTY_MEMBERS do
			if GetPartyMember(i) then
				table.insert(homePlayers, UnitName("party"..i))
			end
		end
		return homePlayers
	end
end

-- https://wowpedia.fandom.com/wiki/API_UnitGUID?oldid=2507049
local GUIDType = {
    [0]="Player",
    [1]="GameObject",
    [3]="Creature",
    [4]="Pet",
    [5]="Vehicle"
}

-- Returns the GUID of the unit.
-- https://wowpedia.fandom.com/wiki/GUID
-- Patch 6.0.2 (2014-10-14): Changed to a new format
function QuestieCompat.UnitGUID(unit)
    local guid = UnitGUID(unit)
    if guid then
        local type = tonumber(guid:sub(5,5), 16) % 8
        if type and (type == 1 or type == 3 or type == 5) then
            local id = tonumber(guid:sub(9, 12), 16)
            -- Creature-0-[serverID]-[instanceID]-[zoneUID]-[npcID]-[spawnUID]
            return string.format("%s-0-4170-0-41-%d-00000F4B37", GUIDType[type], id)
        end
    end
end

-- Returns the ID of the displayed quest at a quest giver.
-- https://wowpedia.fandom.com/wiki/API_GetQuestID
function QuestieCompat.GetQuestID(questStarter)
	local QuestieDB = QuestieLoader:ImportModule("QuestieDB")
	return QuestieDB.GetQuestIDFromName(GetTitleText(), QuestieCompat.UnitGUID("target"), questStarter)
end

-- Gets a list of the auction house item classes.
-- https://wowpedia.fandom.com/wiki/API_GetAuctionItemClasses?oldid=1835520
local itemClass = {GetAuctionItemClasses()}
for classId, className in ipairs(itemClass) do
    itemClass[className] = classId
    itemClass[classId] = nil
end

-- Returns info for an item.
-- https://wowpedia.fandom.com/wiki/API_GetItemInfo?oldid=2376031
-- Patch 7.0.3 (2016-07-19): Added classID, subclassID returns.
function QuestieCompat.GetItemInfo(item)
    local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType,
        itemSubType, itemStackCount,itemEquipLoc, itemTexture, itemSellPrice = GetItemInfo(item)

    return itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType,
        itemSubType, itemStackCount,itemEquipLoc, itemTexture, itemSellPrice, itemClass[itemType]
end

-- Returns info for an item in a container slot.
-- https://wowpedia.fandom.com/wiki/API_GetContainerItemInfo
function QuestieCompat.GetContainerItemInfo(bagID, slot)
	local iconFile, stackCount, isLocked, quality, isReadable, hasLoot, hyperlink = GetContainerItemInfo(bagID, slot)
    if hyperlink then
	    local itemID = string.match(hyperlink, "(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+):(%-?%d+)")
	    -- GetContainerItemInfo does not return a quality value for all items.  If it does not, it returns -1
	    if quality and quality < 0 then
	    	quality = (select(3, GetItemInfo(hyperlink)))
	    end

	    return iconFile, stackCount, isLocked, quality, isReadable, hasLoot, hyperlink, false, false, tonumber(itemID), false
    end
end

-- https://wowpedia.fandom.com/wiki/API_IsSpellKnown
QuestieCompat.IsSpellKnownOrOverridesKnown = IsSpellKnown
QuestieCompat.IsPlayerSpell = IsSpellKnown

local LARGE_NUMBER_SEPERATOR = ".";
function QuestieCompat.FormatLargeNumber(amount)
	amount = tostring(amount);
	local newDisplay = "";
	local strlen = amount:len();
	--Add each thing behind a comma
	for i=4, strlen, 3 do
		newDisplay = LARGE_NUMBER_SEPERATOR..amount:sub(-(i - 1), -(i - 3))..newDisplay;
	end
	--Add everything before the first comma
	newDisplay = amount:sub(1, (strlen % 3 == 0) and 3 or (strlen % 3))..newDisplay;
	return newDisplay;
end

local function Round(value)
	if value < 0.0 then
		return math.ceil(value - .5);
	end
	return math.floor(value + .5);
end
QuestieCompat.Round = Round

local function GenerateHexColor(r, g, b, a)
	return ("ff%.2x%.2x%.2x"):format(Round(r * 255), Round(g * 255), Round(b * 255), Round((a or 1) * 255));
end

-- Returns the color value associated with a given class.
function QuestieCompat.GetClassColor(classFilename)
	local color = RAID_CLASS_COLORS[classFilename];
	if color then
		return color.r, color.g, color.b, GenerateHexColor(color.r, color.g, color.b)
	end
	return 1, 1, 1, "ffffffff";
end

function QuestieCompat.SetupTooltip(frame, OnHide)
    if (frame:GetParent() == WorldMapFrame) then
        local miniWorldMap = WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE
        if (not miniWorldMap) then
            WorldMapFrame:EnableKeyboard(OnHide and true or false)
        end
        WorldMapBlobFrame:SetScript("OnUpdate", OnHide and WorldMapBlobFrame_OnUpdate or nil)
        QuestieCompat.Tooltip = WorldMapTooltip
    else
        QuestieCompat.Tooltip = GameTooltip
    end
    return QuestieCompat.Tooltip
end

local empty_table = {}
function QuestieCompat.TextWrap(self, line, prefix, combineTrailing, desiredWidth)
    QuestieCompat.Tooltip:AddLine(line, 0.86, 0.86, 0.86, 1);
    return empty_table
end

local fontString = UIParent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
fontString:Hide()
-- The minimum width necessary to contain the entire text without truncation
-- https://wowpedia.fandom.com/wiki/API_FontString_GetStringWidth
function QuestieCompat.GetUnboundedStringWidth(self)
    fontString:SetFont(self:GetFont())
    fontString:SetText(self:GetText())

    return fontString:GetStringWidth()
end

-- ???
-- https://wowpedia.fandom.com/wiki/API_FontString_GetNumLines
function QuestieCompat.GetNumLines(self)
    return 1
end

QuestieCompat.LibUIDropDownMenu = {
	Create_UIDropDownMenu = function(self, name, parent)
		return CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
	end,
	EasyMenu = function(self, menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay)
		EasyMenu(menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay)
	end,
	CloseDropDownMenus = function(self, level)
        CloseDropDownMenus(level)
    end,
}

--[[
    xpcall wrapper implementation
]]
local xpcall = xpcall

local function errorhandler(err)
	return geterrorhandler()(err)
end

local function CreateDispatcher(argCount)
	local code = [[
		local xpcall, errorhandler = ...
		local method, ARGS
		local function call() return method(ARGS) end

		local function dispatch(func, eh, ...)
			 method = func
			 if not method then return end
			 ARGS = ...
			 return xpcall(call, eh or errorhandler)
		end

		return dispatch
	]]

	local ARGS = {}
	for i = 1, argCount do ARGS[i] = "arg"..i end
	code = code:gsub("ARGS", table.concat(ARGS, ", "))
	return assert(loadstring(code, "safecall Dispatcher["..argCount.."]"))(xpcall, errorhandler)
end

local Dispatchers = setmetatable({}, {__index=function(self, argCount)
	local dispatcher = CreateDispatcher(argCount)
	rawset(self, argCount, dispatcher)
	return dispatcher
end})

Dispatchers[0] = function(func, eh)
	return xpcall(func, eh or errorhandler)
end

function QuestieCompat.xpcall(func, eh, ...)
    if type(func) == "function" then
		return Dispatchers[select('#', ...)](func, eh, ...)
	end
end

--[[
    It seems that the table size is capped in 3.3.5, with a maximum of 524,288 entries.
    For instance, this code triggers an error message: 'memory allocation error: block too big.

    local t = {}
	for i=1, 524289 do
		t[i] = true
	end

    Spliting the table into multiple subtables should do the trick.
]]

local stringchar = string.char
local MAX_TABLE_SIZE = 524288

function QuestieCompat._writeByte(self, val)
	local subIndex = math.ceil(self._pointer / MAX_TABLE_SIZE)
	local index = self._pointer - (subIndex - 1) * MAX_TABLE_SIZE

	self._bin[subIndex] = self._bin[subIndex] or {}
	self._bin[subIndex][index] = stringchar(val)

    self._pointer = self._pointer + 1
end

function QuestieCompat._readByte(self)
	local subIndex = math.ceil(self._pointer / MAX_TABLE_SIZE)
	local index = self._pointer - (subIndex - 1) * MAX_TABLE_SIZE

    self._pointer = self._pointer + 1

	return self._bin[subIndex][index]
end

function QuestieCompat.Save(self)
	local result = ""
	for i=1, #self._bin do
		result = result .. table.concat(self._bin[i])
	end
	return result
end

function QuestieCompat.QuestEventHandler_RegisterEvents(_QuestEventHandler)
    for _, event in pairs({
        "TRADE_CLOSED",
        "MERCHANT_CLOSED",
        "BANKFRAME_CLOSED",
        "GUILDBANKFRAME_CLOSED",
        "VENDOR_CLOSED",
        "MAIL_CLOSED",
        "AUCTION_HOUSE_CLOSED",
    }) do
        QuestieCompat.frame:RegisterEvent(event)
        QuestieCompat[event] = _QuestEventHandler.QuestRelatedFrameClosed
    end
    QuestieCompat.frame:RegisterEvent("QUEST_QUERY_COMPLETE")

    hooksecurefunc("GetQuestReward", function(itemChoice)
        local questId = QuestieCompat.GetQuestID()
        _QuestEventHandler:QuestTurnedIn(questId)
        _QuestEventHandler:QuestRemoved(questId)
    end)

    hooksecurefunc("SetAbandonQuest", function()
        QuestieCompat.abandonQuestID = select(9, GetQuestLogTitle(GetQuestLogSelection()))
    end)

    hooksecurefunc("AbandonQuest", function()
        local questId = QuestieCompat.abandonQuestID or select(9, GetQuestLogTitle(GetQuestLogSelection()))
        _QuestEventHandler:QuestRemoved(QuestieCompat.abandonQuestID)
    end)
end

function QuestieCompat.QuestieTracker_Initialize(trackerQuestFrame)
    -- TrackerHeaderFrame.Initialize
    Questie_HeaderFrame.trackedQuests.label.GetUnboundedStringWidth = QuestieCompat.GetUnboundedStringWidth
    -- TrackerQuestFrame.Initialize
    trackerQuestFrame.ScrollFrame.scrollBarHideable = true
    trackerQuestFrame.ScrollBar:ClearAllPoints()
    trackerQuestFrame.ScrollBar:SetPoint("TOPRIGHT", trackerQuestFrame.ScrollUpButton, "BOTTOMRIGHT", -1, 4)
    trackerQuestFrame.ScrollBar:SetPoint("BOTTOMRIGHT", trackerQuestFrame.ScrollDownButton, "TOPRIGHT", -1, -4)
    trackerQuestFrame.ScrollDownButton:SetPoint("BOTTOMRIGHT", trackerQuestFrame.ScrollFrame, "BOTTOMRIGHT", -4, 12)
    trackerQuestFrame.ScrollBg:SetTexture(0, 0, 0, 0.35)
    trackerQuestFrame.ScrollBg:Show()
    trackerQuestFrame.ScrollBar.Show = function() end
    -- TrackerLinePool.Initialize
    for i = 1, 250 do
        local line = _G["linePool" .. i]
        line.label.GetUnboundedStringWidth = QuestieCompat.GetUnboundedStringWidth
        line.label.GetNumLines = QuestieCompat.GetNumLines
    end
end

-- prevents the override of existing global variables with the same name(e.g., WorldMapButton)
function QuestieCompat.PopulateGlobals(self)
    for name, module in pairs(QuestieLoader._modules) do
        if not _G[name] then
            _G[name] = module
        end
    end
end

function QuestieCompat:ADDON_LOADED(event, addon)
	if addon == QuestieCompat.addonName then
        for _, moduleName in pairs({
            "HBDHooks",
            "QuestieDebugOffer",
            "SeasonOfDiscovery",
            "QuestieDBMIntegration",
            "QuestieNameplate",
            "QuestieAnnounce",
            "QuestieComms",
            "QuestieAuto",
            "QuestgiverFrame",
        }) do
            local module = QuestieLoader:ImportModule(moduleName)
            setmetatable(module, QuestieCompat.NOOP_MT)
        end

        QuestieLoader.PopulateGlobals = QuestieCompat.PopulateGlobals

        local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
        ZoneDB.private.RunTests = QuestieCompat.NOOP

        local QuestieLib = QuestieLoader:ImportModule("QuestieLib")
        QuestieLib.TextWrap = QuestieCompat.TextWrap

        local QuestieComms = QuestieLoader:ImportModule("QuestieComms")
        QuestieComms.remotePlayerEnabled = {}

        local QuestieMap = QuestieLoader:ImportModule("QuestieMap")
        QuestieMap.DrawWaypoints = QuestieCompat.NOOP

        local QuestieStream = QuestieLoader:ImportModule("QuestieStreamLib")
        QuestieStream._writeByte = QuestieCompat._writeByte
        QuestieStream._readByte = QuestieCompat._readByte
        QuestieStream.Save = QuestieCompat.Save

        local QuestEventHandler = QuestieLoader:ImportModule("QuestEventHandler")
        hooksecurefunc(QuestEventHandler, "RegisterEvents", function()
            QuestieCompat.QuestEventHandler_RegisterEvents(QuestEventHandler.private)
        end)

        local TrackerLinePool = QuestieLoader:ImportModule("TrackerLinePool")
        hooksecurefunc(TrackerLinePool, "Initialize", QuestieCompat.QuestieTracker_Initialize)
    end
end