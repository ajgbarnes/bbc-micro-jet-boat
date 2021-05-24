# Work in progress

This is a disassembly of the Software Invasion game Jet Boat.  Originally written by Robert J. Leatherbarrow in 1984.

You can play the game in your browser here at [bbcmicro.co.uk](http://www.bbcmicro.co.uk/game.php?id=187)

I do not hold the copyright to the original game, only the disassembly labelling and comments.

The commenting isn't quite finished yet - a few little bits left to work and a few zero page variables to name.

# Building

I use the rather excellent [BeebAsm](https://github.com/stardot/beebasm) by *Richard Talbot-Watkins* and I compiled this on WIndows 10.

1. Download the [beebasm.exe](https://github.com/stardot/beebasm/blob/master/beebasm.exe) into the same directory as your clone of this repository
2. Run the following command - the jetnew.ssd image containst he basic loaders, currently required as the memory relocator overwrites the hard coded key values with whatever it finds in memory.  If it's blank, you will not be able to control the boat.

```beebasm -i .\jetboat-commented.asm -do jetboat-new.ssd -di jetnew.ssd```

3. I run it then using [beebjit](https://github.com/scarybeasts/beebjit) created by Chris Evans(scarybeasts) using:

```beebjit -0 jetboat-new.ssd```

4. Shift+Break (F12) to run the compiled game

Andy Barnes

