// Scrappy and dirty tool to format the tile-map.asm into 
// Rows of 128 bytes so it reflects the map that has (x by y) of (128 by 80)
// Each byte is in the correct place as on the map on the screen    
var fs = require('fs');
const readline = require('readline');

const xmax = 128;
const ymax = 80;
let rowCache = '';
let rowXString = '';
var x = 0;
var y = 0;

for(x=0; x<xmax; x++) {
    rowXString+=x.toString().padStart(4,' ');
}

// Reset x
x=0;


var output = fs.createWriteStream('tile-map-formatted.asm');
output.write('; Contains the x,y map for Jet boat - each number is a tile type\n');
output.write('; \n');


const rl = readline.createInterface({
    input: fs.createReadStream('tile-map.asm'),
    output: process.stdout,
    terminal: false
});

rl.on('line', (line) => {
    if(x===0){
        rowCache =';y='+y+',x='+rowXString+'\n'+'EQUB    ';
    } else {
        rowCache +=',';
    }
    rowCache += line.replace('        EQUB    ','');
    x+=8;
    if(x>=xmax) {
        output.write(rowCache+'\n');
        x=0;
        y++;
        if(y>=ymax) {
            output.end();
        }
    }
});