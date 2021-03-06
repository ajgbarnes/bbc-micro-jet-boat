; Disassembly and annotation of Jet Boat from Software Invasion
; 
; Originally written by Robin J. Leatherbrow (c) Copyright 1984
;
; Disassembly labels and comments by Andy Barnes (c) Copyright 2021
;
; Twitter @ajgbarnes

; Notes on the game
; =================
;
; Code
; ----
; - Relocation code is from fn_start_point ($5DE1) onwards (all thrown away when game starts)
; - Main game entry code is at fn_game_start ($0BF8)
; - Main game loop is at main_game_loop ($0D16)
; - Seems well structured and through through
; - No overloadng of zero page locations (used for single purposes)
;
; Timers
; ------
; - "Interval timer crossing 0" used to decrement time remaining every 64 centiseconds
; - Pauses achieved by using the System VIA CA1 interrupts to wait 20ms * n
;   (where n is the multiplier to give the required wait time e.g. 100 for 2 seconds)
;
; Screen
; ------
; - Intro screen(s) and high score screens are in MODE 7
; - Main game runs in MODE 5 with default configuration
; - Screen start address is $5800 and end address $7FFF
; - Screen is scrolled using the 6845 CRTC video controller (R12,R13)
;
; Game
; ----
; - There are no baddies - the only thing that moves around the map is the boat
; - Boat runs slower when it runs aground (doesn't get damaged)
; - Boat always appears in the centre of the screen and the screen scrolls around it
; - Boat can move in 16 compass directions and has a graphic for each
; - No other icon is animated (other than during colour cycling)
;
; Stages/Laps
; -----------
; - There are 13 stages in the game 
; - Each new stage is a different colour (from one of four possible palettes)
; - Each new stage reduces the time available to complete a lap
; - Each stage is 11 laps - all having the same stage completion time
; - Each new lap adds additional hazards
; - The 14th stage has a zero time to complete so you automatically die
; - To complete a lap you must cross both a checkpoint in the centre of the map
;   and also a lap marker
; - Centre checkpoint is satisfied for boat position (x,y) if 94<= x <110 and y= 14
; - Lap    checkpoint is satisfied for boat position (x,y) if 24<= x <37 and  y= 12
; - Centre checkpoint stops you cutting across the map or just looping back
; - "Prepare to enter the next stage" is shown between stages instead of the 
;   repeating Jetboat text at the start of the game
; - Lap times as stored are auto decremented by 1 before the game properly starts
; - Stage Lap times are therefore 
;   -> 70, 60, 51, 46, 41, 38, 36, 33, 31, 28, 26, 23, 21, 0
;
; Controls
; --------
; - Regardless of how you start the game, both joystick and keyboard inputs are checked
; - Keyboard is read using OSBYTE &81 rather than directly
; - Joystick x/y axis read via the ADC chip using OSBYTE &80
; - Joystick button read via the System VIA using OSBYTE &80
;
; Map
; ---
; - Map is 128 (x-axis) x 80 (y-tiles) tiles
; - Map is stored from $3000 and serialised by row
; - Each map position identifies a tile id
;
; Tiles
; -----
; - There are 256 ($00-$FF) possible different tile types
; - Each map tile is 8 bytes (4 pixels wide and 8 pixels high)
; - Tiles are stored sequentially at $2800 to $2FFF
; - Tile source graphics can be looked up using $2800 + (tile id * 8)
;
; Boat Graphics
; -------------
; - There are sixteen full boat sprites
; - One boat sprite for each point on the compass (N, NNW, W, WNW...)
; - Boat is EOR'd on and off the screen
; - Graphics are stored from $1E00 to $2FFF
; - In MDOE 5 a screen byte is 4 pixels wide
; - In MDOE 5 a screen byte is 1 pixel high
; - A boat sprite is 5 bytes wide
; - A boat sprite is 3 x 8 bytes high = 24 bytes high
; - A boat sprite is (5 x 24)  = 120 bytes in total 
; - A boat sprite is therefore (5 x 4)   20  pixels wide
; - A boat sprite is therefore (24 x 1)  24  pixels high
; - A boat sprite is therefore (24 x 20) 480 pixels in total
; - Boat sprites are stored from $1E00 to $27FF
; - Each boat sprite is 120 ($A0) bytes
; - Lookup table at boat_sprite_location_lsb/msb gives memory location for compass point
; - Boat moves speed is from $0A (slowest) to $00 (fastest), used also as duration for second
;   "put" sound so useful to have it in this order
;
; Other Graphics
; --------------
; - Get Ready sprite is shown in the same position as the boat 
; - Get Ready sprite is stored in $04A0 - $053F (relocated there when the game loads)
; - Get Ready sprite is the same size as the boat
; - Times Up! sprite is shown in the same position as the boat
; - Times Up! sprite is stored in $0400 - %04BF (relocated there when the game loads)
; - Times Up! sprite is the same size as the boat
;
; Movement
; --------
; - Compass direction that boat is facing determines speed and direction
; - Lookup table used to lookup compass direction of boat against speed/movement
; - Lookup table is at lookup_table_boat_direction_fns with each fn underneath
; - Each function determines how much up/down or left/right movement there should be
; - NNW wouldn't move W as fast as WNW as an example but faster N than WNW
; - N would have zero E or W movement but maximum N movement
; - E would have zero N or S movement but maximum E movement
; - Boat decelerates every third game loop
;
; Collision Detection
; -------------------
; - Flashing when run aground is achieved by colour cycling the logical/physical colours
; - Colour resets every 4th time around game loop
; - Boat is immediately slowed to slowest speed ($0A)
; - Logical colour 3 is cycled through the colours at palette_colour_cycle 
; - Colour only changed and sound played every fourth time around the game loop
; - Magic happens in fn_toggle_boat_or_time_graphic
; - Tile to be written is EOR'd with what's already there and compared to original tile
;   If it's the same, then no collision, if it's different then collision flag set
;   Water is 0x00000000 so won't affect the EOR
;   Blank tiles are not compared (ones with byte values of $00)
;
; Time remaining
; --------------
; - Time remaining is in 0.64 second units 
; - Time remaining is decremented using the "interval timer crossing 0" timer
; - "Interval timer crossing 0" event is processed by setting the EVNTV vector to custom handler
; - Custom handler checks the event time is "Interval timer crossing 0" ($05) before doing anything
; - Interval timer is always set to 64 centiseconds (to decrement remaining time)
; - Interval timer is switched off when game not playing
; - Interval timer switched back on when game begins (after Jetboat repeating text has scrolled away)
; 
; Hazards
; -------
; - Hazards are cumulative per stage lap (reset on new stage)
; - Hazards are stored in memory as described in hazards-formatted.asm but as a summary:
; - <# tiles wide>,<# tiles high>,<1st tile id>,<2nd tile id>...<nth tile id>,<instances>,<x0>,<x1>...<x>,<y0><y1>...<yn>
; - Hazard configuration for each hazard type is stored $1C00 to $1D0F
; - There a lookup table into this Hazard configuration for each configuration type
; - Hazard lookup table for each lap is held in hazard_lookup_table_lsb/msb
; - Hazards update the map to contain replace water with the hazard tiles
; 
; Game Colours
; ------------
; - Bottom two bits of the stage number drive the palette colours
; - Four different colour schemes to choose from, used in rotation 
; - Colour schemes stored at colour_bank_1/2/3
; - Logical colour 0 is always blue
; 
; Sounds
; ------
; - Boat makes a 'put-put' sound - duration is inversely proportional to boat speed
;   This is played on Channel 0 and set in fn_play_boat_sounds (two consecutive sounds)
; - Times up sound sounds like an alarm clock and uses Envelope 1 on Channel 1
;   (see check_time_remaining)
; - Completed lap sound is like a short hornpipe tune using Envelope 2 on Channel 2
;   (see completed_lap_next_sound)
; - Boat aground sound is two sounds and envelopes
;   (see sound_boat_aground_first/second)
;
; Score
; -----
; - Score is updates every 16th time around the game loop (for just being alive)
; - Score can only be updated to a maximum of 2,000 per lap
; - On lap completion, remaining time is added to the score (time * 10)

; Runtime Memory Map
; ------------------
; From  To      Bytes   Type            Description
;
; 0400	049F	159	Graphics	Load time times Up Clock Graphic
; 04A0	053F	159	Graphics	Load time Get Ready Graphic
; 0540	0567	39	Graphics	Score graphic
; 0568	0587	31	Graphics	Time graphic
; 0588	5A7	31	Graphics	Lap graphic
; 05A8	05AF	7	Graphics	Blank graphic
; 05B0	05E0	48	Unused		
; 05E1  05FF
; 0600	073F	319	Graphics	Map tile buffer for row
; 0740	07E0	160	Graphics	0-9 number graphics
; 0800	08FF	511	Unused	        OS SOUND workspace	
; 0900	09FF	255	Graphics	Map tile buffer for column
; 0A00	0A07	7	Graphics	Blank spacer
; 0A08	0A27	31	Graphics	Runtime copy of time graphic
; 0A28	0A47	31	Graphics	Blank spacer
; 0A48	0A4F	7	Graphics	Runtime copy of the blank graphic
; 0A68	0A8F	39	Graphics	Score icon
; 0A90	0ADF	79	Graphics	Blank spacer (never written to)
; 0AE0	0AF7	23	Graphics	Blank spacer (never written to)
; 0AF8	0B17	31	Graphics	Runtime copy of lap graphic
; 0B18	0B37	31	Graphics	Blank spacer (never written to)
; 0B38	0B3F	7	Graphics	Runtime copy of the blank graphic
; 0B40	1DFF	4288	Code            Main game code (see below)
; 1C00	1D0F	272	Data	        Hazards data
; 1D10	1DFF	240	Data 	        high_score_screen
; 1E00	27FF	2560	Graphics        Boat graphics
; 2800	2FFF	2048	Graphics        Tile graphics
; 3000	57FF	10240	Data	        Map (co-ordinates to tile id)
; 5800	7FFF	10240	Screen	        Mode 5 screen memory
;
; Relocated Game Code Sub-routine Reference
; -----------------------------------------
;
; Once relocated, the main entry point is fn_game_start
; 
; From  To      Bytes   Sub-routine name
;
; 0B40	0B6C	45	fn_write_y_tiles_to_off_screen_buffer
; 0B6D	0B7B	15	fn_check_screen_start_address
; 0B7C	0BAB	48	fn_get_xy_tile_graphic_address
; 0BAC	0BDC	49	fn_write_x_tiles_to_off_screen_buffer
; 0BDD	0BF7	27	fn_break_handler
; 0BF8	0D90	409	fn_game_start
; 0D91	0D97	7	fn_read_key
; 0D98	0EBA	291	fn_scroll_screen_and_update
; 0EBB	0EDB	33	fn_set_6845_screen_start_address
; 0EDC	0EEB	16	fn_wait_20_ms
; 0EEC	0F2E	67	fn_copy_tile_column_to_screen
; 0F2F	0F3B	13	fn_check_joystick_left
; 0F3C	0F4C	17	fn_check_joystick_right
; 0F4D	0F5A	14	fn_check_joystick_button
; 0F5B	1013	185	fn_copy_tile_row_to_screen
; 1014	101D	10	fn_wait_for_n_interrupts
; 101E	1067	74	fn_copy_time_score_lap_to_screen_to_screen
; 1068	107F	24	fn_hide_cursor
; 1080	10B5	54	fn_set_game_colours
; 10B6	10C3	14	fn_change_colour_palette
; 10C4	10C7	4	colour_bank_1
; 10C8	10CB	4	colour_bank_2
; 10CC	10CF	4	colour_bank_3
; 10D0	10D4	5	colour_palette_block
; 10D5	10FB	39	fn_update_score
; 10FC	117F	132	fn_toggle_get_ready_icon
; 118A	120E	133	fn_screen_scroll_rotate_boat_flash_screen
; 120F	122E	32	boat_sprite_location lookup
; 122F	128C	94	fn_toggle_boat_on_screen
; 128D	1307	123	fn_check_keys_and_joystick
; 1308	1319	18	fn_calc_boat_direction_of_motion
; 131A	132F	22	lookup_table_boat_direction_fns
; 133A	138F	86	fn_boat_direction_N/NNE/NE/ENE/E/ESE/SE/SSE/S/SSW/SW/WSW/W/WNW/NW/NNW
; 139A	13A1	8	fn_accelerate_south
; 13A2	13A9	8	fn_move_to_half_south
; 13AA	13B1	8	fn_accelerate_east
; 13B2	13B9	8	fn_move_to_half_east
; 13BA	13C1	8	fn_accelerate_north
; 13C2	13C9	8	fn_move_to_half_north
; 13CA	13D1	8	fn_accelerate_west
; 13D2	13D9	8	fn_move_to_half_west
; 13DA	13E5	12	fn_adjust_east_west_for_full_north_or_south
; 13E6	13EF	10	fn_adjust_north_south_for_full_east_or_west
; 13F0	1411	37	Utility functions for above
; 1412	1414	3	Unused
; 1415	1450	60	fn_check_if_moving_up_or_down
; 1451	148C	60	fn_check_if_moving_left_or_right
; 148D	14E6	90	fn_colour_cycle_screen
; 14E7	14EE	8	sound_boat_aground_first
; 14EF	14F6	8	sound_boat_aground_second
; 14F7	14FE	8	palette_colour_cycle
; 14FF	1543	69	fn_init_graphics_buffers
; 1543	15AB	105	fn_calc_digits_for_display
; 15AC	15B7	12	fn_print_high_score_numbers
; 15B8	15DD	38	fn_draw_current_score
; 15DE	15F1	20	fn_draw_lap_counter
; 15F2	1602	17	fn_draw_time_counter
; 1603	1625	35	fn_set_timer_64ms
; 1626	162A	5	var_int_timer_value
; 162B	1632	8	sound_times_up
; 1633	163B	9	fn_enable_interval_timer
; 163C	1644	9	fn_disable_interval_timer
; 1645	16AC	104	fn_check_checkpoint_or_lap_complete
; 16AD	16BA	14	lap_times
; 16BB	16CD	19	fn_scroll_screen_up
; 16CE	16F2	37	fn_check_sound_keys
; 16F3	171E	44	fn_check_freeze_continue_keys
; 171F	174F	49	fn_add_time_to_score_and_display
; 1750	1754	5	pitch_table_completed_lap
; 1755	1759	5	duration_table_completed_lap
; 175A	1761	8	sound_completed_lap
; 1762	177B	26	fn_play_boat_sounds
; 177C	1783	8	sound_boat_move_first
; 1784	178B	8	sound_boat_move_second
; 178C	1796	11	duration_lookup_sound_table
; 1797	181E	136	fn_did_score_make_high_score_table
; 181F	18B1	147	fn_display_high_score_table
; 18B2	191E	109	fn_enter_high_score
; 191F	192C	14	fn_show_cursor
; 192D	1936	10	vdu_23_show_cursor_params
; 1937	193E	8	high_score_lsb
; 193F	1946	8	high_score_msb
; 1947	194E	8	high_score_name_lsb
; 194F	1956	8	high_score_name_msb
; 1957	19F7	161	high_score_names
; 19F8	1A2C	53	fn_display_press_space
; 1A2D	1A3E	18	fn_wait_for_intro_input
; 1A3F	1A6C	46	fn_show_player_score_below_high_scores
; 1A6D	1A8B	31	string_press_space_or_fire
; 1A8C	1AA4	25	string_enter_name 
; 1AA5	1AB0	12	string_you_scored
; 1AB1	1ADC	44	fn_fill_screen_with_jet_boat
; 1ADD	1AE3	7	jet_boat_string
; 1AE4	1AF4	17	fn_set_colours_to_black
; 1AF5	1B02	14	fn_print_next_stage_text
; 1B03	1B46	68	string_next_stage
; 1B47	1BDA	148	fn_apply_or_reset_hazard_set
; 1BDB	1BE9	15	fn_setup_read_lookup_table
; 1BEA	1BF4	11	hazard_lookup_table_lsb
; 1BF5	1BFF	11	hazard_lookup_table_msb
; 1C00	1D0F	272	Hazards data
; 1D10	1DFF	240	high_score_screen
;
; Interesting pokes 
; =================
; - Stop screen time decrementing
;       Set timer_poke+1 to a high value to ignore all events
;       e.g. ?&1603=&FF
; 


; Evelopes from basic loader:
; ENVELOPE 1,  1,70,16,2,2,0,0,126, 0,0,-126,110,110
; ENVELOPE 2,129, 2, 0,0,0,0,0, 40,-8,0,  -2,126, 45
; ENVELOPE 3,129, 1,-1,0,0,0,0,  0, 0,0,   0,  0,  0

; OSWRCH uses VDU values

; Write character (to screen) from Accumulator
OSWRCH = $FFEE

; Perfrom miscellaneous OS opferation using control block to pass parameters
OSWORD = $FFF1

; Perfrom miscellaneous OS operation using registers to pass parameters
OSBYTE = $FFF4

; Address of the memory mapped hardware
; for the 6845 CRTC video controller
SHEILA_6845_ADDRESS=$FE00
SHEILA_6845_DATA=$FE01

;System VIA Interrupt Flag Register
SYS_VIA_INT_REGISTER = $FE4D

;System VIA Interrupt Enable Register
SYS_VIA_INT_ENABLE = $FE4E

; VDU Variable for current screen mode
VDU_CURRENT_SCREEN_MODE = $0355

; Event vector for handling the interval
; timing crossing zero events
evntv_lsb_vector = $0220
evntv_msb_vector = $0221

; Start of the mode 7 screen memory address
mode7_start_addr = $7C00

; Dummy screen start address that is changed 
; programatically in the LDA/STAs but defaults
; to this value at load
dummy_screen_start = $8000

; Dummy graphics start address that is changed 
; programatically in the LDA/STAs but defaults
; to this value at load
dummy_graphics_load_start = $8000

; Screen graphics buffer (from $0A00 to $0B3F)
graphics_buffer_start = $0A00

; Unscrolled default memory address of the centre of the screen
mode_5_screen_centre =  $6A10

; Zero page variables

; Indicates the direction the boat is facing
; and to what degree (can get inbetween values)
; 0 - going fully west
; 2 - going partly west
; 4 - heading neither west or east
; 6 - going partly east
; 8 - going fully east
zp_boat_east_west_amount = $0000

; Indicates the direction the boat is facing
; and to what degree (can get inbetween values)
; 0 - going fully north
; 2 - going partly north
; 4 - heading neither north or south
; 6 - going partly south
; 8 - going fully south
zp_boat_north_south_amount = $0001

; Compass direction that the boat is facing
; 0  - N
; 1  - NNE
; 2  - NE
; 3  - ENE
; 4  - E
; 5  - ESE
; 6  - SE
; 7  - SSE
; 8  - S
; 9  - SSW
; 10 - SW
; 11 - WSW
; 12 - W
; 13 - WNW
; 14 - NW
; 15 - NNW
zp_boat_direction = $0002

; Used to detect six subsequent left key events
; before processing it to prevent the boat turning
; too fast
zp_turn_left_counter = $0003

; Used to detect six subsequent right key events
; before processing it to prevent the boat turning
; too fast
zp_turn_right_counter = $0004

; Current speed of the boat - starts at $0A and to 
; go faster the value decrements, fastest is zero
zp_boat_speed = $0005

; Used to detect six subsequent acceleration key events
; before processing it to prevent the boat accelerating
; too fast
zp_acceleration_counter = $0006

; Used to decelerate every third time around the game 
; loop (reaches a maximum of $03)
zp_decelerate_counter = $0007

; Status flag used to indiciate if the boat is currently
; aground
; $00 - not aground
; $FF - aground
zp_boat_aground_status = $0008

; Used to throttle the colour cycling when the boat has
; run aground - only flashes every 4th time around
; the game loop
zp_aground_colour_cycle_counter=$0009

; Caches the required number of System VIA CA1 interrupts
; to wait for. One interrupt every 20 ms. Takes the value
; from the accumulator from the caller
zp_wait_interrupt_count = $000A

; Number of "chunks" remianing to copy into the 
; offscreen buffer of the clock or boat
zp_graphics_chunks_remaining = $000B

; Flag to indicate whether the score has already been 
; updated this game loop - gets updated when the 
; screen cycles when aground as well as in the game loop so
; only update once
zp_score_already_updated_status = $000C

; Used to hold the value that needs to be converted into
; individual graphic digits e.g. score or lap or time remaining
zp_number_for_digits_lsb = $000D 
zp_number_for_digits_msb = $000E

; Indicates whether the intro screen is showing
; Set to $FF is intro screen (Jet Boat Jet Boat...)
; is showing otherwise $00
zp_intro_screen_status = $000F

; Holds the current score - note this on screen
; it is suffixed with an extra 0
zp_score_lsb = $0010
zp_score_msb = $0011

; Stores the current lap for the current stage
; It's zero based not one based but displayed as 
; one based
zp_current_lap = $0012

; Used by the generic routine that generates
; the number of graphics to display on the screen
; Score will be 5 digits, Lap 2, Time 2 etc
zp_display_digits = $0013

; Countdown timer for the number of time units (0.64 seconds) 
; remaining for the current lap - game ends on
; zero. Lap time decreaes per stage
zp_time_remaining_secs = $0014

; Where the graphics 0 - 9 are held in memory
zp_graphics_numbers_lsb = $0015
zp_graphics_numbers_msb = $0016

; Offscreen buffer for the digits generated to be
; put on screen later
zp_graphics_numbers_target_storage_lsb = $0017
zp_graphics_numbers_target_storage_msb = $0018

; Limits the rate that the score updates to n game loops
zp_score_update_rate_limiter   = $0019

; Maximum score increment per lap (excluding time bonus)
zp_score_max_lap_limit   = $001A

; Address of the centre of the screen - used to place
; the boat and the start / times up clock - constantly
; recalculated as the screen scrolls
zp_screen_centre_lsb = $001B
zp_screen_centre_msb = $001C

; Number of horizintal bytes to scroll the jet boat or next
; stage screen to fully show the map - set to 40 / $27 because
; it's mode 5
zp_scroll_map_steps = $001D

; Flag to indicate if the boat has been through the 
; checkpoint half way around the map - new lap won't start
; unless this is set
zp_checkpoint_status = $001F

; Players position in the high score table - working
; variable just used to find where to put the player's score
; and name
zp_high_score_position = $0020

; Used to display the high score names and to allow
; the player to enter their name (where it gets written)
zp_high_score_name_lsb = $0021
zp_high_score_name_msb = $0022

; Used to stop the score being updated when the jet boat or 
; new stage text is on the screen and scrolling off
zp_pre_game_scrolling_status = $0023

; Used as a flag to indicate if a scroll down or up should happen 
; during this game loop - if the boat isn't facing fully down or up
; i.e. only partially then this is used to only scroll / move down or up
; every other game loop
zp_north_or_south_on_this_loop_status   = $0024

; Used as a flag to indicate if a scroll left or right should happen 
; during this game loop - if the boat isn't facing fully left or right
; i.e. only partially then this is used to only scroll / move left or right
; every other game loop
zp_east_or_west_on_this_loop_status   = $0025

; Set to the location of the get ready, times up or boat graphic
; and generic routine called to draw that item in the middle of the
; screen
zp_graphics_source_lsb = $0026
zp_graphics_source_msb = $0027

; At the start of a new game or stage, this is used to 
; indicate that the hazard tiles should be reset to water tiles
; on the map
zp_reset_hazards_status = $002A

; Holds the location in memory of the current hazard configuration set
zp_hazard_config_lsb   = $002B
zp_hazard_config_msb   = $002C

; Working index used to add all the hazard tile rows to the map
; Gets initially set to zp_hazard_num_tiles_height and then decremented
zp_hazard_height_index   = $002D

; Width (in tiles) of the current hazard
zp_hazard_num_tiles_width   = $002E

; Height (in tiles) of the current hazard
zp_hazard_num_tiles_height   = $002F

; Used to copy all the tiles from the configuration in normal
; memory into zero page memory - used as a max in the copying loop
zp_total_tiles_for_hazard   = $0030

; Working index used to add all the hazard tiles on the current 
; hazard row to the map e.g. islands are 9 tiles wide so have to copy
; 9 tiles to the map
; Gets initially set to zp_hazard_num_tiles_width and then decremented
zp_hazard_width_index   = $0031

; How many of this hazard need to be added to the map
zp_total_hazard_occurrences   = $0032

; Cache of the current hazard's tile types
zp_hazard_first_tile_type   = $0033

; Cache of the current hazard's (x,y) co-ordinates
; Can have up to 14 instances - copied from the 
; normal memory configuration
zp_hazard_first_x_coordinate   = $0045
zp_hazard_first_y_coordinate   = $0053

; Used to colour the Jet Boat text at the start
; of a new game - alternates between red and yellow
zp_text_colour = $0061

; Which stage the player is currently on
zp_current_stage = $0062

; Which lap in the current stage the player is on
zp_laps_for_current_stage = $0063

; Indicates if all the laps in the the current
; stage have been completed
; $00 not complete
; $FF complete
zp_stage_completed_status = $0064

; Based on the direction that the boat is facing
; this is used to determine which function to call to 
; adjust the speed and direction to move - lookup
; table called and function address cached here
zp_addr_fn_boat_direction_lsb =  $0065
zp_addr_fn_boat_direction_msb =  $0066

; Used for two purposes - where to copy the tile graphics onto the
; screen and also where on the map in memory to update the tile type
; for a hazard
zp_graphics_tiles_storage_lsb = $0070
zp_graphics_tiles_storage_msb = $0071

; Used to store working values for memory addresses
zp_general_purpose_lsb = $0072
zp_general_purpose_msb = $0073

; Centre point of the map on the screen 
; Defaults to (x) $75 (y) $0B
zp_map_pos_x = $0074
zp_map_pos_y = $0075

; Stores the low byte of the screen start address
; that has been divided by 8    
zp_screen_start_div_8_lsb = $0076

; Position of the boat on the screen in (x,y) map co-ordinates
zp_boat_xpos = $0077
zp_boat_ypos = $0078

; Depending on the direction the boat is facing, these
; flags are set to the scroll the screen in the right
; direction
zp_scroll_east_status = $0079
zp_scroll_west_status = $007A
zp_scroll_north_status = $007B
zp_scroll_south_status = $007C

; Screen start address - used in the 6845 R12,R13
; for hardware scrolling
zp_screen_start_msb = $007E
zp_screen_start_lsb = $007D

; Break Intercept vectors
break_intercept_jmp_vector = $0287
break_intercept_lsb_vector = $0288
break_intercept_msb_vector = $0289

; Used to relocate the game and graphics when the game 
; first loads
copy_from_lsb = $0000
copy_from_msb = $0001
copy_to_lsb = $0002
copy_to_msb = $0003
copy_size = $0004
copy_num_pages = $0005

; Where in memory the BASIC loader puts the 
; user selectd keyboard control INKEY values
left_key_value = $7BC0
right_key_value = $7BC1
accel_key_value = $7BC2

; Where in memory the BASIC loader puts the 
; user selected keyboard control descriptions
left_key_string_from_loader = $7BD0
right_key_string_from_loader = $7BE0
accel_key_string_from_loader = $7BF0

; Main game code executes at $0B40 onwards
; Compile here and move later to where it gets loaded above 
; $1100
ORG &0B40

.main_code_block
;0B40
.fn_write_y_tiles_to_off_screen_buffer
        ; ---------------------------------------------------------
        ; Gets a vertical column of tile graphics and
        ; puts them in the off screen buffer (to either)
        ; scroll east or west - they are not written to the screen
        ; here
        ; ---------------------------------------------------------

        ; Define the off screen buffer where we'll
        ; assemble the right tile graphics for a new column
        ; in this case at $0900 - only used for y scrolling
        LDA     #$00
        STA     zp_graphics_tiles_storage_lsb
        LDA     #$09
        STA     zp_graphics_tiles_storage_msb

        ; 32 tiles are required (one for each row in the column)
        LDX     #$1F

;0B4A        
.loop_get_next_y_tile
        ; Get the memory address of the nth tile's
        ; source graphic
        JSR     fn_get_xy_tile_graphic_address

        ; Copy all 8 bytes of the graphic...
        LDY     #$07

.loop_next_tile_byte
        ; ...to the off screen buffer
        LDA     (zp_general_purpose_lsb),Y
        STA     (zp_graphics_tiles_storage_lsb),Y
        DEY

        ; If there are still some bytes left to copy
        ; loop around
        BPL     loop_next_tile_byte

        ; Increment the write address of the off screen
        ; buffer by 8 bytes 
        LDA     zp_graphics_tiles_storage_lsb
        CLC
        ADC     #$08
        STA     zp_graphics_tiles_storage_lsb

        ; Increment the y position in the (x,y)
        ; coordinates
        INC     zp_map_pos_y
        LDA     zp_map_pos_y

        ; The y position can only go up to $4F / 79
        CMP     #$50
        BNE     get_next_tile

        ; Reset the y position in the (x,y)
        ; coordinates to 0 when greater than or equal
        ; to $50 / 80
        LDA     #$00
        STA     zp_map_pos_y

.get_next_tile
        ; Do we still have some of the ($1F) 32 tiles to get?
        DEX
        BPL     loop_get_next_y_tile

        RTS

; L0B6D
.fn_check_screen_start_address
        ; ---------------------------------------------------------
        ; Check that the screen start address is between
        ; $5800 and $7FFF and, if not, adjust it
        ; ---------------------------------------------------------

        ; When scrolling down,
        ; if the screen start address is > $7FFF
        ; then we need to wrap it back to $5800
        ; which is achieved by subtracting $2800
        CMP     #$80
        BCS     reset_screen_to_start

        ; When scrolling up,
        ; if the screen start address is < $5800
        ; then we need to wrap it back to $8000
        ; which is achieved by adding $2800
        CMP     #$58
        BCC     reset_screen_to_end

        RTS

.reset_screen_to_start
        ; Subtract $2800 to wrap it around
        SBC     #$28
        RTS

.reset_screen_to_end
        ; Add $2800 to wrap it around
        ADC     #$28
        RTS

;0B7C
.fn_get_xy_tile_graphic_address
        ; ---------------------------------------------------------
        ; This routine is called with an (x,y) tile coordinates 
        ; stored in zero page zp_map_pos_x/zp_map_pos_y
        ; 
        ; This routine does two key things:
        ; 1. Works out the tile type for the (x,y)
        ; 2. Looks up where the tile graphic data is held in memory;; 
        ;
        ; All the tile type data for all (x,y) coordinates is held
        ; starting at $3000.  
        ;
        ;       0 =< x < 128
        ;       0 =< y < 80
        ; 
        ; So 128 tiles across the map
        ; So 80 tiles down the map
        ;
        ; Simple algorithm for (x,y) tile type lookup
        ; 
        ;    Tile type memory address = $3000 + (y * 128) + x
        ;       or
        ;    Code does this = $3000 + ($y00 / 2) + x
        ;
        ; So first x row (y=0)  is stored $3000 to $307F
        ; Next x row     (y=1)  is stored $3080 to $30FF
        ; ...
        ; Last x row     (y=80) is stored $5780 to $57FF
        ;
        ; This is then used to look up the tile graphic
        ; ---------------------------------------------------------

        ; Treats y as $y00 and divides by 2 and adds x
        LDA     zp_map_pos_y
        LSR     A
        STA     zp_general_purpose_msb
        LDA     #$00
        ROR     A
        ADC     zp_map_pos_x
        STA     zp_general_purpose_lsb

        ; If carry was set adding to the lsb
        ; branch and increment the MSB
        BCS     increment_tile_lookup_msb

.get_tile_type_and_graphic_address
        ; Add $3000 to the address
        LDA     #$30
        ADC     zp_general_purpose_msb
        STA     zp_general_purpose_msb
        
        LDY     #$00
        ; Find the tile at this (x,y) co-ordinate
        ; using the table at $3000+
        LDA     (zp_general_purpose_lsb),Y

        ; Now we have the tile type
        ; reuse the same zero page locations 
        ; to store the tile graphic location
        ;
        ; Reset the MSB to zero
        ; Simple algorithm for tile type to memory location
        ; 
        ;    tile graphic address = $2800 + (type * 8)

        ; Set MSB to zero from Y
        STY     zp_general_purpose_msb

        ; Multiple type by eight 
        ASL     A
        ROL     zp_general_purpose_msb
        ASL     A
        ROL     zp_general_purpose_msb
        ASL     A
        ROL     zp_general_purpose_msb

        ; Store LSB and MSB
        STA     zp_general_purpose_lsb
        LDA     zp_general_purpose_msb
        
        ; Add $2800 to address
        ADC     #$28
        STA     zp_general_purpose_msb

        ; Finished
        RTS

.increment_tile_lookup_msb
        ; Move to the next page of memory
        INC     zp_general_purpose_msb

        ; Carry can never be set here, this just ends the function
        BCC     get_tile_type_and_graphic_address 
    
;0BAC
.fn_write_x_tiles_to_off_screen_buffer
        ; ---------------------------------------------------------
        ; Gets a horizontal row of tile graphics and
        ; puts them in the off screen buffer (to either)
        ; scroll up or down - they are not written to the screen
        ; here
        ; ---------------------------------------------------------
        
        ; Set the Tile graphic off screen buffer - $0600
        ; This is used for rows of tiles only
        LDA     #$00
        STA     zp_graphics_tiles_storage_lsb
        LDA     #$06
        STA     zp_graphics_tiles_storage_msb

        ; In Mode 5 the screen has $27 / 39 columns of bytes
        ; So we need tiles for all of those bytes
        LDX     #$27
.loop_get_next_x_tile
        ; Find the source address for the tile
        ; The tile graphics at this address 
        ; are going to be copied into the off
        ; screen buffer - address will be held
        ; in zp_general_pupose_lsb/msb
        JSR     fn_get_xy_tile_graphic_address

        ; MODE 5 screen is blocks of 8 bytes per x/y
        ; position 
        LDY     #$07

.loop_copy_map_tile_block
        ; Load the first map tile (it's 8 bytes)
        ; and store it in the graphic buffer storage
        ; location
        LDA     (zp_general_purpose_lsb),Y
        ; Store the tile in $06xx
        STA     (zp_graphics_tiles_storage_lsb),Y

        ; If we don't have all 8 bytes then loop again
        DEY
        BPL     loop_copy_map_tile_block

        ; Calculate next tile address by adding
        ; 8 bytes to the LSB
        LDA     zp_graphics_tiles_storage_lsb
        CLC
        ADC     #$08
        STA     zp_graphics_tiles_storage_lsb

        ; Increment the MSB if it carried
        LDA     zp_graphics_tiles_storage_msb
        ADC     #$00
        STA     zp_graphics_tiles_storage_msb

        ; x axis only goes to 128 so if we reach 
        ; 128 we need to reset to zero
        INC     zp_map_pos_x
        BIT     zp_map_pos_x
        BPL     skip_x_reset

        ; Reset the y position to 0 as it went above 128
        LDA     #$00
        STA     zp_map_pos_x
        
.skip_x_reset
        ; Loop until we have loaded all the map tiles
        ; in the offscreen buffer
        DEX
        BPL     loop_get_next_x_tile

        RTS

; 0BDD
.fn_break_handler
        ; ---------------------------------------------------------
        ; Break intercept vector routine - although NEVER
        ; called in the game because the JMP vector is set to
        ; $00 and not $4C - also fn_game_start performs
        ; a *FX 200,3 which clears memory on break
        ; ---------------------------------------------------------
        ; 
        ; Check to see if the CTRL key was also pressed
        LDX     #$FE
        CLI
        JSR     fn_read_key

        ; Just break not ctrl-break so restart the game
        CPX     #$00
        BEQ     fn_game_start

        ; Otherwise clear the break intercept handler (remove the JMP instruction)
        LDA     #$00
        STA     break_intercept_jmp_vector

        ; Set memory to be cleared on Break (*FX 200,2)
        LDA     #$C8
        LDX     #$02
        LDY     #$00
        JSR     OSBYTE

;0BF5
        ; Hang on break with an infinite loop
.break_infinite_loop
        JMP     break_infinite_loop     

;0BF8   
.fn_game_start
        ; --------------------------------------------
        ; Main entry point after relocation and intro
        ; screen shown - called from the
        ; relocation/intro code
        ; --------------------------------------------

        ; Reset the stack pointer (start "clean")
        LDX     #$FF
        TXS
        
        ; Set the Break intercept vector to JMP to 
        ; the game's break handler - never executed
        ; as the break_intercept_jmp_vector is set
        ; to $00 and NOT to a JMP ($4C) instruction
        ; 
        ; MOS will only use this vector if it's set 
        ; to $4C
        ;
        ; To play with this - also need to change 
        ; the LDX #$03 to LDX #$00 to change the
        ; *FX 200,3 to *FX 200,0 to stop memory
        ; being cleared on break
        ;
        ; Maybe this was a quick way to restart a level
        ; for testing by the developer and removed when
        ; published
        LDA     #$00
        STA     break_intercept_jmp_vector
        LDA     #LO(fn_break_handler)
        STA     break_intercept_lsb_vector
        LDA     #HI(fn_break_handler)
        STA     break_intercept_msb_vector

.restart_game
        ; --------------------------------------------
        ; Called on the start of next new game 
        ; (resets everything)
        ; --------------------------------------------

        ; Set memory to be cleared on Break 
        ; and disable escape key (*FX 200,3)
        ; OSBYTE &C8
        LDA     #$C8
        LDX     #$03
        LDY     #$00
        JSR     OSBYTE

        ; Tell the OS to ignore the function keys
        ; OSBYTE $E1
        LDA     #$E1
        LDX     #$00
        LDY     #$00
        JSR     OSBYTE

        ; Initialize all these lovely variables to zero
        LDA     #$00
        STA     zp_turn_left_counter
        STA     zp_turn_right_counter
        STA     zp_acceleration_counter
        STA     zp_decelerate_counter
        STA     zp_score_lsb
        STA     zp_score_msb
        STA     zp_score_update_rate_limiter
        STA     zp_north_or_south_on_this_loop_status
        STA     zp_east_or_west_on_this_loop_status
        STA     zp_score_max_lap_limit
        STA     zp_checkpoint_status
        STA     zp_aground_colour_cycle_counter
        STA     zp_current_lap
        STA     zp_current_stage
        STA     zp_laps_for_current_stage
        STA     zp_stage_completed_status

        ; Look up the current lap time for completion
        ; It varies by stage and gets less and less 
        ; per new stage.  A stage is 12 laps
        LDX     zp_current_lap
        LDA     stage_lap_times,X
        STA     zp_time_remaining_secs

        ; Reduce the lap completion time by 1 time unit (0.64 seconds)
        DEC     zp_time_remaining_secs

        ; Set 0 and 1 to the turn right counter...
        LDA     zp_turn_right_counter
        STA     zp_boat_east_west_amount 
        STA     zp_boat_north_south_amount

        ; Set the event handler EVNTV for 
        ; interval timer crossing 0 
        ; to be the set timer function
        LDA     #LO(fn_set_timer_64cs)
        STA     evntv_lsb_vector
        LDA     #HI(fn_set_timer_64cs)
        STA     evntv_msb_vector

;0C57
.new_stage
        ; Disable interval timer crossing 0 event
        ; timer increments every centisecond - don't 
        ; need this running during game setup, just during
        ; the game as no remaining seconds to update until then
        JSR     disable_interval_timer

        ; Clear sound channels - for some reason
        ; 2 and 3 are not cleared
        ; Clear sound channel 0
        LDA     #$15
        LDX     #$04
        JSR     OSBYTE

        ; Clear sound channel 1
        INX
        JSR     OSBYTE 

        ; Default the boat to pointing down the screen
        ; Value is from 0 to 16
        LDA     #$08
        STA     zp_boat_direction

        ; Set the initial boat and map position
        LDA     #$75
        STA     zp_boat_xpos
        STA     zp_map_pos_x
        LDA     #$0B
        STA     zp_boat_ypos
        STA     zp_map_pos_y

        ; Set start of screen address LSB to &xx00 for Mode 5
        LDA     #$00
        STA     zp_screen_start_lsb
        
        ; Set boat scroll directions to off for
        ; for west, south and north (boat is moving east)
        STA     zp_scroll_west_status
        STA     zp_scroll_south_status
        STA     zp_scroll_north_status

        ; Set start of screen address MSB to &58xxfor Mode 5
        LDA     #$58
        STA     zp_screen_start_msb

        ; Store the centre of the screen as the write
        ; target for the clock
        LDA     #LO(mode_5_screen_centre)
        STA     zp_screen_centre_lsb
        LDA     #HI(mode_5_screen_centre)
        STA     zp_screen_centre_msb

        ; Set the status that the screen is 
        ; scrolling right ($FF) as the boat
        ; faces due East first
        LDA     #$FF
        STA     zp_scroll_east_status

        ; Set the status that it's the intro screen
        STA     zp_intro_screen_status

        ; Also set the flag to reset the hazards to 
        ; water tiles (always sets hazards to water tiles 
        ; if the zp_reset-hazards_status is $FF)
        STA     zp_reset_hazards_status

        ; Set the index counter for looping through all the 
        ; different types of hazard
        LDX     #$00

        ; Reset all the hazards back to a water tile - on the first
        ; lap there are no additional hazards over the standard map
        ; So this goes through all the hazard (x,y) on the map and 
        ; sets each to a water tile - the X register defines 
        ; which set of hazards e.g. ducks
.reset_next_set_of_hazards
        ; Preserve the hazard index before calling the reset
        TXA
        PHA

        ; Clear all the hazards from the map - loop through
        ; all the hazard configs (there are 11 types) which
        ; get added to the map at each progressive lap in a stage
        ; - this just resets them to a water tile
        JSR     fn_get_hazard_for_index_and_apply_or_reset        

        ; Restore the hazard index before calling the reset
        PLA
        TAX
        INX

        ; Check to see if any more hazards to reset, if so
        ; loop onto the next one
        CPX     #$0B
        BNE     reset_next_set_of_hazards

        ; If we add hazards to the map now, don't reset them
        ; to water ($00)
        LDA     #$00
        STA     zp_reset_hazards_status
        
        ; Select screen mode to 5
        ; MODE 5
        LDA     #$16
        JSR     OSWRCH
        LDA     #$05
        JSR     OSWRCH

        ; Set the boat speed to 10 ($0A)
        ; Used to scroll the map and also
        ; to change the duration of the boat 'put'
        ; sound - boat gets faster as this number
        ; gets smaller and slowest speed is $0A, 
        ; fastest $00
        LDA     #$0A
        STA     zp_boat_speed

        ; Set the screen to black
        JSR     fn_set_colours_to_black

        ; Hide the screen cursor
        JSR     fn_hide_cursor        

        ; Initialise graphic buffers
        JSR     fn_init_graphics_buffers

        ; Load the current stage
        LDA     zp_stage_completed_status

        ; Check if starting a new game or a new stage
        BEQ     new_game_screen_text

        ; Print the next stage text if the player
        ; has all the laps in a stage
        JSR     fn_print_next_stage_text

        ; Go to game set up
        JMP     game_setup

.new_game_screen_text
        ; Write "Jet boat" in alternating colours
        ; all over the screen
        JSR     fn_fill_screen_with_jet_boat               

.game_setup
        ; Reset current stage completed status
        LDA     #$00
        STA     zp_stage_completed_status

        ; Set the game colours for the current stage
        JSR     fn_set_game_colours

        ; Pause for 2 seconds on the new game or
        ; next stage screen
        ; CA1 System VIA interrupts every 20 ms
        ; So ($64) 100 x 20 = 2 seconds
        LDA     #$64
        JSR     fn_wait_for_n_interrupts

        ; Set this so that the score won't be updated
        ; when the pre-game scrolling happens
        LDA     #$FF
        STA     zp_pre_game_scrolling_status

        ; Map will be scrolled onto the screen 
        ; using 40 steps - this is because
        ; in Mode 5 there are  39 / $27 columns of bytes
        LDA     #$27
        STA     zp_scroll_map_steps

.loop_scroll_map_start
        ; This loop scrolls the game start / new stage
        ; text off of the screen and scrolls the start
        ; of game map onto the screen

        ; Reset the following direction status indicators
        ; $00 - not moving in that direction
        ; $FF - moving in that direction
        LDA     #$00
        STA     zp_scroll_south_status
        STA     zp_scroll_north_status

        ; Set the status that the score has not been 
        ; updated this game loop iteration as it's a new game
        STA     zp_score_already_updated_status

        ; Scroll the screen into view one step
        JSR     fn_scroll_screen_and_update

        ; Wait for 60 ms before scrolling into view again
        ; CA1 System VIA interrupts every 20 ms
        ; So ($03) 3 x 20 = 60 ms
        LDA     #$03
        JSR     fn_wait_for_n_interrupts

        ; Continue to scroll if we haven't 
        ; moved fully into view
        DEC     zp_scroll_map_steps
        BPL     loop_scroll_map_start

        ; Set the indicator that pre-game scrolling
        ; has completed and updates to the score can now 
        ; happen
        LDA     #$00
        STA     zp_pre_game_scrolling_status

        ; Intro screen is no longer showing
        ; so set the status
        LDA     #$00
        STA     zp_intro_screen_status

        ; Set the graphics source to the Get Ready Graphic
        ; (it's stored at $04A0)
        LDA     #$A0
        STA     zp_graphics_source_lsb
        LDA     #$04
        STA     zp_graphics_source_msb

        ; Show the Get Ready icon
        JSR     fn_toggle_boat_or_time_graphic

        ; Pause for 2 seconds (show icon for 2 seconds)
        ; CA1 System VIA interrupts every 20 ms
        ; So ($64) 100 x 20 = 2 seconds
        LDA     #$64
        JSR     fn_wait_for_n_interrupts

        ; Enable the interval timer (that decrements the
        ; time remaining - time interval set later)
        JSR     fn_enable_interval_timer  

        ; Add a time unit to the remaining time (0.64 seconds)
        INC     zp_time_remaining_secs

        ; Start the timer value that changes the on screen
        ; remaining time - routine is normally called by
        ; the EVNTV vector and therefore A has to be set
        ; to $05 so that the routine thinks it is handling
        ; an "interval timer crossing zero" event - can poke this
        ; in fn_set_timer_64cs to ignore all events and stop
        ; the counter counting down
        LDA     #$05
        JSR     fn_set_timer_64cs   
        
        ; Play the boat "put put sounds"
        JSR     fn_play_boat_sounds

;0D16
.main_game_loop
        ; Use the boat speed to control the map
        ; scrolling steps
        LDA     zp_boat_speed
        STA     zp_scroll_map_steps

;0D1A
.check_time_remaining
        ; Check to see if there is any remaining time
        ; left - continue if there is, otherwise branch ahead
        LDA     zp_time_remaining_secs
        BNE     still_game_time_left

        ; Calculate the bottom row starting memory address
        ; as the time/score/lap counter will be drawn there
        ;
        ; Address is written to write_to_screen_address+1/+2
        JSR     fn_calc_bottom_row_start_address

        ; Wait 20 ms
        JSR     fn_wait_20_ms

        ; Update the time / score / lap counters on screen
        ; to show the final score and laps
        JSR     fn_copy_time_score_lap_to_screen

        ; Remove the boat from the screen
        JSR     fn_toggle_boat_on_screen 

        ; Set the source graphics buffer to be
        ; $0400 where the time's up graphic is off screen
        ; buffered
        LDA     #$00
        STA     zp_graphics_source_lsb
        LDA     #$04
        STA     zp_graphics_source_msb
        
        ; Show the times up icon
        JSR     fn_toggle_boat_or_time_graphic

        ; Flush the buffer for sound channel 0
        LDX     #$04
        LDA     #$15
        JSR     OSBYTE

        ; Flush the buffer for sound channel 1
        INX
        JSR     OSBYTE

        ; Flush the buffer for sound channel 2
        INX
        JSR     OSBYTE

        ; OSBYTE &07
        ; Sound command
        ; Play the times up sound
        LDX     #sound_times_up MOD 256
        LDY     #sound_times_up DIV 256
        LDA     #$07
        JSR     OSWORD

        ; Wait for 2 seconds ($64 / 100 * 20 ms)
        LDA     #$64
        JSR     fn_wait_for_n_interrupts

        ; Wait for another 2 seconds ($64 / 100 * 20 ms)
        LDA     #$64
        JSR     fn_wait_for_n_interrupts

        ; Disable the interval timer crossing 0 event
        JSR     disable_interval_timer

        ; Check if the score made the high score table
        ; and display the high score table
        JSR     fn_did_score_make_high_score_table

        ; Restart the game
        JMP     restart_game

;0D60    
.still_game_time_left
        ; Check for keyboard or joystick input
        JSR     fn_check_keys_and_joystick

        ; Play the boat "putt putt" sounds 
        ; and vary based on speed
        JSR     fn_play_boat_sounds

        DEC     zp_scroll_map_steps
        BPL     check_time_remaining

        ; Boat speed is from 0 (fast) to A (slow)
        ;
        ; Check the boat speed - if we're at the minimum
        ; speed then don't do anything, otherwise,
        ; every three times around, reduce the speed
        ; (counter intuitively by incrementing this variable)
        ; 0A is the minimum, 00 is the maximum
        LDA     zp_boat_speed

        ; Are we at minimum speed of $0A (or higher!), if so branch
        CMP     #$0A
        BCS     post_decelerate_check

        ; If we're beyond minimum speed, every third time around
        ; the loop we'll slow down - means the player has to keep their
        ; finger on accelerate to counter it.
        INC     zp_decelerate_counter
        LDA     zp_decelerate_counter
        CMP     #$03
        BCC     post_decelerate_check

        ; Third time around loop, decrease boat speed
        LDA     #$00
        STA     zp_decelerate_counter
        INC     zp_boat_speed

;0D7E
.post_decelerate_check
        ; Check if the boat is moving vertically
        JSR     fn_check_if_moving_north_or_south

        ; Check if the boat is moving horizontally
        JSR     fn_check_if_moving_east_or_west

        ; Scroll the screen and draw the new tiles
        JSR     fn_scroll_screen_and_update

        ; Check to see if the stage has been
        ; completed - if it has go back to the the
        ; initialisation part and show the congratulations
        ; messages, if not, branch ahead
        LDA     zp_stage_completed_status
        BEQ     stage_not_complete

        ; Stage is complete - move to new stage
        JMP     new_stage

;0D8E
.stage_not_complete
        ; Back around the main game loop
        JMP     main_game_loop

;0D91
.fn_read_key
        ; ---------------------------------------------------------
        ; Check to see if key X is being pressed
        ; ---------------------------------------------------------

        ; OSBYTE &81
        ; Scan keyboard for keypress of key in X
        ; X - negative inkey value of key
        ; Y - always $FF
        ;
        ; On return X and Y will contain $FF if
        ; it was being pressed
        LDY     #$FF
        LDA     #$81
        JMP     OSBYTE

;0D98
.fn_scroll_screen_and_update
        ; ---------------------------------------------------------
        ; Check to see if key X is being pressed
        ; ---------------------------------------------------------

        ; Check to see if either scroll up 
        ; or down has been set (ignore if neither
        ; or both). Neat way to check.
        LDA     zp_scroll_south_status
        EOR     zp_scroll_north_status
        BEQ     check_left_right_status

        ; Check to see if a scroll up is happening
        ; (will be set to $FF so negative) if not,
        ; branch ahead
        BIT     zp_scroll_north_status
        BPL     check_down_status

        ; Move the boat position up the screen
        ; If it goes below zero then reset it to
        ; $4F
        DEC     zp_boat_ypos
        BPL     skip_boat_ypos_reset 

        ; Reset the boat position to the middle of the
        ; screen
        LDA     #$4F
        STA     zp_boat_ypos  

.skip_boat_ypos_reset 
        ; Subtract $140 as the screen is moving up
        ; so change the graphics row write address
        ; and the screen start address

        ; Update the LSB by 
        LDA     zp_screen_start_lsb
        SEC
        SBC     #$40
        STA     zp_screen_start_lsb
        STA     copy_graphics_row_target + 1
        LDA     zp_screen_start_msb
        SBC     #$01

        ; If we went below $58xx for the screen address
        ; reset it to the end of the screen ($7Fxx)
        JSR     fn_check_screen_start_address
        STA     copy_graphics_row_target + 2
        STA     zp_screen_start_msb

        ; Make the boat (x,y) position the map 
        ; (x,y) position - indicates the centre
        ; co-ordinates of the map
        LDA     zp_boat_ypos
        STA     zp_map_pos_y
        LDA     zp_boat_xpos
        STA     zp_map_pos_x

        ; Update the new row that scrolled into view
        JSR     fn_write_x_tiles_to_off_screen_buffer

.check_down_status
        ; Check to see if a scroll down should happen
        BIT     zp_scroll_south_status

        ; Branch if not
        BPL     check_left_right_status

        ; Move the boat down the screen
        INC     zp_boat_ypos
        LDA     zp_boat_ypos

        ; If the boat is at position $50 or greater reset it 
        ; as the screen will wrap around
        CMP     #$50
        BNE     skip_boat_ypos_reset2

        ; Reset the boat position
        LDA     #$00
        STA     zp_boat_ypos

.skip_boat_ypos_reset2
        ; Calculates the address of the start of the
        ; bottom row of the screen by subtracting
        ; the length of a row off of the top left
        ; corner of the visible screen and wrapping
        ; it around if it is outside of screen memory
        LDA     zp_screen_start_lsb
        SEC
        SBC     #$40
        STA     copy_graphics_row_target + 1
        LDA     zp_screen_start_msb
        SBC     #$01
        
        ; Check the result is greater than or equal to
        ; $5800, if not then wrap it around
        JSR     fn_check_screen_start_address
        STA     copy_graphics_row_target + 2

        ; Scrolling down adds $140 to the screen
        ; start address for the top left corner
        LDA     zp_screen_start_lsb
        CLC
        ADC     #$40
        STA     zp_screen_start_lsb
        LDA     zp_screen_start_msb
        ADC     #$01
        
        ; Check it didn't go over $7FFF otherwise
        ; handle the wrapping around
        JSR     fn_check_screen_start_address
        STA     zp_screen_start_msb

        ; Add $1E / 30 to the boat's (x,y) y co-ordinate
        ; to get the bottom row of the screen's y 
        ; co-ordinate (can wrap round on the map to the
        ; start)
        LDA     zp_boat_ypos
        CLC
        ADC     #$1E

        ; If the bottom row y co-ordinate is  greater than
        ; or equal to $50 (80) then wrap it around
        CMP     #$50
        BCC     skip_boat_ypos_decrement

        ; If it's over $50 then reset it by looping it around
        ; Can only be $50 y positions
        SEC
        SBC     #$50
.skip_boat_ypos_decrement

        ; Store the bottom row's map y co-ordinate
        STA     zp_map_pos_y

        ; Set the map position to the boat position
        LDA     zp_boat_xpos
        STA     zp_map_pos_x
        
        ; Get and store the graphics for the newly
        ; visible row in the off screen buffer
        JSR     fn_write_x_tiles_to_off_screen_buffer

.check_left_right_status
        ; Check to see if a scroll left or right is happening
        ; If both, it will be ignored
        LDA     zp_scroll_east_status
        EOR     zp_scroll_west_status

        ; If not, branch ahead
        BEQ     scroll_checks_complete

        ; Check to see if it's a scroll right
        BIT     zp_scroll_east_status
        
        ; If it isn't branch ahead
        BPL     check_left_status

        ; Increment the x position of the boat
        ; (move it right)
        INC     zp_boat_xpos
        LDA     zp_boat_xpos

        ; If the x position of the boat has
        ; gone further than $7F then reset it
        ; to zero (map only exists for 0 =< 0 < $80)
        BPL     skip_boat_xpos_reset

        ; Reset the boat x position to zero
        LDA     #$00
        STA     zp_boat_xpos

.skip_boat_xpos_reset
        ; When scrolling the screen to the right,
        ; calculate where the top right pixels will be
        ; Current screen start address + $140 / 320
        ; That's where we're going to write the next
        ; tile so update the routine with those values
        CLC
        LDA     zp_screen_start_lsb
        ADC     #$40
        STA     copy_graphics_column_target + 1
        LDA     zp_screen_start_msb
        ADC     #$01

        ; Check the start address gone beyond $8000
        ; and correct it if it did - only important
        ; for the MSB not the LSB
        JSR     fn_check_screen_start_address
        STA     copy_graphics_column_target + 2

        ; Move the screen left by 4 pixels / one byte
        ; and update our screen address tracking variables
        CLC
        LDA     zp_screen_start_lsb
        ADC     #$08
        STA     zp_screen_start_lsb
        LDA     zp_screen_start_msb
        ADC     #$00

        ; Check the start address gone beyond $8000
        ; and correct it if it did - only important
        ; for the MSB not the LSB
        JSR     fn_check_screen_start_address
        STA     zp_screen_start_msb

        ; Set the map position to be the same as the boat
        LDA     zp_boat_ypos
        STA     zp_map_pos_y

        ; Add $27 to the x position of the boat to get
        ; to the x position of the right hand edge
        LDA     zp_boat_xpos
        CLC
        ADC     #$27

        ; $7F is the maximum x co-ordinate
        AND     #$7F
        STA     zp_map_pos_x
        JSR     fn_write_y_tiles_to_off_screen_buffer

.check_left_status
        ; Check to see if it's a scroll left
        BIT     zp_scroll_west_status
        BPL     scroll_checks_complete

        DEC     zp_boat_xpos
        BPL     skip_boat_xpos_reset3

        ; If the boat position is less than zero,
        ; reset it to $7F
        LDA     #$7F
        STA     zp_boat_xpos
.skip_boat_xpos_reset3
        ; Move the screen left by 4 pixels / one byte
        ; Calculate the new screen start 
        LDA     zp_screen_start_lsb
        SEC
        SBC     #$08
        STA     zp_screen_start_lsb
        STA     copy_graphics_column_target + 1
        LDA     zp_screen_start_msb
        SBC     #$00
        ; Check the start address gone bel0w $5800
        ; and correct it if it did        
        JSR     fn_check_screen_start_address
        STA     zp_screen_start_msb
        STA     copy_graphics_column_target + 2

        LDA     zp_boat_ypos
        STA     zp_map_pos_y
        LDA     zp_boat_xpos
        STA     zp_map_pos_x
        JSR     fn_write_y_tiles_to_off_screen_buffer  

;0E85
.scroll_checks_complete
        ; Calculate the bottom row starting memory address
        ; as the time/score/lap counter will be drawn there
        ;
        ; Address is written to write_to_screen_address+1/+2
        JSR     fn_calc_bottom_row_start_address

        SEI
        ; Wait 20 milliseconds
        JSR     fn_wait_20_ms

        ; Update the 6845 with the new scregen start address
        JSR     fn_set_6845_screen_start_address

        ; Check to see if the screen should be scrolled up or down
        ; if not, branch ahead.
        LDA     zp_scroll_south_status
        EOR     zp_scroll_north_status
        BEQ     skip_row_to_screen_copy

        ; Needs to be scrolled so copy a new row of data to the 
        ; the screen (addresses have previously been calculated)
        JSR     fn_copy_tile_row_to_screen

.skip_row_to_screen_copy
        ; Check to see if the screen should be scrolled right or 
        ; left, if not branch ahead
        LDA     zp_scroll_east_status
        EOR     zp_scroll_west_status
        BEQ     skip_column_to_screen_copy

        ; Copy the column of tiles to the screen
        JSR     fn_copy_tile_column_to_screen  

.skip_column_to_screen_copy
        ; Check that the intro screen is not being shown, if it 
        ; is branch ahead
        LDA     zp_intro_screen_status
        BMI     skip_rotate_boat_flash_screen

        ; Rest the score update flag
        LDA     #$00
        STA     zp_score_already_updated_status
        JSR     fn_screen_scroll_rotate_boat_flash_screen 

.skip_rotate_boat_flash_screen
        ; Show the score at the bottom of the screen
        ; (even the intro/next stage screen when it
        ; starts to scroll)
        LDA     zp_score_already_updated_status
        BMI     skip_time_score_lap_update

        ; Write the graphics at the bottom of the screen
        ; that contain the time, score and lap counter
        JSR     fn_copy_time_score_lap_to_screen

.skip_time_score_lap_update
        ; Update the score and check if the checkpoint
        ; has been reached or a lap has been completed
        CLI
        JSR     fn_update_score
        JSR     fn_check_checkpoint_or_lap_complete

        RTS             

;0EBB
.fn_set_6845_screen_start_address
        ; ---------------------------------------------------------
        ; Changes the screen start address 
        ; on the 6485 CRTC Video Controller. The
        ; screen start address must be divided by 8 
        ; before setting
        ; ---------------------------------------------------------

        ; Set the new screen start address in the 6845
        ; registers 12 and 13
        LDA     zp_screen_start_lsb
        STA     zp_screen_start_div_8_lsb
        LDA     zp_screen_start_msb

        ; 6845 registers 12 (MSB) and 13 (LSB) require
        ; the screen start address to be divided
        ; by 8 so divide by 8
        ; Accumulator holds the MSB
        ;  LSR A                 ROR $76
        ; ========               ========
        ; 76543210 -> (via C) -> 7654321 -> (throw away)
        LSR     A
        ROR     zp_screen_start_div_8_lsb
        LSR     A
        ROR     zp_screen_start_div_8_lsb
        LSR     A
        ROR     zp_screen_start_div_8_lsb

        ; Set 6845 Register to 12
        ; and give the MSB of the screen start
        ; address divided by 8
        LDX     #$0C
        STX     SHEILA_6845_ADDRESS
        STA     SHEILA_6845_DATA

        ; Set 6845 Register to 13
        ; and give the LSB of the screen start
        ; address divided by 8
        INX
        STX     SHEILA_6845_ADDRESS
        LDA     zp_screen_start_div_8_lsb
        STA     SHEILA_6845_DATA
        RTS

;0EDC
.fn_wait_20_ms
        ; ---------------------------------------------------------
        ; This waits function waits 20 ms for an 
        ; interrupt from CA1 on the System VIA
        ; There's an interrupt every 20ms
        ; ---------------------------------------------------------

        ; Disable the CA1 interrupt on the System VIA
        ; 00000010
        ; Bit 7 - 0 - disable interrupt
        ; Bit 2 - 1 - CA1 interrupt
        LDA     #$02

        ; Call SHEILA FE4E (Write only)
        STA     SYS_VIA_INT_ENABLE

.loop_wait_disable_ca1
        ; Check SHEILA FE4D Interrupt Register
        ; on the System VIA.  Waits until the register
        ; is un set before continuing
        ; Get interrupt status and wait until CA1 
        ; is set
        BIT     SYS_VIA_INT_REGISTER
        BEQ     loop_wait_disable_ca1

        ; Re-enable the CA1 interrupt on the System VIA
        ; 10000010
        ; Bit 7 - 1 - enable interrupt
        ; Bit 2 - 1 - CA1 interrupt
        LDA     #$82
        STA     SYS_VIA_INT_ENABLE
        RTS

;0EEC
.fn_copy_tile_column_to_screen
        ; ---------------------------------------------------------
        ; $0900 is the tile buffer for columns
        ; Tiles are assembled here before writing to the 
        ; screen. Copy from the offscreen buffer to the screen
        ; ---------------------------------------------------------

        ; Write the load address for the buffer
        LDA     #$00
        STA     copy_graphics_column_source + 1
        LDA     #$09
        STA     copy_graphics_column_source + 2

        ; There are 32 rows of 8 bytes in Mode 5
        LDX     #$1F
.loop_copy_graphics_column_8_bytes
        ; Copy the current 8 bytes to the target
        ; screen address
        LDY     #$07
.loop_copy_graphics_column_next_byte
.copy_graphics_column_source
        ; Load the graphics from the source
        LDA     dummy_graphics_load_start,Y

.copy_graphics_column_target
        ; Write to the screen destination
        ; and loop back around if all 8 bytes haven't
        ; been copied
        STA     dummy_screen_start,Y
        DEY
        BPL     loop_copy_graphics_column_next_byte

;0F03
        ; Load the LSB for the screen write address
        ; as we are going to change the location to 
        ; the next Mode 5 row of 8 bytes by adding $140
        LDA     copy_graphics_column_target + 1

        ; Moves the screen write address down a row
        ; Each row is $140 / 320 bytes 
        ; So we add this to the current
        ; write address
        CLC
        ADC     #$40
        STA     copy_graphics_column_target + 1
        LDA     copy_graphics_column_target + 2

        ; Check to see if the screen start address
        ; is greater than the top of screen memory
        ; which is $8000
        ADC     #$01
        CMP     #$80
        BCS     handle_column_screen_write_overflow

        ; Check to see if the screen start address
        ; is greater than or equals the bottom of screen 
        ; memory which is $5800
        CMP     #$58
        BCS     store_column_new_screen_write_address_msb
        
        ; Underflow of write address so wrap it to the 
        ; top of screen memory
        ADC     #$28
        BCC     store_column_new_screen_write_address_msb

;0F1D
.handle_column_screen_write_overflow
        ; Screen write address was higher than
        ; top of screen memory, so loop it to the 
        ; bottom of screen memory ($5800) by subtracting
        ; $28 from $80 in the MSB of screen start address
        SBC     #$28

.store_column_new_screen_write_address_msb
        ; Store the screen write address MSB
        STA     copy_graphics_column_target + 2

        ; We have already copy 8 bytes from the source, so
        ; increment the source address
        CLC
        LDA     copy_graphics_column_source+1
        ADC     #$08
        STA     copy_graphics_column_source+1

        ; Are there more graphics to copy?
        ; loop back around if so
        DEX
        BPL     loop_copy_graphics_column_8_bytes

        RTS

;$0F2F
.fn_check_joystick_left
        ; ---------------------------------------------------------
        ; Check to see if the player has moved the joystick to the
        ; left
        ; ---------------------------------------------------------
	; OSBYTE &80 reads the ADC chip
	; Reading channel 1 the x axis of the joystick
	; This part checks for left
        LDX     #$01
        LDA     #$80
        JSR     OSBYTE

	; If the joystick MSB value > F5 (max FF) then assume user
	; is trying to go left
        CPY     #$F5
        BCS     left_or_right_detected

	; Not going left
        BCC     no_left_or_right_detected

;0F3C
.fn_check_joystick_right
        ; ---------------------------------------------------------
        ; Check to see if the player has moved the joystick to the
        ; right
        ; ---------------------------------------------------------
	; OSBYTE &80 reads the ADC chip
	; Reading channel 1 the x axis of the joystick
	; This part checks for right
        LDX     #$01
        LDA     #$80
        JSR     OSBYTE

	; If the joystick value is < 0A the assume user
	; is trying to go right
        CPY     #$0A
        BCC     left_or_right_detected

.no_left_or_right_detected
	; indicate to caller that NO left or right was detected
        LDY     #$00
        RTS

.left_or_right_detected
	; indicate to caller that left or right WAS detected
        LDY     #$01
        RTS

;0F4D
.fn_check_joystick_button
        ; ---------------------------------------------------------
        ; Check to see if the player has pressed the joystick
        ; button
        ; ---------------------------------------------------------
	; OSBYTE &80 reads the ADC chip
	; Reading channel 0 detects if the joystick
        ; button has been pressed (ok technically
        ; this part isn't through the ADC chip as it 
        ; goes through the System VIA)
        ; 
        ; Bits 0 and 1 of X after the call indicate
        ; if the joystick buttons have been pressed
        ; (we're only interested in bit 0 as only)
        ; one joystick is supported
        LDX     #$00
        LDA     #$80
        JSR     OSBYTE

        ; Test to see if joysick one's button has been
        ; pressed
        TXA
        AND     #$01
        BEQ     no_left_or_right_detected
        BNE     left_or_right_detected

;0F5B
.fn_copy_tile_row_to_screen
        ; ---------------------------------------------------------
        ; Copy the tiles that have been buffered off screen
        ; to the bottom or top of the screen
        ; ---------------------------------------------------------
        ; Get the copy graphics target MSB
        ; Check to see if we're on the last row of the screen?
        LDA     copy_graphics_row_target + 2
        CMP     #$7E

        ; If the screen write address is before $7E00 we can
        ; bulk copy 
        ; If A < $ 7E then branch
        BCC     bulk_copy_tile_row_to_screen

        ; If A != $7E then branch
        BNE     byte_copy_tile_row_to_screen

        ; if A>=M then branch
        LDA     copy_graphics_row_target + 1
        CMP     #$AA
        BCS     byte_copy_tile_row_to_screen

;0F6B
.bulk_copy_tile_row_to_screen
        ; The 320 bytes that will be copied will not cross 
        ; the screen     threshold so this section bulk copies
        ; without checking for screen memory overflow
        ;
        ; Only used to copy if the start memory address for the
        ; screen is $7E00 - $7EA9
        ; Get the target write graphic 
        ; screen address MSB
        LDA     copy_graphics_row_target + 2
        STA     screen_target_block_one + 2
        STA     screen_target_block_two + 2
        STA     screen_target_block_three + 2
        STA     screen_target_block_four + 2
        
        ; Get the target screen address LSB
        ; First block copy in the loop will write here
        LDA     copy_graphics_row_target + 1
        STA     screen_target_block_one +1

        ; Add $50 / 80 to the LSB
        ; Second block copy in the loop will write
        ; from +$50 from the first block
        CLC
        ADC     #$50
        STA     screen_target_block_two + 1
        BCC     skip_second_block_msb_increment

        ; If there was an overflow, increment the MSB
        INC     screen_target_block_two + 2 
        INC     screen_target_block_three + 2
        INC     screen_target_block_four + 2

        CLC
.skip_second_block_msb_increment
        ; Add $50 / 80 to the LSB
        ; Third block copy in the loop will write
        ; from +$A0 ($50 + $50) from the first block
        ADC     #$50
        STA     screen_target_block_three + 1
        BCC     skip_third_block_msb_increment

        INC     screen_target_block_three + 2
        INC     screen_target_block_four + 2
        CLC
.skip_third_block_msb_increment
        ; Add $50 / 80 to the LSB
        ; Fourth block copy in the loop will write
        ; from +$F0 ($50 + $50 + $50) from the first block
        ADC     #$50
        STA     screen_target_block_four + 1
        BCC     skip_fourth_block_msb_increment 

        INC     screen_target_block_four + 2
        CLC
.skip_fourth_block_msb_increment

        ; Each full row in Mode 5 is 320 bytes
        ; The loop copies in 4 parallel blocks
        ; which is 4 * 80 = 320
        LDX     #$4F

.loop_copy_next_four_bytes
        ; Location 0600 to 073F is used to off screen buffer 
        ; the map tiles before writing them to the screen
        ; This loop copies all 320 bytes to the screen
        ; taking 4 bytes per iteration of the loop

        ; Copy block one
        LDA     $0600,X
.screen_target_block_one
        STA     dummy_screen_start,X

        ; Copy block two
        LDA     $0650,X
.screen_target_block_two
        STA     dummy_screen_start,X

        ; Copy block three
        LDA     $06A0,X
.screen_target_block_three
        STA     dummy_screen_start,X

        ; Copy block four
        LDA     $06F0,X
.screen_target_block_four
        STA     dummy_screen_start,X
        DEX
        BPL     loop_copy_next_four_bytes

        RTS

;0FC9
.byte_copy_tile_row_to_screen
        ; The 320 bytes that will be copied WILL cross 
        ; the screen threshold so this section checks after
        ; each 8 bytes if it needs to wrap around screen address

        ; $0600 is the map tile off screen buffer for rows
        ; Tiles are assembled here before writing to the 
        ; screen
        ; Write the off screen buffer load address 
        LDA     #$00
        STA     copy_graphics_row_source + 1
        LDA     #$06
        STA     copy_graphics_row_source + 2

        ; There are 40 columns of 8 bytes across the screen
        ; $27 / 39 but 40 including 0
        CLC
        LDX     #$27

.loop_copy_graphics_row_8_bytes
        ; Copy the current 8 tile bytes to the screen
        LDY     #$07
.loop_copy_graphics_row_next_byte
.copy_graphics_row_source
        LDA     dummy_screen_start,Y

.copy_graphics_row_target
        ; Write to the screen destination
        ; and loop back around if all 8 bytes haven't
        ; been copied
        STA     dummy_screen_start,Y
        DEY
        BPL     loop_copy_graphics_row_next_byte

        ; Load the LSB for the screen write address
        ; as we are going to change the location to 
        ; the next Mode 5 column of 8 bytes by adding $8
        LDA     copy_graphics_row_target + 1
        ADC     #$08
        STA     copy_graphics_row_target + 1

        ; Check to see if a carry happened (number > 255)
        BCC     increment_row_source

        ; Add the carry to the MSB
        LDA     copy_graphics_row_target + 2
        ADC     #$00

        ; Check to see if the screen start address
        ; is greater than the top of screen memory
        ; which is $8000
        CMP     #$80
        BCS     handle_row_screen_write_overflow

        ; Check to see if the screen start address
        ; is greater than or equals the bottom of screen 
        ; memory which is $5800
        CMP     #$58
        BCS     store_row_new_screen_write_address_msb

        ; Underflow of write address so wrap it to the 
        ; top of screen memory
        ADC     #$28
        BCC     store_row_new_screen_write_address_msb

.handle_row_screen_write_overflow
        ; Screen write address was higher than
        ; top of screen memory, so loop it to the 
        ; bottom of screen memory ($5800) by subtracting
        ; $28 from $80 in the MSB of screen start address
        SBC     #$28

.store_row_new_screen_write_address_msb
        ; Store the screen write address MSB
        STA     copy_graphics_row_target + 2
        CLC

.increment_row_source
        ; We have already copy 8 bytes from the source, so
        ; increment the source address, and add the 1 to the MSB
        ; if there is a carry
        LDA     copy_graphics_row_source + 1
        ADC     #$08
        STA     copy_graphics_row_source + 1
        BCC     row_8_bytes_copied_to_screen

        INC     copy_graphics_row_source + 2
        CLC

.row_8_bytes_copied_to_screen
        ; Are there more graphics to copy?
        ; loop back around if so
        DEX
        BPL     loop_copy_graphics_row_8_bytes

        RTS

;1014
.fn_wait_for_n_interrupts
        ; ---------------------------------------------------------
        ; Wait for n * 20ms 
        ; ---------------------------------------------------------
        STA     zp_wait_interrupt_count
.loop_wait_for_interrupt
        JSR     fn_wait_20_ms

        DEC     zp_wait_interrupt_count
        BPL     loop_wait_for_interrupt

        RTS

;101E
.fn_copy_time_score_lap_to_screen
        ; ---------------------------------------------------------
        ; Copy the buffered graphics for the remaining time,
        ; the score and the lap total to the screen
        ; ---------------------------------------------------------
        ;
        ; All these graphics are buffered in $0A00 to $0B3F
        LDA     #graphics_buffer_start MOD 256
        STA     load_from_graphics_buffer + 1
        LDA     #graphics_buffer_start DIV 256
        STA     load_from_graphics_buffer + 2

        LDX     #$27
.loop_copy_more_graphics
        LDY     #$07
.load_from_graphics_buffer
        ; Buffer start - programatically changed
        ; at run time from this function.
        ; In memory the address is stored LSB then MSB
        LDA     dummy_screen_start,Y
.write_to_screen_address
        ; Screen start - programatically changed
        ; at run time from this function
        ; In memory the address is stored LSB then MSB
        STA     dummy_screen_start,Y
        DEY
        ; Loop again until we have copied 8 bytes
        BPL     load_from_graphics_buffer

        ; Get the screen start address LSB
        LDA     write_to_screen_address + 1
        CLC

        ; We just copied 8 bytes so increment the start
        ; addres and move to the next 8 bytesbytes
        ADC     #$08
        ; Update the LSB for the start address
        STA     write_to_screen_address + 1
        BCC     move_to_next_8_bytes

        ; And the carry to the MSB for the start address
        LDA     write_to_screen_address + 2
        ADC     #$00

        ; Check to see if the screen start address
        ; is greater than the top of screen memory
        ; which is $8000
        CMP     #$80
        BCS     handle_screen_start_overflow

        ; Check to see if the screen start address
        ; is greater than or equals the bottom of screen 
        ; memory which is $5800
        CMP     #$58
        BCS     update_screen_start_address_msb

        ; Underflow of screen so wrap it to the 
        ; top of screen memory
        ;
        ; Not sure when this would ever be trigged
        ; unless the start value was wrong entering
        ; this function
        ADC     #$28
        BCC     update_screen_start_address_msb

.handle_screen_start_overflow
        ; Screen start address was higher than
        ; top of screen memory, so loop it to the 
        ; bottom of screen memory ($5800) by subtracting
        ; $28 from $80 in the MSB of screen start address
        SBC     #$28

.update_screen_start_address_msb
        ; Write the new screen start address MSB back to memory
        STA     write_to_screen_address + 2

.move_to_next_8_bytes
         ; Move to the next 8 bytes
        CLC
        LDA     load_from_graphics_buffer + 1
        ADC     #$08
        STA     load_from_graphics_buffer + 1
        BCC     no_screen_address_carry

        ; There was a carry (LSB > 255) so add
        ; 1 to the MSB for screen start address
        INC     load_from_graphics_buffer + 2
.no_screen_address_carry
        DEX
        BPL    loop_copy_more_graphics

        RTS  

;1068
.fn_hide_cursor
        ; ---------------------------------------------------------
        ; Hide the cursor using a VDU 23 command
        ; ---------------------------------------------------------
        ; VDU 23 parameters are read from memory
        LDX     #$00
.loop_vdu_23_hide_cursor_param
        LDA     vdu_23_hide_cursor_params,X
        JSR     OSWRCH

        INX
        CPX     #$0A
        BNE     loop_vdu_23_hide_cursor_param

        RTS

.vdu_23_hide_cursor_params
        ; Switch off the cursor
        ;
        ; VDU 23,0,R,X,0,0,0,0,0,0
        ; R=6845 register
        ; X=Value
        ; VDU 23,0,10,20,0,0,0,0,0,0
        ; R10 is the cursor control register
        ; &20 = 0010 0000
        ; Bit  7 - 0 - not used
        ; Bit  6 - 0 - disable cursor 
        ; Bit  5 - 1 - blink timing control, no blink
        ; Bits 4-0 - 0000 - cursor start line 0
        EQUB    $17,$00,$0A,$20,$00,$00,$00,$00
        EQUB    $00,$00

.fn_set_game_colours
        ; ---------------------------------------------------------
        ; Use the current stage to change the palette
        ; Load value and keep the bottom two bits
        ; Pulls a column of colours from the banks
        ; X is used a the counter into which colour
        ; scheme will be used - there are 4 to choose from
        ; ---------------------------------------------------------
        ; Get the current stage
        LDA     zp_current_stage
        AND     #$03
        TAX

        ; Reset first logical colour to be blue / 04
        LDA     #$04
        STA     palette_physical_colour
        LDA     #$00
        STA     palette_logical_colour

        ; Change logical colour 0
        JSR     fn_change_colour_palette

        ; Set the next 3 colours
        ; Logical colour 1
        LDA     colour_bank_1,X
        STA     palette_physical_colour
        INC     palette_logical_colour
        JSR     fn_change_colour_palette

        ; Logical colour 2
        LDA     colour_bank_2,X
        STA     palette_physical_colour
        INC     palette_logical_colour
        JSR     fn_change_colour_palette

        ; Logical colour 3
        LDA     colour_bank_3,X
        STA     palette_physical_colour
        INC     palette_logical_colour
        JMP     fn_change_colour_palette

.fn_change_colour_palette
        ; ---------------------------------------------------------
        ; Call OSWORD &0C to change the colour palette
        ; ---------------------------------------------------------
        ; Preserve X and A
        TXA
        PHA

        ; Parameter block address specified in X (LSB) / Y (MSB)
        ; Performs a VDU 19 / OSBYTE &0C to change the 
        ; Logical to physical colour mapping for one colour
        LDX     #colour_palette_block MOD 256
        LDY     #colour_palette_block DIV 256
        LDA     #$0C
        JSR     OSWORD

        ; Restore X and A
        PLA
        TAX
        RTS

        ; Colour_bank_n contains the physical colours
        ; logical colour n can be set to based on the 
        ; bottom two bits of the stage number (zero based)
        ; 
        ; Hence taken as a column not a row for the colours
        ; for a stage (Logical colour 0 always set to blue)
        ;
        ; So possible combinations are:
        ; 1. blue, yellow, red, white
        ; 2. blue, yellow, green, white
        ; 3. blue, magenta, white, yellow
        ; 4. blue, yellow, magenta, white
.colour_bank_1
        ; yellow, yellow, magenta, yellow
        EQUB    $03,$03,$05,$03

.colour_bank_2
        ; red, green, white, magenta
        EQUB    $01,$02,$07,$05

.colour_bank_3
        ; white, white, yellow, white
        EQUB    $07,$07,$03,$07

.colour_palette_block
.palette_logical_colour
        EQUB    $00
.palette_physical_colour        
        EQUB    $00
.palette_future_use_padding
        ; Should always be set to zero as reserved
        ; for future use and doesn't do anything on 
        ; a BBC B
        EQUB    $00,$00,$00

;10D5
.update_score_return
        RTS

;10D6
.fn_update_score
        ; ---------------------------------------------------------
        ; Update's the player's score
        ; ---------------------------------------------------------
        ; If it's the pre-game scrolling then
        ; don't update the score
        BIT     zp_pre_game_scrolling_status
        ; Branch if negative (set to negative
        ; during pre-game scrolling)
        BMI     update_score_return

        ; Only update the score every 16th time around
        ; the game loop (about every 3 seconds when not
        ; run aground - about every 12 seconds when you are)
        INC     zp_score_update_rate_limiter
        LDA     zp_score_update_rate_limiter
        CMP     #$10
        BNE     update_score_return

        ; Reset 19 to 0
        LDA     #$00
        STA     zp_score_update_rate_limiter

        ; Only allow a maximum addition of 200 to the score
        ; (note scores are stored divided by 10) per lap
        ; So don't update if it's already been updated
        ; $14 / 20 times
        LDA     zp_score_max_lap_limit
        CMP     #$14
        BEQ     update_score_return

        ; Update the number of times we've updated
        ; the score this lap
        INC     zp_score_max_lap_limit

        ; Add $01 to the current score LSB
        CLC
        LDA     zp_score_lsb
        ADC     #$01
        STA     zp_score_lsb
        ; Check if the carry is set - if so increment 
        ; the MSB otherwise redraw it now
        BCC     redraw_score

        ; Add 1 to the MSB
        INC     zp_score_msb
.redraw_score
        ; Redraw the score on screen
        JMP     fn_draw_current_score

.fn_toggle_boat_or_time_graphic
        ; ---------------------------------------------------------
        ; Shows or hides the boat, get ready or times up
        ; graphics - depending on which memory address is 
        ; referenced in zp_graphics_source_lsb/msb
        ; Caller must set that appropriately for what they want
        ; but generally:
        ;   $0400 is the times up graphic
        ;   $04A0 is the get ready graphic
        ;   Anything else is the boat graphic
        ; ---------------------------------------------------------

        ; Reset the boat aground status indicator
        LDA     #$00
        STA     zp_boat_aground_status

        ; Get the source buffer for the get ready
        ; icon (where it's already been cached)
        ; and use that as the copy from source
        ; later on here.
        LDA     zp_graphics_source_lsb
        STA     source_get_ready_graphic_buffer + 1
        LDA     zp_graphics_source_msb
        STA     source_get_ready_graphic_buffer + 2

        ; Get the target screen address for the get ready
        ; icon and use that as the copy to target - always
        ; written to the centre of the screen
        LDA     zp_screen_centre_lsb
        STA     zp_graphics_tiles_storage_lsb
        LDA     zp_screen_centre_msb
        STA     zp_graphics_tiles_storage_msb

        ; Clock is made of 3 chunks
        CLC
        LDA     #$03
        STA     zp_graphics_chunks_remaining

.get_get_ready_next_chunk
        ; Each chunk is 5 x 8 bytes
        ; (Loops on positive and zero is positive)
        LDX     #$04
.get_get_ready_next_8_bytes
        LDY     #$07
.source_get_ready_graphic_buffer
.loop_copy_get_ready_byte
        ; Load the next byte from the graphic buffer 
        ; (dummy_screen_start replaced at runtime with
        ; a source graphics buffer e.g. times up icon source)
        LDA     dummy_screen_start,Y

        ; If it's just transparent then skip
        ; as EORing it on the screen will have no effect
        BEQ     get_next_get_ready_byte

        ; Cache the graphic byte on the stack
        PHA

        ; If the current graphic on screen is 
        ; transparent then skip ahead and replace it
        ; with the source graphic byte (no point EORing it
        ; as it'll have no effect)
        LDA     (zp_graphics_tiles_storage_lsb),Y
        BEQ     write_get_ready_byte_to_screen

        ; Cache the source graphic address (these values
        ; haven't changed though since they were written the other
        ; way around)
        LDA     source_get_ready_graphic_buffer + 1
        STA     zp_general_purpose_lsb
        LDA     source_get_ready_graphic_buffer + 2
        STA     zp_general_purpose_msb

        ; EOR the graphic we want to write to the screen
        ;  with what's currently on the screen and 
        ; stick it back on the stack (it'll get written if it's 
        ; different)
        PLA
        EOR     (zp_graphics_tiles_storage_lsb),Y
        PHA

        ; Collision detection routine - check to see if the
        ; 
        ; If the graphic that is going to be written to
        ; the screen is the same as the source graphic
        ; after it's been EOR'd then branch ahead or
        ; the source graphic is just water (0x00000000)
        AND     (zp_general_purpose_lsb),Y
        CMP     (zp_general_purpose_lsb),Y
        BEQ     check_same_as_target

        ; Logic summary:
        ; 1. Load source graphic
        ; 2. Check if source graphic is 0 - if so just write 
        ; it to the screen as it's water and will blat whatever is there
        ; 3. Otherwise, get what's on the screen already
        ; 4. EOR the on-screen byte with what we're going to write there
        ; 5. If the result is of the EOR ANDed with the source byte is zero,
        ; then it's unchanged so no collision - just write it to the screen to
        ; blat whatever is there
        ; 6. Otherwise set the run aground flag 

        ; Set the boat is aground status
        LDA     #$FF
        STA     zp_boat_aground_status
        BMI     write_get_ready_byte_to_screen

;113F
.check_same_as_target
        ; Load the graphic byte and preserve it back
        ; on the stack too
        PLA
        PHA

        ; Is the graphic the same as what's on the screen
        ; already? If so, branch ahead to write it...
        ; otherwise the boat has run aground
        AND     (zp_graphics_tiles_storage_lsb),Y
        CMP     (zp_graphics_tiles_storage_lsb),Y
        BEQ     write_get_ready_byte_to_screen

        ; Boat has run aground (the graphic comparison
        ; as different) so set the status flag
        LDA     #$FF
        STA     zp_boat_aground_status

;114B
.write_get_ready_byte_to_screen
        ; Write the graphic to the screen
        PLA
        STA     (zp_graphics_tiles_storage_lsb),Y

.get_next_get_ready_byte
        ; Copy the next bye of the current chunk
        DEY
        BPL     loop_copy_get_ready_byte

        ; Increment the screen target destination
        ; as 8 bytes were just written
        CLC
        LDA     zp_graphics_tiles_storage_lsb
        ADC     #$08
        STA     zp_graphics_tiles_storage_lsb
        ; If the carry wasn't set, no need to 
        ; do the carry add to the MSB as the carry will be
        ; clear
        BCC     increment_get_ready_buffer

        ; Add the carry to the screen target address MSB
        LDA     zp_graphics_tiles_storage_msb
        ADC     #$00

        ; Check it didn't go beyond $7FFF, if so
        ; wrap it around
        JSR     fn_check_screen_start_address

        ; Update the screen target address MSB
        STA     zp_graphics_tiles_storage_msb

        CLC
.increment_get_ready_buffer
        ; Get the source buffer address and increment by
        ; 8 bytes as the current 8 bytes have just
        ; been processed - so add 8 to the LSB and 
        ; write it back 
        LDA     source_get_ready_graphic_buffer + 1
        ADC     #$08
        STA     source_get_ready_graphic_buffer +1

        ; If carry was clear we don't have to increment
        ; the MSB
        BCC     check_get_ready_chunk_complete

        ; Increment the MSB too
        INC     source_get_ready_graphic_buffer + 2
        CLC
.check_get_ready_chunk_complete
        ; Get the next 8 bytes for this chunk
        DEX
        BPL     get_get_ready_next_8_bytes

        ; Calculate the next row address for Mode 5
        ; From the start byte it would be $140 to add
        ; but we just wrote 5 bytes so to get to the 
        ; next row start position use $118
        ; ($140 - ($5 x $8)) = $118
        LDA     zp_graphics_tiles_storage_lsb
        ADC     #$18
        STA     zp_graphics_tiles_storage_lsb
        LDA     zp_graphics_tiles_storage_msb
        ADC     #$01

        ; Check it hasn't gone over $7FFF
        ; and handle it if it has
        JSR     fn_check_screen_start_address

        CLC
        ; Store the address
        STA     zp_graphics_tiles_storage_msb
        DEC     zp_graphics_chunks_remaining
        BPL     get_get_ready_next_chunk

        RTS
;118A
.fn_screen_scroll_rotate_boat_flash_screen
        ; --------------------------------------------
        ; Removes the boat from the screen, checks
        ; which way it is rotating and redraws it 
        ; rotated in that direction
        ; --------------------------------------------

        ; Undraw the boat (it's EOR'd)
        JSR     fn_toggle_boat_on_screen

        ; If left and right scroll directions are both
        ; detected then branch away, otherwise,
        ; check individually for left and right
        LDA     zp_scroll_east_status
        AND     zp_scroll_west_status
        BNE     check_scroll_vertical

        ; Check for scroll right
        BIT     zp_scroll_east_status
        BPL     check_scroll_left

        ; Add 8 bytes to the screen start address
        ; to scroll the right edge of the screen
        LDA     zp_screen_centre_lsb
        CLC
        ADC     #$08
        STA     zp_screen_centre_lsb
        BCC     check_scroll_left

        ; Add the carry to the MSB
        LDA     zp_screen_centre_msb
        ADC     #$00

        ; Check it hasn't gone over $7FFF
        ; and handle it if it has
        JSR     fn_check_screen_start_address
        STA     zp_screen_centre_msb

.check_scroll_left
        ; Check for scroll left
        BIT     zp_scroll_west_status
        BPL     check_scroll_vertical

        ; Subtract 8 bytes to the screen start address
        ; to scroll the left edge of the screen
        LDA     zp_screen_centre_lsb
        SEC
        SBC     #$08
        STA     zp_screen_centre_lsb
        BCS     check_scroll_vertical

        LDA     zp_screen_centre_msb
        SBC     #$00
        ; Check it hasn't gone under $5800
        ; and handle it if it has
        JSR     fn_check_screen_start_address

        STA     zp_screen_centre_msb

.check_scroll_vertical
        ; If both scroll up and down are set then
        ; branch (do nothing)
        LDA     zp_scroll_south_status
        AND     zp_scroll_north_status
        BNE     set_boat_rotation_sprite

        ; Check for scroll up (top of screen)
        BIT     zp_scroll_north_status
        BPL     check_scroll_down

        ; Subtract $140 bytes to the screen start address
        ; to scroll up (the top edge of the screen)
        LDA     zp_screen_centre_lsb
        SEC
        SBC     #$40
        STA     zp_screen_centre_lsb
        LDA     zp_screen_centre_msb
        SBC     #$01

        ; Check it hasn't gone under $5800
        ; and handle it if it has
        JSR     fn_check_screen_start_address
        STA     zp_screen_centre_msb

.check_scroll_down
        ; Scroll for scroll down (bottom of screen)
        BIT     zp_scroll_south_status
        BPL     set_boat_rotation_sprite

        ; Add $140 bytes to the screen start address
        ; to scroll down (the bottom edge of the screen)
        LDA     zp_screen_centre_lsb
        CLC
        ADC     #$40
        STA     zp_screen_centre_lsb
        LDA     zp_screen_centre_msb
        ADC     #$01

        ; Check it hasn't gone over $7FFF
        ; and handle it if it has
        JSR     fn_check_screen_start_address
        STA     zp_screen_centre_msb

.set_boat_rotation_sprite
        ; Set the source sprite location for the boat
        ; based on its current rotation
        LDX     zp_boat_direction
        LDA     boat_sprite_location_lsb,X
        STA     zp_graphics_source_lsb
        LDA     boat_sprite_location_msb,X
        STA     zp_graphics_source_msb
        ; Write it to the screen
        JSR     fn_toggle_boat_or_time_graphic

        ; Has the boat run aground? If so we need to
        ; colour cycle the screen every 4th time
        ; through here.  Status is set to $FF when
        ; the boat is aground
        BIT     zp_boat_aground_status
        BPL     boat_not_aground

        ; Colour cycle only show when status is zero
        ; Whenever the colour cycle is called, it's 
        ; reset to 4 so only flashes ever 4th time around
        ; loop
        LDA     zp_aground_colour_cycle_counter
        BNE     skip_colour_cycle

        ; Colour cycle the screen and slow down
        JMP     fn_colour_cycle_screen

.boat_not_aground
        ; Boat isn't on land anymore - reset the 
        ; the colour cycle count down to zero so
        ; when it is, it'll go straight to colour
        ; cycle above
        LDA     #$00
        STA     zp_aground_colour_cycle_counter
        RTS

.skip_colour_cycle
        DEC     zp_aground_colour_cycle_counter
        RTS

        ; 16 boat sprites for when the boat rotates
        ; around in the following order:
        ; N, NNW, NW, WNW, W, WSW, SW, SSW
        ; S, SSE, SE, ESE, E, ENE, NE, NNE
        ;
        ; Each graphic is 160 bytes across 4 chunks of 40 bytes
        ;
;120F
.boat_sprite_location_lsb
        EQUB    $00,$A0,$40,$E0,$80,$20,$C0,$60
        EQUB    $00,$A0,$40,$E0,$80,$20,$C0,$60

; 121F
.boat_sprite_location_msb
        EQUB    $1E,$1E,$1F,$1F,$20,$21,$21,$22
        EQUB    $23,$23,$24,$24,$25,$26,$26,$27

;122F
.fn_toggle_boat_on_screen
        ; --------------------------------------------
        ; Draws or removes the boat from the screen
        ; --------------------------------------------
        ; Reset zp_boat_aground_status to zero       
        LDA     #$00
        STA     zp_boat_aground_status

        ; Copy the boat graphic source address to our 
        ; working variables
        LDA     zp_graphics_source_lsb
        STA     zp_general_purpose_lsb
        LDA     zp_graphics_source_msb
        STA     zp_general_purpose_msb

        ; Copy the target screen address to our working
        ; variables
        LDA     zp_screen_centre_lsb
        STA     zp_graphics_tiles_storage_lsb
        LDA     zp_screen_centre_msb
        STA     zp_graphics_tiles_storage_msb

        ; A boat is made of three graphic "chunks"
        ; of 8 x 5 bytes so it's 120 bytes per boat
        CLC
        LDA     #$03
        STA     zp_graphics_chunks_remaining

;1248
.get_next_graphic_chunk
        ; Each graphic chunk is 5 x 8 bytes = 40 bytes
        ; So loop four times around the inner 8 byte loop
        LDX     #$04

.copy_graphic
        ; Get this chuck of 8 bytes of the graphic
        LDY     #$07
        
.copy_graphic_8bytes
        ; Load the graphic from the source buffer
        ; If it's a black byte then no point in XORing
        ; it
        LDA     (zp_general_purpose_lsb),Y
        BEQ     source_black_byte

        ; EOR it onto the screen
        EOR     (zp_graphics_tiles_storage_lsb),Y
        ; Store the EOR'd graphic
        STA     (zp_graphics_tiles_storage_lsb),Y
.source_black_byte
        ; Get the next byte of the graphic to copy
        DEY
        BPL     copy_graphic_8bytes

        ; Get the next block of 8 bytes of the source graphic
        ; By incrementing the LSB by 8
        CLC
        LDA     zp_graphics_tiles_storage_lsb
        ADC     #$08
        STA     zp_graphics_tiles_storage_lsb
        ; Carry is clear then no need to increment the MSB
        BCC     source_carry_clear

        ; Add the carry to the MSB
        LDA     zp_graphics_tiles_storage_msb
        ADC     #$00
        
        ; If we went beyond $80xx for the screen address
        ; reset it to the start of the screen ($58xx)
        JSR     fn_check_screen_start_address

        ; Store the updated MSB and clear the carry flag
        STA     zp_graphics_tiles_storage_msb
        CLC

.source_carry_clear

        ; Get where we're going to store the next 8 bytes
        ; (destination) by incrementing the LSB by 8
        LDA     zp_general_purpose_lsb
        ADC     #$08
        STA     zp_general_purpose_lsb
        BCC     destination_carry_clear

        ; Carry is clear then no need to increment the MSB
        INC     zp_general_purpose_msb
        CLC

.destination_carry_clear
        ; Get the next set of 8 bytes of the tile
        DEX
        BPL     copy_graphic

        ; Increment by $18 / 24
        LDA     zp_graphics_tiles_storage_lsb
        ADC     #$18
        STA     zp_graphics_tiles_storage_lsb
        
        LDA     zp_graphics_tiles_storage_msb
        ADC     #$01
        ; Check the screen start address didn't go
        ; higher than $7FFF, if so wrap it around
        JSR     fn_check_screen_start_address

        CLC
        STA     zp_graphics_tiles_storage_msb
        DEC     zp_graphics_chunks_remaining
        BPL     get_next_graphic_chunk

        RTS

;128D
.fn_check_keys_and_joystick
        ; --------------------------------------------
        ; Read key presses and joystick 
        ; and turn or accelerate boat
        ; --------------------------------------------

        ; Sets the acceleration and direction flags 
        ; (how much in each direction) the boat is moving
        ; based on the direction the boat tip is facing
        JSR     fn_calc_boat_direction_of_motion

        ; Check if the S key has been pressed
        ; and turn the sound on if it was
        JSR     fn_check_sound_keys

        ; Check if the F key has been pressed
        ; and freeze the game if it has
        JSR     fn_check_freeze_continue_keys

        ; Disable maskable interrupts
        SEI

        ; Wait 20ms
        JSR     fn_wait_20_ms

        ; Remove the Get Ready icon or boat (whatever was there)
        ; ANDY VALIDATED
        JSR     fn_toggle_boat_or_time_graphic

        ; Check to see if the joystick
        ; is pushed left
        JSR     fn_check_joystick_left
        BNE     turn_left_detected

.read_left_key
        ; Check to see if the turn left key has been pressed
        ; The value is changed programmatically to be 
        ; the user defined or default key from the loading
        ; menus - defaults to be caps lock from the menus
        ; but Z in the code below
        ; INKEY value is 2-complements so to get value
        ; ((FF - 9E) + 1) * -1
        ; LDX     #$9E
        LDX     #$BF
left_key_game = read_left_key+1
        JSR     fn_read_key

        ; If key is being pressed then X will be $FF
        CPX     #$FF
        ; If it wasn't then branch ahead to check right
        BNE     check_right

;12AB
.turn_left_detected
        ; Detects left key press 6 times in a row
        ; before doing anything - so we don't turn too
        ; fast
        INC     zp_turn_left_counter
        LDA     zp_turn_left_counter

        ; If the we haven't detected left 6 times
        ; do nothing (branch ahead)        
        CMP     #$06
        BCC     check_right

        ; Reset the left key detection 
        LDA     #$00
        STA     zp_turn_left_counter

        ; Increment the left counter
        LDA     zp_boat_direction
        CLC
        ADC     #$01

        ; Maximum value is 16 (assume rotation by 360/16 = 27)
        ; as it's a 4-bit counter. Effectively increments the 
        ; counter and wraps around at $0F / 16
        AND     #$0F
        STA     zp_boat_direction
;12C0
.check_right
        ; Check to see if the joystick
        ; is pushed right
        JSR     fn_check_joystick_right
        BNE     turn_right_detected
.read_right_key
        ; Check to see if the turn right key has been pressed
        ; The value is changed programmatically to be 
        ; the user defined or default key from the loading
        ; menus - defaults to be Ctrl from the menus
        ; but Z in the code below
        LDX     #&FE
right_key_game = read_right_key+1
        JSR     fn_read_key

        ; If key is being pressed then X will be $FF
        ; If it wasn't then branch ahead to check accelerate
        CPX     #$FF
        BNE     check_accelerate

;12CE
.turn_right_detected
        ; Detects right key press 6 times in a row
        ; before doing anything - so we don't turn too
        ; fast
        INC     zp_turn_right_counter
        LDA     zp_turn_right_counter

        ; If the we haven't detected right 6 times
        ; do nothing (branch ahead)            
        CMP     #$06
        BCC     check_accelerate

        ; Reset the right key detection 
        LDA     #$00
        STA     zp_turn_right_counter

        ; Maximum value is 16 (assume rotation by 360/16 = 27)
        ; as it's a 4-bit counter. Effectively decrements
        ; the counter and wraps around at $00 / 0
        LDA     zp_boat_direction
        CLC
        ADC     #$0F
        AND     #$0F
        STA     zp_boat_direction

;12E3
.check_accelerate
        JSR     fn_check_joystick_button

        BNE     accelerate_detected

.read_accelerate
        ; Check to see if the accelerate key has been pressed
        ; The value is changed programmatically to be 
        ; the user defined or default key from the loading
        ; menus - defaults to be Ctrl from the menus
        ; but shift in the code below   
        ; LDX     #$FF
        LDX     #$B6
accel_key_game = read_accelerate+1
        JSR     fn_read_key

        ; If key is being pressed then X will be $FF
        ; If it wasn't then branch ahead to check accelerate
        CPX     #$FF
        BNE     redraw_screen

;12F1
.accelerate_detected
        ; Detects acceleration 6 times in a row
        ; before doing anything - so we don't accelerate too
        ; fast
        INC     zp_acceleration_counter
        LDA     zp_acceleration_counter

        ; If the acceleration hasn't reached 6
        ; do nothing (branch ahead)
        CMP     #$06
        BNE     redraw_screen

        ; Set the acceleration to zero
        ; So we don't do the next increment of
        ; speed until we have detected the key press
        ; again six times
        LDA     #$00
        STA     zp_acceleration_counter

        ; Are we already at top speed ($00) 
        ; Speed goes from 10 slow to 0 fast
        LDA     zp_boat_speed
        BEQ     redraw_screen

        ; Increase speed by (counter-intuitively?)
        ; reducing this variable
        DEC     zp_boat_speed

; 1303
.redraw_screen
        ; Based on the current orientation of the boat
        ; lookup the boat sprite to use
        JSR     set_boat_rotation_sprite

        ; Enable maskable interrupts and return
        CLI
        RTS

;1308
.fn_calc_boat_direction_of_motion
        ; --------------------------------------------
        ; Use the direction of the boat which
        ; is stored as 0 - 15, to lookup
        ; which function we should call
        ; This is done by doubling the value and using
        ; it as an offset from the start of the function lookup
        ; table.  Each function address in the table is 2 bytes 
        ; in the table hence having to double the direction.
        ; --------------------------------------------

        ; The calculates how much east or west or north or south
        ; the boat is going depending on its direction
        ; and how long it has been facing that way
        LDA     zp_boat_direction
        ASL     A
        TAX
        LDA     lookup_table_boat_direction_fns,X
        STA     zp_addr_fn_boat_direction_lsb
        INX
        LDA     lookup_table_boat_direction_fns,X
        STA     zp_addr_fn_boat_direction_msb

        ; Call the calculation function
        JMP     (zp_addr_fn_boat_direction_lsb)

;131A
.lookup_table_boat_direction_fns
        ; Function look up table?
        EQUB    LO(fn_boat_direction_N), HI(fn_boat_direction_N)
        EQUB    LO(fn_boat_direction_NNE), HI(fn_boat_direction_NNE)
        EQUB    LO(fn_boat_direction_NE), HI(fn_boat_direction_NE)
        EQUB    LO(fn_boat_direction_ENE), HI(fn_boat_direction_ENE)
        EQUB    LO(fn_boat_direction_E), HI(fn_boat_direction_E)
        EQUB    LO(fn_boat_direction_ESE), HI(fn_boat_direction_ESE)
        EQUB    LO(fn_boat_direction_SE), HI(fn_boat_direction_SE)
        EQUB    LO(fn_boat_direction_SSE), HI(fn_boat_direction_SSE)
        EQUB    LO(fn_boat_direction_S), HI(fn_boat_direction_S)
        EQUB    LO(fn_boat_direction_SSW), HI(fn_boat_direction_SSW)
        EQUB    LO(fn_boat_direction_SW), HI(fn_boat_direction_SW)
        EQUB    LO(fn_boat_direction_WSW), HI(fn_boat_direction_WSW)
        EQUB    LO(fn_boat_direction_W), HI(fn_boat_direction_W)
        EQUB    LO(fn_boat_direction_WNW), HI(fn_boat_direction_WNW)
        EQUB    LO(fn_boat_direction_NW), HI(fn_boat_direction_NW)
        EQUB    LO(fn_boat_direction_NNW), HI(fn_boat_direction_NNW)

        ; --------------------------------------------
        ; All these functions used to determine the amount
        ; in a particular direction the boat is moving
        ; --------------------------------------------

;133A
.fn_boat_direction_N
        ; Boat direction 0 - $133A
        JSR     fn_adjust_east_west_for_full_north_or_south
        JMP     fn_accelerate_north

        ; Boat direction 1 - $1340
.fn_boat_direction_NNE
        JSR     fn_accelerate_north
        JMP     fn_move_to_half_west

.fn_boat_direction_NE
        ; Boat direction 2 - $1346
        JSR     fn_accelerate_north
        JMP     fn_accelerate_west

.fn_boat_direction_ENE
        ; Boat direction 3 - $134C
        JSR     fn_move_to_half_north
        JMP     fn_accelerate_west

.fn_boat_direction_E
        ; Boat direction 4 - $1352
        JSR     fn_adjust_north_south_for_full_east_or_west
        JMP     fn_accelerate_west

.fn_boat_direction_ESE
        ; Boat direction 5 - $1358
        JSR     fn_accelerate_west
        JMP     fn_move_to_half_south
        
.fn_boat_direction_SE
        ; Boat direction 6 - $135E
        JSR     fn_accelerate_west
        JMP     fn_accelerate_south

.fn_boat_direction_SSE
        ; Boat direction 7 - $1364
        JSR     fn_move_to_half_west
        JMP     fn_accelerate_south

.fn_boat_direction_S
        ; Boat direction 8 - $136A
        JSR     fn_adjust_east_west_for_full_north_or_south
        JMP     fn_accelerate_south

.fn_boat_direction_SSW
        ; Boat direction 9 - $1370
        JSR     fn_move_to_half_east
        JMP     fn_accelerate_south

.fn_boat_direction_SW
        ; Boat direction 10 - $1376
        JSR     fn_accelerate_east
        JMP     fn_accelerate_south

.fn_boat_direction_WSW
        ; Boat direction 11 - $137C
        JSR     fn_accelerate_east
        JMP     fn_move_to_half_south

.fn_boat_direction_W
        ; Boat direction 12 - $1382
        JSR     fn_adjust_north_south_for_full_east_or_west
        JMP     fn_accelerate_east

.fn_boat_direction_WNW
        ; Boat direction 13 - $1388
        JSR     fn_accelerate_east
        JMP     fn_move_to_half_north

.fn_boat_direction_NW
        ; Boat direction 14 - $138E
        JSR     fn_accelerate_east
        JMP     fn_accelerate_north

.fn_boat_direction_NNW
        ; Boat direction 15 - $1394
        JSR     fn_move_to_half_east
        JMP     fn_accelerate_north
       
;139A
.fn_accelerate_south
        ; --------------------------------------------
        ; Accelerates South (full speed when 
        ; zp_boat_north_south_amount is 8)
        ; --------------------------------------------
        LDA     zp_boat_north_south_amount
        JSR     accelerate_south_or_east_by_2
        STA     zp_boat_north_south_amount
        RTS

;13A2
.fn_move_to_half_south
        ; --------------------------------------------
        ; Accelerate South but only to a maximum 
        ; of half speed (6)
        ; --------------------------------------------
        LDA     zp_boat_north_south_amount
        JSR     move_to_half_east_or_south
        STA     zp_boat_north_south_amount
        RTS

;13AA
.fn_accelerate_east
        ; --------------------------------------------
        ; Accelerates North (full speed when 
        ; zp_boat_north_south_amount is 0)
        ; --------------------------------------------
        LDA     zp_boat_east_west_amount
        JSR     accelerate_south_or_east_by_2
        STA     zp_boat_east_west_amount
        RTS

;13B2
.fn_move_to_half_east
        ; --------------------------------------------
        ; Accelerate east but only to a maximum
        ; of half speed (6)
        ; --------------------------------------------
        LDA     zp_boat_east_west_amount 
        JSR     move_to_half_east_or_south
        STA     zp_boat_east_west_amount 
        RTS

;13BA
.fn_accelerate_north
        ; --------------------------------------------
        ; Accelerates North (full speed when 
        ; zp_boat_north_south_amount is 0)
        ; --------------------------------------------
        LDA     zp_boat_north_south_amount
        JSR     accelerate_north_or_west_by_2
        STA     zp_boat_north_south_amount
        RTS

;13C2
.fn_move_to_half_north
        ; --------------------------------------------
        ; Accelerate North but only to a maximum
        ; of half speed (2)
        ; --------------------------------------------
        LDA     zp_boat_north_south_amount
        JSR     set_to_half_west_or_half_north
        STA     zp_boat_north_south_amount
        RTS

;13CA
.fn_accelerate_west
        ; --------------------------------------------
        ; Accelerate wast but only to a maximum
        ; of half speed (2)
        ; --------------------------------------------
        LDA     zp_boat_east_west_amount
        JSR     accelerate_north_or_west_by_2
        STA     zp_boat_east_west_amount
        RTS

;13D2
.fn_move_to_half_west
        ; --------------------------------------------
        ; Sets the east/west amount to 2 
        ; (half west)
        ; --------------------------------------------
        LDA     zp_boat_east_west_amount 
        JSR     set_to_half_west_or_half_north
        STA     zp_boat_east_west_amount 
        RTS

;13DA
.fn_adjust_east_west_for_full_north_or_south
        ; --------------------------------------------
        ; If the boat was previously moving left or right
        ; do nothing (4 means neither left or right)
        ; otherwise branch and adjust towards no left / right
        ; --------------------------------------------
        LDA     zp_boat_east_west_amount 
        CMP     #$04
        BNE     check_if_heading_east_or_west

        RTS

;13E1
.check_if_heading_east_or_west
        ; If A is less than 4
        ; If the boat was turning left
        BCC     fn_move_to_half_east

        ; If A is greater than or equal to 4
        ; Otheriwse if the Boat is turning right 
        BCS     fn_move_to_half_west    

;13E5
.fn_adjust_north_south_for_full_east_or_west
        ; --------------------------------------------
        ; If the boat was previously moving east or west
        ; do nothing (4 means neither east or west)
        ; otherwise branch and adjust towards east/west
        ; --------------------------------------------
        LDA     zp_boat_north_south_amount
        CMP     #$04
        BNE     check_if_heading_north_or_south

        RTS

;13EC
.check_if_heading_north_or_south
        ; Carry not set so it was moving South
        BCC     fn_move_to_half_south

        ; Carry not set so it was moving North
        BCS     fn_move_to_half_north

;13F0
.accelerate_south_or_east_by_2
        ; Changes the speed by +2 
        ; For up down, that 0-3 is Up, 4 neither, 5-8 Down
        ; For left right, 0-3 is Left, 4 neither, 5-8 right
        CLC
        ADC     #$02
        CMP     #$08
        BCS     reset_to_max_if_greater

        RTS

;13F8
.reset_to_max_if_greater
        ; If greater than the max of 8 reset to 8
        LDA     #$08
        RTS


;13FB
.move_to_half_east_or_south
        ; Turn right slightly by adding 1 
        ; and making sure the value isn't greater than 6
        CLC
        ADC     #$01
        CMP     #$06
        BCS     set_to_half_east_or_half_north

        RTS           

;1403
.set_to_half_east_or_half_north
        LDA     #$06
        RTS

;1406
.accelerate_north_or_west_by_2
        ; Changes the speed by -2 
        ; For up down, that 0-3 is Up, 4 neither, 5-8 Down
        ; For left right, 0-3 is Left, 4 neither, 5-8 right
        SEC
        SBC     #$02
        BMI     reset_to_zero_if_negative

        RTS

;140C
.reset_to_zero_if_negative
        ; If negative, rest to zero
        LDA     #$00
        RTS

;140F
.set_to_half_west_or_half_north
        ; Max North or West is 0, neutal is 4
        LDA     #$02
        RTS      

;1412
        ; Unused. BUG?!?! Never called and inaccessible
        LDA     #$02
        RTS        

;1415
.fn_check_if_moving_north_or_south

        ; --------------------------------------------
        ; The zp_boat_north_south_amount flag is set from 0 to 8
        ; 0 - moving fully up
        ; ...
        ; 4 - neither up nor down
        ; ...
        ; 8 - moving fully down
        ;
        ; If 8 it will move full speed down
        ; If 6 it will move down every other time through this loop
        ; If 3,4,5 do nothing
        ; If 2 it will move up every other time through this loop
        ; If 1 it will move full speed up
        ; --------------------------------------------

        ; Reset the up and down scrolling status flags
        LDA     #$00
        STA     zp_scroll_south_status
        STA     zp_scroll_north_status

        ; Check to see if the boat is facing down
        ; If it is then set the scroll down status
        ; Needs to have a value greater than or equal
        ; to 7.  
        LDA     zp_boat_north_south_amount
        CMP     #$07
        ; If less than 7 then branch
        BCC     check_partial_south_direction

        ; Set the scroll down status flag as the boat
        ; is facing down the screen
        LDA     #$FF
        STA     zp_scroll_south_status
        RTS

;1426
.check_partial_south_direction
        ; Check to see if the boat is facing partially down
        ; Needs to have a value greater than or equal
        ; to 6 otherwise it will branch  
        CMP     #$06
        ; If less than 6 then branch
        BCC     check_neither_north_nor_south

        ; If the boat isn't facing all the way down the screen
        ; only set scroll down status on every other execution
        ; of the loop - zp_north_or_south_on_this_loop_status will
        ; only be zero on every other loop
        INC     zp_north_or_south_on_this_loop_status
        LDA     zp_north_or_south_on_this_loop_status
        AND     #$01
        STA     zp_north_or_south_on_this_loop_status
        ; If not zero then return
        BNE     calc_north_south_boat_direction_of_motion_return

        ; Set the scroll down status flag as the boat
        ; is facing partly down the screen
        LDA     #$FF
        STA     zp_scroll_south_status        

;1438
.calc_north_south_boat_direction_of_motion_return
        RTS

;1439
.check_neither_north_nor_south
        ; Check to see if it's 3,4,5 (given previous checks)
        ; if so do nothing otherwise branch
        CMP     #$03
        ; If less than 3 then branch as boat is heading up
        BCC     check_partial_north_direction

        RTS

;143E
.check_partial_north_direction
        CMP     #$02
        ; If less than 2 then branch (full speed up)
        BCC     full_north_direction

        ; If the boat isn't facing all the way down the screen
        ; only set scroll down status on every other execution
        ; of the loop - zp_north_or_south_on_this_loop_status will
        ; only be zero on every other loop
        INC     zp_north_or_south_on_this_loop_status
        LDA     zp_north_or_south_on_this_loop_status
        AND     #$01
        STA     zp_north_or_south_on_this_loop_status
        BNE     calc_north_south_boat_direction_of_motion_return

;144C 
.full_north_direction
        ; Boat is scrolling up so set the status flag
        LDA     #$FF
        STA     zp_scroll_north_status
        RTS        

;1451
.fn_check_if_moving_east_or_west
        ; --------------------------------------------
        ; The zp_boat_east_west_amount flag is set from 0 to 8
        ; 0 - moving fully left
        ; ...
        ; 4 - neither left nor right
        ; ...
        ; 8 - moving fully right
        ;
        ; If 8 it will move full speed right
        ; If 6 it will move right every other time through this loop
        ; If 3,4,5 do nothing
        ; If 2 it will move left every other time through this loop
        ; If 1 it will move full speed left
        ; --------------------------------------------

        ; Reset the left and right scrolling status flags
        LDA     #$00
        STA     zp_scroll_east_status
        STA     zp_scroll_west_status

        ; Check to see if the boat is facing right
        ; If it is then set the scroll rgith status
        ; Needs to have a value greater than or equal
        ; to 7.  
        LDA     zp_boat_east_west_amount
        CMP     #$07
        ; If less than 7 then branch
        BCC     check_partial_east_direction

        ; Set the scroll right status flag as the boat
        ; is facing right
        LDA     #$FF
        STA     zp_scroll_east_status
        RTS

;1462
.check_partial_east_direction
        ; Check to see if the boat is facing partially right
        ; Needs to have a value greater than or equal
        ; to 6 otherwise it will branch  
        CMP     #$06
        BCC     check_neither_east_nor_west

        ; If the boat isn't facing all the way left
        ; only set scroll status on every other execution
        ; of the loop - zp_east_or_west_on_this_loop_status will
        ; only be zero on every other loop
        INC     zp_east_or_west_on_this_loop_status
        LDA     zp_east_or_west_on_this_loop_status
        AND     #$01
        STA     zp_east_or_west_on_this_loop_status
        ; If not zero then return
        BNE     calc_east_west_boat_direction_of_motion_return

        ; Set the scroll right status flag as the boat
        ; is facing partly right
        LDA     #$FF
        STA     zp_scroll_east_status
;1474
.calc_east_west_boat_direction_of_motion_return
        RTS

;1475
.check_neither_east_nor_west
        ; Check to see if it's 3,4,5 (given previous checks)
        ; if so do nothing otherwise branch
        CMP     #$03
        ; If less than 3 then branch as boat is heading left
        BCC     check_partial_west_direction

        RTS

;147A
.check_partial_west_direction
        CMP     #$02
        ; If less than 2 then branch (full speed up)
        BCC     full_left_direction

        ; If the boat isn't facing all the way left 
        ; only set scroll left status on every other execution
        ; of the loop - zp_north_or_south_on_this_loop_status will
        ; only be zero on every other loop
        INC     zp_east_or_west_on_this_loop_status
        LDA     zp_east_or_west_on_this_loop_status
        AND     #$01
        STA     zp_east_or_west_on_this_loop_status
        BNE     calc_east_west_boat_direction_of_motion_return

;1488
.full_left_direction
        ; Boat is scrolling left so set the status flag
        LDA     #$FF
        STA     zp_scroll_west_status
        RTS

;148D
.fn_colour_cycle_screen
        ; --------------------------------------------
        ; When the boat has run aground, colour cycle
        ; the palette
        ; --------------------------------------------

        ; Reset the colour cycle counter to 4 (this routine
        ; is only called when it counts down to 0)
        LDA     #$04
        STA     zp_aground_colour_cycle_counter

        ; OSWORD &07
        ; Play boat aground sound one
        ; Parameters are stored at $14E7
        LDX     #sound_boat_aground_first MOD 256
        LDY     #sound_boat_aground_first DIV 256
        LDA     #$07
        JSR     OSWORD

        ; OSWORD &07
        ; Play sound two
        ; Parameters are stored at $14EF
        LDX     #sound_boat_aground_second MOD 256
        LDY     #sound_boat_aground_second DIV 256
        LDA     #$07
        JSR     OSWORD

        ; Immediately slow the boat down to the slowest
        ; speed $0A/10 - 00 is fast
        LDA     #$0A
        STA     zp_boat_speed

        ; Set palette logical colour to 3
        ; So it flashes out of turn by setting this first
        LDA     #$03
        STA     palette_logical_colour

        ; Calculate the bottom row starting memory address
        ; as the time/score/lap counter will be drawn there
        ;
        ; Address is written to write_to_screen_address+1/+2
        JSR     fn_calc_bottom_row_start_address

        ; Redraw the time/score/laps to the screen
        JSR     fn_copy_time_score_lap_to_screen

        ; OSBYTE &13 
        ; Wait for vertical sync (start of the next)
        ; frame of display.
        LDA     #$13
        JSR     OSBYTE

        ; Colour palette cycle index
        LDX     #$00

;14B9
.loop_colour_cycle_screen
        ; Cycle through the physical colours
        ; to make the screen flash when the boat is
        ; on land
        LDA     palette_colour_cycle,X
        STA     palette_physical_colour

        ; Preserve X, used as the physical palette
        ; index
        TXA
        PHA

        ; OSBYTE &13 
        ; Wait for vertical sync (start of the next)
        ; frame of display.  Wait twice to only update
        ; 25 times a second instead of 50.
        LDA     #$13
        JSR     OSBYTE
        JSR     OSBYTE

        LDA     #$FF
        STA     zp_score_already_updated_status

        ; Calculate the bottom row starting memory address
        ; as the time/score/lap counter will be drawn there
        ;
        ; Address is written to write_to_screen_address+1/+2
        JSR     fn_calc_bottom_row_start_address

        ; Redraw the time/score/lap counters in memory
        ; location calc'd above
        JSR     fn_copy_time_score_lap_to_screen

        ; OSWORD &0C / VDU 19
        ; Change the logical colour palette
        ; using the in memory parameter block
        LDX     #palette_logical_colour MOD 256
        LDY     #palette_logical_colour DIV 256
        LDA     #$0C
        JSR     OSWORD

        ; Restore the physical colour index
        PLA
        TAX

        ; Check to see if we have flashed through
        ; all the physical colours in the sequence
        INX
        CPX     #$08
        BNE     loop_colour_cycle_screen

        ; Default back to the standard game colours
        JSR     fn_set_game_colours

        RTS

.sound_boat_aground_first
        ; Boat has run aground sound
        ; SOUND 10, -15, 7, 20
        ; 10 - flush buffer, play channel 0 sound
        EQUB    $10,$00,$F1,$FF,$07,$00,$14,$00

.sound_boat_aground_second
        ; Boat has run aground sound 2
        ; SOUND 10, 3, 10, 20
        ; 3  means it uses Envelope 3 
        ; 11 - flush buffer, play channel 1 sound
        EQUB    $11,$00,$03,$00,$0A,$00,$14,$00

.palette_colour_cycle
        ; When a boat runs aground, used to change
        ; logical colour 3 through cyan, magenta, red
        ; white, black, cyan, magenta, white
        EQUB    $06,$05,$01,$07,$00,$06,$05,$07

;14FF
.fn_init_graphics_buffers
        ; --------------------------------------------
        ; Initialise the graphics buffer to $00
        ; from 0A00 to 0A9F and
        ; from 0AA0 to 0B3F
        ; --------------------------------------------
        LDA     #$00
        LDY     #$9F
.clear_graphics_buffer_loop
        STA     $0A00,Y
        STA     $0AA0,Y
        DEY
        CPY     #$FF
        BNE     clear_graphics_buffer_loop

        ; TIME and LAP icons are 32 bytes each
        LDY     #$1F
.buffer_time_and_lap_loop
        ; Copy the TIME icon to the graphics buffer
        LDA     $0568,Y
        STA     $0A08,Y

        ; Copy the LAP icon to the graphics buffer
        LDA     $0588,Y
        STA     $0AF8,Y
        DEY
        BPL     buffer_time_and_lap_loop

        ; 39 Bytes
        LDY     #$27
.buffer_score_loop
        ; Copy the SCORE icon to the graphics buffer
        LDA     $0540,Y
        STA     $0A68,Y
        DEY
        BPL     buffer_score_loop

        ; 7 bytes
        LDY     #$07
.buffer_blanks_loop
        ; Just blank areas on load
        LDA     $05A8,Y
        ; Put blank to the right of the time remaining
        STA     $0A48,Y

        ; Put a blank to the right of the score
        STA     $0AE0,Y

        ; Put a blank to the right of the lap counter
        STA     $0B38,Y

        ; Check we have blanked all the 8 bytes in each location
        DEY
        ; Loop back if not
        BPL     buffer_blanks_loop

        ; Draw the score on screen
        JSR     fn_draw_current_score

        ; Draw the time on screen
        JSR     fn_draw_time_counter

        ; Draw the lap counter on screen and return
        JMP     fn_draw_lap_counter

.fn_calc_digits_for_display
        ; --------------------------------------------
        ; This function rotates the units, then the 10s
        ; then the 100s etc into the accumulator until
        ; all the digits have been found individually
        ; and pushed onto the stack. 
        ;
        ; On entry A states how many digits we want to
        ; display and if we don't derive enough then
        ; the routine prefixes with enough zeros so
        ; the main body will pull out say 2 5 0 
        ; but if 5 digits were required then 0 0 2 5 0
        ; will be put on the stack
        ; 
        ; If we're in mode 7, they are then written directly
        ; to the screen
        ;
        ; Otherwise the number graphics in order are
        ; placed in the buffer specified in X and Y 
        ; --------------------------------------------

        ; Preserve the status register
        PHP

        ; Disable maskable interrupts
        SEI

        ; Cache where we need to store the
        ; number graphics in sequence to represent
        ; the score / timer / lap
        STX     zp_graphics_numbers_target_storage_lsb
        STY     zp_graphics_numbers_target_storage_msb
        STA     zp_display_digits

        ; X is used to see if we have generated
        ; all the individual digits and put them on
        ; the stack
        LDX     #$00
.get_next_digit
        ; Perform the calculation 16 times
        LDY     #$10

        ; Reset the accumulator where we store the digit
        ; Has the affect of subtracting the digit we 
        ; rolled out previously
        LDA     #$00
.rotate_bits
        ; Low numbers 
        ; Multiply the score by 2 using A to take the overflow
        ;         A               0E             0D
        ; C <- 7654321 <- C <- 7654321 <- C <- 7654321 <- 0
        ;
        ; If A goes above 0A then that is rotated into bit 1 of 0D
        ASL     zp_number_for_digits_lsb
        ROL     zp_number_for_digits_msb
        ROL     A

        CMP     #$0A
        ; Check to see if we have overflowed 0A (10)
        ; We put the overlow back into bit 0 of 0D
        BCC     skip_carry_handler

        ; A >= 10
        ; We don't need numbers greater than 9 as a digit
        ; Just interested in 0-9 but we keep the carry 
        ; and put it back into bit zero
        SBC     #$0A

        ; Add the overflow (aka carry) back into the first bit
        ; No idea....
        INC     zp_number_for_digits_lsb

.skip_carry_handler
        ; Go around the inner loop 16 times
        DEY
        BNE     rotate_bits

        ; We have processed the current digit
        ; Add it to the stack and increase the
        ; processed digits index (X)
        PHA
        INX

        ; Are there still more non-zero digits 
        ; to get
        LDA     zp_number_for_digits_lsb
        ORA     zp_number_for_digits_msb
        BNE     get_next_digit

.test_right_num_digits_generated
        ; Check to see if we have generated
        ; enough individual score digits
        ; on the stack
        CPX     zp_display_digits
        ; If we haven't so pad leading edge
        ; with a zero (and test again)
        BCC     add_leading_zero_to_score

        ; If we have generated the right
        ; number of digits then print the
        ; score
        BEQ     print_score

        ; Too many digits were generated
        ; so remove one, decrement the index
        ; and test we have everything again
        PLA
        DEX
        JMP     test_right_num_digits_generated

.add_leading_zero_to_score
        ; Add a leading zero to the score
        ; Each digit is added to the stack
        ; to be pulled out individually and 
        ; printed
        LDA     #$00
        PHA
        INX
        JMP     test_right_num_digits_generated

.print_score
        ; Check if the current screen mode
        ; is MODE 7 - if so then the high 
        ; score table is being displayed
        ; so branch to print out the current 
        ; score digits otherwise do something 
        ; else...
        LDA     VDU_CURRENT_SCREEN_MODE
        CMP     #$07
        BEQ     fn_print_high_score_numbers

.calc_number_graphics_location
        ; Calculate the location of the first
        ; byte of the required number graphic
        ; Number Graphics are 16 bytes each
        ; 8 bytes per column x 2 columns
        ; 16 pixels high x 8 pixels wide 
        ; (2 bits per pixel in mode 5)
        
        ; Get the current digit from the stack
        PLA

        ; Multiply it by 16 to get the offset
        ; to the next number as each graphic
        ; is 16 bytes
        ; e.g. 0=0; 1=16; 2=32 etc
        ASL     A
        ASL     A
        ASL     A
        ASL     A
        CLC

        ; Add the LSB for the where the number
        ; graphics are held in memory
        ADC     #$40
        STA     zp_graphics_numbers_lsb
        LDA     #$00

        ; Add the MSB for the where the number
        ; graphics are held in memory ($0740)
        ADC     #$07
        STA     zp_graphics_numbers_msb

        ; Each number graphic is 16 bytes
        LDY     #$0F

.copy_graphic_number
        ; Copy the number graphics in the right
        ; sequence from the working area into the 
        ; requested target memory area
        LDA     (zp_graphics_numbers_lsb),Y
        STA     (zp_graphics_numbers_target_storage_lsb),Y
        DEY
        BPL     copy_graphic_number

        ; Increment the location of where we need to
        ; save the next one by 16. If the LSB 
        ; carries add one to the MSB
        LDA     zp_graphics_numbers_target_storage_lsb
        CLC
        ADC     #$10
        STA     zp_graphics_numbers_target_storage_lsb
        BCC     no_target_carry

        INC     zp_graphics_numbers_target_storage_msb

.no_target_carry
        ; Have we found and copied all the 
        ; number graphics that we need
        DEX
        BNE     calc_number_graphics_location

        PLP
        RTS

; 15AC
.fn_print_high_score_numbers
        ; --------------------------------------------
        ; Call OSWRCH to write the score digits
        ; stored on the stack to the screen
        ; --------------------------------------------

        ; The Stack contains the four score 
        ; numbers previously calculated
        ; Values are pulled off highest to 
        ; lowest e.g. 0350 in left to right
        ; order

        ; Get the next score digit 
        PLA
        CLC
        ; Add $30 / 48 to find the ASCII printable
        ; number (numbers are in range $30 to $39
        ; in the 0 - 9 order)
        ADC     #$30
        ; Send it to the screen 
        ; Print it on the high score table
        JSR     OSWRCH

        ; If we haven't printed all the 4 score characters
        ; then loop again
        DEX
        BNE     fn_print_high_score_numbers

        PLP
        RTS

;15B8
.fn_draw_current_score

        ; Preserve the processor status onto the stack
        PHP

        ; Stop maskable interrupts
        SEI

        ; Transfer the score into the general
        ; memory for display
        LDA     zp_score_lsb
        STA     zp_number_for_digits_lsb
        LDA     zp_score_msb
        STA     zp_number_for_digits_msb

        ; Score should be 4 digits wide so set that
        LDA     #$04

        ; Set X and Y to point where the individual 
        ; digit graphics should be stored.
        LDX     #$90
        LDY     #$0A

        ; Generate the score digits and store at $0A90 onwards
        JSR     fn_calc_digits_for_display

        LDA     #$40
        STA     zp_graphics_numbers_lsb
        LDA     #$07
        STA     zp_graphics_numbers_msb

        ; Add a trailing zero to the buffer above
        ; the fn_calc_digits_for_display will have 
        ; incremented the address in 
        ; zp_graphics_numbers_target_storage_lsb/msb
        ; so write the 16 bytes of the zero there
        LDY     #$0F
.L15D5
        LDA     (zp_graphics_numbers_lsb),Y
        STA     (zp_graphics_numbers_target_storage_lsb),Y
        DEY
        BPL     L15D5

        ; Pull the processor status onto the stack
        PLP
        RTS

;15DE
.fn_draw_lap_counter
        ; Gets the lap counter which is zero based
        LDA     zp_current_lap
        CLC

        ; Makes it one based for display
        ADC     #$01

        ; Store the Lap LSB
        STA     zp_number_for_digits_lsb

        ; Set the lap MSB to zero
        LDA     #$00
        STA     zp_number_for_digits_msb

        ; Buffer the lap digits at $0B18
        LDX     #$18
        LDY     #$0B

        ; Lap counter is only 2 digits wide so set that
        ; so only two digits are drawn
        LDA     #$02
        JMP     fn_calc_digits_for_display

;15F2
.fn_draw_time_counter
        ; --------------------------------------------
        ; Update the time counter buffer with the 
        ; remaining time
        ; --------------------------------------------
        LDA     zp_time_remaining_secs
        STA     zp_number_for_digits_lsb

        ; Reset the number to zero
        LDA     #$00
        STA     zp_number_for_digits_msb
        
        ; Call the function and say that we
        ; want 2 digits for the result
        ; and store the number graphics at
        ; $0A28
        LDX     #$28
        LDY     #$0A

        ; Lap counter is only 2 digits wide so set that
        ; so only two digits are drawn
        LDA     #$02
        JMP     fn_calc_digits_for_display

;1603
.fn_set_timer_64cs
        ; --------------------------------------------
        ; EVNTV Interval Timer handler 
        ; 
        ; Called every 64 centi-seconds
        ; 
        ; Accumulator is always set to 5 - anything
        ; else will stop the clock counting down the 
        ; first time around
        ;
        ; Also called independently by code... to
        ; start in the first instance and set up
        ; the interval timer
        ; --------------------------------------------

        ; Preserve the status registers on the stack
        PHP

        ; At the start of the game or new level, 
        ; accumulator is set to 5 so will set up the 
        ; interval timer to count from 64 milliseconds

        ; An interrupt wil be generated when it crosses
        ; zero and this will be called again when that
        ; happens to reset the timer

        ; Check to see if the event type is 
        ; "interval timer crossing zero" ($05)

.timer_poke        
        CMP     #$05
        BNE     set_timer_64ms_end

        ; Preserve Accumulator, X and Y on the stack
        ; so we don't break whatever was interrupted
        PHA
        TXA
        PHA
        TYA
        PHA

        ; Reset the interval timer to another 64 centi-seconds
        ; using the 5 byte value at the location 
        ; specified here ($1626 / var_int_timer_value)
        ; X - low byte, Y - high byte
        LDX     #var_int_timer_value MOD 256
        LDY     #var_int_timer_value DIV 256
        LDA     #$04
        JSR     OSWORD

        ; If there is no more remaining time
        ; do nothing and  jump ahead
        LDA     zp_time_remaining_secs
        BEQ     skip_loop

        ; Decrement remaining time by one time unit (0.64 seconds)
        DEC     zp_time_remaining_secs

        ; Redraw the time counter on the screen
        JSR     fn_draw_time_counter

.skip_loop
        ; Restore Accumulator, X and Y on the stack
        PLA
        TAY
        PLA
        TAX
        PLA

.set_timer_64ms_end
        ; Restore the status registers
        PLP
        RTS                 

; 1626
.var_int_timer_value
        ; Countdown value for interval timer
        ; $BF / 64 centiseconds (just over half a second)
        ; ($FF-$BF = $40 / 64 cs)
        EQUB    $BF,$FF,$FF,$FF,$FF

.sound_times_up
        ; SOUND 1, 1, 110, 30
        ; Channel 1 (LSB MSB)
        EQUB    $01,$00
        ; Amplitude / loudness (LSB MSB)
        ; 1 means it uses Envelope 1 otherwise it'd be negative
        EQUB    $01,$00
        ; Pitch (LSB MSB) 
        EQUB    $6E,$00
        ; Duration (LSB MSB)
        EQUB    $1E,$00

; 1633
.fn_enable_interval_timer
        ; --------------------------------------------
        ; Enable interval timer crossing 0 event
        ; timer increments every centisecond
        ; --------------------------------------------
        LDA     #$0E
        LDX     #$05
        LDY     #$00
        JMP     OSBYTE

.disable_interval_timer
        ; --------------------------------------------
        ; Disable interval timer crossing 0 event
        ; timer increments every centisecond
        ; --------------------------------------------
        LDA     #$0D
        LDX     #$05
        LDY     #$00
        JMP     OSBYTE

.fn_check_checkpoint_or_lap_complete
        ; --------------------------------------------
        ; Checks to see if the mid-map checkpoint or
        ; the lap position has been reached
        ; --------------------------------------------

        ; Check to see if the checkpoint mid-map
        ; has been reached - if not test for it
        ; Status will be $FF if it's been reached
        BIT     zp_checkpoint_status
        BPL     check_if_at_checkpoint 

        ; Boat has completed a lap if the checkpoint
        ; status is set AND the returns to the start.
        ; The start is tested for the (x,y) coordinates 
        ; if the following is true:
        ;        $18 =< x < $25
        ;               y = $0C

        ; Check if the boat's y position is at $0C
        ; if not then return
        LDA     zp_boat_ypos
        CMP     #$0C
        BNE     end_fn_check_checkpoint_or_lap_complete

        ; Check if the boat's x position is greater
        ; than or equal to $18, it not then return
        LDA     zp_boat_xpos
        CMP     #$18
        BCC     end_fn_check_checkpoint_or_lap_complete

        ; Check if the boat's x position is less
        ; than to $25, it not then return
        CMP     #$25
        BCS     end_fn_check_checkpoint_or_lap_complete

        ; Lap completion now confirmed, reset
        ; the checkpoint status for the next lap
        LDA     #$00
        STA     zp_checkpoint_status


        STA     zp_score_max_lap_limit
        STA     zp_score_update_rate_limiter

        ; Stop any maskable interrupts and
        ; Add the time to the score plus display it
        SEI
        JSR     fn_add_time_to_score_and_display
        CLI

        ; Load the additional hazards for this lap in this
        ; stage - they get progressively harder per stage lap
        ; There are 13 levels of difficulty per stage 
        ; where additional objects are added to the map
        ; Each set of hazards is additive e.g. first the ducks are
        ; added, then on the next lap another type of hazard
        LDX     zp_laps_for_current_stage
        JSR     fn_get_hazard_for_index_and_apply_or_reset

        ; Increase the total laps and
        ; laps for the current stage
        INC     zp_current_lap
        INC     zp_laps_for_current_stage

        ; Check to see if we've reached the 13th lap
        ; if so we've completed the stage
        LDA     zp_laps_for_current_stage
        CMP     #$0C
        BNE     skip_stage_increment

        ; Reset the stage number of laps
        LDA     #$00
        STA     zp_laps_for_current_stage

        ; Set the stage completed status
        LDA     #$FF
        STA     zp_stage_completed_status

        ; Move to the next stage
        INC     zp_current_stage

.skip_stage_increment
        ; Get the new lap time for the current stage
        ; (they always reduce on new stages so it's harder)
        ; but the lap time stays constant for all laps
        ; in a stage
        LDX     zp_current_stage
        LDA     stage_lap_times,X
        STA     zp_time_remaining_secs
        
        ; Set up the timer
        ; Need to have the accumulator set to 05
        ; or it'll ignore setup of the timer
        LDA     #$05
        JSR     fn_set_timer_64cs

        ; Redraw the lap counter with the new
        ; reduced lap time
        JSR     fn_draw_lap_counter

        ; Calculate the bottom row starting memory address
        ; as the time/score/lap counter will be drawn there
        ;
        ; Address is written to write_to_screen_address+1/+2
        JSR     fn_calc_bottom_row_start_address

        ; Wait 20 ms 
        JSR     fn_wait_20_ms

        ; Copy the updated time/score/laps to the screen
        JSR     fn_copy_time_score_lap_to_screen

.end_fn_check_checkpoint_or_lap_complete
        RTS

;1698
.check_if_at_checkpoint 
        ; Boat is at the checkpoint if for the boat's
        ; (x,y) coordinates the following is true:
        ;        $5E =< x < $6E
        ;               y = $0E

        ; Check if the boat's y position is at $0E
        ; if not then return
        LDA     zp_boat_ypos
        CMP     #$0E
        BNE     end_fn_check_checkpoint_or_lap_complete

        ; Check if the boat's x position is greater
        ; than or equal to $5E, it not then return
        LDA     zp_boat_xpos
        CMP     #$5E
        BCC     end_fn_check_checkpoint_or_lap_complete

        ; Check if the boat's x position is less
        ; than to $6E, it not then return
        CMP     #$6E
        BCS     end_fn_check_checkpoint_or_lap_complete

        ; Checkpoint reached - set the status flag
        LDA     #$FF
        STA     zp_checkpoint_status
        RTS        

;16AD
.stage_lap_times
        ; Timings per lap for each stage - each 
        ; stage reduces the lap times but the lap
        ; time stays constant for all laps in a stage
        ; (until it becomes impossible)
        ;
        ; Stage Lap times are decremented before the game begins by 1
        ; so the times are:
        ; -> 70, 60, 51, 46, 41, 38, 36, 33, 31, 28, 26, 23, 21, 0
        EQUB    $47,$3D,$33,$2E,$29,$26,$24,$21
        EQUB    $1F,$1C,$1A,$17,$15,$01

;16BB
.fn_calc_bottom_row_start_address
        ; --------------------------------------------
        ; Calculates the starting memory address for writing the
        ; time/score/lap counters to the screen - this is 
        ; one screen row behind the screen start address
        ; when wrapped back around.
        ; --------------------------------------------
        ;
        ; So if the screen start address (top left) is $5800 then
        ; the previous row (bottom left of the screen is calculated
        ; by subtracting $140 (28 characters * 8 bytes for a row)
        ; and wrapping it around to be between $5800 - $7FFF by
        ; adding $2800
        ;
        ; ($5800 - $140) + $2800 = $7EC0 
        ; 
        ; So start of previous row (bottom left of screen) is $7EC0
        ;
        ; Similarly if it's scrolled and the start is e.g. $6800 then
        ; no wrap around is required as the bottom left row address
        ; will be within screen memory
        ; 
        ; ($6800 - $140)  = $66C0
        ; 
        ; Subtract $140 / 320 from the screen start
        LDA     zp_screen_start_lsb
        SEC
        SBC     #$40
        STA     write_to_screen_address + 1

        LDA     zp_screen_start_msb
        SBC     #$01
        ; Wrap the address round to still be in screen memory
        ; if it's lower than the screen start address
        JSR     fn_check_screen_start_address
        STA     write_to_screen_address + 2
        RTS

;16CE
.fn_check_sound_keys
        ; --------------------------------------------
        ; Check to see if the S or Q keys have been
        ; pressed and process them
        ; --------------------------------------------
        ; Check to see if the S key is pressed to turn on sound
        LDX     #$AE
        JSR     fn_read_key

        ; If it hasn't been pressed then do nothing
        CPX     #$00
        BEQ     check_q_key        

        ; Turn the sound on and return (JMP will force the return)
        LDA     #$D2
        LDX     #$00
        LDY     #$00
        JMP     OSBYTE

.check_q_key
        ; Check to see if the Q key is pressed to turn on sound
        LDX     #$EF
        JSR     fn_read_key

        ; If it hasn't been pressed then do nothing
        CPX     #$00
        BEQ     check_sound_keys_end

        ; Turn the sound off and return (JMP will force the return)
        LDA     #$D2
        LDX     #$01
        LDY     #$00
        JSR     OSBYTE

.check_sound_keys_end
        ; return to calling code
        RTS

.fn_check_freeze_continue_keys
        ; --------------------------------------------
        ; Check to see if the F or C keys have been
        ; pressed and process them
        ; --------------------------------------------
        ; Check to see if the F key has been pressed
        LDX     #$BC
        JSR     fn_read_key

        ; If it hasn't been pressed then do nothing
        CPX     #$00
        BEQ     check_freeze_keys_end

        ; Disable the interval timer
        JSR     disable_interval_timer

        ; Clear the sound channels 0 to 3
        LDA     #$15
        LDX     #$04
.clear_sound_buffer_loop
        JSR     OSBYTE

        ; move to next sound channel and clear it
        INX
        CPX     #$08
        BNE     clear_sound_buffer_loop

.check_c_key
        ; Check to see if the C key has been pressed
        LDX     #$AD
        JSR     fn_read_key

        ; If it hasn't been pressed then loop until it has
        CPX     #$00
        BEQ     check_c_key

        ; Re-enable interval timer crossing 0 event 
        ; Interval timer increments every centisecond
        JSR     fn_enable_interval_timer

        ; Add a time unit back back (guess it's being kind) - 0.64 seconds
        INC     zp_time_remaining_secs
        ; If the accumulator is set to anything other than
        ; 5 the time will NOT decrement.  Testing artefact
        ; and/or cheat poke
        LDA     #$05
        ; Start the on screen timer coutdown
        JSR     fn_set_timer_64cs

.check_freeze_keys_end
        RTS

;171F
.fn_add_time_to_score_and_display
        ; --------------------------------------------
        ; Adds the remaining time to the score
        ; --------------------------------------------
        ;
        ; Score is stored divided by 10
        ; so if you have 100 it's stored 
        ; as 10.  Units are always zero
        ; when displayed

        ; Get the score, add the remaing
        ; seconds to the score and
        ; update the score on screen

        ; Score is stored across two bytes
        ; so if e go above 255 we have to
        ; add the carry to the most significant
        ; byte
        LDA     zp_score_lsb
        CLC
        ADC     zp_time_remaining_secs
        STA     zp_score_lsb
        LDA     zp_score_msb
        ADC     #$00
        STA     zp_score_msb
        JSR     fn_draw_current_score

        LDX     #$00

.completed_lap_next_sound
        LDA     pitch_table_completed_lap,X
        STA     sound_completed_lap_pitch
        LDA     duration_table_completed_lap,X
        STA     sound_completed_lap_duration

        ; Preserve the X index value
        TXA
        PHA

        ; OSWORD &07
        ; Play completed lap sound
        ; Parameters are stored at $175A
        ; All sounds use Envelope 2 (2nd parameter)
        ; SOUND 2, 2, 193, 2
        ; SOUND 2, 2, 189, 2
        ; SOUND 2, 2, 193, 4
        ; SOUND 2, 2, 145, 4
        ; SOUND 2, 2, 145, 3
        LDA     #$07
        LDX     #LO(sound_completed_lap)
        LDY     #HI(sound_completed_lap)
        JSR     OSWORD

        ; Restore the X index value
        PLA
        TAX

        ; Get the next sound if we haven't played
        ; 5 notes
        INX
        CPX     #$05
        BNE     completed_lap_next_sound

        RTS        

.pitch_table_completed_lap
        EQUB    $C1,$BD,$C1,$91,$91

.duration_table_completed_lap
        EQUB    $02,$02,$04,$04,$03

.sound_completed_lap
        ; Completed lap sound
        ; d and p are changed programmatically
        ; SOUND 2, 2, d, p
        ; second 2 means it uses envelope 2
        EQUB    $02,$00
        EQUB    $02,$00

.sound_completed_lap_pitch
        ; Pitch (LSB MSB) 
        EQUB    $00,$00

.sound_completed_lap_duration
        ; Duration (LSB MSB)
        EQUB    $00,$00

;1762
.fn_play_boat_sounds
        ; --------------------------------------------
        ; Play the boat "put-put" sound - second
        ; sound duration is influenced by boat speed
        ; --------------------------------------------

        ; OSWORD &07
        ; Play a sound - first boat 'put'
        ; Parameters are stored at $177C
        ; Sound 10, 0, 246, 245
        ; Sounds 10:
        ;   1 - Flush the channel and play this sound immediately
        ;   0 - Play on channel 0
        LDX     #LO(sound_boat_move_first)
        LDY     #HI(sound_boat_move_first)
        LDA     #$07
        JSR     OSWORD
        
        ; OSWORD &07
        ; Play a sound - second boat 'put'
        ; Duration depends on speed - duration is looked up 
        ; in a table
        ; Parameters are stored at $1784
        ; Sound 10, 0, 246, 245
        ; Sounds 10:
        ;   1 - Flush the channel and play this sound immediately
        ;   0 - Play on channel 0
        LDX     zp_boat_speed
        LDA     duration_lookup_sound_table,X
        STA     sound_boat_move_second_pitch
        LDX     #LO(sound_boat_move_second)
        LDY     #HI(sound_boat_move_second)
        LDA     #$07
        JMP     OSWORD

; 177C
.sound_boat_move_first
        ; First boat moving "put"
        ; SOUND 2, 2, d, p
        ; d and p are changed programmatically
        EQUB    $10,$00
        EQUB    $F6,$FF

.sound_boat_move_first_pitch
        ; Pitch (LSB MSB) 
        EQUB    $03,$00

.sound_boat_move_first_duration
        ; Duration (LSB MSB)
        EQUB    $E8,$03

; 1784
.sound_boat_move_second
        ; Second boat moving "put"
        ; d and p are changed programmatically
        ; SOUND 2, 2, d, p
        EQUB    $11,$00
        EQUB    $03,$00
;1788
.sound_boat_move_second_pitch
        ; Pitch (LSB MSB)
        ; Controlled programmitically based
        ; on boat speed
        EQUB    $00,$00

.sound_boat_move_second_duration
        ; Duration (LSB MSB)
        EQUB    $0A,$00  

; 178C
.duration_lookup_sound_table
        ; As the boat goes faster, reduce
        ; the duration of the second sound
        ; From $6E (110) to $19 (25)
        EQUB    $6E,$6E,$69,$5F,$55,$4B
        EQUB    $41,$37,$2D,$23,$19

; L1797
.fn_did_score_make_high_score_table
        ; --------------------------------------------
        ; Check to see if the player score made it 
        ; into the high score table
        ; --------------------------------------------
        ; Highest 8 scores are stored in memory

        ; Load the scores starting at the lowest first
        ; which is held highest in memory so we count down
        ; from 7        
        LDX     #$07
.check_next_high_score
        ; Subtract the player's score from 
        ; the current high score entry to see if it's
        ; greater than or equal to it
        SEC
        LDA     zp_score_lsb
        SBC     high_score_lsb,X
        LDA     zp_score_msb
        SBC     high_score_msb,X

        ; Current score in high score table is higher
        ; than the player's score - so we have 
        ; found the position
        BCC     high_score_position_found

        ; Player score is either higher than current
        ; entry or the same (as we did the check above
        ; on both bytes to see if the current high score
        ; was overall higher)
        LDA     zp_score_lsb
        CMP     high_score_lsb,X
        
        ; Player score LSB is less than high score table
        ; so branch and use previous high score entry
        BNE     player_score_greater_than_current_score

        ; Check to see if the player sore MSB is the same
        ; If so the player score is the same as the current
        ; high score so they DO get to replace it,
        ; otherwise use previous entry 
        LDA     zp_score_msb
        CMP     high_score_msb,X
        BEQ     high_score_position_found

;17B4
.player_score_greater_than_current_score
        ; Check the next (higher) high score in the table
        ; and see if the player's score is greater than or 
        ; equal to it
        DEX
        ; If it goes to $FF/-1 we've checked all the high scores
        CPX     #$FF
        BNE     check_next_high_score

.high_score_position_found
        ; Check to see if the score was below
        ; the lowest score on the high score table
        ; If it is just show the high score table
        ; Otherwise branch ahead to move the scores
        ; around on the table
        INX
        CPX     #$08
        BNE     player_score_made_table

        ; Score was less than lowest score so just
        ; show the table
        JSR     fn_display_high_score_table
        JSR     fn_show_player_score_below_high_scores
        JMP     fn_display_press_space 

.player_score_made_table
        ; Store the high score position
        STX     zp_high_score_position

        ; Load the highest score in the high score table
        ; Note - scores are stored low to high but
        ; high score in memory is high to low... 
        ; And store on the stack
        LDA     high_score_name_lsb + 7
        PHA
        LDA     high_score_names - 1
        PHA

        ; If the player score goes into the bottom of the table
        ; we don't need to move any scores down
        CPX     #$07
        BEQ     high_scores_demoted

        LDX     #$06
.demote_high_scores
        ; Move all the scores in the positions 
        ; at and below the player's score position 
        ; down one place
        TXA
        TAY
        INY
        ; Move the LSBs of the high scores down
        LDA     high_score_lsb,X
        STA     high_score_lsb,Y
        ; Move the MSBs of the high scores down
        LDA     high_score_msb,X
        STA     high_score_msb,Y

        ; Move the LSBs of the high score name pointer down one
        LDA     high_score_name_lsb,X
        STA     high_score_name_lsb,Y
        
        ; Move the MSBs of the high score name pointer down one        
        LDA     high_score_name_msb,X
        STA     high_score_name_msb,Y

        ; If we have reached the high score index
        ; where the player's score will go we've finished
        ; the demotions
        CPX     zp_high_score_position
        BEQ     high_scores_demoted

        ; Move to the next high score in the table
        DEX
        JMP     demote_high_scores

.high_scores_demoted
        ; Write the player's score into the 
        ; right part of the high score array
        LDA     zp_score_lsb
        STA     high_score_lsb,X
        LDA     zp_score_msb
        STA     high_score_msb,X

        ; Player name is always stored as the last name
        ; and indexed to the right position in the 
        ; high_score_name_lsb/msb arrays
        PLA
        STA     high_score_name_msb,X
        STA     zp_high_score_name_msb
        PLA
        STA     high_score_name_lsb,X
        STA     zp_high_score_name_lsb


        ; Empty the player's name string as they haven't
        ; entered it yet (so display it as empty)
        LDY     #$00
        LDA     #$0D
        STA     (zp_high_score_name_lsb),Y

        ; Display the high score table
        JSR     fn_display_high_score_table

        ; Overlay the enter high score on the
        ; right position and get the player to enter 
        ; their name
        JSR     fn_enter_high_score

        ; Overlay the press space or fire to start
        JMP     fn_display_press_space            

; 181F
.fn_display_high_score_table
        ; --------------------------------------------
        ; Show the high score table
        ; --------------------------------------------
        ; Switch to MODE 7
        LDA     #$16
        JSR     OSWRCH
        LDA     #$07
        JSR     OSWRCH

        ; Hide the cursor
        JSR     fn_hide_cursor

        ; Read the high score screen
        ; and display it
        LDX     #$00
.display_high_score_screen
        LDA     high_score_screen,X
        STA     mode7_start_addr,X
        INX
        ; There are 240 bytes to fill the screen
        CPX     #$F0
        BNE     display_high_score_screen

        LDX     #$00
.display_high_score_n_loop

        ; Move cursor to next high score position
        ; OSWRCH $1F moves the cursor to text
        ; position x/y
        ; Mode 7 is 40 cols x 24 rows
        LDA     #$1F
        JSR     OSWRCH

        ; Provide the x co-ordinate of 3 on screen
        LDA     #$03
        JSR     OSWRCH

        ; Calculate the Y co-ordinate
        ; Row Y = (n * 2) + 7
        ; where n is the high score line
        ;  n     Y
        ;  ===  ===
        ;  0     7
        ;  1     9
        ;  2     11
        ;  3     13
        ;  4     15
        ;  5     17
        ;  6     19
        ;  7     21
        ;  8     23

        ; X holds the current high score index
        ; Move it to A so we can caculate the row
        TXA
        ; Times by 2 (and throw away the carry flag)
        ASL     A
        CLC
        ; Add 7
        ADC     #$07
        ; Provide the calculate y co-ordinate on screen
        JSR     OSWRCH

        ; Set the colour to alphanumeric green
        LDA     #$82
        JSR     OSWRCH

        ; X holds the current high score index
        ; Move it to A so we can output an ASCII
        ; number to the screen
        ; 1 = ASCII 49
        ; ...
        ; 8 = ASCII 56
        TXA
        CLC
        ; Add $31 / 49 to get to ASCII 49+ so it's
        ; ASCII character number
        ADC     #$31
        JSR     OSWRCH

        ; Set the colour to alphanumeric cyan
        LDA     #$86
        JSR     OSWRCH

        ; Get the high score value for current high score position
        LDA     high_score_lsb,X
        STA     zp_number_for_digits_lsb
        LDA     high_score_msb,X
        STA     zp_number_for_digits_msb

        ; Preserve the high score index held in X
        TXA
        PHA

        ; Output two spaces
        LDA     #$20
        JSR     OSWRCH
        JSR     OSWRCH

        ; Output the score to the screen
        ; We only want it to generate
        ; 4 digits for the score as we 
        ; add a trailing zero when it 
        ; return
        LDA     #$04
        JSR     fn_calc_digits_for_display

        ; Restore X - the high score index
        PLA
        TAX

        ; Write a trailing zero for the score
        LDA     #$30
        JSR     OSWRCH

        ; Write three spaces to the screen
        LDA     #$20
        JSR     OSWRCH
        JSR     OSWRCH
        JSR     OSWRCH

        ; Set the colour to alphanumeric white
        LDA     #$87
        JSR     OSWRCH

        ; The high score names are stored via a lookup address table
        ; in memory. 
        ; 1947 - 194E contain the LSB for the name string
        ; 194F - 1956 contain the MSB for the name string
        ; 1957 - 19F6 contain the name strings
        LDA     high_score_name_lsb,X
        STA     zp_high_score_name_lsb
        LDA     high_score_name_msb,X
        STA     zp_high_score_name_msb
        LDY     #$00

.loop_display_high_score_name_n
        ; Load the next high score name
        ; Y is used to index the name string
        ; and only 12 characters are allowed?
        LDA     (zp_high_score_name_lsb),Y
        CMP     #$0D
        BEQ     high_score_name_completed

        ; If it's a control character (less than ASCII $20/32)
        ; then don't output it
        CMP     #$20
        BCC     skip_print_control_code

        ; Write the character to the screen
        JSR     OSWRCH

.skip_print_control_code
        INY
        ; Have we displayed all the name
        ; Each name can have 18 charactersf
        CPY     #$13
        BNE     loop_display_high_score_name_n

.high_score_name_completed
        INX
        ; Have we displayed all the high scores?
        ; If not, loop around agan
        CPX     #$08
        BNE     display_high_score_n_loop

        ; End of function
        RTS

;18B2
.fn_enter_high_score
        ; --------------------------------------------
        ; Get the player to enter their name for
        ; the high score table
        ; --------------------------------------------
        ; Switch on CAPS LOCK 
        ; OSBYTE &CA - Read/write keyboard status
        ; Same as *FX 2020,160
        LDA     #$CA    
        LDX     #$A0
        LDY     #$00
        JSR     OSBYTE

        ; OSBYTE $1F
        ; Move text cursor to
        ; x position - 7, y position - 24
        LDA     #$1F
        JSR     OSWRCH

        ; X position
        LDA     #$07
        JSR     OSWRCH

        ; Y position
        LDA     #$18
        JSR     OSWRCH

        LDY     #$00

.get_next_enter_name_byte
        ; Read the please enter your name string
        ; and write it to the screen. 
        LDA     string_enter_name,Y
        ; Have we reached the end of the string?
        CMP     #$0D
        BEQ     enter_name_string_complete

        ; Write the character to the screen
        JSR     OSWRCH

        INY
        JMP     get_next_enter_name_byte

.enter_name_string_complete
        ; Get the new high score index
        LDX     zp_high_score_position

        ; Look up where the name is in memory
        ; As we're going to overwrite it
        LDA     high_score_name_lsb,X
        STA     read_high_score_name_params_lsb
        LDA     high_score_name_msb,X
        STA     read_high_score_name_params_msb

        ; OSBYTE $1F
        ; Move text cursor to
        ; x position - 17, y position - to be calculated
        LDA     #$1F
        JSR     OSWRCH

        ; X position
        LDA     #$11
        JSR     OSWRCH

        ; X holds the new high score index
        TXA

        ; Calculate Y position
        ; Times it by 2 and add 7 to get the x position
        ; so 0 becomes 7
        ;    1 becomes 9
        ;    ....
        ;    8 becomes 23
        ASL     A
        CLC
        ADC     #$07
        JSR     OSWRCH

        ; OSBYTE &0F
        ; Flush the keyboard input buffer
        LDX     #$01
        LDA     #$0F
        JSR     OSBYTE

        ; Show the cursor
        JSR     fn_show_cursor

        ; OSWORD &00
        ; Read line from input
        ; (Get the user's name for the high score table)
        LDX     #read_high_score_name_params MOD 256
        LDY     #read_high_score_name_params DIV 256
        LDA     #$00
        JSR     OSWORD

        ; Hide the cursor
        JSR     fn_hide_cursor

        ; Move cursor up one line
        LDA     #$0B
        JSR     OSWRCH

        ; Make the text flash
        ; JMP ends sub-routine
        LDA     #$88
        JMP     OSWRCH

.read_high_score_name_params
.read_high_score_name_params_lsb
        ; Parameter block for OSWORD &00 call
        ; to read user's name for high score table
        ; read_high_score_name_params_lsb
        
        ; Buffer where to write the input (LSB)
        EQUB    $00

.read_high_score_name_params_msb
        ; Buffer where to write the input (MSB)
        EQUB    $00
        ; Maximum number of characters (19)
        EQUB    $13
        ; Minimum character value (32 / space)
        EQUB    $20
        ; Maximum character value (255)
        EQUB    $FF

;191F
.fn_show_cursor
        ; --------------------------------------------
        ; Switch on the screen cursor
        ; --------------------------------------------
        LDY     #$00
;1921
.vdu_23_show_cursor_param_loop
        LDA     vdu_23_show_cursor_params,Y
        JSR     OSWRCH

        INY
        ; Have we read all 10 bytes?
        ; If not, then loop again
        CPY     #$0A
        BNE     vdu_23_show_cursor_param_loop

        RTS

;192D
.vdu_23_show_cursor_params
        ; Show the cursor
        ;
        ; VDU 23,0,R,X,0,0,0,0,0,0
        ; R=6845 register
        ; X=Value
        ; VDU 23,0,10,20,0,0,0,0,0,0
        ; R10 is the cursor control register
        ; &20 = 0010 0000
        ; Bit  7 - 0 - not used
        ; Bit  6 - 1 - enable cursor 
        ; Bit  5 - 1 - blink
        ; Bits 4-0 - 0010 - cursor start at line 2
 
        ; VDU 23,0,10,114,0,0,0,0,0,0
        EQUB    $17,$00,$0A,$72,$00,$00,$00,$00
        EQUB    $00,$00       

;1937
; The 8 high scores stored in LSB and MSB locations
; Scores are highest to lowest and divided by 10 when stored
.high_score_lsb
        EQUB    $5E,$2C,$FA,$C8,$64,$4B,$32,$19

;193F
.high_score_msb
        EQUB    $01,$01,$00,$00,$00,$00,$00,$00

;1947
.high_score_name_lsb
        EQUB    $57,$6B,$7F,$93,$A7,$BB,$CF,$E3

;194F
.high_score_name_msb
        EQUB    $19,$19,$19,$19,$19,$19,$19,$19

.high_score_names
        EQUS    "Britannia",$0D,"          "
        EQUS    "Chris Colombus",$0D,"     "
        EQUS    "Captain Birdseye",$0D,"   "
        EQUS    "Long John",$0D,"          "
        EQUS    "Frannie Drake",$0D,"      "
        EQUS    "Jack Tar",$0D,"           "
        EQUS    "Popeye",$0D,"             "
        EQUS    "Muggins",$0D,"            "
        EQUB    $00

;19F8
.fn_display_press_space
        ; --------------------------------------------
        ; Display the Press Space or Fire text
        ; --------------------------------------------

        ; Write 40 spaces to the bottom of the Mode 7 screen
        ; Not sure why this isn't done with OSWRCH like the
        ; rest
        LDX     #$00
        ; Code for space
        LDA     #$20
.write_space_to_screen
        ; Write to the bottom line of the screen        
        STA     $7FC0,X
        INX
        ; Have we written 40 spaces?
        CPX     #$28
        ; If not loop back around
        BNE     write_space_to_screen

        LDA     #$81
        STA     $7FC0
        LDA     #$9D
        STA     $7FC1

        ; OSBYTE $1F
        ; In MODE 7 - move text cursor to
        ; x position - 4, y position - 24
        LDA     #$1F
        JSR     OSWRCH

        ; x position
        LDA     #$04
        JSR     OSWRCH

        ; y position
        LDA     #$18
        JSR     OSWRCH

        LDY     #$00
;1A1F
.get_next_string_press_space_or_fire_byte
        LDA     string_press_space_or_fire,Y
        ; Have we reached the string termination character?
        ; If yes then branch ahead
        CMP     #$0D
        BEQ     fn_wait_for_intro_input

        JSR     OSWRCH

        INY
        JMP     get_next_string_press_space_or_fire_byte

; 1A2D
.fn_wait_for_intro_input
        ; Check sounds keys S/Q
        JSR     fn_check_sound_keys
        
        ; Check if joystick button pressed
        JSR     fn_check_joystick_button

        ; If the joystick button was pressed, end the wait for input loop
        BNE     end_fn_wait_for_intro_input

        ; Check to see if space was pressed
        LDX     #$9D
        JSR     fn_read_key
        CPX     #$00

        ; It wasn't so loop again waiting for input
        BEQ     fn_wait_for_intro_input

.end_fn_wait_for_intro_input
        RTS

; 1A3F
.fn_show_player_score_below_high_scores
        ; --------------------------------------------
        ; Show player score below the high score table
        ; --------------------------------------------

        ; The high score screen in MODE 7 is
        ; already displayed at this point -
        ; this is to add the "You scored" text
        ; and player's score and "Press space or fire
        ; to start" on top of the screen
        ; Mode 7 is 40 cols x 24 rows
        LDA     #$1F
        JSR     OSWRCH

        ; Provide the x co-ordinate of 11 on screen
        LDA     #$0B
        JSR     OSWRCH

        ; Provide the y co-ordinate of 23 on screen
        LDA     #$17
        JSR     OSWRCH

        LDX     #$00

;1A50
.get_you_scored_byte
        ; Get each character of the "You scored" string
        ; and output to the screen
        LDA     string_you_scored,X
        JSR     OSWRCH
        INX
        ; Have we read all 11 characters and codes
        ; if not, loop back around
        CPX     #$0C
        BNE     get_you_scored_byte

        ; Get the current score, and output it to
        ; the screen 
        LDA     zp_score_lsb
        STA     zp_number_for_digits_lsb
        LDA     zp_score_msb
        STA     zp_number_for_digits_msb
        LDA     #$04
        ; Function checks to see if it's mode 7
        ; and writes the score to the screen
        JSR     fn_calc_digits_for_display

        ; Write a trailing zero to the screen
        ; to effectively times it by 10
        ; and return / end function
        LDA     #$30
        JMP     OSWRCH

;1A6D
.string_press_space_or_fire
        EQUS    $87,$88,"Press SPACE or FIRE to start",$0D

;1A8C
.string_enter_name
        ; $85 - alphanumeric magenta colour teletext code
        ; $88 - flash text teletext code
        ; $0D - used as string terminator
        EQUS    $85,$88,"Please enter your name",$0D

.string_you_scored
        ; $85 - alphanumeric magenta colour teletext code
        ; $86 - alphanumeric cyan colour teletext code
        EQUS    $85,"You scored",$86

;1AB1
.fn_fill_screen_with_jet_boat
        ; --------------------------------------------
        ; Repeat the Jet Boat string to fill the Mode 5
        ; screen in alternating colours
        ; --------------------------------------------

        ; Set initial text colour to red (1)
        LDA     #$01
        STA     zp_text_colour
        ; X is a counter - used to fill 
        ; the mode 5 screen with 71 
        ; Jet Boat multi-coloured text
        LDX     #$47

.loop_fill_screen_with_jet_boat
        ; Writes Jet boat onto the screen 71 times in alternating
        ; red / yellow foreground text colours- it does NOT
        ; set the background colour
        ; Change the text colour VDU 17 
        LDA     #$11
        JSR     OSWRCH

        ; Set the text colour to red (1) or yellow (2)
        LDA     zp_text_colour
        JSR     OSWRCH

        ; Clear carry flag 
        CLC
        ; Set the next counter (why not use INC given the carry flag was cleared)
        ; and remove 2 bytes?
        ADC     #$01
        CMP     #$03
        ; If the counter doesn't equal 3
        ; don't reset the text colour to red
        BNE     skip_text_colour_reset

        ; Reset the text colour to red (1)
        LDA     #$01

.skip_text_colour_reset
        STA     zp_text_colour
        ; There are 8 characters in "Jet boat"
        LDY     #$08

.loop_load_jet_boat_chars
        ; Write the current character of "Jet boat"
        ; to the screen (note the characters are reversed)
        ; in memory
        LDA     jet_boat_string,Y
        JSR     OSWRCH

        ; Move to the next "Jet boat" character
        DEY
        ; If there are any characters left, print them
        BPL     loop_load_jet_boat_chars

        ; Move to the next print of "Jet boat"
        DEX
        BNE     loop_fill_screen_with_jet_boat

        RTS

.jet_boat_string
        ; "Jet boat" reversed
        EQUS    " taoB teJ"

.fn_set_colours_to_black
        ; --------------------------------------------
        ; Set logical colour 3 to black 
        ; and update the palette
        ; --------------------------------------------
        LDX     #$03

.loop_next_logical_colour
        ; Loop four times; setting each
        ; logical colour (from 3 to 0) 
        ; to physical colour black 
        
        ; Set physical colour to black (0)
        ; for logical colour X
        LDA     #$00
        STA     palette_physical_colour
        STX     palette_logical_colour
        JSR     fn_change_colour_palette

        DEX
        BPL     loop_next_logical_colour

        RTS

.fn_print_next_stage_text
        ; --------------------------------------------
        ; Reads from memory and writes on the screen the
        ; Prepare to enter the next stage CONGRATULATIONS!
        ; text
        ; --------------------------------------------

        ; Set index counter to 0
        LDX     #$00
.loop_read_next_stage_chars
        ; Read next character from memory and write to screen
        LDA     string_next_stage,X
        JSR     OSWRCH
        ; Increment index counter, check if we have all 68 chars
        ; of the string if not loop again to get next one
        INX
        CPX     #$44
        BNE     loop_read_next_stage_chars

        RTS

.string_next_stage
        EQUS    $11,$00,$11,$01,$1F,$02,$10,"Prepare to enter"
        EQUS    $1F,$03,$12,"the next stage"
        EQUS    $1C,$01,$0A,$12,$08,$11,$03,$11,$82,$0C,$0A,$09
        EQUS    "CONGRATULATIONS!"

;1B46


;1B47
.fn_apply_or_reset_hazard_set
        ; --------------------------------------------
        ; Applies or resets the current hazard set - location of
        ; the hazard configuration is in the X and Y registers
        ; on entry and stored in zero page
        ; --------------------------------------------

        ; Cache the hazard configuration address
        STX     zp_hazard_config_lsb
        STY     zp_hazard_config_msb

        ; Width of hazard in (number of tiles wide)
        ; Y=0
        LDY     #$00
        LDA     (zp_hazard_config_lsb),Y
        STA     zp_hazard_num_tiles_width

        ; Height of hazard in (number of tiles high)
        ; Y=1
        INY
        LDA     (zp_hazard_config_lsb),Y
        STA     zp_hazard_num_tiles_height

        ; Y=2
        ; Third value is the total number of tiles that
        ; are used to draw the hazard e.g. 1 for ducks, 4 
        ; for buoys - should equal width x height about
        INY
        LDA     (zp_hazard_config_lsb),Y
        STA     zp_total_tiles_for_hazard

        ; Y is now 3, set x = 0
        ; y =3
        INY
        LDX     #$00

        ; 1C00 + 2 controls how many times around this loop
        ; Once, tracked by X
.load_lookup_table_loop
        ; Copy all the tile sequence from the configuration
        ; into L0033 onwards for fast access - tile sequence
        ; represents the tile combination needed to draw the hazard
        LDA     (zp_hazard_config_lsb),Y
        STA     zp_hazard_first_tile_type,X

        ; Some hazards need exactly one tile (ducks) others
        ; need many e.g. 28 (islands)
        INY
        INX
        ; Have we cached all of the hazard tile sequence in zero
        ; page? If not, loop back around
        CPX     zp_total_tiles_for_hazard
        BNE     load_lookup_table_loop

        ; Next value is the total number of (x,y) 
        ; instances there will be on the map
        LDA     (zp_hazard_config_lsb),Y
        STA     zp_total_hazard_occurrences

        ; Fifth value is the total number of hazard occurrences
        ; of this type that will be added or reset on the map
        ;Y =5
        INY
        LDX     zp_total_hazard_occurrences
.cache_hazard_x_coordinates
        ; Cache the x co-ordinates for the (x,y) placement
        ; of the hazard
        LDA     (zp_hazard_config_lsb),Y
        STA     zp_hazard_first_x_coordinate,X
        ; If there are more to copy then loop
        INY
        DEX
        BPL     cache_hazard_x_coordinates

        ; Reset the loop counter
        LDX     zp_total_hazard_occurrences

.cache_hazard_y_coordinates
        ; Cache the y co-ordinates for the (x,y) placement
        ; of the hazard
        LDA     (zp_hazard_config_lsb),Y
        STA     zp_hazard_first_y_coordinate,X
        ; If there are more to copy then loop
        INY
        DEX
        BPL     cache_hazard_y_coordinates

        ; Reset the loop counter
        LDX     zp_total_hazard_occurrences

;1B83
.loop_copy_hazard_next_instance
        ; Calculate the memory location of the
        ; map where to store the hazard tile  id based
        ; on the (x,y) co-ordinate
        
        ; Storage address = (y * $FF) / 2 + $3000 + x
        LDA     #$00
        STA     zp_graphics_tiles_storage_lsb

        ; Making y the MSB is the say as (y * $FF)
        ; Take the value we found in memory, divide it by 2
        ; and add $30 / 48 to it and save as the MSB
        LDA     zp_hazard_first_y_coordinate,X

        ; Divide A by two
        LSR     A

        ; Dividing MSB by 2, move the carry into the LSB
        ROR     zp_graphics_tiles_storage_lsb
        
        ; Add $30 / 48 to the MSB (effectively adds $3000 to the address)
        ADC     #$30

        ; Store result in the MSB variable
        STA     zp_graphics_tiles_storage_msb

        ; Add x to the address
        LDA     zp_graphics_tiles_storage_lsb
        CLC
        ADC     zp_hazard_first_x_coordinate,X
        STA     zp_graphics_tiles_storage_lsb

        ; If adding x to the LSB made it greater than
        ; 255 (carry flag set) then add the carry to the 
        ; MSB
        LDA     #$00
        ADC     zp_graphics_tiles_storage_msb
        STA     zp_graphics_tiles_storage_msb

        LDY     #$00
        TXA
        PHA

        ; Hazard is x * y bytes e.g. duck is 1 * 1 and island is 9 x 2
        ; Copies all the x tile bytes onto the map first
        ; then moves to the next row and copies the next x tiles to the map

        ; Get the height of the hazard in number of tiles
        ; and store it as a working counter/index
        LDA     zp_hazard_num_tiles_height
        STA     zp_hazard_height_index
        LDX     #$00
.loop_copy_hazard_next_y_row_tile_types
        LDA     #$00
        STA     zp_hazard_width_index
;1BAB
.loop_copy_hazard_x_tile_types
        LDA     zp_hazard_first_tile_type,X

        ; Check to see if we're starting a new stage / new game 
        ; and if we need to reset the hazards back to the water tile
        ; (if we are then the status will be $FF)
        BIT     zp_reset_hazards_status
        BPL     skip_reset_to_water_tile

        ; We'll reset back to the water tile ($03)
        ; so must be start of game or stage
        LDA     #$03
;1BB3
.skip_reset_to_water_tile
        ; Copy the tile type to the map and overwrite whatever was there 
        ; before (this either adds part of the hazard or resets it to water)
        STA     (zp_graphics_tiles_storage_lsb),Y
        INY
        INX

        ; If there are still horizontal / x tile types to copy
        ; then loop around again 
        INC     zp_hazard_width_index
        LDA     zp_hazard_width_index
        CMP     zp_hazard_num_tiles_width
        BNE     loop_copy_hazard_x_tile_types

        ; Each row is 128 tile ids ($80) wide
        ; 
        ; Get the start position of the next hazard
        ; tile role by subtracing of the width of the
        ; tile from 128.  And then processing that row
        ;
        ; Remember that at this point it's pointing to the 
        ; map to tile id data in memory (not the graphics)
        LDA     #$80

        ; Set the carry flag
        SEC

        ; Subtract the width of the hazard
        ; from the width of the map
        SBC     zp_hazard_num_tiles_width
        CLC

        ; Add this to the storage address
        ADC     zp_graphics_tiles_storage_lsb
        STA     zp_graphics_tiles_storage_lsb

        ; Add any carry to the MSB
        LDA     #$00
        ADC     zp_graphics_tiles_storage_msb
        STA     zp_graphics_tiles_storage_msb

        ; Move to the next row of the hazard data
        DEC     zp_hazard_height_index
        LDA     zp_hazard_height_index

        ; If still more to process, loop back around
        BNE     loop_copy_hazard_next_y_row_tile_types

        ; Restore X and move to the next instance of this
        ; hazard
        PLA
        TAX
        DEX
        BPL     loop_copy_hazard_next_instance

        ; All done!
        RTS

; 1BDB
.fn_get_hazard_for_index_and_apply_or_reset
        ; --------------------------------------------
        ; There are 12 entries in the lookup
        ; table - this is used to find the obstacles
        ; per lap in a stage - in each stage there
        ; are more per lap
        ; --------------------------------------------
        CPX     #$0B
        BCC     get_hazard_for_index_from_lookup_table

        RTS

        ; Find out where in memory the current lap's hazard
        ; information is held - e.g. second lap has ducks
.get_hazard_for_index_from_lookup_table
        LDY     hazard_lookup_table_msb,X
        LDA     hazard_lookup_table_lsb,X
        TAX
        JMP     fn_apply_or_reset_hazard_set

        ; The hazard lookup table gives the memory location of 
        ; the hazard tile and multiple (x,y) co-ordinate 
        ; configuratoin information - each pair of MSB/LSBs 
        ; are a different hazard e.g. ducks and are applied cumulatively
        ; for each subsequent lap 
.hazard_lookup_table_lsb
        EQUB    LO(hazard_ducks)
        EQUB    LO(hazard_buoys)
        EQUB    LO(hazard_islands)
        EQUB    LO(hazard_sea_serpents)
        EQUB    LO(hazard_barriers)
        EQUB    LO(hazard_yachts)
        EQUB    LO(hazard_crocodiles)
        EQUB    LO(hazard_sand_banks)
        EQUB    LO(hazard_gondolas)
        EQUB    LO(hazard_rafts)
        EQUB    LO(hazard_lighthouses)

;        EQUB    $00,$21,$35,$51,$69,$81,$9A,$AE
;        EQUB    $C4,$DA,$F1

; All hazard configuration stored at 1Cxx
.hazard_lookup_table_msb
        EQUB    HI(hazard_ducks)
        EQUB    HI(hazard_buoys)
        EQUB    HI(hazard_islands)
        EQUB    HI(hazard_sea_serpents)
        EQUB    HI(hazard_barriers)
        EQUB    HI(hazard_yachts)
        EQUB    HI(hazard_crocodiles)
        EQUB    HI(hazard_sand_banks)
        EQUB    HI(hazard_gondolas)
        EQUB    HI(hazard_rafts)
        EQUB    HI(hazard_lighthouses)        

;        EQUB    $1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C
;        EQUB    $1C,$1C,$1C

INCLUDE "hazards-formatted.asm"

; 1D10
.high_score_screen
        EQUS    $94,$9D,$87,"     ",$93,$F0,$F0,$F0,$B0," ",$96,$9A,$A0,$80,$B8,$A1,$F0,"  ",$B8,"                ",$94,$9D,$87,"HIGH ",$93,$FF,$A0," ",$FF,$9A,$96,$B6,$E0,$A6," ",$B6,$AC,$E1,$A6,$E3
        EQUS    $A1,$99,$93,$FF,"    ",$87,"SCORES ",$94,$9D,$87,"HIGH ",$93,$FF,$F0,$F0,$BF,$9A,$96,$A2,$A1,"  ",$A2,$A1,$A0,$A3,$A1,$99," ",$93,$FF,$AC,$AC,"  ",$87,"SCORES ",$94,$9D,$87,"HIGH "
        EQUS    $93,$FF,"  ",$FD,"  ",$FE,$A3,$A3,$FD,"  ",$A2,$A3,$A3,$FD,"  ",$FF,$9A,"   ",$87,"SCORES ",$94,$9D,$87,"HIGH ",$93,$FF,"  ",$FF,"  ",$FF,"  ",$FF,"  ",$FE,$A3,$A3,$FF,"  ",$FF,"  ",$FC," "
        EQUS    $87,"SCORES ",$94,$9D,$87,"     ",$93,$A3,$A3,$A3,$A1,"  ",$A2,$A3,$A3,$A1,"  ",$A2,$A3,$A3,$A1,"  ",$A2,$A3,$A3,$A1,"         "
; 1E00
INCLUDE "boat-graphics-formatted.asm"

; 2800
INCLUDE "tile-graphics.asm"
; 3000
INCLUDE "tile-map-formatted.asm"

.main_code_block_end

; Code was compiled above in its runtime position $0B40
; Now need to move it to $1100 where it will load before it
; is relocated back to $0B40
load = $1100
main_code_block_load = load
relocate_code_block_load = main_code_block_load + (main_code_block_end - main_code_block)
COPYBLOCK main_code_block, main_code_block_end, main_code_block_load



ORG relocate_code_block_load
;5DC0
.relocate_code_block

.fn_copy_memory
        ; ----------------------------------------------------------------------------------------
        ; Relocate the game code and graphics
        ; ----------------------------------------------------------------------------------------
        LDY     #$00  ; Set y to zero for later memory copy loops 
        LDX     copy_num_pages  ; Check if we're copying full pages or less than a page
        BEQ     init_copy_memory ;
		
	; Copy full pages
.copy_memory_full_page
        LDA     (copy_from_lsb),Y
        STA     (copy_to_lsb),Y
        INY
        BNE     copy_memory_full_page
	; Increment to next page of memory in source and target
	; e.g if copying 1100 to 0B40 now copy 1200 to 0C40
	; X  is tracking the number of pages we copy - keeps going until 
	; it reaches zero
        INC     copy_from_msb
        INC     copy_to_msb
        DEX
        BNE     copy_memory_full_page	
		
	; If copy partial page then X will be zero and it'll branch to finished
	; If only partial page then go and copy it
.init_copy_memory
        LDX     copy_size
        BEQ     copy_memory_finished
			
	; Copy n bytes from source to target
	; e.g. copy A0 bytes of data from &5EC0 to &0400 (basic workspace)
.copy_memory_n_bytes
        LDA     (copy_from_lsb),Y
        STA     (copy_to_lsb),Y
        INY
        DEX
        BNE     copy_memory_n_bytes

	; All memory copied
.copy_memory_finished
        RTS

;5DE1
.fn_start_point
        ; ----------------------------------------------------------------------------------------
        ; On load, code execution point
        ; ----------------------------------------------------------------------------------------
        ; Set the mode to MODE 7
        LDA     #$16    
        JSR     OSWRCH
        LDA     #$07  
        JSR     OSWRCH
		
	LDX     #$00
.get_key_config
	; Read the key configuration 
	; from the loader and move it to where
	; the game expect it. All strings
	; regardless of key selected are 10 characters
	; plus a new line (&0D)
        LDA     left_key_string_from_loader,X
        CMP     #$0D
        BEQ     copy_to_0400

        STA     left_key_string_game,X
        LDA     right_key_string_from_loader,X
        STA     right_key_string_game,X
        LDA     accel_key_string_from_loader,X
        STA     accel_key_string_game,X
        INX
        BNE     get_key_config


.copy_to_0400
        ; Copy the Times Up Clock
	; copy_from = &5EC0
	; copy_to   = &0400 Basic Workspace
	; copy_size = $A0 bytes
        LDA     #$00
        STA     copy_to_lsb
        STA     copy_num_pages
        LDA     #LO(graphics_times_up_clock)
        STA     copy_from_lsb
        LDA     #HI(graphics_times_up_clock)
        STA     copy_from_msb
        LDA     #$04
        STA     copy_to_msb
        LDA     #$A0
        STA     copy_size
        JSR     fn_copy_memory
		
.copy_to_0540
        ; Copys the Score, Time, Lap Graphics
	; copy_from = &5F60 (to &5FFF)
	; copy_to   = &0540  Basic Workspace
	; copy_size = $A0 bytes (unchanged)
        LDA     #$40
        STA     copy_to_lsb
        LDA     #LO(graphics_icons)
        STA     copy_from_lsb
        LDA     #HI(graphics_icons)
        STA     copy_from_msb
        LDA     #$05
        STA     copy_to_msb
        JSR     fn_copy_memory

.copy_to_0740
        ; Copys the number graphics to this region
	; copy_from = &6000 (to &609F)
	; copy_to   = &0740  Basic Workspace
	; copy_size = $A0 bytes (unchanged)
        LDA     #$40
        STA     copy_to_lsb
        LDA     #LO(graphics_numbers)
        STA     copy_from_lsb
        LDA     #HI(graphics_numbers)
        STA     copy_from_msb
        LDA     #$07
        STA     copy_to_msb
        JSR     fn_copy_memory

.copy_to_04A0
        ; Copys the Get Ready Icon
	; copy_from = &64B0  (to &654F)
	; copy_to   = &04A0  Basic Workspace
	; copy_size = $A0 bytes (unchanged)		
        LDA     #LO(graphics_get_ready_icon)
        STA     copy_from_lsb
        LDA     #HI(graphics_get_ready_icon)
        STA     copy_from_msb
        LDA     #$A0
        STA     copy_to_lsb
        LDA     #$04
        STA     copy_to_msb
        JSR     fn_copy_memory

.copy_to_0B40
	; Shift most of the game code to 0B40 up to 5740
	; copy_from = &1100
	; copy_to   = &0B40 Function key text work space
	; copy_size = $C0 bytes (changed)
	; copy_num_pages = &4C / 76
	LDA     #$00
        STA     copy_from_lsb
        LDA     #$40
        STA     copy_to_lsb
        LDA     #$C0
        STA     copy_size
        LDA     #$11
        STA     copy_from_msb
        LDA     #$0B
        STA     copy_to_msb
        LDA     #$4C
        STA     copy_num_pages
        JSR     fn_copy_memory

.display_intro_screen	
	; Display the telext intro screen
	; Shows keys and instructions
        ; Shift 4 pages to 7C00 to 8000
	; copy_from = &60B0
	; copy_to   = &7C00
	; copy_size = $00 bytes (changed)
	; copy_num_pages = &04
        LDA     #$00
        STA     copy_to_lsb
        STA     copy_size
        LDA     #LO(intro_screen)
        STA     copy_from_lsb
        LDA     #$7C
        STA     copy_to_msb
        LDA     #HI(intro_screen)
        STA     copy_from_msb
        LDA     #$04
        STA     copy_num_pages
        JSR     fn_copy_memory

.copy_key_control_values
	; Get the keyboard control values that the basic loader set
	; and insert them into the game code - this is done after
        ; the code is moved
        LDA     left_key_value
        STA     left_key_game
        LDA     right_key_value
        STA     right_key_game
        LDA     accel_key_value
        STA     accel_key_game

        JSR     fn_hide_cursor
	
        ; Wait for user input to start game (in game code)
        JSR     fn_wait_for_intro_input 

        ; Call thew main game entry point (all this relocation
        ; and intro screen code will die when the game starts)
        JMP     fn_game_start

  
; 5EA7
.junk_bytes
        EQUB    $69,$72,$64,$73,$65,$79,$65,$22
        EQUB    $2C,$22,$4C,$6F,$6E,$67,$20,$4A
        EQUB    $6F,$68,$6E,$22,$2C,$22,$46,$72
        EQUB    $61

; 5EC0
.graphics_times_up_clock
        EQUB    $00,$01,$03,$03,$03,$03,$01,$00
        EQUB    $0C,$0E,$0E,$0E,$0C,$0B,$14,$78
        EQUB    $00,$08,$0C,$04,$0F,$D0,$D0,$D0
        EQUB    $03,$07,$07,$07,$03,$0D,$82,$E1
        EQUB    $00,$08,$0C,$0C,$0C,$0C,$08,$00

        EQUB    $01,$02,$13,$12,$34,$34,$34,$34
        EQUB    $F0,$F0,$FD,$F9,$F9,$F9,$F9,$F0
        EQUB    $F0,$F0,$F6,$F5,$F5,$F5,$F5,$F0
        EQUB    $F0,$F0,$FD,$F5,$F5,$F5,$F5,$F0
        EQUB    $08,$04,$8C,$84,$CA,$C2,$CA,$C2

        EQUB    $34,$14,$34,$34,$34,$34,$34,$12
        EQUB    $F0,$00,$F0,$F0,$F1,$F1,$F1,$F1
        EQUB    $F0,$22,$F0,$F0,$F5,$F5,$F5,$F5
        EQUB    $F0,$F0,$70,$B0,$DC,$F4,$FC,$F0
        EQUB    $C2,$02,$C2,$C2,$C2,$C2,$84,$84

        EQUB    $02,$01,$01,$00,$00,$00,$11,$11
        EQUB    $F1,$F0,$F0,$58,$16,$CD,$88,$00
        EQUB    $FD,$F0,$D0,$D0,$D0,$0F,$00,$00
        EQUB    $F0,$F0,$F0,$A1,$86,$3B,$11,$00
        EQUB    $04,$08,$08,$00,$00,$00,$88,$88 

.graphics_icons
        ; Score icon
        EQUB    $F0,$F7,$F4,$F7,$F1,$F1,$F7,$F0
        EQUB    $F0,$F7,$F4,$F4,$F4,$F4,$F7,$F0
        EQUB    $F0,$F7,$F5,$F5,$F5,$F5,$F7,$F0
        EQUB    $F0,$F7,$F5,$F5,$F6,$F5,$F5,$F0
        EQUB    $F0,$F6,$F4,$F6,$F4,$F4,$F6,$F0

        ; Time icon
        EQUB    $F0,$F0,$80,$D0,$D0,$D0,$D0,$F0
        EQUB    $F0,$F0,$A0,$A0,$A0,$A0,$A0,$F0
        EQUB    $F0,$F0,$40,$A0,$A0,$A0,$A0,$F0
        EQUB    $F0,$F0,$90,$B0,$90,$B0,$90,$F0
        EQUB    $10,$10,$10,$10,$10,$10,$10,$10

        ; Lap icon
        EQUB    $F0,$00,$40,$40,$40,$40,$60,$00
        EQUB    $F0,$00,$40,$A0,$E0,$A0,$A0,$00
        EQUB    $F0,$00,$E0,$A0,$E0,$80,$80,$00
        EQUB    $80,$80,$80,$80,$80,$80,$80,$80
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00

        ; Blank icon
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00

.graphics_numbers
        ; 0
        EQUB    $F0,$33,$46,$46,$46,$46,$46,$33
        EQUB    $F0,$8C,$46,$46,$46,$46,$46,$8C
        
        ; 1
        EQUB    $F0,$11,$33,$11,$11,$11,$11,$77
        EQUB    $F0,$08,$08,$08,$08,$08,$08,$CE

        ; 2
        EQUB    $F0,$33,$46,$00,$00,$11,$23,$77
        EQUB    $F0,$8C,$46,$46,$8C,$08,$00,$CE

        ; 3
        EQUB    $F0,$33,$46,$00,$11,$00,$46,$33
        EQUB    $F0,$8C,$46,$46,$8C,$46,$46,$8C

        ; 4
        EQUB    $F0,$00,$11,$23,$46,$77,$00,$00
        EQUB    $F0,$8C,$8C,$8C,$8C,$CE,$8C,$8C

        ; 5
        EQUB    $F0,$77,$46,$77,$00,$00,$46,$33
        EQUB    $F0,$CE,$00,$8C,$46,$46,$46,$8C

        ; 6
        EQUB    $F0,$11,$23,$46,$77,$46,$46,$33
        EQUB    $F0,$8C,$00,$00,$8C,$46,$46,$8C

        ; 7
        EQUB    $F0,$77,$00,$00,$11,$23,$23,$23
        EQUB    $F0,$CE,$46,$8C,$08,$00,$00,$00

        ; 8
        EQUB    $F0,$33,$46,$46,$33,$46,$46,$33
        EQUB    $F0,$8C,$46,$46,$8C,$46,$46,$8C

        ; 9
        EQUB    $F0,$33,$46,$46,$33,$00,$00,$33
        EQUB    $F0,$8C,$46,$46,$CE,$46,$8C,$08

;60A0
.unused_bytes
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00

;......
;60b0
.intro_screen
        ; Teletext intro screen with lots of embedded control codes
        EQUS    $91,"          ",$9A," ",$93,"  "

.L60C0
        EQUS    $BA,"  ",$BA,$A3,$A3," ",$A2,$E3

.L60C9
        EQUS    $A7,$A3,$99,$8E,"           ",$91,"    ",$FF,$FF,$FF,$FF,$FF,$F4,$9A,$93,$B8," ",$E8,$A1," ",$E8,$A3,$A3,"   ",$B6,"  ",$99,$91,$FF,$B5,"         ",$91,"    ",$FF,$B5,"  "
        EQUS    $EB,$FF,$9A,$93,$A9,$AC,$A1,"  ",$AD,$AC,$A4,"  ",$AA,"   ",$99,$91,$FF,$B5,"         ",$91,"    ",$FF,$F5,$F0,$F0,$FE,$BF,"  ",$F8,$FF,$FF,$FF,$FF,$F4,"   ",$FF,$FF,$FF,$FF,$F4,"  ",$FF,$FF,$FF,$FF
        EQUS    "       ",$91,"   "

.L6154
        EQUS    " ",$FF,$BF,$AF,$AF,$FF,$F4,"  ",$FF,$B7,"  ",$EB,$FF,"      "

.L6169
        EQUS    $EA,$FF,"  ",$FF

.L616E
        EQUS    $B5,"     "

.L6174
        EQUS    "    ",$91,"    ",$FF,$B5,"  ",$EA,$FF,"  ",$FF,$B5,"  ",$EA,$FF,"  ",$F8,$FF,$FF,$FF,$FF,$FF,"  ",$FF,$B5,"  ",$E0,$F0,"     ",$91,"    ",$FF,$F5,$F0,$F0,$FE,$FF,"  ",$FF,$FD,$F0,$F0,$FE,$FF," "
        EQUS    " ",$FF,$F5,$F0,$F0,$FA,$FF,"  ",$FF,$FD,$F0,$F0,$FE,$FF,"     ",$91,"    ",$AF,$AF,$AF,$AF,$AF,$A1,"  ",$A2,$AF,$AF,$AF,$AF,$A1,"  ",$A2,$AF,$AF,$AF,$AF,$AF,"  ",$A2,$AF,$AF,$AF,$AF,$A1,"     ",$82,"   "
        EQUS    "   By Robin J. Leatherbarrow        ",$94,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0
        EQUS    $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0," ",$84,$9D,$86,"Keyboard  ",$87,$8D,"CONTROLS     ",$8C,$86,"Joystick ",$9C,$84,$9D,"          "
        EQUS    " ",$87,$8D,"CONTROLS      ",$8C,"         ",$9C,$94,$B5,"                                  "
        EQUS    " ",$94,$EA," ",$94,$B5,$85

.left_key_string_game
        EQUS    "CAPS LOCK ",$83," Turn left     ",$82,"  LEFT ",$94,$EA," ",$94,$B5,$85

.right_key_string_game
        EQUS    "CTRL      ",$83," Turn right    ",$82,"  RIGHT",$94,$EA," ",$94,$B5,$85,"                        "
        EQUS    "          ",$94,$EA," ",$94,$B5,$85

.accel_key_string_game
        EQUS    "RETURN    ",$83," Accelerate    ",$82,"  FIRE ",$94,$EA," ",$94,$B5,$85,"                        "
        EQUS    "          ",$94,$EA," ",$94,$B5,$85,"S         ",$83," Sound ON              ",$94,$EA," ",$94,$B5,$85,"Q       "
        EQUS    " ",$83,"  Sound OFF             ",$94,$EA," ",$94,$B5,$85,"                                "
        EQUS    "  ",$94,$EA," ",$94,$B5,$85,"F        ",$83,"  Freeze      "        

.L6413
        EQUS    "          ",$94,$EA," ",$94,$B5,$85,"C        ",$83,"  Continue              ",$94,$EA," ",$94,$F5,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0
        EQUS    $F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$F0,$FA," ",$84,$9D,$86,"  ",$88,"Press SPACE or FIRE to start "
        EQUS    "    ",$9C,"                        "

; 64B0
.graphics_get_ready_icon
        EQUB    $05,$05,$05,$05,$0F,$F0,$30,$F0
        EQUB    $05,$05,$05,$05,$0F,$F0,$00,$77
        EQUB    $05,$05,$05,$05,$0F,$F0,$00,$66
        EQUB    $05,$05,$05,$05,$0F,$F0,$00,$EE
        EQUB    $05,$05,$05,$05,$0F,$F0,$C0,$F0
        EQUB    $30,$F0,$30,$F0,$30,$F0,$30,$F0
        EQUB    $55,$44,$44,$55,$55,$77,$11,$00
        EQUB    $44,$44,$66,$44,$44,$44,$66,$00
        EQUB    $44,$44,$44,$44,$44,$44,$44,$00
        EQUB    $C0,$F0,$C0,$F0,$C0,$F0,$C0,$F0

; Possibly junk above        
        EQUB    $F0,$F7,$F5,$F5,$F7,$F6,$F5,$F5
        EQUB    $F0,$F6,$F4,$F4,$F6,$F4,$F4,$F4
        EQUB    $F0,$F4,$FA,$FA,$FE,$FA,$FA,$FA
        EQUB    $F0,$FC,$FA,$FA,$FA,$FA,$FA,$FA
        EQUB    $F0,$FA,$FA,$FA,$F4,$F4,$F4,$F4
        EQUB    $F5,$F0,$F0,$0F,$07,$07,$02,$02
        EQUB    $F6,$F0,$F0,$0F,$03,$03,$01,$01
        EQUB    $FA,$F0,$F0,$0F,$09,$09,$00,$00
        EQUB    $FC,$F0,$F0,$0F,$0C,$0C,$08,$08
        EQUB    $F4,$F0,$F0,$0F,$0E,$0E,$04,$04

        EQUB    $00,$86,$40,$00,$00,$00,$3F,$67
        EQUB    $6D,$61,$67,$65,$64,$61,$74,$61
        EQUB    $00,$86,$4C,$00,$00,$00,$DF,$65
        EQUB    $73,$74,$61,$72,$74,$00,$87,$0A
        EQUB    $00,$00,$00,$E7,$65,$73,$74,$61
        EQUB    $72,$74,$00,$87,$26,$00,$00,$00
        EQUB    $46,$72,$65,$74,$43,$6F,$6C,$00
        EQUB    $87,$42,$00,$00,$00,$68,$6E,$6F
        EQUB    $4C,$00,$04,$00,$A9,$80,$8D,$CA
        EQUB    $03,$4C,$E1,$5D,$00,$00,$00,$00 

        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00        

        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00 

        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00 

        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00 

        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00

        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00        

        EQUB    $00,$00,$00,$00,$00,$00,$00,$00                
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00                
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00        

.relocate_block_end

     
SAVE "Jetboa1", load, relocate_block_end, fn_start_point