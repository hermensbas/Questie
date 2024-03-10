-- addon/folder name
QuestieCompat.addonName = "Questie-335"
QuestieCompat.NOOP = function() end
QuestieCompat.frame = CreateFrame("Frame")
QuestieCompat.frame:RegisterEvent("ADDON_LOADED")
QuestieCompat.frame:SetScript("OnEvent", function(self, event, ...)
    QuestieCompat[event](...)
end)

-- current expansion level (https://wowpedia.fandom.com/wiki/WOW_PROJECT_ID)
QuestieCompat.WOW_PROJECT_CLASSIC = 2
QuestieCompat.WOW_PROJECT_BURNING_CRUSADE_CLASSIC = 5
QuestieCompat.WOW_PROJECT_WRATH_CLASSIC = 11
QuestieCompat.WOW_PROJECT_ID = QuestieCompat.WOW_PROJECT_WRATH_CLASSIC

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

-- https://wowpedia.fandom.com/wiki/API_IsQuestFlaggedCompleted
-- Determine if a quest has been completed.
function QuestieCompat.IsQuestFlaggedCompleted(questID)
	return false
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

function QuestieCompat.ADDON_LOADED(addon)
	if addon == QuestieCompat.addonName then
        local ZoneDB = QuestieLoader:ImportModule("ZoneDB")
        ZoneDB.private.RunTests = QuestieCompat.NOOP

        local QuestieStream = QuestieLoader:ImportModule("QuestieStreamLib")
        QuestieStream._writeByte = QuestieCompat._writeByte
        QuestieStream._readByte = QuestieCompat._readByte
        QuestieStream.Save = QuestieCompat.Save
    end
end