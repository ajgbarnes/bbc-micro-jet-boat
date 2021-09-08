# Jet Boat Disassembly

This is a disassembly of the **Software Invasion** game **Jet Boat**.  Originally written by **Robin J. Leatherbarrow** in 1984. It's not perfect, I will massage it over time now I undertstand more, and it may contain some commenting howlers or grammar or spelling mistakes.

I did not intend to decompile and understand its inner workings until revisitng this game some 35 years on, wondering why it juddered all the time and was so unplayable. It turns out that there is an issue with my Analogue Joystick port on my old BBC Model B which creates constant noise - the code always checks both keyboard and joystick input (rather than just switching to the one that started the game).  That's not a problem on good BBC Micro but is on mine and a Master Compact (that doesn't have an analogue port).  I recompiled a version that disabled joystick support for the Master Compact, which can be found on [StarDot](https://stardot.org.uk/forums/viewtopic.php?p=319995#p319995).

You can play the game in your browser here at [bbcmicro.co.uk](http://www.bbcmicro.co.uk/game.php?id=187)

I do not hold the copyright to the original game, only the disassembly labelling and comments.

I probably need to review the commenting now I have been through all of the code.  I learnt a great deal going through this code which was nicely structured by Robin. 

I assume too that he had a tool to design the map and chop it into individual tiles. It wouldn't be too hard to write something similar now.

# Disassembly

I used the [BeedDis](https://github.com/prime6809/BeebDis) by *Phill Harvey-Smith* which was fantastic.

I also used [HxD for Window](https://mh-nexus.de/en/hxd/) for inspecting the original binary and comparing my new one to it

And all editing was completed in [Visual Studio Code](https://code.visualstudio.com/) and [Simon M's](https://github.com/simondotm) excellent BBC Specific 6502 extension [Beeb VSC](https://marketplace.visualstudio.com/items?itemName=simondotm.beeb-vsc)

I used the [BBC Micro User Guide](https://stardot.org.uk/forums/download/file.php?id=57043) and [New Advanced User Guide](https://stardot.org.uk/forums/download/file.php?id=65551) as references - the versions that *dv8* [remastered after a huge amount of work](https://stardot.org.uk/forums/viewtopic.php?t=17243). Invaluable.

And the [BBC Micro Memory Map](http://mdfs.net/Docs/Comp/BBC/AllMem) by *John Ripley* and *J.G.Harston* was absolutely invaluable.



# Building

I use the rather excellent [BeebAsm](https://github.com/stardot/beebasm) by *Richard Talbot-Watkins* and I compiled this on WIndows 10.

1. Download the [beebasm.exe](https://github.com/stardot/beebasm/blob/master/beebasm.exe) into the same directory as your clone of this repository
2. Run the following command - the jetnew.ssd image contains the basic loaders, currently required as the memory relocator overwrites the hard coded key values with whatever it finds in memory.  If it's blank, you will not be able to control the boat.

```beebasm -i .\jetboat-commented.asm -do jetboat-new.ssd -di jetnew.ssd```

3. I run it then using [beebjit](https://github.com/scarybeasts/beebjit) created by *Chris Evans(scarybeasts)* using:

```beebjit -0 jetboat-new.ssd```

4. Shift+Break (F12) to run the compiled game

Note that when it compiles the binary is *byte identical* to the original.

Hope you can learn something from this disassembly and it inspires a project. 

Things to do:
- Revisit some of the code comments now I know more
- Add the lap times to the README.md
- Transfer the memory map from Excel into markdown

# Generating the map

I wrote a node.js script to inspect the BBC Micro binary and generate the map from it. To run it, install [node.js](https://nodejs.org/en/download/).  I used 14.17.0 to develop this.  Then:

1. Ensure the Jet Boat binary is available and named **jetboa1** - it should NOT be in an SSD
2. Run **npm install canvas** - I might get around to putting in a package.json if I need more libraries
3. Run the script using **node generate-map.js** (in the Powershell on windows you'll have to use node ./generate-map.js)
4. Open the generated jetboat-map.png image file
5. Enjoy!

There are four levels each with different colours as below.  Each level has 11 laps with increasing hazards per lap.  The lap times also reduce per level per lap until it becomes impossible to complete.

![alt text](https://github.com/ajgbarnes/bbc-micro-jet-boat/blob/main/jetboat-map-scheme-all.png "Jet Boat Map - All Colour Schemes Tessellated")

# Generating the stage hazards


I wrote a node.js script to inspect the BBC Micro binary and generate the map for each lap with the additional hazards on each. To run it, install [node.js](https://nodejs.org/en/download/).  I used 14.17.0 to develop this.  Then:

1. Ensure the Jet Boat binary is available and named **jetboa1** - it should NOT be in an SSD
2. Run **npm install canvas** - I might get around to putting in a package.json if I need more libraries
3. Run the script using **node generate-map-with-hazards.js** (in the Powershell on windows you'll have to use node ./generate-map-with-hazards.js)
4. Open the generated jetboat-maplap-n.png image files (where n is 0 to 10)
5. Enjoy!

## Lap 1 - Standard ducks, boats and rocks

By default:

- 2 boats
- 14 ducks
- 8 rocks

![alt text](https://github.com/ajgbarnes/bbc-micro-jet-boat/blob/main/jetboat-map-lap-0.png "Jet Boat Map - Lap 1")

## Lap 2 - Buoys

Addition of:
- 6 buoys

![alt text](https://github.com/ajgbarnes/bbc-micro-jet-boat/blob/main/jetboat-map-lap-1.png "Jet Boat Map - Lap 2")

## Lap 3 - Islands

Addition of:
- 3 islands

![alt text](https://github.com/ajgbarnes/bbc-micro-jet-boat/blob/main/jetboat-map-lap-2.png "Jet Boat Map - Lap 3")

## Lap 4 - Sea Monsters

Addition of:
- 3 sea monsters

![alt text](https://github.com/ajgbarnes/bbc-micro-jet-boat/blob/main/jetboat-map-lap-3.png "Jet Boat Map - Lap 4")

## Lap 5 - Channel Markers

Addition of:
- 9 channel markers (some in pairs)


![alt text](https://github.com/ajgbarnes/bbc-micro-jet-boat/blob/main/jetboat-map-lap-4.png "Jet Boat Map - Lap 5")

## Lap 6 - Yachts

Addition of:
- 6 yachts

![alt text](https://github.com/ajgbarnes/bbc-micro-jet-boat/blob/main/jetboat-map-lap-5.png "Jet Boat Map - Lap 6")

## Lap 7 - Crocodiles

Addition of:
- 6 crocodiles

![alt text](https://github.com/ajgbarnes/bbc-micro-jet-boat/blob/main/jetboat-map-lap-6.png "Jet Boat Map - Lap 7")

## Lap 8 - Sandbanks

Addition of:
- 5 sandbacks

![alt text](https://github.com/ajgbarnes/bbc-micro-jet-boat/blob/main/jetboat-map-lap-7.png "Jet Boat Map - Lap 8")

## Lap 9 - Lighthouses

Addition of:
- 5 lighthouses

![alt text](https://github.com/ajgbarnes/bbc-micro-jet-boat/blob/main/jetboat-map-lap-8.png "Jet Boat Map - Lap 9")

## Lap 10 - Wooden Rafts

Addition of:
- 5 wooden rafts

![alt text](https://github.com/ajgbarnes/bbc-micro-jet-boat/blob/main/jetboat-map-lap-9.png "Jet Boat Map - Lap 10")

## Lap 11 - Gondolas

Addition of:
- 6 gondolas

![alt text](https://github.com/ajgbarnes/bbc-micro-jet-boat/blob/main/jetboat-map-lap-10.png "Jet Boat Map - Lap 11")


Andy Barnes