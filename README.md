# Experiencer 2.0
Experience bar replacement for World of Warcraft.

Continuation of the old [Experiencer](https://www.curseforge.com/wow/addons/experiencer) updated for Dragonflight and later.

## General description
Experiencer is a minimum configuration required experience bar addon. It tracks multiple progress bar options which can even be split up into three different sections to display multiple data sources simultaneously.
The following options are supported:  
- Experience  
- Reputation (including Renown & Paragon support)  
- Artifact power  
- Honor  
- Conquest  
- Threads (WoW Remix's Cloak)  

### Experience tracking
Experiencer will display your current rested percentage and remaining exp (and percentage) required to level. The session values are saved even when you log out and can be reset from the experience options menu.

The addon will track the following information per active session:  
- Total exp sum gained.  
- Experience per hour.  
- Estimated time and number of quests to level.  
  
Additionally the total exp gained from turning in all completed quests (and optionally incomplete quests) is displayed by an accompanying visualizer bar.  

Once you have reached the maximum level, experiencer will change itself to displaying reputation progress.  

### Reputation tracking
Experiencer will display your current level, reputation (and percentage) required to the next level. By default the addon will attempt to automatically track the faction you last gained reputation with.  

The addon is also capable of tracking the following reputation-related information:  
- Reputations that work with renown levels.  
- Your paragon level and if you have an active paragon cache.  

### Artifact power tracking
Experiencer is capable of tracking your artifact power, howeer do note you first need to unlock your Heart of Azeroth before this will work.  

### Honor tracking
Experiencer is capable of tracking your honor.  

### Conquest tracking
Experiencer is capable of tracking your Conquest, provided you are max level.  

### Thread tracking (WoW Remix's Cloak)
Experiencer is capable of tracking your WoW Remix's Cloak of Infinite Potential threads:  
- Tracks amount of total threads (and amount gained per session).  
- Track remaining necessary threads for next "Infinite Power" level.  

### Usage and Shortcuts
Experiencer options can be accessed by right clicking the bar or the DataBroker module. In order to make things smoother there are a few useful shortcuts.  
- Control left-click toggles bar visiblity. There will always be a slightly translucent black bar where the bar is anchored.  
- Middle-click toggles text visibility if text is not set to be always hidden.  
- Holding control while scrolling with mouse wheel lets you browse through available bars in following order: experience, reputation, artifact power and honor.  
- Shift left-click pastes current statistics to chat editbox. Shift control left-click for quick paste.  
- **Reputation:** Holding shift while scrolling with mouse wheel over reputation bar will cycle through recent reputations.  

## Notes
Please keep the following in mind:  
- Experiencer's bar can only be anchored **to the bottom or top of your screen**, which means it may overlap with other frames positioned in these places.  
- Experiencer will not hide the existing experience bar by Blizzard, requiring a separate addon for this (Dominos, Bartender, ElvUI, etc...).
- Experiencer's bar color is by default your current character's class color, this can be changed in the options.

## Databroker
Experiencer adds a DataBroker module that displays the current text if you wish to place it somewhere. 

To freely place it anywhere, check out Sonaza's DataBroker display addon [Candy](https://www.curseforge.com/wow/addons/candy). In case Experiencer is split into more than one section the left most bar will be used as the data source for DataBroker text.

## Dependencies
Experiencer uses Ace3, LibSharedMedia and LibDataBroker which are included in the /libs directory.

## License
Experiencer is licensed under MIT license. See license terms in file LICENSE.