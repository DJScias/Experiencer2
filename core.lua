------------------------------------------------------------
-- Experiencer2 by DJScias (https://github.com/DJScias/Experiencer2)
-- Originally by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME = ...;
local Addon = LibStub("AceAddon-3.0"):NewAddon(select(2, ...), ADDON_NAME, "AceEvent-3.0", "AceHook-3.0");
_G[ADDON_NAME] = Addon;

Addon:SetDefaultModuleLibraries("AceEvent-3.0");

local AceDB = LibStub("AceDB-3.0");
local LibSharedMedia = LibStub("LibSharedMedia-3.0");

-- Adding default media to LibSharedMedia in case they're not already added
LibSharedMedia:Register("font", "DorisPP", [[Interface\AddOns\Experiencer2\Media\DORISPP.TTF]]);

EXPERIENCER_SPLITS_TIP = "You can split Experiencer bar in up to three different sections allowing you to display more information at once.|n|nRight-click the bar to see options.";

local TEXT_VISIBILITY_HIDE      = 1;
local TEXT_VISIBILITY_HOVER     = 2;
local TEXT_VISIBILITY_ALWAYS    = 3;
local baseFrameLevel;

local FrameLevels = {
	"rested",
	"visualSecondary",
	"visualPrimary",
	"change",
	"main",
	"color",
	"highlight",
	"textFrame",
};

Addon.activeModules = {}
Addon.orderedModules = {};

ExperiencerModuleBarsMixin = {
	module   = nil,
	moduleId = "",

	previousData     = nil,
	hasModuleChanged = false,
	changeTarget     = 0,

	hasBuffer        = false,
	bufferTimeout    = 0,
};

function Addon:GetPlayerClassColor()
	local _, class = UnitClass("player");
	return (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class or 'PRIEST'];
end

function Addon:OnInitialize()
	local defaults = {
		char = {
			Visible 	    = true,
			TextVisibility  = TEXT_VISIBILITY_ALWAYS,

			NumSplits       = 1,
			ActiveModules   = { },

			DataBrokerSource = 1,
		},

		global = {
			AnchorPoint	    = "BOTTOM",
			BigBars         = false,
			FlashLevelUp    = true,

			FontFace = "DorisPP",
			FontScale = 1,

			Color = {
				UseClassColor = true,
				r = 1,
				g = 1,
				b = 1,

				UseRepColor = false,
				Rep = {
					r = 1,
					g = 1,
					b = 1,
				}
			},

			SplitsTipShown = false,
		}
	};

	self.db = AceDB:New("ExperiencerDB", defaults);

	Addon:InitializeDataBroker();
	Addon:InitializeModules();

	local activeModules = self.db.char.ActiveModules;

	if not activeModules[1] then
		-- Set default module based on player's level (Max = rep, not max = exp).
		activeModules[1] = GetMaxLevelForLatestExpansion() == UnitLevel("player") and "reputation" or "experience";
	end

	for index = 1, self.db.char.NumSplits do
		local activeModule = activeModules[index];
		if activeModule then
			Addon:SetModule(index, activeModule, true);
		else
			local newModule = Addon:FindValidModuleForBar(index);
			Addon:SetModule(index, newModule.id, true);
		end
	end
end


function Addon:SetReputationColor(colors)
	if not colors then
		colors = {r=1.00, g=1.00, b=0.00};
	end

	self.db.global.Color.Rep = colors;
	Addon:UpdateFrames();
end

function Addon:GetBarColor(bar)
	bar = bar or "";
	local colorDB = self.db.global.Color;

	if bar == "reputation" and colorDB.UseRepColor then
		return {
			r = colorDB.Rep.r,
			g = colorDB.Rep.g,
			b = colorDB.Rep.b
		};
	elseif colorDB.UseClassColor then
		return Addon:GetPlayerClassColor();
	else
		return {
			r = colorDB.r,
			g = colorDB.g,
			b = colorDB.b
		};
	end
end

function ExperiencerSplitsAlertCloseButton_OnClick(self)
	Addon.db.global.SplitsTipShown = true;
end

function Addon:OnEnable()
	WorldMapFrame:HookScript("OnShow", function() Addon:UpdateVisiblity() end);
	WorldMapFrame:HookScript("OnHide", function() Addon:UpdateVisiblity() end);
	hooksecurefunc(WorldMapFrame, "Minimize", function() Addon:UpdateVisiblity() end);
	hooksecurefunc(WorldMapFrame, "Maximize", function() Addon:UpdateVisiblity() end);

	Addon:RegisterEvent("PLAYER_REGEN_DISABLED");
	Addon:RegisterEvent("PET_BATTLE_OPENING_START");
	Addon:RegisterEvent("PET_BATTLE_CLOSE");

	ExperiencerFrame:EnableMouse(true);
	ExperiencerFrame:EnableMouseWheel(true);

	ExperiencerFrame:SetScript("OnEnter", Experiencer_OnEnter);
	ExperiencerFrame:SetScript("OnLeave", Experiencer_OnLeave);
	ExperiencerFrame:SetScript("OnMouseDown", Experiencer_OnMouseDown);
	ExperiencerFrame:SetScript("OnMouseWheel", Experiencer_OnMouseWheel);
	ExperiencerFrame:SetScript("OnUpdate", Experiencer_OnUpdate);

	Addon:UpdateFrames();

	Addon:RefreshBars(true);
	Addon:UpdateVisiblity();
end

function Addon:IsBarVisible()
	return self.db.char.Visible;
end

function Addon:InitializeModules()
	for moduleId, module in Addon:IterateModules() do
		Addon.orderedModules[module.order] = module;

		if module.savedvars then
			module.db = AceDB:New("ExperiencerDB_module_" .. moduleId, module.savedvars);
		end

		module:Initialize();
		module.initialized = true;
	end

	Addon.modulesInitialized = true;
end

function Addon:RegisterModule(moduleId, prototype)
	if Addon:GetModule(moduleId, true) then
		error(("Addon:RegisterModule(moduleId[, prototype]): Module '%s' is already registered."):format(tostring(moduleId)), 2);
		return;
	end

	local module = Addon:NewModule(moduleId, prototype or {});
	module.id = moduleId;

	module.Refresh = function(self, instant)
		Addon:RefreshModule(self, instant);
	end

	module.RefreshText = function(self)
		Addon:RefreshText(self);
	end

	return module;
end

function Addon:ToggleVisibility(visiblity)
	self.db.char.Visible = visiblity or not self.db.char.Visible;
	Addon:UpdateVisiblity();
end

function Addon:UpdateVisiblity()
	if WorldMapFrame then
		ExperiencerFrame:SetShown(not WorldMapFrame.isMaximized or not WorldMapFrame:IsVisible());
	end

	if self.db.char.Visible then
		Addon:ShowBar();
	else
		Addon:HideBar();
	end
end

function Addon:ShowBar()
	ExperiencerFrameBars:Show();

	if Addon.db.char.TextVisibility == TEXT_VISIBILITY_ALWAYS then
		for _, moduleFrame in Addon:GetModuleFrameIterator() do
			moduleFrame.textFrame:Show();
		end
	end
end

function Addon:HideBar()
	ExperiencerFrameBars:Hide();
end

function Addon:GetProgressColor(progress)
	local r = math.floor(math.min(1.0, math.max(0.0, 2.0 - progress * 1.8)) * 255);
	local g = math.floor(math.min(1.0, math.max(0.0, progress * 2.0)) * 255);
	local b = 0;

	return string.format("|cff%02x%02x%02x", r, g, b);
end

function Addon:FinishedProgressColor()
	local r = 0
	local g = 1;
	local b = 1;

	return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255);
end

local function UnitAuraByNameOrId(unit, aura_name_or_id, filter)
    local auraIndex = 1;
    local auraInfo = C_UnitAuras.GetAuraDataByIndex(unit, auraIndex, filter);

    while auraInfo do
        if auraInfo.name == aura_name_or_id or auraInfo.spellId == aura_name_or_id then
            return true;  -- Aura found
        end

        auraIndex = auraIndex + 1;
        auraInfo = C_UnitAuras.GetAuraDataByIndex(unit, auraIndex, filter);
    end

    return false;  -- Aura not found
end

function Addon:PlayerHasBuff(spellID)
    return UnitAuraByNameOrId("player", spellID, "HELPFUL|PLAYER|CANCELABLE");
end

local function roundnum(num, idp)
	return tonumber(string.format("%." .. (idp or 0) .. "f", num));
end

function Addon:FormatNumber(num)
	num = tonumber(num);

	if num >= 1000000 then
		return roundnum(num / 1e6, 2) .. "m";
	elseif num >= 1000 then
		return roundnum(num / 1e3, 2) .. "k";
	end

	return num;
end

function Addon:FormatNumberFancy(num, billions)
	billions = billions or true;
	num = tonumber(num);
	if not num then
		return num;
	end

	local divisor = 1;
	local suffix = "";
	if num >= 1e9 and billions then
		suffix = "b";
		divisor = 1e9;
	elseif num >= 1e6 then
		suffix = "m";
		divisor = 1e6;
	elseif num >= 1e3 then
		suffix = "k";
		divisor = 1e3;
	end

	return BreakUpLargeNumbers(num / divisor) .. suffix;
end

function Addon:GetCurrentSplit()
	return Addon.db.char.NumSplits;
end

function Addon:RefreshModule(module, instant)
	for _, moduleFrame in Addon:GetModuleFrameIterator() do
		if moduleFrame.module == module then
			moduleFrame:Refresh(instant);
			return;
		end
	end
end

function Addon:RefreshText(module)
	for _, moduleFrame in Addon:GetModuleFrameIterator() do
		if not module or moduleFrame.module == module then
			moduleFrame:RefreshText();
		end
		if module and moduleFrame.module == module then
			return;
		end
	end
end

function Addon:GetModuleFrame(index)
	assert(tonumber(index) ~= nil, "Index must be a number");
	local frameName = "ExperiencerFrameBarsModule" .. tonumber(index);
	return _G[frameName];
end

function Addon:GetModuleFrameIterator()
	return ipairs({
		Addon:GetModuleFrame(1),
		Addon:GetModuleFrame(2),
		Addon:GetModuleFrame(3),
	});
end

function Addon:UpdateFrames()
	local globalDB = self.db.global;
	local anchor = globalDB.AnchorPoint or "BOTTOM";
	local offset = 0;

	if anchor == "TOP" then
		offset = 1;
	elseif anchor == "BOTTOM" then
		offset = -1;
	end

	ExperiencerFrame:ClearAllPoints();
	ExperiencerFrame:SetPoint(anchor .. "LEFT", UIParent, anchor .. "LEFT", 0, offset);
	ExperiencerFrame:SetPoint(anchor .. "RIGHT", UIParent, anchor .. "RIGHT", 0, offset);

	if not globalDB.SplitsTipShown then
		local alertFrame = ExperiencerFrame.SplitsAlert;

		alertFrame:ClearAllPoints();
		alertFrame.Arrow:ClearAllPoints();

		if anchor == "BOTTOM" then
			alertFrame:SetPoint("BOTTOM", ExperiencerFrame, "TOP", 0, 30);
			alertFrame.Arrow:SetPoint("TOP", alertFrame, "BOTTOM", 0, 2);
			SetClampedTextureRotation(alertFrame.Arrow.Arrow, 0);
			SetClampedTextureRotation(alertFrame.Arrow.Glow, 0);
		elseif anchor == "TOP" then
			alertFrame:SetPoint("TOP", ExperiencerFrame, "BOTTOM", 0, -30);
			alertFrame.Arrow:SetPoint("BOTTOM", alertFrame, "TOP", 0, -2);
			SetClampedTextureRotation(alertFrame.Arrow.Arrow, 180);
			SetClampedTextureRotation(alertFrame.Arrow.Glow, 180);
		end

		alertFrame.Arrow.Glow:Hide();
		alertFrame:Show();
	end

	if not globalDB.BigBars then
		ExperiencerFrame:SetHeight(10);
	else
		ExperiencerFrame:SetHeight(17);
	end

	local numSplits = Addon:GetCurrentSplit();
	local width, _ = ExperiencerFrameBars:GetSize();
	local sectionWidth = width / numSplits;

	local parentFrame = ExperiencerFrameBars;
	local moduleBars = {
		Addon:GetModuleFrame(1),
		Addon:GetModuleFrame(2),
		Addon:GetModuleFrame(3),
	};

	for _, moduleBar in ipairs(moduleBars) do
		moduleBar:ClearAllPoints();
	end

	if numSplits == 1 then
		moduleBars[1]:Show();
		moduleBars[1]:SetAllPoints(parentFrame);

		moduleBars[2]:Hide();
		moduleBars[3]:Hide();
	elseif numSplits == 2 then
		moduleBars[1]:Show();
		moduleBars[1]:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, 0);
		moduleBars[1]:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", 0, 0);
		moduleBars[1]:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOM", 0, 0);

		moduleBars[2]:Show();
		moduleBars[2]:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", 0, 0);
		moduleBars[2]:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOM", 0, 0);
		moduleBars[2]:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", 0, 0);

		moduleBars[3]:Hide();
	elseif numSplits == 3 then
		moduleBars[1]:Show();
		moduleBars[1]:SetPoint("TOPLEFT", parentFrame, "TOPLEFT", 0, 0);
		moduleBars[1]:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMLEFT", 0, 0);
		moduleBars[1]:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMLEFT", sectionWidth, 0);

		moduleBars[2]:Show();
		moduleBars[2]:SetPoint("TOP", parentFrame, "TOP", 0, 0);
		moduleBars[2]:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOM", -sectionWidth / 2, 0);
		moduleBars[2]:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOM", sectionWidth / 2, 0);

		moduleBars[3]:Show();
		moduleBars[3]:SetPoint("TOPRIGHT", parentFrame, "TOPRIGHT", 0, 0);
		moduleBars[3]:SetPoint("BOTTOMLEFT", parentFrame, "BOTTOMRIGHT", -sectionWidth, 0);
		moduleBars[3]:SetPoint("BOTTOMRIGHT", parentFrame, "BOTTOMRIGHT", 0, 0);
	end

	for i, moduleFrame in Addon:GetModuleFrameIterator() do
		local barColor = Addon:GetBarColor(self.db.char.ActiveModules[i]);
		local brightness = 0.2126 * barColor.r + 0.7152 * barColor.g + 0.0722 * barColor.b; -- calculate brightness
		local inverseBrightness = 1 - brightness; -- calculate inverse brightness

		-- Set status bar colors
		moduleFrame.main:SetStatusBarColor(barColor.r, barColor.g, barColor.b);
		moduleFrame.main:SetAnimatedTextureColors(barColor.r, barColor.g, barColor.b);

		moduleFrame.color:SetStatusBarColor(barColor.r, barColor.g, barColor.b, 0.23 + inverseBrightness * 0.26);
		moduleFrame.rested:SetStatusBarColor(barColor.r, barColor.g, barColor.b, 0.3);

		moduleFrame.visualPrimary:SetStatusBarColor(barColor.r, barColor.g, barColor.b, 0.375);
		moduleFrame.visualSecondary:SetStatusBarColor(barColor.r, barColor.g, barColor.b, 0.375);

		-- Configure text frame
		moduleFrame.textFrame:ClearAllPoints();
		moduleFrame.textFrame:SetPoint(anchor, moduleFrame, anchor);
		moduleFrame.textFrame:SetWidth(sectionWidth);

		local fontPath = LibSharedMedia:Fetch("font", globalDB.FontFace);
		ExperiencerFont:SetFont(fontPath, math.floor(10 * globalDB.FontScale), "OUTLINE");
		ExperiencerBigFont:SetFont(fontPath, math.floor(13 * globalDB.FontScale), "OUTLINE");

		local frameHeightMultiplier = (globalDB.FontScale - 1.0) * 0.55 + 1.0;

		if not globalDB.BigBars then
			moduleFrame.textFrame:SetHeight(math.max(18, 20 * frameHeightMultiplier));
			moduleFrame.textFrame.text:SetFontObject("ExperiencerFont");
		else
			moduleFrame.textFrame:SetHeight(math.max(24, 28 * frameHeightMultiplier));
			moduleFrame.textFrame.text:SetFontObject("ExperiencerBigFont");
		end

		-- Set frame levels
		baseFrameLevel = moduleFrame[FrameLevels[1]]:GetFrameLevel();
		for index, frameName in ipairs(FrameLevels) do
			moduleFrame[frameName]:SetFrameLevel(baseFrameLevel + index - 1);
		end
	end
end

function ExperiencerModuleBarsMixin:SetActiveModule(moduleId)
	assert(moduleId ~= nil);
	self.module = Addon:GetModule(moduleId, true);

	if self.module then
		self.moduleId = moduleId;
		self:Refresh(true);
	else
		self:RemoveActiveModule();
	end
end

function ExperiencerModuleBarsMixin:RemoveActiveModule()
	self.moduleId = "";
	self.module = nil;
	self:Refresh(true);
end

function ExperiencerModuleBarsMixin:SetAnimationSpeed(speed)
	assert(speed and speed > 0);

	speed = (1 / speed) * 0.5;
	self.main.tileTemplateDelay = 0.3 * speed;

	local durationPerDistance = 0.008 * speed;

	for _, anim in ipairs({ self.main.Anim:GetAnimations() }) do
		if anim.durationPerDistance then
			anim.durationPerDistance = durationPerDistance;
		end
		if anim.delayPerDistance then
			anim.delayPerDistance = durationPerDistance;
		end
	end
end

function ExperiencerModuleBarsMixin:StopAnimation()
	for _, anim in ipairs({ self.main.Anim:GetAnimations() }) do
		anim:Stop();
	end
end

function Addon:RefreshBars(instant)
	for _, moduleFrame in Addon:GetModuleFrameIterator() do
		moduleFrame:Refresh(instant);
	end
end

function ExperiencerModuleBarsMixin:TriggerBufferedUpdate(instant)
	if not self.module then
		return;
	end

	local data;
	local barData = self.module:GetBarData() or {}; -- Ensure barData is a table even if GetBarData() is nil.

	data = {
		id      = barData.id,                       -- No default for id as nil might be valid.
		level   = barData.level or 0,               -- Default to 0 if level is nil.
		min     = barData.min or 0,                 -- Default to 0 if min is nil.
		max     = barData.max or 1,                 -- Default to 1 if max is nil.
		current = barData.current or 0,             -- Default to 0 if current is nil.
		rested  = barData.rested,                   -- No default for rested as nil might be valid.
		visual  = barData.visual                    -- No default for visual as nil might be valid.
	};

	local valueHasChanged = true;
	local isLoss = false;

	if self.previousData and not self.hasModuleChanged then
		if (data.level < self.previousData.level) or (data.level == self.previousData.level and data.current < self.previousData.current) then
			isLoss = true;
		end

		if data.current == self.previousData.current then
			valueHasChanged = false
		end
	end

	if not isLoss then
		self.main.accumulationTimeoutInterval = 0.01;
	else
		self.main.accumulationTimeoutInterval = 0.35;
	end

	self.main.matchBarValueToAnimation = true;

	self:SetAnimationSpeed(1.0);

	if valueHasChanged and not self.hasModuleChanged and not instant and not isLoss then
		if self.previousData then
			local current = data.current;
			local previous = self.previousData.current;

			if self.previousData.level < data.level then
				current = current + self.previousData.max;
			end

			local diff = (current - previous) / data.max;
			local speed = math.max(1, math.min(10, diff * 1.2 + 1.0)^2);
			self:SetAnimationSpeed(speed);
		end
	end

	self.main:SetAnimatedValues(data.current, data.min, data.max, data.level);

	if not (valueHasChanged and not self.hasModuleChanged and not instant and not isLoss) then
		self.main:ProcessChangesInstantly();
	end

	if not instant and valueHasChanged and not self.hasModuleChanged then
		if not isLoss then
			local fadegain = self.change;

			fadegain.fadegain_in:Stop();
			fadegain.fadegain_out:Stop();
			fadegain.fadegain_out:Play();
		end
		local sparkFade = self.main.spark.fade;

		sparkFade:Stop();
		sparkFade:Play();
	end

	self.previousData = data;
end

function Addon:ShouldShowSecondaryText(moduleIndex)
	return self.db.char.NumSplits < 3 or (Addon.Hovering and Addon:GetModuleIndexFromMousePosition() == moduleIndex);
end

function ExperiencerModuleBarsMixin:RefreshText()
	local text = "";
	local brokerText = "";

	if self.module and self.module.initialized then
		local primaryText, secondaryText = self.module:GetText();
		secondaryText = secondaryText and string.trim(secondaryText) or nil;

		if secondaryText and Addon:ShouldShowSecondaryText(self:GetID()) then
			text = string.trim(primaryText .. "  " .. secondaryText);
		elseif secondaryText then
			text = string.trim(primaryText .. "  |cffffff00+|r");
		else
			text = string.trim(primaryText);
		end

		brokerText = string.trim(primaryText .. "  " .. (secondaryText or ""));
	end

	self.textFrame.text:SetText(text);

	if Addon.db.char.DataBrokerSource == self:GetID() then
		Addon:UpdateDataBrokerText(brokerText);
	end

	local numSplits = Addon:GetCurrentSplit();

	local width, _ = ExperiencerFrameBars:GetSize();
	local sectionWidth = width / numSplits;

	local stringWidth = self.textFrame.text:GetStringWidth();
	self.textFrame:SetWidth(math.max(sectionWidth, stringWidth + 26));
	self.textFrame:SetClampedToScreen(true);

	if Addon.Hovering and Addon:GetModuleIndexFromMousePosition() == self:GetID() then
		Addon.ExpandedTextField = self:GetID();
	elseif Addon.ExpandedTextField == self:GetID() then
		Addon.ExpandedTextField = nil;
	end
end

function ExperiencerModuleBarsMixin:Refresh(instant)
	self:RefreshText();

	self.hasModuleChanged = (self.module ~= self.previousModule);
	self.previousModule = self.module;

	local data;
	if self.module and self.module.initialized then
		local barData = self.module:GetBarData() or {};  -- Ensure barData is a table even if GetBarData() is nil.

		data = {
			id      = barData.id,                       -- No default for id as nil might be valid.
			level   = barData.level or 0,               -- Default to 0 if level is nil.
			min     = barData.min or 0,                 -- Default to 0 if min is nil.
			max     = barData.max or 1,                 -- Default to 1 if max is nil.
			current = barData.current or 0,             -- Default to 0 if current is nil.
			rested  = barData.rested,                   -- No default for rested as nil might be valid.
			visual  = barData.visual                    -- No default for visual as nil might be valid.
		};
	else
		data          = {};
		data.id       = nil;
		data.level    = 0;
		data.min  	  = 0;
		data.max  	  = 1;
		data.current  = 0;
		data.rested   = nil;
		data.visual   = nil;
	end

	local valueHasChanged = true;

	local isLoss = false;
	local changeCurrent = data.current;

	self.hasDataIdChanged = self.previousData and self.previousData.id ~= data.id;

	if self.previousData and not self.hasModuleChanged and not self.hasDataIdChanged then
		local prevLevel, prevCurrent = self.previousData.level, self.previousData.current;

		if data.level == prevLevel and data.current < prevCurrent then
			isLoss = true;
			changeCurrent = prevCurrent;
		end

		if data.level < prevLevel then
			isLoss = true;
			changeCurrent = data.max;
		end

		valueHasChanged = (data.current ~= prevCurrent);
	end

	if instant or isLoss then
		self.hasBuffer = false;
		self:TriggerBufferedUpdate(true);
	else
		self.hasBuffer = true;
		self.bufferTimeout = 0.5;
	end

	self.color:SetMinMaxValues(data.min, data.max);
	self.color:SetValue(self.main:GetContinuousAnimatedValue());

	self.change:SetMinMaxValues(data.min, data.max);
	if not isLoss then
		self.changeTarget = changeCurrent;
		if not self.change.fadegain_in:IsPlaying() then
			self.change:SetValue(self.main:GetContinuousAnimatedValue());
		end
	else
		self.changeTarget = self.main:GetContinuousAnimatedValue();
		self.change:SetValue(changeCurrent);
	end

	if instant or self.hasModuleChanged or self.hasDataIdChanged then
		self.changeTarget = changeCurrent;
		self.change:SetValue(self.changeTarget);
	end

	if data.rested and data.rested > 0 then
		self.rested:Show();
		self.rested:SetMinMaxValues(data.min, data.max);
		self.rested:SetValue(self.main:GetContinuousAnimatedValue() + data.rested);
	else
		self.rested:Hide();
	end

	if data.visual then
		local primary, secondary;
		if type(data.visual) == "number" then
			primary = data.visual;
		elseif type(data.visual) == "table" then
			primary, secondary = unpack(data.visual);
		end

		if primary and primary > 0 then
			self.visualPrimary:Show();
			self.visualPrimary:SetMinMaxValues(data.min, data.max);
			self.visualPrimary:SetValue(self.main:GetContinuousAnimatedValue() + primary);
		else
			self.visualPrimary:Hide();
		end

		if secondary and secondary > 0 then
			self.visualSecondary:Show();
			self.visualSecondary:SetMinMaxValues(data.min, data.max);
			self.visualSecondary:SetValue(self.main:GetContinuousAnimatedValue() + secondary);
		else
			self.visualSecondary:Hide();
		end
	else
		self.visualPrimary:Hide();
		self.visualSecondary:Hide();
	end

	if not instant and valueHasChanged then
		if not isLoss then
			if not self.change.fadegain_in:IsPlaying() then
				self.change.fadegain_in:Play();
			end
		else
			self.change.fadeloss:Stop();
			self.change.fadeloss:Play();
		end
	end
end

function Addon:GetHoveredModule()
	local hoveredIndex = Addon:GetModuleIndexFromMousePosition();
	local moduleFrame = Addon:GetModuleFrame(hoveredIndex)
	if moduleFrame then
		return moduleFrame.module;
	end
	return nil;
end

function Addon:SendModuleChatMessage()
	local module = Addon:GetHoveredModule();
	if not module then
		return;
	end

	local hasMessage, reason = module:HasChatMessage();
	if not hasMessage then
		DEFAULT_CHAT_FRAME:AddMessage(("|cfffaad07Experiencer|r %s"):format(reason));
		return;
	end

	local msg = module:GetChatMessage();

	if IsControlKeyDown() then
		ChatFrame_OpenChat(msg);
	else
		DEFAULT_CHAT_FRAME.editBox:SetText(msg)
	end
end

function Addon:ToggleTextVisilibity(visibility, noAnimation)
	if visibility then
		self.db.char.TextVisibility = visibility;
	elseif self.db.char.TextVisibility == TEXT_VISIBILITY_HOVER then
		self.db.char.TextVisibility = TEXT_VISIBILITY_ALWAYS;
	elseif self.db.char.TextVisibility == TEXT_VISIBILITY_ALWAYS then
		self.db.char.TextVisibility = TEXT_VISIBILITY_HOVER;
	end

	if not noAnimation then
		for _, moduleFrame in Addon:GetModuleFrameIterator() do
			if self.db.char.TextVisibility == TEXT_VISIBILITY_ALWAYS then
				moduleFrame.textFrame.fadeout:Stop();
				moduleFrame.textFrame.fadein:Play();
			else
				moduleFrame.textFrame.fadein:Stop();
				moduleFrame.textFrame.fadeout:Play();
			end
		end
	end
end

function Addon:GetNumOfEnabledModules()
	local numTotalEnabled = 0;
	local numActiveEnabled = 0;

	for _, module in Addon:IterateModules() do
		if not module:IsDisabled() then
			numTotalEnabled = numTotalEnabled + 1;
		end
	end
	for _, moduleId in ipairs(self.db.char.ActiveModules) do
		local module = Addon:GetModule(moduleId, true);
		if module and not module:IsDisabled() then
			numActiveEnabled = numActiveEnabled + 1;
		end
	end
	return numTotalEnabled, numActiveEnabled;
end

function Addon:CollapseActiveModules()
	local collapsedList = {};
	for _, moduleId in ipairs(self.db.char.ActiveModules) do
		local module = Addon:GetModule(moduleId, true);
		if (module and not module:IsDisabled()) then
			tinsert(collapsedList, moduleId);
		end
	end

	self.db.char.ActiveModules = {};
	if #collapsedList > 0 then
		for index, moduleId in ipairs(collapsedList) do
			Addon:SetModule(index, moduleId, true);
		end
	else
		local newModule = Addon:FindValidModuleForBar(1);
		Addon:SetModule(1, newModule.id, true);
	end

	Addon:UpdateFrames();
	Addon:RefreshBars(true);
end

function Addon:CheckDisabledStatus()
	local numTotalEnabled, numActiveEnabled = Addon:GetNumOfEnabledModules();
	if numActiveEnabled < self.db.char.NumSplits then
		if numTotalEnabled == numActiveEnabled then
			self.db.char.NumSplits = numActiveEnabled;
			Addon:CollapseActiveModules();
		else
			for index = 1, self.db.char.NumSplits do
				local moduleId = self.db.char.ActiveModules[index];
				local module = Addon:GetModule(moduleId, true);
				if module and module:IsDisabled() then
					local newModule = Addon:FindValidModuleForBar(index);
					Addon:SetModule(index, newModule.id, true);
				end
			end
		end
	end
end

function Addon:SetModule(splitIndex, moduleId, novalidation)
	if not novalidation then
		local alreadySet = nil;
		for i = 1, 3 do
			if (i ~= splitIndex and self.db.char.ActiveModules[i] == moduleId) then
				alreadySet = i;
				break;
			end
		end

		if alreadySet then
			self.db.char.ActiveModules[alreadySet] = self.db.char.ActiveModules[splitIndex];

			local moduleFrame = Addon:GetModuleFrame(alreadySet);
			if moduleFrame then
				moduleFrame:SetActiveModule(self.db.char.ActiveModules[alreadySet]);
			end
		end
	end

	self.db.char.ActiveModules[splitIndex] = moduleId;

	local moduleFrame = Addon:GetModuleFrame(splitIndex);
	if moduleId then
		moduleFrame:SetActiveModule(moduleId);
	else
		moduleFrame:RemoveActiveModule();
	end

	Addon:UpdateFrames();
	Addon:RefreshBars(true);
end

function Addon:IsModuleInUse(moduleId, ignoreIndex)
	for index, activeModuleId in ipairs(self.db.char.ActiveModules) do
		if index > self.db.char.NumSplits then
			break;
		end
		if activeModuleId == moduleId and ignoreIndex ~= index then
			return true;
		end
	end
	return false;
end

function Addon:FindValidModuleForBar(index, direction, findNext)
	findNext = findNext or false;
	direction = direction or 1;

	local newIndex = Addon:GetModuleFrame(index) and Addon:GetModuleFrame(index).module and Addon:GetModuleFrame(index).module.order or 1;
    local numModules = #Addon.orderedModules;
    local loops = 0;

	local orderedModule = Addon.orderedModules[newIndex];
	if findNext or orderedModule:IsDisabled() or Addon:IsModuleInUse(orderedModule.id, index) then
		repeat
			-- Move to the next module index based on the direction
			newIndex = (newIndex + direction - 1) % numModules + 1;
			orderedModule = Addon.orderedModules[newIndex];

			-- Check if the module is valid (not disabled or in use)
            loops = loops + 1;
        until (not orderedModule:IsDisabled() and not Addon:IsModuleInUse(orderedModule.id, index)) or loops > numModules;

		-- Return nil if no valid module was found
        if loops > numModules then
            return nil;
        end
	end

	return orderedModule;
end

function Addon:GetAnchors(frame)
    local BOTTOM, TOP = "BOTTOM", "TOP";

    local _, centerY = frame:GetCenter();

    if centerY < (_G.GetScreenHeight() / 2) then
        return BOTTOM, TOP, 1;
    else
        return TOP, BOTTOM, -1;
    end
end

function Addon:SetSplits(newSplits)
	local charDB = self.db.char;  -- Store table reference locally
    local oldSplits = charDB.NumSplits;
    charDB.NumSplits = newSplits;

	if oldSplits < newSplits then
		for index = 2, newSplits do
			local moduleId = charDB.ActiveModules[index];
			if not moduleId then
                local newModule = Addon:FindValidModuleForBar(index, 1, index);
                if newModule then
                    moduleId = newModule.id;
                end
            end
			if moduleId then
                Addon:SetModule(index, moduleId, true);
            else
				charDB.NumSplits = index - 1;
				break;
			end
		end
	end

	Addon:UpdateFrames();
	Addon:RefreshText();
end

function Addon:GenerateFontsMenu(currentMenu)
	local sharedFonts = LibSharedMedia:List("font");
    local numFonts = #sharedFonts;
    local globalDB = self.db.global;

    for index = 1, numFonts do
        local font = sharedFonts[index];
        currentMenu:CreateRadio(font,
		function() return globalDB.FontFace == font; end,
            function()
                globalDB.FontFace = font;
                Addon:UpdateFrames();
            end
        );
	end
end

function Addon:GetFontScaleMenu(currentMenu)
	local windowScales = { 0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.2, 1.3, 1.4, 1.5 };
	local globalDB = self.db.global;

	local fontScaleOption = currentMenu:CreateButton(string.format("Font scale |cnGREEN_FONT_COLOR:(%d%%)|r", globalDB.FontScale * 100));

	for i = 1, #windowScales do
		local scale = windowScales[i];
		local scalePercent = scale * 100;  -- Cache scale * 100 for efficiency
        fontScaleOption:CreateRadio(string.format("%d%%", scalePercent),
            function() return globalDB.FontScale == scale end,
            function()
                globalDB.FontScale = scale;
                Addon:UpdateFrames();
            end
        );
	end
end

function Addon:OpenContextMenu(clickedModuleIndex)
	if InCombatLockdown() then
		return;
	end

	local usedClassColor;
	local charDB = self.db.char;
	local colorDB = self.db.global.Color;
	local globalDB = self.db.global;

	local swatchFunc = function()
		if usedClassColor == nil then
			usedClassColor = colorDB.UseClassColor;
			colorDB.UseClassColor = false;
		end

		local r, g, b = ColorPickerFrame:GetColorRGB();
		colorDB.r, colorDB.g, colorDB.b = r, g, b;
		Addon:UpdateFrames();
	end

	local cancelFunc = function(values)
		if usedClassColor then
			colorDB.UseClassColor = true;
		end
		usedClassColor = nil;

		colorDB.r, colorDB.g, colorDB.b = values.r, values.g, values.b;
		Addon:UpdateFrames();
	end

	local numTotalEnabled = Addon:GetNumOfEnabledModules();

	MenuUtil.CreateContextMenu(UIParent, function(_, rootDescription)
		local title = rootDescription:CreateTitle("Experiencer Options");
		title:SetTooltip(function(tooltip, elementDescription)
			GameTooltip_SetTitle(tooltip, MenuUtil.GetElementText(elementDescription));
			GameTooltip_AddNormalLine(tooltip, "Version: " .. C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version"));
		end);
		rootDescription:CreateButton(("%s bar"):format(charDB.Visible and "Hide" or "Show"), function() Addon:ToggleVisibility(); end);
		local flashOption = rootDescription:CreateCheckbox("Flash when able to level up", function() return charDB.FlashLevelUp; end, function()
			charDB.FlashLevelUp = not charDB.FlashLevelUp;
		end);
		flashOption:SetTooltip(function(tooltip, elementDescription)
			GameTooltip_SetTitle(tooltip, MenuUtil.GetElementText(elementDescription));
			GameTooltip_AddNormalLine(tooltip, "Used for Artifact and Honor");
		end);
		rootDescription:CreateRadio("Always show text", function() return charDB.TextVisibility == TEXT_VISIBILITY_ALWAYS; end, function()
			Addon:ToggleTextVisilibity(TEXT_VISIBILITY_ALWAYS);
		end):SetResponse(MenuResponse.Refresh);
		rootDescription:CreateRadio("Show text on hover", function() return charDB.TextVisibility == TEXT_VISIBILITY_HOVER; end, function()
			Addon:ToggleTextVisilibity(TEXT_VISIBILITY_HOVER);
		end):SetResponse(MenuResponse.Refresh);
		rootDescription:CreateRadio("Always hide text", function() return charDB.TextVisibility == TEXT_VISIBILITY_HIDE; end, function()
			Addon:ToggleTextVisilibity(TEXT_VISIBILITY_HIDE);
		end):SetResponse(MenuResponse.Refresh);

		rootDescription:CreateDivider();

		local frameOptions = rootDescription:CreateButton("Frame Options");
		frameOptions:CreateTitle("Frame Options");
		frameOptions:CreateCheckbox("Enlarge Experiencer Bar", function() return globalDB.BigBars; end, function()
			globalDB.BigBars = not globalDB.BigBars;
			Addon:UpdateFrames();
		end);

		frameOptions:CreateDivider();
		frameOptions:CreateTitle("Font");
		local fontFaceOption = frameOptions:CreateButton(string.format("Font face |cnGREEN_FONT_COLOR:(%s)|r", globalDB.FontFace));
		local optionHeight = 20; -- 20 is default
		local maxElements = 30;
		local maxScrollExtent = optionHeight * maxElements;
		Addon:GenerateFontsMenu(fontFaceOption);
		fontFaceOption:SetScrollMode(maxScrollExtent);

		Addon:GetFontScaleMenu(frameOptions);

		frameOptions:CreateDivider();
		frameOptions:CreateTitle("Bar Color");
		frameOptions:CreateRadio("Use class color", function() return colorDB.UseClassColor; end, function()
			colorDB.UseClassColor = true;
			Addon:UpdateFrames();
		end):SetResponse(MenuResponse.Refresh);
		frameOptions:CreateRadio("Use custom color", function() return not colorDB.UseClassColor; end, function()
			colorDB.UseClassColor = false;
			Addon:UpdateFrames();
		end):SetResponse(MenuResponse.Refresh);
		frameOptions:CreateColorSwatch("Set custom color", function()
			local info = {
				swatchFunc = swatchFunc,
				cancelFunc = cancelFunc,
				r = colorDB.r,
				g = colorDB.g,
				b = colorDB.b
			};
			ColorPickerFrame:SetupColorPickerAndShow(info);
		end, colorDB);
		frameOptions:CreateCheckbox("Use reputation color", function() return colorDB.UseRepColor; end, function()
			colorDB.UseRepColor = not colorDB.UseRepColor;
			Addon:UpdateFrames();
		end);

		frameOptions:CreateDivider();
		frameOptions:CreateTitle("Frame Anchor");
		frameOptions:CreateRadio("Anchor to Bottom", function() return globalDB.AnchorPoint == "BOTTOM"; end, function()
			globalDB.AnchorPoint = "BOTTOM";
			Addon:UpdateFrames();
		end);
		frameOptions:CreateRadio("Anchor to Top", function() return globalDB.AnchorPoint == "TOP"; end, function()
			globalDB.AnchorPoint = "TOP";
			Addon:UpdateFrames();
		end);

		rootDescription:CreateDivider();
		rootDescription:CreateTitle("Sections");

		local splitOneOption = rootDescription:CreateRadio("Split into one", function() return charDB.NumSplits == 1; end, function()
			Addon:SetSplits(1);
		end);
		local splitTwoOption = rootDescription:CreateRadio("Split into two", function() return charDB.NumSplits == 2; end, function()
			Addon:SetSplits(2);
		end);
		if numTotalEnabled < 2 then
			splitTwoOption:SetEnabled(false);
		end
		local splitThreeOption = rootDescription:CreateRadio("Split into three", function() return charDB.NumSplits == 3; end, function()
			Addon:SetSplits(3);
		end);
		splitThreeOption:SetTooltip(function(tooltip, elementDescription)
			GameTooltip_SetTitle(tooltip, MenuUtil.GetElementText(elementDescription));
			GameTooltip_AddNormalLine(tooltip, "When the bar is split into three, the text is truncated and you can hover over the bar to see the full text.|n|nYou will see a plus symbol (+) when some information is hidden.");
		end);
		if numTotalEnabled < 3 then
			splitThreeOption:SetEnabled(false);
		end

		rootDescription:CreateDivider();
		rootDescription:CreateTitle("Displayed Bar");

		local activeModules = charDB.ActiveModules;
		local numSplits = charDB.NumSplits;

		for _, module in pairs(Addon.orderedModules) do
			local menutext = module.label;

			if module.active then
				if module:IsDisabled() then
					menutext = string.format("%s |cnGRAY_FONT_COLOR:(inactive)|r", menutext);
				elseif activeModules[clickedModuleIndex] == module.id then
					menutext = string.format("%s |cnGREEN_FONT_COLOR:(current)|r", menutext);
				end

				local moduleCheckbox = rootDescription:CreateCheckbox(menutext, function()
					for i = 1, numSplits do
						if activeModules[i] == module.id then
							return true;
						end
					end
					return false;
				end, function()
					Addon:SetModule(clickedModuleIndex, module.id);
				end);

				local isDisabled = module:IsDisabled();  -- Cache the result of IsDisabled()
				moduleCheckbox:SetEnabled(not isDisabled);  -- Set enabled status based on the cached result

				if not isDisabled then
					module:GetOptionsMenu(moduleCheckbox);
					moduleCheckbox:SetShouldRespondIfSubmenu(true);
					moduleCheckbox:SetResponse(MenuResponse.CloseAll);
					-- moduleCheckbox:SetResponse(MenuResponse.Close);
				end
			end
		end
	end);
end

function Addon:GetModuleIndexFromMousePosition()
	local mouseX = GetCursorPosition();
	local scale = UIParent:GetEffectiveScale();
	local width = ExperiencerFrameBars:GetSize() or 0;
	local sectionWidth = width / self.db.char.NumSplits;
	return math.floor((mouseX / scale) / sectionWidth) + 1;
end

function Addon:GetModuleFromModuleIndex(moduleIndex)
	local moduleFrame = Addon:GetModuleFrame(moduleIndex);
	if moduleFrame and moduleFrame.module then
		return moduleFrame.module;
	end
end

function Experiencer_OnMouseDown(self, button)
	local clickedModuleIndex = Addon:GetModuleIndexFromMousePosition();
	local clickedModule = Addon:GetModuleFromModuleIndex(clickedModuleIndex);

	if clickedModule and clickedModule.hasCustomMouseCallback and clickedModule.OnMouseDown then
        if clickedModule:OnMouseDown(button) then
            return;
        end
    end

	if button == "LeftButton" then
        if IsShiftKeyDown() then
            Addon:SendModuleChatMessage();
        elseif IsControlKeyDown() then
            Addon:ToggleVisibility();
        end
		return;
	end

	if button == "MiddleButton" and Addon.db.char.TextVisibility ~= TEXT_VISIBILITY_HIDE then
		Addon:ToggleTextVisilibity(nil, true);
		return;
	end

	if button == "RightButton" then
		Addon:OpenContextMenu(clickedModuleIndex);
		return;
	end
end

function Experiencer_OnMouseWheel(self, delta)
	local clickedModuleIndex = Addon:GetModuleIndexFromMousePosition();
	local clickedModule = Addon:GetModuleFromModuleIndex(clickedModuleIndex);

	if clickedModule and clickedModule.hasCustomMouseCallback and clickedModule.OnMouseWheel then
        if clickedModule:OnMouseWheel(delta) then
            return;
        end
    end

	if IsControlKeyDown() then
        local hoveredModuleIndex = Addon:GetModuleIndexFromMousePosition();
        local newModule = Addon:FindValidModuleForBar(hoveredModuleIndex, -delta, true);
        if newModule then
            Addon:SetModule(hoveredModuleIndex, newModule.id);
        end
		Addon:RefreshBars(true);
    end
end

function Experiencer_OnEnter(self)
	Addon.Hovering = true;
	Addon:RefreshText();

	if Addon.db.char.TextVisibility == TEXT_VISIBILITY_HOVER then
		for _, moduleFrame in Addon:GetModuleFrameIterator() do
			moduleFrame.textFrame.fadeout:Stop();
			moduleFrame.textFrame.fadein:Play();
		end
	end
end

function Experiencer_OnLeave(self)
	Addon.Hovering = false;
	Addon:RefreshText();

	if Addon.db.char.TextVisibility == TEXT_VISIBILITY_HOVER then
		for _, moduleFrame in Addon:GetModuleFrameIterator() do
			moduleFrame.textFrame.fadein:Stop();
			moduleFrame.textFrame.fadeout:Play();
		end
	end
end

function Experiencer_OnUpdate(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed;

	if Addon.modulesInitialized then
		Addon:CheckDisabledStatus();

		for _, module in Addon:IterateModules() do
			if module.initialized then
				module:Update(elapsed);
			end
		end

		for _, moduleFrame in Addon:GetModuleFrameIterator() do
			if moduleFrame:IsVisible() and moduleFrame.module then
				moduleFrame:OnUpdate(elapsed);
			end
		end
	end

	if Addon.Hovering then
		Addon:RefreshText();
	end
end

function ExperiencerModuleBarsMixin:OnUpdate(elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed;

    if self.hasBuffer then
        self.bufferTimeout = self.bufferTimeout - elapsed;
        if self.bufferTimeout <= 0.0 and self.module:AllowedToBufferUpdate() then
            self:TriggerBufferedUpdate();
            self.hasBuffer = false;
        end
    end

	local currentChangeValue = self.change:GetValue();
    local valueChange = (self.changeTarget - currentChangeValue) * elapsed;
    valueChange = valueChange >= 0 and valueChange / 0.175 or valueChange / 0.325;
    self.change:SetValue(currentChangeValue + valueChange);

	if self.previousData then
		if self.rested:IsVisible() and self.previousData.rested then
            self.rested:SetValue(self.main:GetContinuousAnimatedValue() + self.previousData.rested);
        end

        if self.previousData.visual then
            local primary, secondary;
            if type(self.previousData.visual) == "number" then
                primary = self.previousData.visual;
            elseif type(self.previousData.visual) == "table" then
                primary, secondary = unpack(self.previousData.visual);
            end

            if self.visualPrimary:IsVisible() and primary then
                self.visualPrimary:SetValue(self.main:GetContinuousAnimatedValue() + primary);
            end

            if self.visualSecondary:IsVisible() and secondary then
                self.visualSecondary:SetValue(self.main:GetContinuousAnimatedValue() + secondary);
            end
        end
	end

    local current = self.main:GetContinuousAnimatedValue();
    local minvalue, maxvalue = self.main:GetMinMaxValues();
    self.color:SetValue(current);

	local progress = (current - minvalue) / max(maxvalue - minvalue, 1);
    if progress > 0 then
        self.main.spark:Show();
        self.main.spark:ClearAllPoints();
        self.main.spark:SetPoint("CENTER", self.main, "LEFT", progress * self.main:GetWidth(), 0);
    else
        self.main.spark:Hide();
    end

    if Addon.db.global.FlashLevelUp then
        if self.module.levelUpRequiresAction then
            local canLevelUp = self.module:CanLevelUp();
            self.highlight:SetMinMaxValues(minvalue, maxvalue);
            self.highlight:SetValue(current);

            if canLevelUp and not self.highlight:IsVisible() then
                self.highlight.fadein:Play();
            elseif not canLevelUp and self.highlight:IsVisible() then
                self.highlight.flash:Stop();
                self.highlight.fadeout:Play();
            end
        else
            self.highlight:Hide();
        end
    end
end

local DAY_ABBR, HOUR_ABBR = gsub(DAY_ONELETTER_ABBR, "%%d%s*", ""), gsub(HOUR_ONELETTER_ABBR, "%%d%s*", "");
local MIN_ABBR, SEC_ABBR = gsub(MINUTE_ONELETTER_ABBR, "%%d%s*", ""), gsub(SECOND_ONELETTER_ABBR, "%%d%s*", "");

local DHMS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", DAY_ABBR, "%02d", HOUR_ABBR, "%02d", MIN_ABBR, "%02d", SEC_ABBR)
local  HMS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", HOUR_ABBR, "%02d", MIN_ABBR, "%02d", SEC_ABBR)
local   MS = format("|cffffffff%s|r|cffffcc00%s|r |cffffffff%s|r|cffffcc00%s|r", "%d", MIN_ABBR, "%02d", SEC_ABBR)
local    S = format("|cffffffff%s|r|cffffcc00%s|r", "%d", SEC_ABBR)

function Addon:FormatTime(t)
	if not t then
		return;
	end

	local timeComponents = {
        days = floor(t / 86400),
        hours = floor((t % 86400) / 3600),
        minutes = floor((t % 3600) / 60),
        seconds = floor(t % 60)
    };

	if timeComponents.days > 0 then
        return format(DHMS, timeComponents.days, timeComponents.hours, timeComponents.minutes, timeComponents.seconds);
    elseif timeComponents.hours > 0 then
        return format(HMS, timeComponents.hours, timeComponents.minutes, timeComponents.seconds);
    elseif timeComponents.minutes > 0 then
        return format(MS, timeComponents.minutes, timeComponents.seconds);
    else
        return format(S, timeComponents.seconds);
    end
end

if (not LibSharedMedia) then
	error("LibSharedMedia not loaded. You should restart the game.");
end
