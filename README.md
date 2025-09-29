# WIP
Sven Co-op version of the Half-Life mod Vampire Slayer by Routetwo  
Players choose to be either Vampires or Slayers, each team has 3 different classes with different weapons/abilities (only invisibility for vamps atm)  
Teams can win by:  
A) Killing all members of the opposing team.  
B) Destroying all opposing team relics. (on certain maps)  
C) Capture the Cross (on certain maps) NYI  


[Download Resources](https://www.dropbox.com/scl/fi/5ptg864qnal3cao4e7fqn/Vampire-Slayer-resources_v1.0.zip?rlkey=nwcvyk7xu9e2sfr2tl3deq93v&dl=0)  
If you want to keep the VS resources out of the regular svencoop_addon files, you can put them in "Sven Co-op\svencoop_event_vampslay"  
This will require putting event_info.txt in the same folder, using the console command `ev_scan` or restarting the game, then `ev_enable vampslay`  


# PLAYER MODEL ANIMATION GLITCHING  
The player models are old, and have had several animations removed/reordered. I am not a modeler so fixing it will take some time (feel free to help :ayaya:)  
In the meantime you'll have to use the player.mdl from this "mod", I would highly recommend doing the event thing for that, so it doesn't override normal player models.  


# COMMANDS  
CONSOLE  
`vs_roundtime` - Get/Set how long each round lasts. ADMIN ONLY  
`vs_roundlimit` - Get/Set how many rounds until the map changes. ADMIN ONLY  
`vs_restart` - Reset scores and round number. ADMIN ONLY  
`vs_restartround` - Restart current round. ADMIN ONLY  
`changeteam` - Opens the team select menu. PUBLIC  

CHAT  
`!team` - Opens the team select menu. PUBLIC  

CVARS (can be set in mapconfig with as_command cvar num)  
`vs-roundtime`  
`vs-roundlimit`  

