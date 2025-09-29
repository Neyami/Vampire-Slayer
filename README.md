# WIP
Sven Co-op version of the Half-Life mod Vampire Slayer by Routetwo  
Players choose to be either Vampires or Slayers, each team has 3 different classes with different weapons/abilities (only stealth for vamps atm)  
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


# TEAMS/CHARACTERS  
[The manual](https://vsmod.co.uk/manual/manual.htm)
The Vampires' Louis, Edgar and Nina have the same phsyical attributes, but each has a special unique ability on the 'secondary fire' button. (only stealth for now)  

`Father D` starts each round with a Shotgun, Double Barrel Shotgun and Stake and Crucifix.  
The secondary attack when Father D has his Stake and Crucifix selected gives him a few seconds of immunity to vampire attacks. This only works when he has the crucifix out AND he is speaking the Holy words.  


`Molly` starts each round with a Crossbow, Micro-Uzi Submachine Gun and stake and Colt Governement Pistol combination.  
When using the Stake and Colt, the primary attack uses the Stake weapon and the secondary attack fires the Colt Pistol.  

`8-Ball` starts each round with a Winchester rifle, Thunder 5 revolver and a Pool Cue.  
When using the Pool Cue primary attack uses it as a stake, and secondary attack swings it like a bat.  

Vampires cannot pick up weapons blessed by Slayers.  
There is nothing to stop Slayers from picking up weapons left by a dead Slayer.  

If a Vampire is knocked out out by bullets, the undead creature will rise after a short time. This is your chance to stake him whilst he's down if you are a Slayer, but be careful 'cos he may rise just before you get to him!  
If a Vampire manages to ressurrect, and escapes being staked, he may look for a dead body to feed off to recover his health up to full. Vampires can feed off dead slayers by standing or crouching near the body and pressing the "Use" key.  
