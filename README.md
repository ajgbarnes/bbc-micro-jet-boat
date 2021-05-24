# Jet Boat - Work in progress

This is a disassembly of the **Software Invasion** game **Jet Boat**.  Originally written by **Robert J. Leatherbarrow** in 1984.

I did not intend to decompile and understand its inner workings until reivisitng this game some 35 years on, wondering why it juddered all the time and was so unplayable. It turns out that there is an issue with my Analogue Joystick port on my old BBC Model B which creates constant noise - the code always checks both keyboard and joystick input (rather than just switching to the one that started the game).  That's not a problem on good BBC Micro but is on mine and a Master Compact (that doesn't have an analogue port).  I recompiled a version that disabled joystick support for the Master Compact, which can be found on [StarDot](https://stardot.org.uk/forums/viewtopic.php?p=319995#p319995).

You can play the game in your browser here at [bbcmicro.co.uk](http://www.bbcmicro.co.uk/game.php?id=187)

I do not hold the copyright to the original game, only the disassembly labelling and comments.

The commenting isn't quite finished yet - a few little bits left to work and a few zero page variables to name.

# Disassembly

I used the [BeedDis](https://github.com/prime6809/BeebDis) by *Phill Harvey-Smith* which was fantastic.

I also used [HxD for Window](https://mh-nexus.de/en/hxd/) for inspecting the original binary and comparing my new one to it

And all editing was completed in [Visual Studio Code](https://code.visualstudio.com/) and [Simon M's](https://github.com/simondotm) excellent BBC Specific 6502 extension [Beeb VSC](https://marketplace.visualstudio.com/items?itemName=simondotm.beeb-vsc)

# Building

I use the rather excellent [BeebAsm](https://github.com/stardot/beebasm) by *Richard Talbot-Watkins* and I compiled this on WIndows 10.

1. Download the [beebasm.exe](https://github.com/stardot/beebasm/blob/master/beebasm.exe) into the same directory as your clone of this repository
2. Run the following command - the jetnew.ssd image containst he basic loaders, currently required as the memory relocator overwrites the hard coded key values with whatever it finds in memory.  If it's blank, you will not be able to control the boat.

```beebasm -i .\jetboat-commented.asm -do jetboat-new.ssd -di jetnew.ssd```

3. I run it then using [beebjit](https://github.com/scarybeasts/beebjit) created by *Chris Evans(scarybeasts)* using:

```beebjit -0 jetboat-new.ssd```

4. Shift+Break (F12) to run the compiled game

Note that when it compiles the binary is *byte identical* to the original.

Hope you can learn something from this disassembly and it inspires a project. 

Andy Barnes

