------------------------------------------------------------
-- Experiencer2 by DJScias (https://github.com/DJScias/Experiencer2)
-- Originally by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;

local module = Addon:RegisterModule("experience", {
	label       = "Experience",
	order       = 1,
	active      = true,
	savedvars   = {
		char = {
			session = {
				Exists = false,
				Time = 0,
				TotalXP = 0,
				AverageQuestXP = 0,
			},
		},
		global = {
			ShowRemaining = true,
			ShowGainedXP = true,
			ShowHourlyXP = true,
			ShowTimeToLevel = true,
			ShowQuestsToLevel = true,
			KeepSessionData = true,

			QuestXP = {
				ShowText = true,
				AddIncomplete = false,
				IncludeAccountWide = false,
				ShowVisualizer = true,
			},
		},
	},
});

module.session = {
	LoginTime       = time(),
	GainedXP        = 0,
	LastXP          = UnitXP("player"),
	MaxXP           = UnitXPMax("player"),

	QuestsToLevel   = -1,
	AverageQuestXP  = 0,

	Paused          = false,
	PausedTime      = 0,
};

-- Required data for experience module
local HEIRLOOM_ITEMXP = {
	["INVTYPE_HEAD"] 		= 0.1,
	["INVTYPE_SHOULDER"] 	= 0.1,
	["INVTYPE_CHEST"] 		= 0.1,
	["INVTYPE_ROBE"] 		= 0.1,
	["INVTYPE_LEGS"] 		= 0.1,
	["INVTYPE_FINGER"] 		= 0.05,
	["INVTYPE_CLOAK"] 		= 0.05,

	-- Rings with battleground xp bonus instead
	[126948] 	= 0.0,
	[126949]	= 0.0,
};

local HEIRLOOM_SLOTS = {
	1, 3, 5, 7, 11, 12, 15,
};

local BUFF_MULTIPLIERS = {
	[46668]		= { multiplier = 0.1, },	-- Darkmoon Carousel Buff
	[89479]		= { multiplier = 0.05, },	-- Guild Battle Standard - 1 - A
	[90631]		= { multiplier = 0.05, },	-- Guild Battle Standard - 1 - H
	[90626]		= { multiplier = 0.1, },	-- Guild Battle Standard - 2 - A
	[90632]		= { multiplier = 0.1, },	-- Guild Battle Standard - 2 - H
	[90628]		= { multiplier = 0.15, },	-- Guild Battle Standard - 3 - A
	[90633]		= { multiplier = 0.15, },	-- Guild Battle Standard - 3 - H
	[289982]	= { multiplier = 0.1, },	-- Draught of Ten Lands
};

local GROUP_TYPE = {
	SOLO 	= 0x1,
	PARTY 	= 0x2,
	RAID	= 0x3,
};

local QUEST_COMPLETED_PATTERN = "^" .. string.gsub(ERR_QUEST_COMPLETE_S, "%%s", "(.-)") .. "$";
local QUEST_EXPERIENCE_PATTERN = "^" .. string.gsub(ERR_QUEST_REWARD_EXP_I, "%%d", "(%%d+)") .. "$";

function module:Initialize()
	self:RegisterEvent("CHAT_MSG_SYSTEM");
	self:RegisterEvent("PLAYER_XP_UPDATE");
	self:RegisterEvent("PLAYER_LEVEL_UP");
	self:RegisterEvent("QUEST_LOG_UPDATE");
	self:RegisterEvent("UNIT_INVENTORY_CHANGED");
	self:RegisterEvent("UPDATE_EXPANSION_LEVEL");

	module.playerCanLevel = not module:IsPlayerMaxLevel();

	module:RestoreSession();
end

function module:IsDisabled()
	return module:IsPlayerMaxLevel() or IsXPUserDisabled();
end

function module:AllowedToBufferUpdate()
	return true;
end

function module:Update(elapsed)
	local lastPaused = self.session.Paused;
	local charDB = self.db.char;
	local currentSession = self.session;
	currentSession.Paused = UnitIsAFK("player");

	if (currentSession.Paused and lastPaused ~= currentSession.Paused) then
		self:Refresh();
	elseif (not currentSession.Paused and lastPaused ~= currentSession.Paused) then
		currentSession.LoginTime = currentSession.LoginTime + math.floor(currentSession.PausedTime);
		currentSession.PausedTime = 0;
	end

	if (currentSession.Paused) then
		currentSession.PausedTime = currentSession.PausedTime + elapsed;
	end

	if (self.db == nil) then
		return;
	end

	if (self.db.global.KeepSessionData) then
		charDB.session.Exists = true;

		charDB.session.Time = time() - (currentSession.LoginTime + math.floor(currentSession.PausedTime));
		charDB.session.TotalXP = currentSession.GainedXP;
		charDB.session.AverageQuestXP = currentSession.AverageQuestXP;
	end
end

function module:GetText()
	local primaryText = {};
	local secondaryText = {};

	local current_xp, max_xp = UnitXP("player"), UnitXPMax("player");
	local rested_xp = GetXPExhaustion() or 0;
	local remaining_xp = max_xp - current_xp;

	local progress = current_xp / (max_xp > 0 and max_xp or 1);
	local progressColor = Addon:GetProgressColor(progress);

	local globalDB = self.db.global;

	if globalDB.ShowRemaining then
		tinsert(primaryText,
			string.format("%s%s|r (%s%.1f|r%%)", progressColor, BreakUpLargeNumbers(remaining_xp), progressColor, 100 - progress * 100)
		);
	else
		tinsert(primaryText,
			string.format("%s%s|r / %s (%s%.1f|r%%)", progressColor, BreakUpLargeNumbers(current_xp), BreakUpLargeNumbers(max_xp), progressColor, progress * 100)
		);
	end

	if rested_xp > 0 then
		tinsert(primaryText,
			string.format("%d%% |cff6fafdfrested|r", math.ceil(rested_xp / max_xp * 100))
		);
	end

	if module.session.GainedXP > 0 then
		local hourlyXP, timeToLevel = module:CalculateHourlyXP();

		if globalDB.ShowGainedXP then
			tinsert(secondaryText,
				string.format("+%s |cffffcc00xp|r", BreakUpLargeNumbers(module.session.GainedXP))
			);
		end

		if globalDB.ShowHourlyXP then
			tinsert(primaryText,
				string.format("%s |cffffcc00xp/h|r", BreakUpLargeNumbers(hourlyXP))
			);
		end

		if globalDB.ShowTimeToLevel then
			tinsert(primaryText,
				string.format("%s |cff80e916until level|r", Addon:FormatTime(timeToLevel))
			);
		end
	end

	if globalDB.ShowQuestsToLevel then
		if module.session.QuestsToLevel > 0 and module.session.QuestsToLevel ~= math.huge then
			tinsert(secondaryText,
				string.format("~%s |cff80e916quests|r", module.session.QuestsToLevel)
			);
		end
	end

	if globalDB.QuestXP.ShowText then
		local completeXP, incompleteXP, totalXP = module:CalculateQuestLogXP();

		local levelUpAlert = "";
		if current_xp + completeXP >= max_xp then
			levelUpAlert = " (|cfff1e229enough to level|r)";
		end

		if not globalDB.QuestXP.AddIncomplete then
			tinsert(secondaryText,
				string.format("%s |cff80e916xp from quests|r%s", BreakUpLargeNumbers(math.floor(completeXP)), levelUpAlert)
			);
		elseif globalDB.QuestXP.AddIncomplete then
			tinsert(secondaryText,
				string.format("%s |cffffdd00+|r %s |cff80e916xp from quests|r%s", BreakUpLargeNumbers(math.floor(completeXP)), BreakUpLargeNumbers(math.floor(incompleteXP)), levelUpAlert)
			);
		end
	end

	return table.concat(primaryText, "  "), table.concat(secondaryText, "  ");
end

function module:HasChatMessage()
	return not module:IsPlayerMaxLevel() and not IsXPUserDisabled(), "Max level reached.";
end

function module:GetChatMessage()
	local current_xp, max_xp = UnitXP("player"), UnitXPMax("player");
	local remaining_xp = max_xp - current_xp;
	local rested_xp = GetXPExhaustion() or 0;

	local rested_xp_percent = floor(((rested_xp / max_xp) * 100) + 0.5);

	local max_xp_text = Addon:FormatNumber(max_xp);
	local current_xp_text = Addon:FormatNumber(current_xp);
	local remaining_xp_text = Addon:FormatNumber(remaining_xp);

	return string.format("Currently level %d at %s/%s (%d%%) with %s xp to go (%d%% rested)", 
		UnitLevel("player"),
		current_xp_text,
		max_xp_text, 
		math.ceil((current_xp / max_xp) * 100), 
		remaining_xp_text, 
		rested_xp_percent
	);
end

function module:GetBarData()
	local data = {
		id = nil,
		level = UnitLevel("player"),
		min = 0,
		max = UnitXPMax("player"),
		current = UnitXP("player"),
		rested = GetXPExhaustion() or 0,
	};
	local globalDB = self.db.global;

	if globalDB.QuestXP.ShowVisualizer then
		local completeXP, incompleteXP, totalXP = module:CalculateQuestLogXP();

		data.visual = completeXP;

		if globalDB.QuestXP.AddIncomplete then
			data.visual = { completeXP, totalXP };
		end
	end

	return data;
end

function module:GetOptionsMenu(currentMenu)
	local globalDB = self.db.global;

	currentMenu:CreateTitle("Experience Options");

	-- Create Radio Buttons
	local radioOptions = {
		{"Show remaining XP", true},
		{"Show current and max XP", false},
	};

	for _, option in ipairs(radioOptions) do
		currentMenu:CreateRadio(option[1], function() return globalDB.ShowRemaining == option[2]; end, function()
			globalDB.ShowRemaining = option[2];
			module:RefreshText();
		end):SetResponse(MenuResponse.Refresh);
	end

	currentMenu:CreateDivider();

	-- Create Checkboxes
	local checkboxOptions = {
		{"Show gained XP", "ShowGainedXP"},
		{"Show XP per hour", "ShowHourlyXP"},
		{"Show time to level", "ShowTimeToLevel"},
		{"Show quests to level", "ShowQuestsToLevel"},
	};

	for _, option in ipairs(checkboxOptions) do
		currentMenu:CreateCheckbox(option[1], function() return globalDB[option[2]]; end, function()
			globalDB[option[2]] = not globalDB[option[2]];
			module:RefreshText();
		end);
	end

	currentMenu:CreateDivider();

	currentMenu:CreateCheckbox("Remember session data", function() return globalDB.KeepSessionData; end, function() globalDB.KeepSessionData = not globalDB.KeepSessionData; end);
	currentMenu:CreateButton("Reset session", function() module:ResetSession();	end):SetResponse(MenuResponse.Refresh);

	currentMenu:CreateDivider();

	currentMenu:CreateTitle("Quest XP Visualizer");
	local questCheckboxOptions = {
		{"Show completed quest XP", "ShowText"},
		{"Also show XP from incomplete quests", "AddIncomplete"},
		{"Include XP from account wide quests (pet battles)", "IncludeAccountWide"},
		{"Display visualizer bar", "ShowVisualizer"},
	};

	for _, option in ipairs(questCheckboxOptions) do
		currentMenu:CreateCheckbox(option[1], function() return globalDB.QuestXP[option[2]]; end, function()
			globalDB.QuestXP[option[2]] = not globalDB.QuestXP[option[2]];
			module:RefreshText();
		end);
	end
end

------------------------------------------

function module:RestoreSession()
	if not self.db.char.session.Exists or not self.db.global.KeepSessionData or module:IsPlayerMaxLevel() then
		return;
	end

	local data = self.db.char.session;

	module.session.LoginTime        = module.session.LoginTime - data.Time;
	module.session.GainedXP         = data.TotalXP;
	module.session.AverageQuestXP   = module.session.AverageQuestXP;

	if module.session.AverageQuestXP > 0 then
		local remaining_xp = UnitXPMax("player") - UnitXP("player")
		module.session.QuestsToLevel = ceil(remaining_xp / module.session.AverageQuestXP)
	end
end

function module:ResetSession()
	module.session = {
		LoginTime        = time(),
		GainedXP         = 0,
		LastXP           = UnitXP("player"),
		MaxXP            = UnitXPMax("player"),

		AverageQuestXP   = 0,
		QuestsToLevel    = -1,

		Paused           = false,
		PausedTime       = 0,
	};

	self.db.char.session = {
		Exists           = false,
		Time             = 0,
		TotalXP          = 0,
		AverageQuestXP   = 0,
	};

	module:RefreshText();
end

function module:IsPlayerMaxLevel(level)
	local playerLevel = level or UnitLevel("player");
	return GetMaxLevelForPlayerExpansion() == playerLevel;
end


function module:CalculateHourlyXP()
	local hourlyXP, timeToLevel = 0, 0;

	local logged_time = time() - (module.session.LoginTime + math.floor(module.session.PausedTime));
	local coeff = logged_time / 3600;

	if coeff > 0 and module.session.GainedXP > 0 then
		hourlyXP = math.ceil(module.session.GainedXP / coeff);
		timeToLevel = (UnitXPMax("player") - UnitXP("player")) / hourlyXP * 3600;
	end

	return hourlyXP, timeToLevel;
end

function module:GetGroupType()
	if (IsInRaid()) then
		return GROUP_TYPE.RAID;
	elseif (IsInGroup()) then
		return GROUP_TYPE.PARTY;
	end

	return GROUP_TYPE.SOLO;
end

local partyUnitID = { "player", "party1", "party2", "party3", "party4" };
function module:GetUnitID(group_type, index)
	if group_type == GROUP_TYPE.SOLO or group_type == GROUP_TYPE.PARTY then
		return partyUnitID[index];
	elseif group_type == GROUP_TYPE.RAID then
		return string.format("raid%d", index);
	end

	return nil;
end

local function GroupIterator()
	local index = 0;
	local groupType = module:GetGroupType();
	local numGroupMembers = GetNumGroupMembers();
	if groupType == GROUP_TYPE.SOLO then
		numGroupMembers = 1;
	end

	return function()
		index = index + 1;
		if index <= numGroupMembers then
			return index, module:GetUnitID(groupType, index);
		end
	end
end

function module:HasRecruitingBonus()
	local playerLevel = UnitLevel("player");

	for _, unit in GroupIterator() do
		if not UnitIsUnit("player", unit) and UnitIsVisible(unit) and C_RecruitAFriend.IsRecruitAFriendLinked(unit) then
			local unitLevel = UnitLevel(unit);
			if math.abs(playerLevel - unitLevel) <= 4 and playerLevel < 120 then
				return true;
			end
		end
	end

	return false;
end

function module:CalculateXPMultiplier()
	local multiplier = 1.0;

	-- Heirloom xp bonus is now factored in quest log
	--for _, slotID in ipairs(HEIRLOOM_SLOTS) do
	--	local link = GetInventoryItemLink("player", slotID);

	--	if link then
	--		local _, _, itemRarity, _, _, _, _, _, itemEquipLoc = GetItemInfo(link);

	--		if itemRarity == 7 then
	--			local itemID = tonumber(strmatch(link, "item:(%d*)")) or 0;
	--			local itemMultiplier = HEIRLOOM_ITEMXP[itemID] or HEIRLOOM_ITEMXP[itemEquipLoc];

	--			multiplier = multiplier + itemMultiplier;
	--		end
	--	end
	--end

	if module:HasRecruitingBonus() then
		multiplier = math.max(1.5, multiplier);
	end

	local playerLevel = UnitLevel("player");

	for buffSpellID, buffMultiplier in pairs(BUFF_MULTIPLIERS) do
		if Addon:PlayerHasBuff(buffSpellID) then
			if not buffMultiplier.maxlevel or (buffMultiplier.maxlevel and playerLevel <= buffMultiplier.maxlevel) then
				multiplier = multiplier + buffMultiplier.multiplier;
			end
		end
	end

	return multiplier;
end

function module:CalculateQuestLogXP()
	local completeXP, incompleteXP = 0, 0;

	local numEntries, _ = C_QuestLog.GetNumQuestLogEntries();
	if numEntries == 0 then return 0, 0, 0; end

	for index = 1, numEntries do repeat
		local qinfo = C_QuestLog.GetInfo(index);
		local questID = qinfo["questID"];
		if questID == 0 or qinfo["isHeader"] or qinfo["isHidden"] then
			break;
		end
		if not self.db.global.QuestXP.IncludeAccountWide and C_QuestLog.IsAccountQuest(questID) then
			break;
		end
		if C_QuestLog.ReadyForTurnIn(questID) then
			completeXP = completeXP + GetQuestLogRewardXP(questID);
		else
			incompleteXP = incompleteXP + GetQuestLogRewardXP(questID);
		end
	until true end

	local multiplier = module:CalculateXPMultiplier();
	return completeXP * multiplier, incompleteXP * multiplier, (completeXP + incompleteXP) * multiplier;
end

function module:UPDATE_EXPANSION_LEVEL()
	if not module.playerCanLevel and not module:IsPlayerMaxLevel() then
		DEFAULT_CHAT_FRAME:AddMessage(("|cfffaad07Experiencer|r %s"):format("Expansion level upgraded, you are able to gain experience again."));
	end
	module.playerCanLevel = not module:IsPlayerMaxLevel();
end

function module:QUEST_LOG_UPDATE()
	module:Refresh(true);
end

function module:UNIT_INVENTORY_CHANGED(_, unit)
	if unit ~= "player" then
		return;
	end
	module:Refresh();
end

function module:CHAT_MSG_SYSTEM(_, msg)
	if msg:match(QUEST_COMPLETED_PATTERN) then
		module.QuestCompleted = true;
		return;
	end

	if not module.QuestCompleted then return end
	module.QuestCompleted = false;

	local xp_amount = msg:match(QUEST_EXPERIENCE_PATTERN);
	if not xp_amount then return end

	xp_amount = tonumber(xp_amount);

	if module.session.AverageQuestXP > 0 then
		local weight = math.min(xp_amount / module.session.AverageQuestXP, 0.9);
		module.session.AverageQuestXP = module.session.AverageQuestXP * (1.0 - weight) + xp_amount * weight;
	else
		module.session.AverageQuestXP = xp_amount;
	end

	if module.session.AverageQuestXP == 0 then
		return;
	end

	local currentXP = UnitXP("player");
	local maxXP = UnitXPMax("player");
	local remaining_xp = maxXP - currentXP;

	module.session.QuestsToLevel = math.floor(remaining_xp / module.session.AverageQuestXP);

	if module.session.QuestsToLevel > 0 and xp_amount > 0 then
		local quests_text = string.format("%d more quests to level", module.session.QuestsToLevel);
		DEFAULT_CHAT_FRAME:AddMessage("|cffffff00" .. quests_text .. ".|r");

		if Parrot then
			Parrot:ShowMessage(quests_text, "Errors", false, 1.0, 1.0, 0.1);
		end
	end
end

function module:PLAYER_XP_UPDATE()
	local current_xp = UnitXP("player");
	local max_xp = UnitXPMax("player");
	local gained = current_xp - module.session.LastXP;

	if gained < 0 then
		gained = module.session.MaxXP - module.session.LastXP + current_xp;
	end

	module.session.GainedXP = module.session.GainedXP + gained;
	module.session.LastXP = current_xp;
	module.session.MaxXP = max_xp;

	if module.session.AverageQuestXP > 0 then
		local remaining_xp = max_xp - current_xp;
		module.session.QuestsToLevel = ceil(remaining_xp / module.session.AverageQuestXP);
	end

	module:Refresh();
end

function module:UPDATE_EXHAUSTION()
	module:Refresh();
end

function module:PLAYER_LEVEL_UP(_, level)
	if module:IsPlayerMaxLevel(level) then
		Addon:CheckDisabledStatus();
	else
		local max_xp = UnitXPMax("player");
		local current_xp = UnitXP("player");

		module.session.MaxXP = max_xp;
		local remaining_xp = max_xp - current_xp;
		module.session.QuestsToLevel = ceil(remaining_xp / module.session.AverageQuestXP) - 1;
	end

	module.playerCanLevel = not module:IsPlayerMaxLevel(level);
end
