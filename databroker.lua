------------------------------------------------------------
-- Experiencer2 by DJScias (https://github.com/DJScias/Experiencer2)
-- Originally by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;

local LibDataBroker = LibStub("LibDataBroker-1.1");

local settings = {
	type  = "data source",
	label = "Experiencer",
	text  = "Experiencer Text Display",
	icon  = "Interface\\Icons\\Ability_Paladin_EmpoweredSealsRighteous",
	OnClick = function(_, button)
		if button == "RightButton" then
			Addon:OpenContextMenu();
		end
	end,
};

function Addon:InitializeDataBroker()
	Addon.BrokerModule = LibDataBroker:NewDataObject("Experiencer", settings);
end

function Addon:UpdateDataBrokerText(text)
	if Addon.BrokerModule then
		Addon.BrokerModule.text = text;
	end
end
