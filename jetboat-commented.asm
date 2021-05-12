; zero page - variables
; 0400 - 04A0 - copied stuff
; 0540 - 05E0 - copied stuff
; 0740 - 07E0 - copied stuff
; 04A0 - 
; 0B40 - 

; OSWRCH uses VDU values

; Interesting pokes 
; timer_poke+1  =4
; ?&1605=4 or after load before execution ?&1BC5=4 

VDU_CURRENT_SCREEN_MODE = $0355
eventv_lsb_vector = $0220
eventv_msb_vector = $0221
mode7_start_addr = $7C00
dummy_screen_start = $8000
dummy_graphics_buffer_start = $0A00

;L0B40
. 
        LDA     #$00
        STA     zp_graphics_tiles_storage_lsb
        LDA     #$09
        STA     zp_graphics_tiles_storage_lsb

        LDX     #$1F
        JSR     L0B7C
;...

; This routine is called with an (x,y) tile coordinates 
; stored in zero page.
; 
; This routine does two key things:
; 1. Works out the tile type for the (x,y)
; 2. Looks up where the tile graphic data is held in memory;; 
;
; All the tile type data for all (x,y) coordinates is held
; starting at $3000.  
;       0 =< x < 128
;       0 =< y < 128
; 
; So 128 tiles across the map
; So 128 tiles down the map
;
; Simple algorithm for (x,y) tile type lookup
; 
;    tile memory address = $3000 + (x * $FF) + y
;
; More complex below as it's spread across 2 bytes
;
; So it does the following:
; 1. msb = x / 2 (LSR A)
; 2. lsb = 
; 3. msb = msb + $30 (effectively adds $3000 to the address)

;L0B7C
.fn_get_xy_tile_graphic_address
        ; Treats x as $x00 and divides by 2
        ; and adds y
        LDA     zp_map_pos_x
        LSR     A
        STA     zp_map_xy_tile_lookup_addr_msb
        LDA     #$00
        ROR     A
        ADC     zp_map_pos_y
        STA     zp_map_xy_tile_lookup_addr_lsb

        ; If carry was set adding to the lsb
        ; branch and increment the MSB
        BCS     increment_tile_lookup_msb

.get_tile_type_and_graphic_address
        ; Effectively add $3000 to the address
        LDA     #$30
        ADC     zp_map_xy_tile_lookup_addr_msb
        STA     zp_map_xy_tile_lookup_addr_msb
        
        LDY     #$00
        ; Find the tile at this (x,y) co-ordinate
        ; using the table at $3000+
        LDA     (zp_map_xy_tile_lookup_addr_lsb),Y

        ; Now we have the tile type
        ; reuse the same zero page locations 
        ; to store the tile graphic location
        ;
        ; Reset the MSB to zero
        ; Simple algorithm for tile type to memory location
        ; 
        ;    tile graphic address = $2800 + (type * 8)

        ; Set MSB to zero from Y
        STY     zp_map_xy_tile_lookup_addr_msb
        ; Multiple type by two 
        ASL     A
        ROL     zp_map_xy_tile_lookup_addr_msb
        ; Multiple type by two 
        ASL     A
        ROL     zp_map_xy_tile_lookup_addr_msb
        ; Multiple type by two 
        ASL     A
        ROL     zp_map_xy_tile_lookup_addr_msb
        ; Store LSB and MSB
        STA     zp_map_xy_tile_lookup_addr_lsb
        LDA     zp_map_xy_tile_lookup_addr_msb
        ; Add $2800 to address
        ADC     #$28
        STA     zp_map_xy_tile_lookup_addr_msb
        ; Finished
        RTS

.increment_tile_lookup_msb
        INC     zp_map_xy_tile_lookup_addr_msb
        ; Carry can never be set here, this just ends the function
        BCC     get_tile_type_and_graphic_address 

; TUESDAY'S FUNCTION      
.L0BAC
        
        ; Tile graphic buffer storage location
        LDA     #$00
        STA     zp_graphics_tiles_storage_lsb
        LDA     #$06
        STA     zp_graphics_tiles_storage_lsb
        ; In Mode 5 the screen is $27 / 39
        LDX     #$27
.L0BB6
        JSR     fn_get_xy_tile_graphic_address

        ; MODE 5 screen is blocks of 8 bytes per x/y
        ; position 
        LDY     #$07
.loop_copy_map_tile_block
        ; Load the first map tile (it's 8 bytes)
        ; and store it in the graphic buffer storage
        ; location
        LDA     (zp_map_xy_tile_lookup_addr_lsb),Y
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
        LDA     zp_graphics_tiles_storage_lsb
        ADC     #$00
        STA     zp_graphics_tiles_storage_lsb

        ; Loop until we have loaded all the map tiles
        ; up to FF
        INC     zp_map_pos_y
        BIT     zp_map_pos_y
        BPL     L0BD9

        ; Reset the y position to 0
        LDA     #$00
        STA     zp_map_pos_y
.L0BD9
        DEX
        BPL     L0BB6

        RTS

; 0BDD
.fn_break_handler
        ; Check to see if the CTRL key was also pressed
        LDX     #$FE
        ; TODO - does the break key or ctrl break set the interrupt flag?
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

; 0BF8
.fn_game_start
        ; Reset the stack pointer (not sure why)
        LDX     #$FF
        TXS
        
        ; Set the Break intercept vector to JMP to 0BDD
        ; Well don't because the  JMP isn't set to $47
        ; Wonder what 0BDD does...
        LDA     #$00
        STA     break_intercept_jmp_vector
        LDA     #$DD
        STA     break_intercept_lsb_vector
        LDA     #$0B
        STA     break_intercept_msb_vector

.main_game_loop
        ; Set memory to be cleared on Break 
        ; and disable escape key (*FX 200,3)
        ; OSBYTE &C8
        LDA     #$C8
.L0C0C
        LDX     #$03
        LDY     #$00
        JSR     OSBYTE

        ; Tell the OS to ignore the function keys
        ; OSBYTE $E1
        LDA     #$E1
        LDX     #$00
        LDY     #$00
        JSR     OSBYTE

        ; Initialize variables to zero
        ; Missing 0002, 0005, 0008, 0013-0018
        ; 0003
        ; 0004
        ; 0006
        ; 0007
        ; 0009
        ; 0010
        ; 0011
        ; 0012
        ; 0019
        ; 001A
        ; 001F
        ; 0024
        ; 0025
        ; 0062
        ; 0063
        ; 0064
        LDA     #$00
        STA     L0003
        STA     L0004
        STA     L0006
        STA     L0007
        STA     zp_score_lsb
        STA     zp_score_msb
        STA     L0019
        STA     L0024
        STA     L0025
        STA     L001A
        STA     L001F
        STA     L0009
        STA     zp_current_lap
        STA     L0062
        STA     L0063
        STA     zp_current_stage

        ; Look up the current lap time for completion
        LDX     zp_current_lap
        LDA     lap_times,X
        STA     zp_time_remaining_secs
        DEC     zp_time_remaining_secs

        ; start of loop 0004 is zero
        LDA     L0004
        STA     L0000
        STA     L0001

        ; Set the event handler for interval timer crossing 0 
        ; to be the set timer function
        LDA     #set_timer_64ms MOD 256
        STA     eventv_lsb_vector
        LDA     #set_timer_64ms DIV 256
        STA     eventv_msb_vector

        ; TODO add label
.L0C57
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

        ; More variable set up
        LDA     #$08
        STA     L0002

        ; MSB / LSB address? 0B75
        LDA     #$75
        STA     L0077
        STA     L0074
        LDA     #$0B
        STA     L0078
        STA     L0075

        ; Set start of screen address to &5800 for Mode 5
        LDA     #$00
        STA     zp_screen_start_lsb
        STA     L007A
        STA     L007C
        STA     L007B
        LDA     #$58
        STA     zp_screen_start_msb

        ; Store the vdu loop address in 1B and 1C
        LDA     #vdu_23_hide_cursor_params DIV 256
        STA     zp_vdu_23_hide_cursor_params_msb
        LDA     #vdu_23_hide_cursor_params MOD 256
        STA     zp_vdu_23_hide_cursor_params_lsb

        ; Set these to FF
        LDA     #$FF
        STA     L0079
        STA     L000F
        STA     L002A

        ; Set X=0
        LDX     #$00

        ; TODO SOME LOOP
.some_loop
        ; Set A=0
        TXA
        ; Push A=0 onto stack
        PHA
        ; No freaking idea yet what that subroutine does
        ; 1BDB
        JSR     fn_setup_read_lookup_table        

        PLA
        TAX
        INX
        CPX     #$0B
        BNE     some_loop

        ; Set variable 2A to 0
        LDA     #$00
        STA     L002A
        
        ; Select screen mode to 5
        ; MODE 5
        LDA     #$16
        JSR     OSWRCH
        LDA     #$05
        JSR     OSWRCH

        ; Set the sound duration offset
        ; lookup to 10
        LDA     #$0A
        STA     zp_sound_duration_offset

        ; Set the screen to black
        JSR     fn_set_colours_to_black

        ; Change the screen cursor
        JSR     fn_hide_cursor        

        ; Initialise graphic buffers
        JSR     init_graphics_buffers

        ; Load the current stage
        LDA     zp_current_stage

        ; Check if starting a new game or a new level
        BEQ     new_game_screen_text

        JSR     fn_print_next_stage_text

        JMP     game_setup

.new_game_screen_text
        JSR     fn_fill_screen_with_jet_boat               

.game_setup
        ; Reset current stage
        LDA     #$00
        STA     zp_current_stage

        ; Set the game colours
        JSR     fn_set_game_colours

        ; Pause for 2 seconds on the new game or
        ; next stage screen
        ; CA1 System VIA interrupts every 20 ms
        ; So ($64) 100 x 20 = 2 seconds
        LDA     #$64
        JSR     fn_wait_for_n_interrupts

        ; TODO Dunno more variables
        ; 255
        LDA     #$FF
        STA     L0023

        ; Map will be scrolled onto the screen 
        ; using 40 steps (including 0)
        LDA     #$27
        STA     zp_scroll_map_steps

.loop_scroll_map_start
        ; This loop scrolls the game start / new stage
        ; text off of the screen and scrolls the start
        ; of game map onto the screen

        ; TODO More variables reset
        LDA     #$00
        STA     L007C
        STA     L007B
        STA     L000C

        ; TODO LOOKING (Big function)
        ; Is this where it draws the map and scrolls into view
        JSR     L0D98          

        ; Wait for 60 ms before scrolling into view again
        ; CA1 System VIA interrupts every 20 ms
        ; So ($03) 3 x 20 = 60 ms
        LDA     #$03
        JSR     fn_wait_for_n_interrupts

        DEC     zp_scroll_map_steps
        BPL     loop_scroll_map_start

        ; NOW START THE GAME?  NEEDS CLOCK FIRST
        ; TODO DUNNO Reset some variables
        LDA     #$00
        STA     L0023
        LDA     #$00
        STA     L000F
        LDA     #$A0
        STA     L0026
        LDA     #$04
        STA     L0027

        ; Show the Get Ready icon
        JSR     fn_toggle_get_ready_icon

        ; Pause for 2 seconds (show icon for 2 seconds)
        ; CA1 System VIA interrupts every 20 ms
        ; So ($64) 100 x 20 = 2 seconds
        LDA     #$64
        JSR     fn_wait_for_n_interrupts

        JSR     enable_interval_timer  

        ; What is 14.... 
        INC     zp_time_remaining_secs

        ; Start the timer that changes the on screen
        ; remaining time.
        LDA     #$05
        JSR     set_timer_64ms   
        
        JSR     fn_play_boat_sounds

.L0D16
        LDA     zp_sound_duration_offset
        STA     zp_scroll_map_steps
.L0D1A
        ; Check to see if there is any remaining time
        ; left - continure if there is, otherwise branch ahead
        LDA     zp_time_remaining_secs
        BNE     L0D60

        JSR     L16BB

        JSR     fn_wait_20_ms

        JSR     L101E

        JSR     L122F

        LDA     #$00
        STA     L0026
        LDA     #$04
        STA     L0027
        JSR     fn_toggle_get_ready_icon

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
        LDX     #first_sound MOD 256
        LDY     #first_sound DIV 256
        LDA     #$07
        JSR     OSWORD

        ; Wait for 2 seconds ($64 / 100 * 20 ms)
        LDA     #$64
        JSR     fn_wait_for_n_interrupts

        ; Wait for 2 seconds ($64 / 100 * 20 ms)
        LDA     #$64
        JSR     fn_wait_for_n_interrupts

        ; Disable the interval timer crossing 0 event
        JSR     disable_interval_timer

        JSR     L1797

        JMP     main_game_loop
;0D60    

.L0D60
        ; Show get ready icon?
        JSR     L128D

        JSR     fn_play_boat_sounds

        DEC     zp_scroll_map_steps
        BPL     L0D1A

        LDA     zp_sound_duration_offset
        CMP     #$0A
        BCS     L0D7E

        INC     L0007
        LDA     L0007
        CMP     #$03
        BCC     L0D7E

        LDA     #$00
        STA     L0007
        INC     zp_sound_duration_offset
.L0D7E
        JSR     L1415

        JSR     L1451

        JSR     L0D98

        LDA     zp_current_stage
        BEQ     L0D8E

        JMP     L0C57
;....

; changing the screen start address?
; screen start address must be divided by 8 
; before sending
;0EBB
.fn_set_6845_screen_start_address
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
        STX     LFE00
        STA     LFE01

        ; Set 6845 Register to 13
        ; and give the LSB of the screen start
        ; address divided by 8
        INX
        STX     LFE00
        LDA     zp_screen_start_div_8_lsb
        STA     LFE01
        RTS

;....

;L0EDC
.fn_wait_20_ms
        ; This waits function waits 20 ms for an 
        ; interrupt from CA1 on the System VIA
        ; There's an interrupt every 20ms

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
; ...


;$0F2F
.fn_get_joystick_x
	; OSBYTE &80 reads the ADC chip
	; Reading channel 1 the x axis of the joystick
	; This part checks for left
        LDX     #$01
        LDA     #$80
        JSR     OSBYTE

.check_joystick_left
	; If the joystick MSB value > F5 (max FF) then assume user
	; is trying to go left
        CPY     #$F5
        BCS     left_or_right_detected

	; Not going left
        BCC     no_left_or_right_detected

.fn_check_joystick_right
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

;....

;1068
.fn_hide_cursor
        ; Hide the cursor 
        ; VDU 23 parameters are read from memory
        LDX     #$00
.vdu_23_hide_cursor_param_loop
        LDA     vdu_23_hide_cursor_params,X
        JSR     OSWRCH

        INX
        CPX     #$0A
        BNE     vdu_23_hide_cursor_param_loop

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
        ; Load value from 62 and keep the bottom two bits
        ; Pulls a column of colours from the banks
        ; X is used a the counter into which colour
        ; scheme will be used - there are 3 to choose from
        LDA     L0062
        AND     #$03
        TAX

        ; Reset first logical colour to be blue / 04
        LDA     #$04
        STA     palette_physical_colour
        LDA     #$00
        STA     palette_logical_colour


        ; Not sure what it calls this here
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
        ; Preserve X and A
        TXA
        PHA

        ; Parameter block address specified in X (LSB) / Y (MSB)
        ; Performs a VDU 12 / OSBYTE &0C to change the 
        ; Logical to physical colour mapping for one colour
        LDX     #colour_palette_block MOD 256
        LDY     #colour_palette_block DIV 256
        LDA     #$0C
        JSR     OSWORD

        ; Restore X and A
        PLA
        TAX
        RTS

        ; taken as a column not a row for the colours
        ; so possible combinations are:
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

.palette_logical_colour
        EQUB    $00
.palette_physical_colour        
        EQUB    $00
.palette_future_use_padding
        ; should always be set to zero as reserved
        ; for future use and don't do anything on 
        ; a BBC B
        EQUB    $00,$00,$00
;...

;1014
.fn_wait_for_n_interrupts
        ; Wait for n * 20 ms
        STA     zp_wait_interrupt_count
.loop_wait_for_interrupt
        JSR     fn_wait_20_ms

        DEC     zp_wait_interrupt_count
        BPL     loop_wait_for_interrupt

        RTS

;L101E
.fn_copy_graphics_from_buffer_to_screen
        ; Self modifying code - locations
        ; below default to 0A00 but could be 
        ; changed by code before this.  These
        ; values are used to indicate where to 
        ; copy 8 bytes from in the graphics buffer
        ; before writing to the screen. 
        LDA     #dummy_graphics_buffer_start MOD 256
        STA     load_from_graphics_buffer + 1
        LDA     #dummy_graphics_buffer_start DIV 256
        STA     load_from_graphics_buffer + 2

        LDX     #$27
.loop_copy_more_graphics
        LDY     #$07
.load_from_graphics_buffer
        ; In memory the address is stored LSB then MSB
        LDA     dummy_screen_start,Y
.write_to_screen_address
        ; In memory the address is stored LSB then MSB
        STA     dummy_screen_start,Y
        DEY
        ; Loop again until we have copied 8 bytes
        BPL     loop_copy_more_graphics

        ; Get the screen start address LSB
        LDA     write_to_screen_address + 1
        CLC

        ; Add 8 as we scroll from right to left <-
        ADC     #$08
        ; Update the LSB for the start address
        STA     write_to_screen_address + 1
        BCC     move_to_next_8 bytes

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
; L104B
        BCS     update_screen_start_address_msb

        ; Overlow of screen so wrap it to the 
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

.move_to_next_8 bytes
        ; Move to the next 8 bytes
        CLC
        LDA     write_to_screen_address + 1
        ADC     #$08
        STA     write_to_screen_address + 1
        BCC     no_screen_address_carry

        ; There was a carry (LSB > 255) so add
        ; 1 to the MSB for screen start address
        INC     write_to_screen_address + 2
.no_screen_address_carry
        DEX
        BPL    loop_copy_more_graphics

        RTS        
;....

.fn_colour_cycle_screen
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
        STA     L000C

        ; Scroll the sceen up a row
        JSR     fn_scroll_screen_up

        ; TODO
        JSR     L101E

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
        BNE     fn_colour_cycle_screen

        ; Default back to the standard game colours
        JSR     fn_set_game_colours

        RTS

;...

.palette_colour_cycle
        EQUB    $06,$05,$01,$07,$00,$06,$05,$07

;L14FF
.init_graphics_buffers
        ; TODO reference the 0Axx areas with variables

        ; Initialise the graphics buffer to $00
        ; from 0A00 to 0A9F and
        ; from 0AA0 to 0B3F
        LDA     #$00
        LDY     #$9F
.clear_graphics_buffer_loop
        STA     L0A00,Y
        STA     L0AA0,Y
        DEY
        CPY     #$FF
        BNE     clear_graphics_buffer_loop

        ; TIME and LAP icons are 32 bytes each
        LDY     #$1F
.buffer_time_and_lap_loop
        ; Copy the TIME icon to the graphics buffer
        LDA     L0568,Y
        STA     L0A08,Y
        ; Copy the LAP icon to the graphics buffer
        LDA     L0588,Y
        STA     L0AF8,Y
        DEY
        BPL     buffer_time_and_lap_loop

        ; 39 Bytes
        LDY     #$27
.buffer_score_loop
        ; Copy the SCORE icon to the graphics buffer
        LDA     L0540,Y
        STA     L0A68,Y
        DEY
        BPL     buffer_score_loop

        ; 7 bytes
        LDY     #$07
.buffer_blanks_loop
        ; TODO Maybe a hangover from the prototype?
        ; Or a graphics workspace
        ; Just blank areas on load
        LDA     L05A8,Y
        STA     L0A48,Y
        STA     L0AE0,Y
        STA     L0B38,Y

        DEY
        BPL     buffer_blanks_loop

        JSR     fn_draw_current_score

        JSR     fn_draw_time_counter

        JMP     fn_draw_lap_counter

.fn_calc_digits_for_display
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
        ; place in the buffer specified in X and Y no entry
        ; for the caller to move into display memory

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
        ADC     #graphics_numbers MOD 256
        STA     zp_graphics_numbers_lsb
        LDA     #$00

        ; Add the MSB for the where the number
        ; graphics are held in memory ($0740)
        ADC     #graphics_numbers DIV 256
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

.fn_print_high_score_numbers
; 15AC
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

;L15B8
.fn_draw_current_score
        PHP
        SEI
        LDA     zp_score_lsb
        STA     zp_number_for_digits_lsb
        LDA     zp_score_msb
        STA     zp_number_for_digits_msb
        LDA     #$04
        LDX     #$90
        LDY     #$0A
        JSR     fn_calc_digits_for_display

        LDA     #$40
        STA     zp_graphics_numbers_lsb
        LDA     #$07
        STA     zp_graphics_numbers_msb
        LDY     #$0F
.L15D5
        LDA     (zp_graphics_numbers_lsb),Y
        STA     (zp_graphics_numbers_target_storage_lsb),Y
        DEY
        BPL     L15D5

        PLP
        RTS

;L15DE
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

        ; 0B18
        ; Only need two digits and this uses
        ; the graphics at 0b18 I think...
        LDX     #$18
        LDY     #$0B
        LDA     #$02
        JMP     fn_calc_digits_for_display

;L15F2
.fn_draw_time_counter
        ; called before drawing jet boat text
        ; called after get ready
        ; Set counter to 10 / $0D
        LDA     zp_time_remaining_secs
        STA     zp_number_for_digits_lsb

        ; Set 0E to 00
        LDA     #$00
        STA     zp_number_for_digits_msb
        
        ; Call the function and say that we
        ; want 2 digits for the result
        ; and store the number graphics at
        ; $0A28
        LDX     #$28
        LDY     #$0A
        LDA     #$02
        JMP     fn_calc_digits_for_display

.set_timer_64ms
        ; EVENTV Interval Timer - called every 64ms
        ; Accumulator is always set to 5

        ; Preserve the status registers on the stack
        PHP

        ; At the start of the game or new level, 
        ; accumulator is set to 5 so will set up the 
        ; interval timer to count from 64 seconds

        ; An interrupt wil be generated when it crosses
        ; zero and this will be called again when that
        ; happens to reset the timer

        ; Looks like a testing artefact to stop the screen
        ; time decrementing - change to e.g.$04 and it will
        ; never decrement
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

        ; Set the interval timer to the 5 byte value at
        ; the location specified here ($1626 / var_int_timer_value)
        ; X - low byte, Y - high byte
        ; Defaults to 64 centiseconds
        LDX     #var_int_timer_value MOD 256
        LDY     #var_int_timer_value DIV 256
        LDA     #$04
        JSR     OSWORD

        ; If some counter variable is zero jump ahead
        ; Seems to be $47 or 71 on first invocation
        LDA     zp_time_remaining_secs
        BEQ     skip-loop

        ; Decrement counter
        DEC     zp_time_remaining_secs
        JSR     L15F2   

.skip-loop
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

;...

; 1626
.var_int_timer_value
        ; Countdown value for interval timer
        ; $BF / 64 centiseconds (just over half a second)
        ; ($FF-$BF = $40 / 64 cs)
        EQUB    $BF,$FF,$FF,$FF,$FF

.first_sound
        ; SOUND 1, 1, 110, 30
        ; Channel 1 (LSB MSB)
        EQUB    $01,$00
        ; Amplitude / loudness (LSB MSB)
        EQUB    $01,$00
        ; Pitch (LSB MSB) 
        EQUB    $6E,$00
        ; Duration (LSB MSB)
        EQUB    $1E,$00

; 1633
.enable_interval_timer
        ; Disable interval timer crossing 0 event
        ; timer increments every centisecond
        LDA     #$0E
        LDX     #$05
        LDY     #$00
        JMP     OSBYTE

.disable_interval_timer
        ; Disable interval timer crossing 0 event
        ; timer increments every centisecond
        LDA     #$0D
        LDX     #$05
        LDY     #$00
        JMP     OSBYTE

;....

;L16AD
.lap_times
        ; TODO Timings per stage or lap
        EQUB    $47,$3D,$33,$2E,$29,$26,$24,$21
        EQUB    $1F,$1C,$1A,$17,$15,$01

;L16BB
.fn_scroll_screen_up
        ; TODO
        ; Scroll up a row - can only scroll a full row 
        ; 16 bits / 2 bytes at a time up or down because
        ; the screen register is start address / 8
        ; and 8 pixels are are 16 bits because we're in mode 5
        ; where it's 2 bits per pixel
        ; 
        ; Subtract $140 / 320 from the screen start
        ; address
        LDA     zp_screen_start_lsb
        SEC
        SBC     #$40
        STA     write_to_screen_address + 1
        LDA     zp_screen_start_msb
        SBC     #$01
        JSR     L0B6D

        STA     write_to_screen_address + 2
        RTS

;16CE
; -------------------------------
; function - check s / q keys
.check_s_key
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
; end function - check s / q keys
; -------------------------------
; function - check f / c keys
.check_f_key
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
        JSR     enable_interval_timer

        ; TODO - Give this a variable name
        INC     zp_time_remaining_secs
        ; TODO - Some state flag for the main loop?
        LDA     #$05
        ; TODO - Main game loop?
        JSR     L1603

.check_freeze_keys_end
        RTS
; end function - check f / c keys
;L171F
.fn_add_time_to_score_and_display
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
        LDA     L1750,X
        STA     .sound_completed_lap_pitch
        LDA     L1755,X
        STA     .sound_completed_lap_duration

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
        LDX     #sound_completed_lap DIV 256
        LDY     #sound_completed_lap MOD 256
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
        ; OSWORD &07
        ; Play a sound - first boat 'put'
        ; Parameters are stored at $177C
        ; Sound 10, 0, 246, 245
        ; Sounds 10:
        ;   1 - Flush the channel and play this sound immediately
        ;   0 - Play on channel 0
        LDX     #sound_boat_move_first MOD 256
        LDY     #sound_boat_move_first DIV 256
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
        LDX     zp_sound_duration_offset
        LDA     duration_lookup_sound_x2,X
        STA     sound_x2_duration + 1
        LDX     #sound_boat_move_second MOD 256
        LDY     #sound_boat_move_second DIV 256
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
        ; TODO Pitch controlled by Envelope 3? 
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
; ....

.fn_display_high_score_table
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
        LDA     L1937,X
        STA     zp_number_for_digits_lsb
        LDA     L193F,X
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
        LDA     high_score_name_lsb,X
        STA     zp_high_score_name_msb
        LDY     #$00

.loop_display_high_score_name_n
        ; Load the next high score name
        ; Y is used to index the name string
        ; and only 12 characters are allowed?
        LDA     (zp_high_score_name_lsb),Y
        CMP     #$0D
        BEQ     skip_print_control_code

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

high_score_name_completed
        INX
        ; Have we displayed all the high scores?
        ; If not, loop around agan
        CPX     #$08
        BNE     display_high_score_n_loop

        ; End of function
        RTS

;L18B2
.fn_enter_high_score
        ; TODO SOMETHING WITH KEYBOARD BUFFER
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
.
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
        LDX     L0020

        ; Look up where the name is in memory
        ; As we're going to overwrite it
        LDA     high_score_name_lsb,X
        STA     L191A
        LDA     high_score_name_msb,X
        STA     L191B

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

;L191F
.fn_show_cursor
        LDY     #$00
;L1921
.vdu_23_show_cursor_param_loop
        LDA     vdu_23_show_cursor_params,Y
        JSR     OSWRCH

        INY
        ; Have we read all 10 bytes?
        ; If not, then loop again
        CPY     #$0A
        BNE     vdu_23_show_cursor_param_loop

        RTS

;L192D
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

;....

;1947
.high_score_name_lsb
        EQUB    $57,$6B,$7F,$93,$A7,$BB,$CF,$E3

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

;....

;1A8C
.string_enter_name
        ; Teletext control code - Alphanumeric magenta
        EQUB    $85
        ; Flash the text
        EQUB    $88
        ; String
        EQUS    "Please enter your name", $0D
        
        ; Teletext control code - block
        EQUB    $65

;L1AA5
.string_you_scored
        ; Teletext control code - Alphanumeric magenta
        EQUB    $85
        EQUS    "You scored"
        ; Teletext control code - Alphanumeric cyan
        EQUB    $86

;1AB1
.fn_fill_screen_with_jet_boat
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
        ; Set logical colour 3 to black 
        ; and update the palette
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
        ; Reads from memory and writes on the screen the
        ; Prepare to enter the next stage CONGRATULATIONS!
        ; text

        ; Set index counter to 0
        LDX     #$00
.loop_read_next_stage_chars
        ; Read next character from memory and write to screen
        LDA     next_stage_string,X
        JSR     OSWRCH
        ; Increment index counter, check if we have all 68 chars
        ; of the string if not loop again to get next one
        INX
        CPX     #$44
        BNE     loop_read_next_stage_chars

        RTS

.next_stage_string
        EQUS    $11,$00,$11,$01,$1F,$02,$10,"Prepare to enter",
        EQUS    $1F,$03,$12,"the next stage",
        EQUS    $1C,$01,$0A,$12,$08,$11,$03,$11,$82,$0C,$0A,$09
        EQUS    "CONGRATULATIONS!"
;...

; 1A2D
.fn_wait_for_intro_input
        ; Check sounds keys S/Q
        JSR     check_s_key
        
        ; Check if joystick button pressed
        JSR     fn_check_joystick_button

        ; If the joystick button was pressed, end the wait for input loop
        BNE     end_fn_wait_for_intro_input

        ; Check to see if space was pressed
        LDX     #$9D
        JSR     fn_read_key
        CPX     #$00

        ; It wasn't so loop again waiting for input
        BEQ     first_routine

.end_fn_wait_for_intro_input
        RTS

; ...

.L1B47
        ; Store the lookup table addres in 2B (MSB) and 2C (LSB)
        ; 
        STX     L002B
        STY     L002C

        ; Get the value at that address and store it in 2E
        LDY     #$00
        LDA     (L002B),Y
        STA     L002E

        ; Get the value at that address + 1 and store it in 2F
        INY
        LDA     (L002B),Y
        STA     L002F
        INY

        ; Get the value at that address + 2 and store it in 30  
        LDA     (L002B),Y
        STA     L0030
.L1B5B
        ; Y is now 3, set x = 0
        INY
        LDX     #$00

.load_lookup_table_loop
        ; Get the value at that address + 3 and store it in 33
        ; Read 30 values and store in 0030 - 0060 (why are first three values different)
        LDA     (L002B),Y
        STA     L0033,X
        INY
        INX
        ; Check to see if X is 30 or greater - if so loop
        CPX     L0030
        BNE     load_lookup_table_loop

        ; 
        LDA     (L002B),Y
        STA     L0032
        INY
        LDX     L0032
.L1B6F
        LDA     (L002B),Y
        STA     L0045,X
        INY
        DEX
        BPL     L1B6F

        LDX     L0032
.L1B79
        LDA     (L002B),Y
        STA     L0053,X
        INY
        DEX
        BPL     L1B79

        LDX     L0032
.L1B83
        ; Set 70 to 0 - then look at the second buffered value
        ; Put the lowest bit as the highest bit in 0070
        ; so 70 = $0 or $80 / 128
        LDA     #$00
        STA     zp_graphics_tiles_storage_lsb
        LDA     L0053,X
        LSR     A
        ROR     zp_graphics_tiles_storage_lsb
        ; add $30 to first buffered value and store in 71 (becomes 55)
        ADC     #$30
        STA     zp_graphics_tiles_storage_lsb
        ; Load the 10000000 or 00000000
        LDA     zp_graphics_tiles_storage_lsb
        ; Clear carry flag
        CLC
        ; add first buffer value to 0 or 128 and store it back in 70
        ADC     L0045,X
        STA     zp_graphics_tiles_storage_lsb

        ; 70 is now buffer 1[x] + 128 or 0
        ; 71 is now (buffer 2[x] / 2) + 30 = 55

        ; add zero to 71 (still 55)
        LDA     #$00
        ADC     zp_graphics_tiles_storage_lsb
        STA     zp_graphics_tiles_storage_lsb
        LDY     #$00
        TXA
        PHA
        LDA     L002F
        STA     L002D
        LDX     #$00
.L1BA7
        LDA     #$00
        STA     L0031
.L1BAB
        LDA     L0033,X
        ; Check to see if bit 7 is positive
        ; 2A is set to FF - top two bits are taking into overflow and zero
        BIT     L002A
        BPL     L1BB3

        ; if negative set Y to 3
        LDA     #$03
.L1BB3
        STA     (zp_graphics_tiles_storage_lsb),Y
        INY
        INX
        INC     L0031
        LDA     L0031
        CMP     L002E
        BNE     L1BAB

        LDA     #$80
        SEC
        SBC     L002E
        CLC
        ADC     zp_graphics_tiles_storage_lsb
        STA     zp_graphics_tiles_storage_lsb
        LDA     #$00
        ADC     zp_graphics_tiles_storage_lsb
        STA     zp_graphics_tiles_storage_lsb
        DEC     L002D
        LDA     L002D
        BNE     L1BA7

        PLA
        TAX
        DEX
        BPL     L1B83

        RTS


; 1BDB
.fn_setup_read_lookup_table
        ; There are 11 entries in the lookup
        ; table - when entering X = 0 so it'll
        ; loop across the lookup table addresses
        CPX     #$0B
        BCC     fn_read_lookup_table

        RTS

.fn_read_lookup_table
        LDY     lookup_table_msb,X
        LDA     lookup_table_lsb,X
        TAX
        JMP     L1B47

.lookup_table_lsb
        EQUB    $00,$21,$35,$51,$69,$81,$9A,$AE
        EQUB    $C4,$DA,$F1

.lookup_table_msb
        EQUB    $1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C
        EQUB    $1C,$1C,$1C

.high_score
        EQUS    $94,$9D,$87,"     ",$93,$F0,$F0,$F0,$B0," ",$96,$9A,$A0,$80,$B8,$A1,$F0,"  ",$B8,"                ",$94,$9D,$87,"HIGH ",$93,$FF,$A0," ",$FF,$9A,$96,$B6,$E0,$A6," ",$B6,$AC,$E1,$A6,$E3
        EQUS    $A1,$99,$93,$FF,"    ",$87,"SCORES ",$94,$9D,$87,"HIGH ",$93,$FF,$F0,$F0,$BF,$9A,$96,$A2,$A1,"  ",$A2,$A1,$A0,$A3,$A1,$99," ",$93,$FF,$AC,$AC,"  ",$87,"SCORES ",$94,$9D,$87,"HIGH "
        EQUS    $93,$FF,"  ",$FD,"  ",$FE,$A3,$A3,$FD,"  ",$A2,$A3,$A3,$FD,"  ",$FF,$9A,"   ",$87,"SCORES ",$94,$9D,$87,"HIGH ",$93,$FF,"  ",$FF,"  ",$FF,"  ",$FF,"  ",$FE,$A3,$A3,$FF,"  ",$FF,"  ",$FC," "
        EQUS    $87,"SCORES ",$94,$9D,$87,"     ",$93,$A3,$A3,$A3,$A1,"  ",$A2,$A3,$A3,$A1,"  ",$A2,$A3,$A3,$A1,"  ",$A2,$A3,$A3,$A1,"         "

;22D0
.high_score_screen
        EQUS    $94,$9D,$87,"     ",$93,$F0,$F0,$F0,$B0," ",$96,$9A,$A0,$80,$B8,$A1,$F0,"  ",$B8,"                ",$94,$9D,$87,"HIGH ",$93,$FF,$A0," ",$FF,$9A,$96,$B6,$E0,$A6," ",$B6,$AC,$E1,$A6,$E3
        EQUS    $A1,$99,$93,$FF,"    ",$87,"SCORES ",$94,$9D,$87,"HIGH ",$93,$FF,$F0,$F0,$BF,$9A,$96,$A2,$A1,"  ",$A2,$A1,$A0,$A3,$A1,$99," ",$93,$FF,$AC,$AC,"  ",$87,"SCORES ",$94,$9D,$87,"HIGH "
        EQUS    $93,$FF,"  ",$FD,"  ",$FE,$A3,$A3,$FD,"  ",$A2,$A3,$A3,$FD,"  ",$FF,$9A,"   ",$87,"SCORES ",$94,$9D,$87,"HIGH ",$93,$FF,"  ",$FF,"  ",$FF,"  ",$FF,"  ",$FE,$A3,$A3,$FF,"  ",$FF,"  ",$FC," "
        EQUS    $87,"SCORES ",$94,$9D,$87,"     ",$93,$A3,$A3,$A3,$A1,"  ",$A2,$A3,$A3,$A1,"  ",$A2,$A3,$A3,$A1,"  ",$A2,$A3,$A3,$A1,"         "

; ----------------------------------------------------------------------------------------
; Move Memory One off
; Currently from 5DC0 ++
; ----------------------------------------------------------------------------------------

	; First time through, var 6 will always
	; be 0 so will go to L5DD4
.fn_copy_memory
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


.start_point
        LDA     #$16    // Mode command
        JSR     OSWRCH

        LDA     #$07    // set to mode 7
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
        BEQ     init_vars

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
        LDA     #graphics_times_up_clock MOD 256
        STA     copy_from_lsb
        LDA     #graphics_times_up_clock DIV 256
        STA     copy_from_msb
        LDA     #$04
        STA     copy_to_msb
        LDA     #$A0
        STA     copy_size
        JSR     L5DC0
		
.copy_to_0540
        ; Copys the Score, Time, Lap Graphics
	; copy_from = &5F60 (to &5FFF)
	; copy_to   = &0540  Basic Workspace
	; copy_size = $A0 bytes (unchanged)
        LDA     #$40
        STA     copy_to_lsb
        LDA     #graphics_icons MOD 256
        STA     copy_from_lsb
        LDA     #graphics_icons DIV 256
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
        LDA     #graphics_numbers MOD 256
        STA     copy_from_lsb
        LDA     #graphics_numbers DIV 256
        STA     copy_from_msb
        LDA     #$07
        STA     copy_to_msb
        JSR     fn_copy_memory

.copy_to_04A0
        ; Copys the Get Ready Icon
	; copy_from = &64B0  (to &654F)
	; copy_to   = &04A0  Basic Workspace
	; copy_size = $A0 bytes (unchanged)		
        LDA     #graphics_get_ready_icon MOD 256
        STA     copy_from_lsb
        LDA     #graphics_get_ready_icon DIV 256
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
        LDA     #$intro_screen MOD 256
        STA     copy_from_lsb
        LDA     #$7C
        STA     copy_to_msb
        LDA     #intro_screen DIV 256
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
	
        ; Wait for user input to start game (in game code)
        JSR     fn_wait_for_intro_input 

        JMP     fn_game_start

;....   
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
        EQUB    $F0,$F7,$F4,$F7,$F1,$F1,$F7,$F0
        EQUB    $F0,$F7,$F4,$F4,$F4,$F4,$F7,$F0
        EQUB    $F0,$F7,$F5,$F5,$F5,$F5,$F7,$F0
        EQUB    $F0,$F7,$F5,$F5,$F6,$F5,$F5,$F0
        EQUB    $F0,$F6,$F4,$F6,$F4,$F4,$F6,$F0

        EQUB    $F0,$F0,$80,$D0,$D0,$D0,$D0,$F0
        EQUB    $F0,$F0,$A0,$A0,$A0,$A0,$A0,$F0
        EQUB    $F0,$F0,$40,$A0,$A0,$A0,$A0,$F0
        EQUB    $F0,$F0,$90,$B0,$90,$B0,$90,$F0
        EQUB    $10,$10,$10,$10,$10,$10,$10,$10

        EQUB    $F0,$00,$40,$40,$40,$40,$60,$00
        EQUB    $F0,$00,$40,$A0,$E0,$A0,$A0,$00
        EQUB    $F0,$00,$E0,$A0,$E0,$80,$80,$00
        EQUB    $80,$80,$80,$80,$80,$80,$80,$80
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
        EQUB    $00,$00,$00,$00,$00,$00,$00,$00
	
     