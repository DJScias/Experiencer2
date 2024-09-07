------------------------------------------------------------
-- Experiencer2 by DJScias (https://github.com/DJScias/Experiencer2)
-- Originally by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local module = Addon:RegisterModule("reputation", {
	label 	    = "Reputation",
	order       = 2,
	active      = true,
	savedvars   = {
		global = {
			ShowRemaining = true,
			ShowGainedRep = true,

			AutoWatch = {
				Enabled = false,
				SwitchTo = false,
				IgnoreGuild = true,
				IgnoreInactive = true,
				IgnoreBodyguard = true,
			},
		},
	},
});

module.tooltipText = "You can quickly scroll through recently gained reputations by scrolling the mouse wheel while holding down shift key."

module.recentReputations = {};
module.hasCustomMouseCallback = true;

local BODYGUARD_FACTIONS = {
	[1738] = "Defender Illona",
	[1740] = "Aeda Brightdawn",
	[1733] = "Delvar Ironfist",
	[1739] = "Vivianne",
	[1737] = "Talonpriest Ishaal",
	[1741] = "Leorajh",
	[1736] = "Tormmok",
};

function module:Initialize()
	module:RegisterEvent("UPDATE_FACTION");
	module:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE");

	local factionData = C_Reputation.GetWatchedFactionData();
	module.Tracked = factionData and factionData.name;

	if factionData and factionData.name then
		module.recentReputations[factionData.name] = {
			factionID = factionData.factionID,
			amount = 0,
		};
	end

	module.AutoWatchRecent = {};
	module.AutoWatchUpdate = 0;
	module.AutoWatchRecentTimeout = 0;
end

function module:IsDisabled()
	return false;
end

function module:GetSortedRecentList()
	local sortedList = {};
	for name, data in pairs(module.recentReputations) do
		tinsert(sortedList, {name = name, data = data});
	end
	table.sort(sortedList, function(a, b)
		if (a == nil and b == nil) then return false end
		if (a == nil) then return true end
		if (b == nil) then return false end

		return a.name < b.name;
	end);
	for index, data in ipairs(sortedList) do
		module.recentReputations[data.name].sortedIndex = index;
	end
	return sortedList;
end

function module:OnMouseWheel(delta)
	if IsShiftKeyDown() then
		local recentRepsList = module:GetSortedRecentList();
		if not recentRepsList or #recentRepsList == 0 then return end

		local currentIndex = 1;
		local name = C_Reputation.GetWatchedFactionData() and C_Reputation.GetWatchedFactionData().name or nil;
		if name then
			currentIndex = module.recentReputations[name].sortedIndex;
		end

		currentIndex = currentIndex - delta;
		if currentIndex > #recentRepsList then currentIndex = 1 end
		if currentIndex < 1 then currentIndex = #recentRepsList end

		if recentRepsList[currentIndex] then
			local data =recentRepsList[currentIndex].data;
			module:MenuSetWatchedFactionID(data.factionID);
		end
	end
end

function module:CanLevelUp()
	local factionID = C_Reputation.GetWatchedFactionData() and C_Reputation.GetWatchedFactionData().factionID or nil;
	if factionID and C_Reputation.IsFactionParagon(factionID) then
		local _, _, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID);
		return hasRewardPending;
	end
	return false;
end

function module:SetStanding(factionID)
	local standing = C_Reputation.GetFactionDataByID(factionID).reaction;
	local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
	local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

	local standingText = "";
	local standingColor = {};
	local isCapped = false;

	if majorFactionData then
		isCapped = not majorFactionData.renownLevelThreshold; -- This will never trigger for now, Renowns don't get capped.

		standingText = string.format("|cnHEIRLOOM_BLUE_COLOR:Renown %s|r", majorFactionData.renownLevel);
		standingColor = {r=0.00, g=0.80, b=1.00};
	elseif reputationInfo and reputationInfo.friendshipFactionID > 0 then
		isCapped = not reputationInfo.nextThreshold;

		standingText, standingColor = module:GetFriendShipColorText(reputationInfo.friendshipFactionID, reputationInfo.reaction);
	else
		isCapped = standing == MAX_REPUTATION_REACTION;

		standingText, standingColor = module:GetStandingColorText(standing);
	end

	if isCapped and C_Reputation.IsFactionParagon(factionID) or C_Reputation.IsFactionParagon(factionID) then
		local currentReputation, maxReputation = C_Reputation.GetFactionParagonInfo(factionID);
		isCapped = false;

		local paragonLevel = math.floor(currentReputation / maxReputation);

		if paragonLevel > 1 then
			standingText, standingColor = string.format("%dx %s", paragonLevel, module:GetStandingColorText(9));
		else
			standingText, standingColor = module:GetStandingColorText(9);
		end
	end

	Addon:SetReputationColor(standingColor);
	return standingText;
end

function module:GetText()
	if not module:HasWatchedReputation() then
		return "No active watched reputation";
	end

	local factionData = C_Reputation.GetWatchedFactionData();
	local factionID, name, standing, minReputation, maxReputation, currentReputation = factionData.factionID, factionData.name, factionData.reaction, factionData.currentReactionThreshold, factionData.nextReactionThreshold, factionData.currentStanding;
	local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
	local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

	local isCapped = false;
	local standingText = module:SetStanding(factionID);

	if majorFactionData then
		isCapped = not majorFactionData.renownLevelThreshold; -- This will never trigger for now, Renowns don't get capped.
	else
		if (reputationInfo and reputationInfo.friendshipFactionID > 0) then
			isCapped = not reputationInfo.nextThreshold;
		else
			isCapped = standing == MAX_REPUTATION_REACTION;
		end
	end

	local remainingReputation = 0;
	local realCurrentReputation = 0;
	local realMaxReputation = 0;

	local hasRewardPending = false;
	local isParagon = false;
	local paragonLevel = 0;

	if isCapped and C_Reputation.IsFactionParagon(factionID) or C_Reputation.IsFactionParagon(factionID) then
		currentReputation, maxReputation, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID);
		isCapped = false;
		isParagon = true;

		paragonLevel = math.floor(currentReputation / maxReputation);
		currentReputation = currentReputation % maxReputation;

		remainingReputation = maxReputation - currentReputation;
	elseif not isCapped then
		remainingReputation = maxReputation - currentReputation;
		realCurrentReputation = currentReputation - minReputation;
		realMaxReputation = maxReputation - minReputation;
		if majorFactionData then
			local renownReputationEarned = majorFactionData.renownReputationEarned;
			local renownLevelThreshold = majorFactionData.renownLevelThreshold;

			remainingReputation = renownLevelThreshold - renownReputationEarned;
			realCurrentReputation = renownReputationEarned;
			realMaxReputation = renownLevelThreshold;
		elseif reputationInfo and reputationInfo.friendshipFactionID > 0 then
			local friendStanding = reputationInfo.standing;
			local friendThreshold = reputationInfo.reactionThreshold;
			local nextFriendThreshold = reputationInfo.nextThreshold;

			remainingReputation = nextFriendThreshold - friendStanding;
			realCurrentReputation = friendStanding - friendThreshold;
			realMaxReputation = nextFriendThreshold - friendThreshold;
		end

		currentReputation = realCurrentReputation;
		maxReputation = realMaxReputation;
	end

	local progress = currentReputation / maxReputation;
	local color = Addon:GetProgressColor(progress);

	local primaryText = {};

	if not isCapped then
		if self.db.global.ShowRemaining then
			tinsert(primaryText,
				string.format("%s (%s): %s%s|r (%s%.1f|r%%)", name, standingText, color, BreakUpLargeNumbers(remainingReputation), color, 100 - progress * 100)
			);
		else
			tinsert(primaryText,
				string.format("%s (%s): %s%s|r / %s (%s%.1f|r%%)", name, standingText, color, BreakUpLargeNumbers(currentReputation), BreakUpLargeNumbers(maxReputation), color, progress * 100)
			);
		end
	end

	if isCapped then
		tinsert(primaryText,
			string.format("%s (%s)", name, standingText)
		);
	end

	local secondaryText = {};

	if hasRewardPending then
		tinsert(secondaryText, "|cnGREEN_FONT_COLOR:Paragon reward earned!|r");
	end

	if self.db.global.ShowGainedRep and module.recentReputations[name] then
		if module.recentReputations[name].amount > 0 then
			tinsert(secondaryText, string.format("+%s |cnNORMAL_FONT_COLOR:rep|r", BreakUpLargeNumbers(module.recentReputations[name].amount)));
		end
	end

	return table.concat(primaryText, "  "), table.concat(secondaryText, "  ");
end

function module:HasChatMessage()
	return C_Reputation.GetWatchedFactionData() ~= nil, "No watched reputation.";
end

function module:GetChatMessage()
	local factionData = C_Reputation.GetWatchedFactionData();
	local factionID, name, standing, minReputation, maxReputation, currentReputation = factionData.factionID, factionData.name, factionData.reaction, factionData.currentReactionThreshold, factionData.nextReactionThreshold, factionData.currentStanding;
	local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
	local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

	local standingText = "";
	local isCapped = false;

	if majorFactionData then
		standingText = string.format("|cnHEIRLOOM_BLUE_COLOR:Renown %s|r", majorFactionData.renownLevel);
		isCapped = not majorFactionData.renownLevelThreshold; -- This will never trigger for now, Renowns don't get capped.
	elseif reputationInfo and reputationInfo.friendshipFactionID > 0 then
		standingText = reputationInfo.reaction;
		isCapped = not reputationInfo.nextThreshold;
	else
		standingText = GetText("FACTION_STANDING_LABEL" .. standing, UnitSex("player"));
		isCapped = standing == MAX_REPUTATION_REACTION;
	end

	local paragonLevel = 0;

	if isCapped and C_Reputation.IsFactionParagon(factionID) or C_Reputation.IsFactionParagon(factionID) then
		currentReputation, maxReputation = C_Reputation.GetFactionParagonInfo(factionID);
		minReputation = 0;
		isCapped = false;

		paragonLevel = math.floor(currentReputation / maxReputation);
		if paragonLevel < 1 then
			paragonLevel = 1;
		end
		currentReputation = currentReputation % maxReputation;
	end

	if not isCapped then
		local remaining_rep = maxReputation - currentReputation;
		if majorFactionData then
			local renownLevelThreshold = majorFactionData.renownLevelThreshold;
			local renownReputationEarned = majorFactionData.renownReputationEarned;

			remaining_rep = renownLevelThreshold - renownReputationEarned;
		elseif reputationInfo and reputationInfo.friendshipFactionID > 0 then
			local friendStanding = reputationInfo.standing;
			local nextFriendThreshold = reputationInfo.nextThreshold;

			remaining_rep = nextFriendThreshold - friendStanding;
		end
		local progress = (currentReputation - minReputation) / (maxReputation - minReputation);

		local paragonText = "";
		if paragonLevel > 0 then
			paragonText = string.format(" (%dx paragon)", paragonLevel);
		end

		return string.format("%s%s with %s: %s/%s (%d%%) with %s to go",
			standingText,
			paragonText,
			name,
			BreakUpLargeNumbers(currentReputation - minReputation),
			BreakUpLargeNumbers(maxReputation - minReputation),
			progress * 100,
			BreakUpLargeNumbers(remaining_rep)
		);
	else
		return string.format("%s with %s",
			standingText,
			name
		);
	end
end

function module:GetBarData()
	local data    = {};
	data.id       = nil;
	data.level    = 0;
	data.min  	  = 0;
	data.max  	  = 1;
	data.current  = 0;
	data.rested   = nil;
	data.visual   = nil;

	if module:HasWatchedReputation() then
		local factionData = C_Reputation.GetWatchedFactionData();
		local factionID, standing, minReputation, maxReputation, currentReputation = factionData.factionID, factionData.reaction, factionData.currentReactionThreshold, factionData.nextReactionThreshold, factionData.currentStanding;
		data.id = factionID;

		local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
		local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

		local isCapped = false;
		local isParagon = false;

		if majorFactionData then
			minReputation = 0;
			isCapped = not majorFactionData.renownLevelThreshold; -- This will never trigger for now, Renowns don't get capped.
		else
			if reputationInfo and reputationInfo.friendshipFactionID > 0 and not reputationInfo.nextThreshold then
				isCapped = true;
			elseif standing == MAX_REPUTATION_REACTION then
				isCapped = true;
			end
		end

		if isCapped and C_Reputation.IsFactionParagon(factionID) or C_Reputation.IsFactionParagon(factionID) then
			currentReputation, maxReputation = C_Reputation.GetFactionParagonInfo(factionID);
			isCapped = false;
			isParagon = true;
			minReputation = 0;

			currentReputation = currentReputation % maxReputation;
		end

		data.level       = standing;

		if not isCapped then
			data.min  	 = minReputation;
			data.max  	 = maxReputation;
			data.current = currentReputation;
			if (majorFactionData and not isParagon) then
				data.max = majorFactionData.renownLevelThreshold;
			elseif (reputationInfo and reputationInfo.friendshipFactionID > 0) then
				data.min = reputationInfo.reactionThreshold;
				data.max = reputationInfo.nextThreshold;
			end
		else
			data.min     = 0;
			data.max     = 1;
			data.current = 1;
		end
	end

	return data;
end

function module:GetOptionsMenu(currentMenu)
	currentMenu:CreateTitle("Reputation Options");
	currentMenu:CreateRadio("Show remaining reputation", function() return self.db.global.ShowRemaining == true; end, function()
		self.db.global.ShowRemaining = true;
		module:RefreshText();
	end):SetResponse(MenuResponse.Refresh);
	currentMenu:CreateRadio("Show current and max reputation", function() return self.db.global.ShowRemaining == false; end, function()
		self.db.global.ShowRemaining = false;
		module:RefreshText();
	end):SetResponse(MenuResponse.Refresh);

	currentMenu:CreateDivider();

	currentMenu:CreateCheckbox("Show gained reputation", function() return self.db.global.ShowGainedRep; end, function()
		self.db.global.ShowGainedRep = not self.db.global.ShowGainedRep;
		module:RefreshText();
	end);
	local autoWatchedOption = currentMenu:CreateCheckbox("Auto add to Recent Reputations list", function() return self.db.global.AutoWatch.Enabled; end, function()
		self.db.global.AutoWatch.Enabled = not self.db.global.AutoWatch.Enabled;
	end);
	autoWatchedOption:SetTooltip(function(tooltip, elementDescription)
		GameTooltip_SetTitle(tooltip, MenuUtil.GetElementText(elementDescription));
		GameTooltip_AddNormalLine(tooltip, "Increased reputations are automatically added to the Recent Reputations list.");
	end);
	autoWatchedOption:CreateCheckbox("Ignore guild reputation", function() return self.db.global.AutoWatch.IgnoreGuild; end, function() self.db.global.AutoWatch.IgnoreGuild = not self.db.global.AutoWatch.IgnoreGuild; end);
	autoWatchedOption:CreateCheckbox("Ignore bodyguard reputation", function() return self.db.global.AutoWatch.IgnoreBodyguard; end, function() self.db.global.AutoWatch.IgnoreBodyguard = not self.db.global.AutoWatch.IgnoreBodyguard; end);
	autoWatchedOption:CreateCheckbox("Ignore inactive reputation", function() return self.db.global.AutoWatch.IgnoreInactive; end, function() self.db.global.AutoWatch.IgnoreInactive = not self.db.global.AutoWatch.IgnoreInactive; end);
	local switchToOption = currentMenu:CreateCheckbox("Auto switch bar to last gained reputation", function() return self.db.global.AutoWatch.SwitchTo; end, function()
		self.db.global.AutoWatch.SwitchTo = not self.db.global.AutoWatch.SwitchTo;
	end);
	switchToOption:SetTooltip(function(tooltip, elementDescription)
		GameTooltip_SetTitle(tooltip, MenuUtil.GetElementText(elementDescription));
		GameTooltip_AddNormalLine(tooltip, "Automatically switch the Reputation bar to track latest gained reputation.");
	end);

	currentMenu:CreateDivider();
	currentMenu:CreateTitle("Set Watched Faction");

	module:GetReputationsMenu(currentMenu);
end

------------------------------------------

function module:SaveCollapsedHeaders()
	local numFactions = C_Reputation.GetNumFactions();
	local collapsedHeaders = {};

	for factionIndex = 1, numFactions do
		local factionData = C_Reputation.GetFactionDataByIndex(factionIndex);
		if factionData and factionData.isCollapsed then
			tinsert(collapsedHeaders, factionData.factionID);
		end
	end

	return collapsedHeaders;
end

function module:CloseCollapsedHeaders(collapsedHeaders)
	local numFactions = C_Reputation.GetNumFactions();
	for factionIndex = numFactions, 1, -1 do
		local factionData = C_Reputation.GetFactionDataByIndex(factionIndex);

		for index, value in pairs(collapsedHeaders) do
			if factionData and value == factionData.factionID then
				C_Reputation.CollapseFactionHeader(factionIndex);
				tremove(collapsedHeaders, index)
				break;
			end
		end
	end
end

function module:GetFactionActive(givenFactionID)
	local isActive = true;
	local numFactions = C_Reputation.GetNumFactions();
	local inactiveCollapsed = false;

	while numFactions >= 1 do
		local factionData = C_Reputation.GetFactionDataByIndex(numFactions);
		if factionData then
			local factionID, isHeader, isCollapsed = factionData.factionID, factionData.isHeader, factionData.isCollapsed;

			if factionID == 0 and isHeader and isCollapsed then
				inactiveCollapsed = true;
				C_Reputation.ExpandFactionHeader(numFactions);
				numFactions = C_Reputation.GetNumFactions();
			else
				if factionID == givenFactionID then
					isActive = C_Reputation.IsFactionActive(numFactions);
					break;
				end
	
				numFactions = numFactions - 1;
			end
		end
	end

	if inactiveCollapsed then
		for factionIndex = numFactions, 1, -1 do
			local faction = C_Reputation.GetFactionDataByIndex(factionIndex);
			if faction and faction.factionID == 0 then
				C_Reputation.CollapseFactionHeader(factionIndex);
			end
		end
	end

	return isActive;
end

function module:GetFactionIDByName(factionName)
	local requestedFactionID = 0;
	local collapsedHeaders = {};

	local numFactions = C_Reputation.GetNumFactions();
	local factionIndex = 1;

	while factionIndex <= numFactions do
		local factionData = C_Reputation.GetFactionDataByIndex(factionIndex);
		local factionID, name, isHeader, isCollapsed = factionData.factionID, factionData.name, factionData.isHeader, factionData.isCollapsed;
		-- Don't count inactive reps.
		if factionID == 0 then
			break;
		end
		if name then
			if name == factionName then
				requestedFactionID = factionID;
				break;
			end

			if isHeader and isCollapsed then
				C_Reputation.ExpandFactionHeader(factionIndex);
				tinsert(collapsedHeaders, factionData.factionID);
				numFactions = C_Reputation.GetNumFactions();
			end
		end

		factionIndex = factionIndex + 1;
	end

	module:CloseCollapsedHeaders(collapsedHeaders);
	return requestedFactionID;
end

function module:MenuSetWatchedFactionID(factionID)
	C_Reputation.SetWatchedFactionByID(factionID);
end

function module:MenuSetWatchedFactionIndex(factionIndex)
	C_Reputation.SetWatchedFactionByIndex(factionIndex);
end

function module:GetRecentReputationsMenu()
	local factions = {
		{
			name = "Recent Reputations", isRecentTitle = true,
		},
	};

	local recentRepsList = module:GetSortedRecentList();
	for _, rep in ipairs(recentRepsList) do
		local name = rep.name;
		local data = rep.data;

		if name then
			local factionData = C_Reputation.GetFactionDataByID(data.factionID);
			local standing, isHeader, hasRep, isWatched = factionData.reaction, factionData.isHeader, factionData.isHeaderWithRep, factionData.isWatched;

			if not isHeader or hasRep then
				local standing_text = "";
				local majorFactionData = C_MajorFactions.GetMajorFactionData(data.factionID);
				local reputationInfo = C_GossipInfo.GetFriendshipReputation(data.factionID);

				if (majorFactionData) then
					standing_text = string.format("|cnHEIRLOOM_BLUE_COLOR:Renown %s|r", majorFactionData.renownLevel);
				elseif (reputationInfo and reputationInfo.friendshipFactionID > 0) then
					standing_text, _ = module:GetFriendShipColorText(reputationInfo.friendshipFactionID, reputationInfo.reaction);
				else
					standing_text, _ = module:GetStandingColorText(standing);
				end

				tinsert(factions, {
					name = string.format("%s (%s)  +%s rep this session", name, standing_text, BreakUpLargeNumbers(data.amount)),
					isRecentFaction = true,
					factionID = data.factionID,
					isWatched = isWatched,
				})
			end
		end
	end

	if #recentRepsList == 0 then
		return false;
	end

	return factions;
end

function module:GetReputationProgressByFactionID(factionID)
	if not factionID then return nil end

	local factionData = C_Reputation.GetFactionDataByID(factionID);
	local name, standing, minReputation, maxReputation, currentReputation = factionData.name, factionData.reaction, factionData.currentReactionThreshold, factionData.nextReactionThreshold, factionData.currentStanding;
	if not name or not minReputation or not maxReputation then return nil end

	-- Friendships
	local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);

	-- Renown
	local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);

	local isCapped = false;
	local isParagon = false;

	if majorFactionData then
		minReputation = 0;
		if not majorFactionData.renownLevelThreshold then
			isCapped = true; -- This will never trigger for now, Renown does not get capped.
		elseif C_Reputation.IsFactionParagon(factionID) then
			currentReputation, maxReputation = C_Reputation.GetFactionParagonInfo(factionID);
			isParagon = true;
			currentReputation = currentReputation % maxReputation;
		else
			currentReputation = majorFactionData.renownReputationEarned;
			maxReputation = majorFactionData.renownLevelThreshold;
		end
	elseif reputationInfo and reputationInfo.friendshipFactionID > 0 then
		local friendStanding = reputationInfo.standing;
		local friendThreshold = reputationInfo.reactionThreshold;
		local nextFriendThreshold = reputationInfo.nextThreshold;
		if not nextFriendThreshold then
			isCapped = true;
		else
			minReputation = friendThreshold;
			currentReputation = friendStanding;
			maxReputation = nextFriendThreshold;
		end
	else
		if standing == MAX_REPUTATION_REACTION then
			if C_Reputation.IsFactionParagon(factionID) then
				currentReputation, maxReputation = C_Reputation.GetFactionParagonInfo(factionID);
				isParagon = true;
				minReputation = 0;
				currentReputation = currentReputation % maxReputation;
			else
				isCapped = true;
			end
		end
	end

	return currentReputation - minReputation, maxReputation - minReputation, isCapped, isParagon;
end

function module:CreateRecentReputationsMenu(currentMenu, recents)
	for _, recentsInfo in ipairs(recents) do
		if recentsInfo.isRecentTitle then
			currentMenu:CreateTitle(recentsInfo.name);
		elseif recentsInfo.isRecentFaction then
			currentMenu:CreateRadio(recentsInfo.name, function() return recentsInfo.isWatched; end, function()
				module:MenuSetWatchedFactionID(recentsInfo.factionID);
			end);
		end
	end
	currentMenu:CreateButton("Clear recent reputations", function() wipe(module.recentReputations); end);
end

function module:CreateWatchedFactionSubMenu(subMenu, factionInfo)
	subMenu:CreateTitle(factionInfo.menuList[1].name);
	tremove(factionInfo.menuList, 1);
	for _, faction in ipairs(factionInfo.menuList) do
		local factionOption;

		if faction.isHeader then
			factionOption = subMenu:CreateButton(faction.name);
			module:CreateWatchedFactionSubMenu(factionOption, faction);
		else
			factionOption = subMenu:CreateRadio(faction.name, function() return faction.isWatched; end, function()
				module:MenuSetWatchedFactionID(faction.factionID);
			end);
		end

		if faction.isHeaderWithRep then
			factionOption:SetShouldRespondIfSubmenu(true);
			factionOption:SetResponse(MenuResponse.CloseAll);
			module:CreateWatchedFactionSubMenu(factionOption, faction);
		end
	end
end

function module:CreateWatchedFactionsMenu(currentMenu, factions)
	for _, faction in ipairs(factions) do
		if faction.isMajorHeader then
			local majorHeader = currentMenu:CreateButton(faction.name);
			module:CreateWatchedFactionSubMenu(majorHeader, faction);
		end
	end
end

function module:GetReputationsMenu(currentMenu)
	local factions = {};

	local previous, current = nil, nil;
	local tier = 0;

	local collapsedHeaders = {};

	local numFactions = C_Reputation.GetNumFactions();
	local factionIndex = 1;
	while factionIndex <= numFactions do
		local factionData = C_Reputation.GetFactionDataByIndex(factionIndex);
		-- TWW introduced potential empty headers, only handle below if factionData exists.
		if factionData then
			local factionID, name, standing, isHeader, isCollapsed, hasRep, isWatched, isChild = factionData.factionID, factionData.name, factionData.reaction, factionData.isHeader, factionData.isCollapsed, factionData.isHeaderWithRep, factionData.isWatched, factionData.isChild;
			-- Don't count inactive reps.
			if factionID == 0 then
				break;
			end
			if name then
				local progressText = "";
				if factionID then
					local currentRep, nextThreshold, isCapped, isParagon = module:GetReputationProgressByFactionID(factionID);
					if (isParagon) then
						standing = 9;
					end

					if (currentRep and not isCapped) then
						progressText = string.format("  (|cfffff2ab%s|r / %s)", BreakUpLargeNumbers(currentRep), BreakUpLargeNumbers(nextThreshold));
					end
				end

				local standingText = "";

				if not isHeader or hasRep then
					local reputationInfo = C_GossipInfo.GetFriendshipReputation(factionID);
					local majorFactionData = C_MajorFactions.GetMajorFactionData(factionID);
					if (majorFactionData and standing ~= 9) then
						standingText = string.format("|cnHEIRLOOM_BLUE_COLOR:Renown %s|r", majorFactionData.renownLevel);
					elseif (reputationInfo and reputationInfo.friendshipFactionID > 0) then
						standingText, _ = module:GetFriendShipColorText(reputationInfo.friendshipFactionID, reputationInfo.reaction);
					else
						standingText, _ = module:GetStandingColorText(standing);
					end
				end

				-- Open up collapsed headers temporarily
				if isHeader and isCollapsed then
					C_Reputation.ExpandFactionHeader(factionIndex);
					tinsert(collapsedHeaders, factionData.factionID);
					numFactions = C_Reputation.GetNumFactions();
				end

				-- 2nd tier has some quirks which we fix here:
				-- If 2nd but not a child, it's 1st tier.
				-- If 2nd tier but a child, but also a header (with or without rep), it's 1st tier.
				if tier == 2 then
					if not isChild or (isChild and (isHeader or hasRep)) then
						current = previous;
						tier = 1;
					end
				end

				if isHeader and not hasRep and not isChild then -- Expansion 1st tier header
					tinsert(factions, {
						name = name,
						isMajorHeader = true;
						menuList = {},
					})

					current = factions[#factions].menuList;
					tinsert(current, {
						name = name,
						isMajorHeaderTitle = true,
					})

					tier = 1;
				elseif tier == 1 then -- 2nd tier header/expansions
					if not isHeader then -- Simple faction, no header business.
						tinsert(current, {
							name = string.format("%s (%s)%s", name, standingText, progressText),
							isFaction = true,
							factionID = factionID,
							isWatched = isWatched,
						})
					else
						if not hasRep then
							tinsert(current, {
								name = name,
								isHeader = true,
								menuList = {},
							})
						else
							tinsert(current, {
								name = string.format("%s (%s)%s", name, standingText, progressText),
								isHeaderWithRep = true,
								factionID = factionID,
								isWatched = isWatched,
								menuList = {},
							})
						end

						previous = current;
						current = current[#current].menuList;
						tinsert(current, {
							name = name,
							isSubMenuTitle = true,
						})

						tier = 2;
					end
				elseif tier == 2 then -- 3rd tier header
					tinsert(current, {
						name = string.format("%s (%s)%s", name, standingText, progressText),
						isFaction = true,
						factionID = factionID,
						isWatched = isWatched,
					})
				end
			end
		end

		factionIndex = factionIndex + 1;
	end

	module:CloseCollapsedHeaders(collapsedHeaders);
	module:CreateWatchedFactionsMenu(currentMenu, factions);

	local recent = module:GetRecentReputationsMenu();
	if recent ~= false then
		currentMenu:CreateDivider();
		module:CreateRecentReputationsMenu(currentMenu, recent);
	end

	currentMenu:CreateDivider();

	currentMenu:CreateButton("Open reputations panel", function() ToggleCharacter("ReputationFrame"); end);
end

------------------------------------------

function module:HasWatchedReputation()
	return C_Reputation.GetWatchedFactionData() ~= nil;
end

function module:GetStandingColorText(standing)
	local colors = {
		[1] = {r=0.80, g=0.13, b=0.13}, -- hated
		[2] = {r=1.00, g=0.25, b=0.00}, -- hostile
		[3] = {r=0.93, g=0.40, b=0.13}, -- unfriendly
		[4] = {r=1.00, g=1.00, b=0.00}, -- neutral
		[5] = {r=0.00, g=0.70, b=0.00}, -- friendly
		[6] = {r=0.00, g=1.00, b=0.00}, -- honored
		[7] = {r=0.00, g=0.60, b=1.00}, -- revered
		[8] = {r=0.00, g=1.00, b=1.00}, -- exalted
		[9] = {r=0.00, g=1.00, b=1.00}, -- paragon
	}

	local label;
	if (standing < 9) then
		label = GetText("FACTION_STANDING_LABEL" .. standing, UnitSex("player"));
	else
		label = "Paragon";
	end

	return string.format('|cff%02x%02x%02x%s|r',
		colors[standing].r * 255,
		colors[standing].g * 255,
		colors[standing].b * 255,
		label
	), colors[standing];
end

function module:GetFriendShipColorText(friendshipFactionID, standing)
	local standingLevel = C_GossipInfo.GetFriendshipReputationRanks(friendshipFactionID).currentLevel;
	local colors = {
		[1] = {r=0.80, g=0.13, b=0.13}, -- hated
		[2] = {r=1.00, g=0.25, b=0.00}, -- hostile
		[3] = {r=0.93, g=0.40, b=0.13}, -- unfriendly
		[4] = {r=1.00, g=1.00, b=0.00}, -- neutral
		[5] = {r=0.00, g=0.70, b=0.00}, -- friendly
		[6] = {r=0.00, g=1.00, b=0.00}, -- honored
		[7] = {r=0.00, g=0.60, b=1.00}, -- revered
		[8] = {r=0.00, g=1.00, b=1.00}, -- exalted
		[9] = {r=0.00, g=1.00, b=1.00}, -- paragon
	}

	local friendshipColors = {
		[1] = colors[4], -- Stranger
		[2] = colors[5], -- Acquaintance/Pal
		[3] = colors[6], -- Buddy
		[4] = colors[6], -- Friend
		[5] = colors[7], -- Good Friend
		[6] = colors[8], -- Best Friend
		[9] = colors[9], -- Paragon
	}

	if friendshipFactionID == 1374 or friendshipFactionID == 1419 or friendshipFactionID == 1690 or friendshipFactionID == 1691 or friendshipFactionID == 2010 or friendshipFactionID == 2011 then -- Brawlers S1-S3
		friendshipColors = {
			[1] = colors[5], -- Rank 1
			[2] = colors[5], -- Rank 2
			[3] = colors[5], -- Rank 3
			[4] = colors[5], -- Rank 4
			[5] = colors[5], -- Rank 5
			[6] = colors[5], -- Rank 6
			[7] = colors[5], -- Rank 7
			[8] = colors[5], -- Rank 8
			[9] = colors[5], -- Rank 9
			[10] = colors[5], -- Rank 10
		}
	elseif friendshipFactionID == 2371 or friendshipFactionID == 2372 then -- Brawlers S4/Current
		friendshipColors = {
			[1] = colors[5], -- Rank 1
			[2] = colors[5], -- Rank 2
			[3] = colors[5], -- Rank 3
			[4] = colors[5], -- Rank 4
			[5] = colors[5], -- Rank 5
			[6] = colors[5], -- Rank 6
			[7] = colors[5], -- Rank 7
			[8] = colors[5], -- Rank 8
		}
	elseif friendshipFactionID == 2135 then -- Chromie
		friendshipColors = {
			[1] = colors[4], -- Whelpling
			[2] = colors[4], -- Temporal Trainee
			[3] = colors[5], -- Timehopper
			[4] = colors[5], -- Chrono-Friend
			[5] = colors[6], -- Bronze Ally
			[6] = colors[7], -- Epoch-Mender
			[7] = colors[8], -- Timelord
		}
	elseif friendshipFactionID == 1357 then -- Nomi
		friendshipColors = {
			[1] = colors[4], -- Apprentice
			[2] = colors[4], -- Apprentice
			[3] = colors[5], -- Journeyman
			[4] = colors[6], -- Journeyman
			[5] = colors[7], -- Journeyman
			[6] = colors[8], -- Expert
		}
	elseif friendshipFactionID == 2517 or friendshipFactionID == 2518 then -- Wrathion/Sabellian TO-DO: Confirm colors
		friendshipColors = {
			[1] = colors[4], -- Acquaintance
			[2] = colors[4], -- Cohort
			[3] = colors[5], -- Ally
			[4] = colors[6], -- Fang
			[5] = colors[7], -- Friend
			[6] = colors[8], -- True Friend
			[9] = colors[9], -- Paragon
		}
	elseif friendshipFactionID == 2544 or friendshipFactionID == 2568 or friendshipFactionID == 2553 or friendshipFactionID == 2550 or friendshipFactionID == 2615 then -- Artisan's Consortium - Dragon Isles Branch / Glimmerogg Racer / Soridormi / Cobalt Assembly / Azerothian Archives
		friendshipColors = {
			[1] = colors[4], -- Neutral    -- Aspirational  -- Anomaly                   -- Empty    -- Junior
			[2] = colors[5], -- Preferred  -- Amateur       -- Future Friend             -- Low      -- Capable
			[3] = colors[6], -- Respected  -- Competent     -- Rift Mender               -- Medium   -- Learned
			[4] = colors[7], -- Valued     -- Skilled       -- Timewalker                -- High     -- Resident
			[5] = colors[8], -- Esteemed   -- Professional  -- Legend of the Multiverse  -- Maximum  -- Tenured
		}
	end

	if friendshipColors[standingLevel] == nil then
		return string.format('|cff%02x%02x%02x%s|r',
		colors[5].r * 255,
		colors[5].g * 255,
		colors[5].b * 255,
		standing
		), colors[5];
	end

	return string.format('|cff%02x%02x%02x%s|r',
		friendshipColors[standingLevel].r * 255,
		friendshipColors[standingLevel].g * 255,
		friendshipColors[standingLevel].b * 255,
		standing
	), friendshipColors[standingLevel];
end

function module:UPDATE_FACTION()
	local factionData = C_Reputation.GetWatchedFactionData();
	if factionData then
		module.levelUpRequiresAction = (factionData.factionID and C_Reputation.IsFactionParagon(factionData.factionID));

		local instant = false;
		if (factionData.name ~= module.Tracked or not factionData.name) then
			instant = true;
			module.AutoWatchUpdate = 0;
		end
		module.Tracked = factionData.name;

		module:SetStanding(factionData.factionID);
		module:Refresh(instant);
	end
end

local reputationPattern = FACTION_STANDING_INCREASED:gsub("%%s", "(.-)"):gsub("%%d", "(%%d*)%%");
local warbandReputationPattern = FACTION_STANDING_INCREASED_ACCOUNT_WIDE:gsub("%%s", "(.-)"):gsub("%%d", "(%%d*)%%");

function module:CHAT_MSG_COMBAT_FACTION_CHANGE(event, message, ...)
	local reputation, amount = message:match(reputationPattern);
	amount = tonumber(amount) or 0;

	-- If no reputation is found, check for warband (account-wide).
	if not reputation then
		reputation, amount = message:match(warbandReputationPattern);
		amount = tonumber(amount) or 0;
	end

	-- If not char-specific or warband reputation or keeping track of recent rep, end here.
	if not reputation or not module.recentReputations then return end

	local isGuild = false;
	if reputation == GUILD then
		isGuild = true;

		local guildName = GetGuildInfo("player");
		if guildName then
			reputation = guildName;
		end
	end

	if not module.recentReputations[reputation] then
		module.recentReputations[reputation] = {
			amount = 0,
			factionID = module:GetFactionIDByName(reputation),
		};
	end

	module.recentReputations[reputation].amount = module.recentReputations[reputation].amount + amount;

	if self.db.global.AutoWatch.Enabled then
		if self.db.global.AutoWatch.SwitchTo then
			module:MenuSetWatchedFactionID(module.recentReputations[reputation].factionID);
		end

		if module.AutoWatchUpdate ~= 2 then
			if (self.db.global.AutoWatch.IgnoreInactive and module:GetFactionActive(module.recentReputations[reputation].factionID)) then return end
			if (self.db.global.AutoWatch.IgnoreBodyguard and BODYGUARD_FACTIONS[module.recentReputations[reputation].factionID] ~= nil) then return end
			if (self.db.global.AutoWatch.IgnoreGuild and isGuild) then return end

			module.AutoWatchUpdate = 1;
			module.AutoWatchRecentTimeout = 0.1;

			if (not module.AutoWatchRecent[reputation]) then
				module.AutoWatchRecent[reputation] = 0;
			end
			module.AutoWatchRecent[reputation] = module.AutoWatchRecent[reputation] + amount;
		end
	end
end

function module:AllowedToBufferUpdate()
	return module.AutoWatchUpdate == 0;
end

function module:Update(elapsed)
	if module.AutoWatchUpdate == 1 then
		if module.AutoWatchRecentTimeout > 0.0 then
			module.AutoWatchRecentTimeout = module.AutoWatchRecentTimeout - elapsed;
		end

		if module.AutoWatchRecentTimeout <= 0.0 then
			local selectedFaction = nil;
			local largestGain = 0;
			for faction, gain in pairs(module.AutoWatchRecent) do
				if gain > largestGain then
					selectedFaction = faction;
					largestGain = gain;
				end
			end

			local factionData = C_Reputation.GetWatchedFactionData();
			if factionData and selectedFaction ~= factionData.name then
				module:MenuSetWatchedFactionID(factionData.factionID);
				module.AutoWatchUpdate = 2;
			else
				module.AutoWatchUpdate = 0;
			end

			module.AutoWatchRecentTimeout = 0;
			wipe(module.AutoWatchRecent);
		end
	end
end
