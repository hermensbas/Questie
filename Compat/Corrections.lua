---@type QuestieDB
local QuestieDB = QuestieLoader:ImportModule("QuestieDB")

if QuestieCompat.WOW_PROJECT_ID < QuestieCompat.WOW_PROJECT_WRATH_CLASSIC then return end

QuestieCompat.RegisterCorrection("questData", function()
	local questKeys = QuestieDB.questKeys

	return {
        [12372] = {
            [questKeys.objectivesText] = {"Afrasastrasz at Wyrmrest Temple has asked you to slay 3 Azure Dragons, slay 5 Azure Drakes, and to destabilize the Azure Dragonshrine while riding a Wyrmrest Defender into battle."},
        },
        [12435] = {
            [questKeys.name] = "Report to Lord Afrasastrasz",
            [questKeys.objectivesText] = {"Speak with Lord Afrasastrasz at Wyrmrest Temple."},
        },
	}
end)

QuestieCompat.RegisterCorrection("npcData", function()
	local npcKeys = QuestieDB.npcKeys

	return {
        [27575] = {
            [npcKeys.name] = "Lord Afrasastrasz",
        },
	}
end)