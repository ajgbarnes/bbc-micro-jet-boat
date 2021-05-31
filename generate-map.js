// (c) Copyright Andy Barnes, 2021
//
const { createCanvas, createImageData } = require('canvas');
var fs = require('fs');
const { isRegExp } = require('util');

// Width of the canvas is 128 x co-ordinates by 4 pixels
// And 80 y-co-oridinates of 8-bytes per tile
// So it's 512 x 640 in total
const width = 128*4;
const height = 80*8;

// Define the colour rgb / transparency values
const rgbaBlack   = [0,0,0,255];
const rgbaBlue    = [0,0,255,255];
const rgbaRed     = [255,0,0,255];
const rgbaGreen   = [0,255,0,255];
const rgbaWhite   = [255,255,255,255];
const rgbaYellow  = [255,255,0,255];
const rgbaMagenta = [255,0,255,255];

const colourSchemeList = [
    [rgbaBlue, rgbaYellow, rgbaRed, rgbaWhite],
    [rgbaBlue, rgbaYellow, rgbaGreen, rgbaWhite],
    [rgbaBlue, rgbaMagenta, rgbaWhite, rgbaYellow],
    [rgbaBlue, rgbaYellow, rgbaMagenta, rgbaWhite]
];

// Create the canvas and get the context - 
// this is where the map image will be drawn
const canvas = createCanvas(width, height);
const context = canvas.getContext('2d');

// Get the image data and the pixel buffer - the
// latter is used to draw the pixels
const imageData = context.getImageData(0,0,width,height);
const pixels = imageData.data;

// This is the address where the game is loaded in memory
// This is used to calculate where things will be in the 
// file binary based on where they load into BBC Micro memory
const loadAddress = parseInt(0x1100);


const mapStart = parseInt(0x35C0);
const tileGraphicsStart = parseInt(0x2DC0);
const mapSize = parseInt(0x2FFF);
const mapStartInBuffer = (mapStart - loadAddress);
const mapEndInBuffer = (mapStartInBuffer + mapSize);

// Load the jetboat game binary 
fs.readFile('jetboa1', (err, data) => {

    // Error occured so report it and end
    if(err) {
        console.error(err);
        return;
    }

    // Create a buffer from the file data
    const fileBuffer = Buffer.from(data,'ascii');

    // JSON to hold the counts
    let count = {};
    

    // This is just loops through the map data from the jet boat file
    // to see how many of each tile is used by the map - just out of curiosity!
    // Also dumps to the screen the raw map data (first) then the tile type counts
    // Output used to hold a printable string of the values
    let output = "";
    // Loop over all the map tiles
    for(let i=0; i<=mapSize; i++) {
        // Every 16 bytes write the memory location to the
        // start of the line
        if(i % 16 === 0) {
            output = (mapStartInBuffer + i).toString(16) + ": ";
        }

        // Get the current tile type
        let value = fileBuffer[mapStartInBuffer+i].toString(16).padStart(2,'0');
        // If the JSON array already contains a count of the current tile type
        // increment it otherwise add a new entry with a value of 1
        if(count.hasOwnProperty(value)) {
            count[value] = count[value] + 1;
        } else {
            count[value] = 1;
        }
        // Add a space between values on a line
        output = output + value + " ";
        // If we have all 16 bytes then write them to the screen
        if(i > 0 && (i + 1) % 16 === 0) {
            console.log(output);
            output = "";
        }       
    }
    // If there are any bytes we haven't written to the screen
    // write them now
    if(output.length) {
        console.log(output);            
    }

    // Generate a printable string and write it to the console of 
    // how many times each tile type is used
    let counts = "";
    const zero = 0;
    for(let i=0; i<256;i++) {
        let key = i.toString(16).padStart(2,'0');
        if(count.hasOwnProperty(key)) {
            counts = counts + key + ": " + count[key].toString().padStart(4,'0') + " ";
        } else {
            counts = counts + key + ": " + zero.toString().padStart(4,'0') + " ";            
        }
        if((i +1) % 10 === 0) {
            counts += "\n";
        }
    }
    console.log(counts);

    // For the current map (x,y) co-ordinate get the tile type number
    function getTileType(x,y) {
        // This is where the BBC Micro runtime engine for the game calculates it to be
        let lookupAddress = 0x3000 + (y * 128) + x;

        // This is where the it would have loaded in memory before relocation
        let loadAddress = lookupAddress + 0x5C0;

        // This is where it will be in the file binary (which loads at 0x1100)
        // So we need the offset from the start of the file which we get
        // by subtracing 0x1100
        let fileAddress = loadAddress - 0x1100;

        // Load the tiletype for this (x,y) coordinate
        let tileType = fileBuffer[fileAddress];
        //console.log(x,y,lookupAddress.toString(16).padStart(4,'0'), 
        //    fileAddress.toString(16), tileType);
        return tileType;
    }

    // Find out where in the file buffer the tile type 8 bytes start
    function getTileAddress(tileType) {
        let tileGraphicAddress = 0x2800 + (tileType * 8);
        let loadAddress = tileGraphicAddress + 0x5C0;
        let fileAddress = loadAddress - 0x1100;
        //console.log(tileType,tileGraphicAddress.toString(16).padStart(4,'0')
        //    ,fileAddress.toString(16));
        return fileAddress;
    }

    // Work out where on the canvas the current pixel should be written
    // (x only here)
    function getPixelXPosition(x,y, byte, bytePixel) {
        let screenx = 0;

        screenx = (4 * x) + bytePixel;

        return screenx;
    }
    // Work out where on the canvas the current pixel should be written
    // (y only here)
    function getPixelYPosition(x,y, byte, bytePixel) {
        let screeny = 0;

        screeny = (8 * y) + byte;
        
        return screeny;
    }

    // Based on the two bits masked out of the byte, work out 
    // the colour for the current pixel
    function getPixelColour(currentPixel, colourScheme) {
        let colour = rgbaRed; 
        switch(currentPixel) {
            case 0:
                colour = colourSchemeList[colourScheme][0];
                break;
            case 1:
                colour = colourSchemeList[colourScheme][1];
                break;
            case 16:
                colour = colourSchemeList[colourScheme][2];
                break;                
            case 17 :
                colour = colourSchemeList[colourScheme][3];
                break;                                
            default:
                break;
        }
        return colour;
    }

    // For a given canvas x,y position work out where in the
    // canvas buffer that will be
    function getPixelPosition(writex,writey,width) {
        let position = writey * (width * 4) + writex * 4;
        return position;
    }

    let writex = 0;
    let writey = 0;

    // In MODE 5, it's two bits per pixel so a byte of data
    // represents four pixels - we use the pixel mask
    // to get two bits at a time (one pixel) and rotate it right
    // to get the next until we have processed all four
    let pixelMask = 0b10001000;

    // Each tile is 8 bytes on hte map
    let currentByte = null;

    // The pixel masked out of the currentByte
    let currentPixel = null;

    // The colour of the pixel, drive by the two bit values
    let currentColour = null;
    let pixelLocation = null;

    // Use this to work out which tile numbers have been used
    var tileSet = new Set();

    var tileArray = new Array(128);

    for (let i = 0; i < tileArray.length; i++) {
        tileArray[i] = new Array(80);
    }

    // Each x position represents four pixels (because it's 2 bits per pixel and 
    // each x position is a byte wide)
    // 
    // Each y position is 8 pixels high and each tile is that same height
    //
    // Gives x = 128 * 4 = 512 pixels wide
    // Gives y = 80  * 8 = 640 pixels high
    //
    // So...
    //    1. Find the tile type for the current (x,y) position
    //    2. Find the tile type data (8 bytes) in the file
    //    3. Go through each byte and pull out the four individual pixels
    //    4. Write each pixel to the canvas

    for(let colourScheme=0; colourScheme<4; colourScheme++) {

        // Loop through all the y co-ordinates in the (x,y) on the map
        for(let y=0; y<80; y++) {
            // Loop through all the x co-ordinates in the (x,y) on the map
            for(let x=0; x< 128; x++) {
                // Find the tile type for the current (x,y) position
                tileType = getTileType(x,y)
                // Find the tile type data (8 bytes) in the file
                tileAddress = getTileAddress(tileType);

                // Will do something with this later... 
                // tileArray just holds the map to tile type
                // tileSet just shows me which tile type numbers were used
                tileArray[x][y]=tileType;
                tileSet.add(tileType);

                // Loop over each of the 8 bytes for the tile type
                // Pull out the individual pixesl for each (4 pixels per byte)
                // Write them to the canvas in the correct place
                for(let byte = 0; byte<8; byte++) {
                    // Get the current nth byte for the tile (up to 8th)
                    currentByte = fileBuffer[tileAddress + byte];

                    // Pixel mask used to pull out the four individual pixels
                    // from the byte (it's rotated right each time around the loop)
                    pixelMask = 0b10001000;
                    for(let bytePixel = 0; bytePixel < 4; bytePixel++) {
                        // Find out where on the canvas the pixel should be written
                        writex = getPixelXPosition(x,y,byte,bytePixel);
                        writey = getPixelYPosition(x,y,byte,bytePixel);

                        // Get the current pixel (4 per byte, 2 bits per pixel)
                        currentPixel = (currentByte & pixelMask);

                        // Make all the pixels in the byte the same 2-bits
                        // to represent colour and lookup the colour
                        currentPixel = currentPixel >>> (3-bytePixel);
                        currentColour = getPixelColour(currentPixel, colourScheme);

                        // Calculate where in the buffer for the canvas the 
                        // write position is for the canvas x,y position
                        pixelLocation = getPixelPosition(writex,writey,canvas.width);

                        // Set the rgba values in the buffer for the canvas for this pixel
                        pixels[pixelLocation]  =  currentColour[0];  // red
                        pixels[pixelLocation+1]=  currentColour[1];  // green
                        pixels[pixelLocation+2]=  currentColour[2]; // blue
                        pixels[pixelLocation+3]=  currentColour[3];

                        // Rotate right the pixel mask to get the next pixel from the
                        // the byte (up to 4)
                        pixelMask = pixelMask >>> 1;
                    } // bytePixel
                } // byte
            } // x
        }  // y  

        // Update the canvas and write it to a png
        context.putImageData(imageData,0,0);
        const imageBuffer = canvas.toBuffer('image/png');
        fs.writeFileSync('./jetboat-map-scheme-'+colourScheme+'.png', imageBuffer);

        //console.log(Array.from(tileSet).sort((a,b)=>a-b));
        //console.log(tileArray);
        //console.log(tileArray[0x1d][0x0b]);
    } // colourScheme
});