-- addon/folder name
QuestieCompat.addonName = "Questie-335"

QuestieCompat.frame = CreateFrame("Frame")

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