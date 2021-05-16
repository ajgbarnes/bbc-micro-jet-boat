; zero page - variables
; 0400 - 04A0 - copied stuff
; 0540 - 05E0 - copied stuff
; 0740 - 07E0 - copied stuff
; 04A0 - 
; 0B40 - 

; From basic loader:
;ENVELOPE 1,  1,70,16,2,2,0,0,126, 0,0,-126,110,110
;ENVELOPE 2,129, 2, 0,0,0,0,0, 40,-8,0,  -2,126, 45
;ENVELOPE 3,129, 1,-1,0,0,0,0,  0, 0,0,   0,  0,  0

; OSWRCH uses VDU values

; Interesting pokes 
; timer_poke+1  =4
; ?&1605=4 or after load before execution ?&1BC5=4 

VDU_CURRENT_SCREEN_MODE = $0355
eventv_lsb_vector = $0220
eventv_msb_vector = $0221
mode7_start_addr = $7C00
dummy_screen_start = $8000
dummy_graphics_load_start = $8000
graphics_buffer_start = $0A00
mode_5_screen_centre =  $6A10

;L0B40
.fn_write_tiles_to_off_screen_buffer
        ; Define the off screen buffer where we'll
        ; assemble the right tile graphics, in this
        ; case at $0900
        LDA     #$00
        STA     zp_graphics_screen_or_buffer_lsb
        LDA     #$09
        STA     zp_graphics_screen_or_buffer_msb

        ; 32 tiles are required
        LDX     #$1F

;L0B4A        
.loop_get_next_tile
        ; Get the memory address of the nth tile's
        ; source graphic
        JSR     fn_get_xy_tile_graphic_address
.L0B4D
        ; Copy all 8 bytes of the graphic
        LDY     #$07

.loop_next_tile_byte
        ; to the off screen buffer
        LDA     (zp_general_purpose_lsb),Y
        STA     (zp_graphics_screen_or_buffer_lsb),Y
        DEY
        ; If there are still some bytes left to copy
        ; loop around
        BPL     next_tile_byte

        ; Increment the write address of the off screen
        ; buffer by 8 bytes 
        LDA     zp_graphics_screen_or_buffer_lsb
        CLC
        ADC     #$08
        STA     zp_graphics_screen_or_buffer_lsb

        ; Increment the x position in the (x,y)
        ; coordinates
        INC     zp_map_pos_x
        LDA     zp_map_pos_x

        ; The x position can only go up to $50 / 80
        CMP     #$50
        BNE     get_next_tile

        ; Reset the x position in the (x,y)
        ; coordinates to 0 when greater than or equal
        ; to $50 / 80
        LDA     #$00
        STA     zp_map_pos_x
.get_next_tile
        ; Do we still have some of the 32 tiles to get?
        DEX
        BPL     loop_get_next_tile

        RTS

; L0B6D
.fn_check_screen_start_address
        ; When scrolling down,
        ; if the screen start address is > $8000
        ; then we need to loop it back to $5800
        ; which is achieved by subtracting $2800
        CMP     #$80
        BCS     reset_screen_to_start

        ; When scrolling up,
        ; if the screen start address is < $5800
        ; then we need to loop it back to $8000
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
        STA     zp_general_purpose_msb
        LDA     #$00
        ROR     A
        ADC     zp_map_pos_y
        STA     zp_general_purpose_lsb

        ; If carry was set adding to the lsb
        ; branch and increment the MSB
        BCS     increment_tile_lookup_msb

.get_tile_type_and_graphic_address
        ; Effectively add $3000 to the address
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
        INC     zp_general_purpose_msb
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

.restart_game
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
        STA     zp_turn_left_counter
        STA     zp_turn_right_counter
        STA     zp_acceleration_counter
        STA     zp_decelerate_counter
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
        STA     zp_stage_completed_status

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
        LDA     #fn_set_timer_64ms MOD 256
        STA     eventv_lsb_vector
        LDA     #fn_set_timer_64ms DIV 256
        STA     eventv_msb_vector

;L0C57
.new_stage
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

        ; Store the vdu parameter block address in 1B and 1C
        LDA     #mode_5_screen_centre DIV 256
        STA     zp_screen_target_msb
        LDA     #mode_5_screen_centre MOD 256
        STA     zp_screen_target_lsb

        ; TODO 
        ; Set these to $FF / 255
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

        ;TODO 
        ; Set variable 2A to 0
        LDA     #$00
        STA     L002A
        
        ; Select screen mode to 5
        ; MODE 5
        LDA     #$16
        JSR     OSWRCH
        LDA     #$05
        JSR     OSWRCH

        ; Set the boat speed to 10
        ; Used to scroll the map and also
        ; to change the duration of the boat 'put'
        ; sound
        LDA     #$0A
        STA     zp_boat_speed

        ; Set the screen to black
        JSR     fn_set_colours_to_black

        ; Change the screen cursor
        JSR     fn_hide_cursor        

        ; Initialise graphic buffers
        JSR     init_graphics_buffers

        ; Load the current stage
        LDA     zp_stage_completed_status

        ; Check if starting a new game or a new level
        BEQ     new_game_screen_text

        JSR     fn_print_next_stage_text

        JMP     game_setup

.new_game_screen_text
        JSR     fn_fill_screen_with_jet_boat               

.game_setup
        ; Reset current stage
        LDA     #$00
        STA     zp_stage_completed_status

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
        ; using 40 steps (including 0) - this is because
        ; in Mode 5 there are 40 columns of bytes
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

        ; Continue to scroll if we haven't 
        ; moved fully into view
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

        JSR     fn_enable_interval_timer  

        ; What is 14.... 
        INC     zp_time_remaining_secs

        ; Start the timer that changes the on screen
        ; remaining time.
        LDA     #$05
        JSR     fn_set_timer_64ms   
        
        JSR     fn_play_boat_sounds

;L0D16
.main_game_loop
        LDA     zp_boat_speed
        STA     zp_scroll_map_steps
.L0D1A
        ; Check to see if there is any remaining time
        ; left - continue if there is, otherwise branch ahead
        LDA     zp_time_remaining_secs
        BNE     still_game_time_left

        JSR     fn_scroll_screen_up

        JSR     fn_wait_20_ms

        JSR     fn_copy_time_score_lap_to_screen

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
        ; Play the times up sound
        LDX     #sound_times_up MOD 256
        LDY     #sound_times_up DIV 256
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

        JMP     restart_game

;0D60    
.still_game_time_left
        ; Check for keyboard or joystick input
        JSR     fn_check_keys_and_joystick

        ; Play the boat "putt putt" sounds 
        ; and vary based on speed
        JSR     fn_play_boat_sounds

        DEC     zp_scroll_map_steps
        BPL     L0D1A

        ; Boat speed is from 0 to A
        ; Check the boat speed - if we're at the minimum
        ; speed then don't do anything, otherwise,
        ; every three times around, reduce the speed
        ; (counter intuitively by incrementing this variable)
        ; 0A is the minimum, 00 is tha maximum
        LDA     zp_boat_speed
        ; Are we at minimum speed of $0A (or higher!), if so branch
        CMP     #$0A
        BCS     post_delecerate_check

        ; If we're beyond minimum speed, every third time around
        ; the loop we'll slow down - means the player has to keep their
        ; finger on accelerate to counter it.
        INC     zp_decelerate_counter
        LDA     zp_decelerate_counter
        CMP     #$03
        BCC     post_delecerate_check

        ; Third time around loop, decrease boat speed
        LDA     #$00
        STA     zp_decelerate_counter
        INC     zp_boat_speed
;L0D7E
.post_decelerate_check
        JSR     L1415

        JSR     L1451

        JSR     L0D98

        ; Check to see if the stage has been
        ; completed - if it has go back to the the
        ; initialisation part and show the congratulations
        ; messages, if not, branch ahead
        LDA     zp_stage_completed_status
        BEQ     stage_not_complete

        JMP     new_stage

;0D8E
.stage_not_complete
        JMP     main_game_loop

;0D91
.fn_read_key
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

.L0D98
        ; Neat way to check to see if a memory
        ; address is set in 7B/7C - if either
        ; has a value, don't branch
        LDA     L007C
        EOR     L007B
        BEQ     L0E12

        ; Check to see if the value in L007B
        ; is negative - if it's positive, branch
        BIT     L007B
        BPL     L0DCB

        DEC     L0078
        BPL     L0DAA

        ; Set to 79 or 80
        LDA     #$4F
        STA     L0078   
;
.L0E12
        ; Neat way to check to see if a memory
        ; address is set in 7B/7C - if either
        ; has a value, don't branch
        LDA     L0079
        EOR     L007A
        BEQ     L0E85

        ; Check to see if the value in L0079
        ; is negative - if it's positive, branch
        BIT     L0079
        BPL     L0E58

        ; If 77 is positive then branch...
        INC     L0077
        LDA     L0077
        BPL     L0E26

        LDA     #$00
        STA     L0077

.L0E26
        ; When scrolling the screen to the left,
        ; calculate where the top right pixels will be
        ; Current screen start address + $140 / 320
        ; That's where we're going to write the next
        ; tile so update the routine with those values
        CLC
        LDA     zp_screen_start_lsb
        ADC     #$40
        STA     L0EFE
        LDA     zp_screen_start_msb
        ADC     #$01
        ; Check the start address gone beyond $8000
        ; and correct it if it did - only important
        ; for the MSB not the LSB
        JSR     fn_check_screen_start_address
        STA     L0EFF

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

        LDA     L0078
        STA     zp_map_pos_x
        LDA     L0077
        CLC
        ADC     #$27
        AND     #$7F
        STA     zp_map_pos_y
        JSR     L0B40

.L0E58
        BIT     L007A
        BPL     L0E85

        DEC     L0077
        BPL     L0E64

        LDA     #$7F
        STA     L0077
.L0E64
        ; Move the screen right by 4 pixels / one byte
        ; Calculate the new screen start 
        LDA     zp_screen_start_lsb
        SEC
        SBC     #$08
        STA     zp_screen_start_lsb
        STA     L0EFE
        LDA     zp_screen_start_msb
        SBC     #$00
        ; Check the start address gone bel0w $5800
        ; and correct it if it did        
        JSR     fn_check_screen_start_address
        STA     zp_screen_start_msb
        STA     L0EFF

        LDA     L0078
        STA     zp_map_pos_x
        LDA     L0077
        STA     zp_map_pos_y
        JSR     L0B40    

.L0E85
        JSR     fn_scroll_screen_up

        SEI
        JSR     fn_wait_20_ms

        JSR     fn_set_6845_screen_start_addresss

        LDA     L007C
        EOR     L007B
        BEQ     L0E98

        JSR     L0F5B

.L0E98
        LDA     L0079
        EOR     L007A
        BEQ     L0EA1

        JSR     L0EEC    

.L0EA1

;gets called 41 times on screen load
        LDA     L000F
        BMI     L0EAC

        LDA     #$00
        STA     L000C
        JSR     L118A   

.L0EAC
        LDA     L000C
        BMI     L0EB3

        JSR     fn_copy_time_score_lap_to_screen

.L0EB3
        CLI
        JSR     L10D6

        JSR     L1645

        RTS             

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

.L0EEC
        ; $0900 is the tile buffer
        ; Write the load address 
        LDA     #$00
        STA     L0EFB
        LDA     #$09
        STA     L0EFC
        LDX     #$1F
.L0EF8
        LDY     #$07
.copy_graphics
        LDA     dummy_graphics_load_start,Y
L0EFB = L0EFA+1
L0EFC = L0EFA+2
.L0EFD
        STA     dummy_screen_start,Y
L0EFE = L0EFD+1
L0EFF = L0EFD+2
        DEY
        BPL     L0EFA

.L0F03
        LDA     L0EFE
L0F04 = L0F03+1

        ; Moves the screen write address down a row
        ; Each row is $0140 / 320 bytes 
        ; So we add this to the current
        ; write address
        CLC
        ADC     #$40
        STA     L0EFE
        LDA     L0EFF
.L0F0F
        ; Check to see if the screen start address
        ; is greater than the top of screen memory
        ; which is $8000
        ADC     #$01
        CMP     #$80
        BCS     handle_screen_write_overflow

        ; Check to see if the screen start address
        ; is greater than or equals the bottom of screen 
        ; memory which is $5800
        CMP     #$58
        BCS     L0F1F
        
        ; Underflow of write address so wrap it to the 
        ; top of screen memory
        ADC     #$28
        BCC     L0F1F

;L0F1D
.handle_screen_write_overflow
        ; Screen write address was higher than
        ; top of screen memory, so loop it to the 
        ; bottom of screen memory ($5800) by subtracting
        ; $28 from $80 in the MSB of screen start address
        SBC     #$28

.L0F1F
        STA     L0EFF
        CLC
        LDA     L0EFB
        ADC     #$08
        STA     L0EFB
        DEX
.L0F2C
        BPL     L0EF8

        RTS

;$0F2F
.fn_check_joystick_left
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

;....
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
.fn_copy_time_score_lap_to_screen
        ; Copy the buffered graphics for the remaining time,
        ; the score and the lap total to the screen
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
        BPL     loop_copy_more_graphics

        ; Get the screen start address LSB
        LDA     write_to_screen_address + 1
        CLC

        ; We just copied 8 bytes so increment the start
        ; addres and move to the next 8 bytesbytes
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

;1068
.fn_hide_cursor
        ; Hide the cursor 
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

.colour_palette_block
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
       
;L122F
.fn_draw_boat_on_screen
        ; Reset L0008 to zero       
        LDA     #$00
        STA     L0008

        ; Copy the boat graphic source address to our 
        ; working variables
        LDA     zp_graphics_source_lsb
        STA     zp_general_purpose_lsb
        LDA     zp_graphics_source_msb
        STA     zp_general_purpose_msb

        ; Copy the target screen address to our working
        ; variables
        LDA     zp_screen_target_lsb
        STA     zp_graphics_screen_or_buffer_lsb
        LDA     zp_screen_target_msb
        STA     zp_graphics_screen_or_buffer_msb

        ; A boat is made of three graphic "chunks"
        ; of 8 x 5 bytes so it's 120 bytes per boat
        CLC
        LDA     #$03
        STA     zp_graphics_chunks_remaining

;L1248
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
        BEQ     .black_byte

        ; EOR it onto the screen
        EOR     (zp_graphics_screen_or_buffer_lsb),Y
        ; Store the EOR'd graphic
        STA     (zp_graphics_screen_or_buffer_lsb),Y
.source_black_byte
        ; Get the next byte of the graphic to copy
        DEY
        BPL     copy_graphic_8bytes

        ; Get the next block of 8 bytes of the source graphic
        ; By incrementing the LSB by 8
        CLC
        LDA     zp_graphics_screen_or_buffer_lsb
        ADC     #$08
        STA     zp_graphics_screen_or_buffer_lsb
        ; Carry is clear then no need to increment the MSB
        BCC     source_carry_clear

        ; Add the carry to the MSB
        LDA     zp_graphics_screen_or_buffer_msb
        ADC     #$00
        
        ; If we went beyond $80xx for the screen address
        ; reset it to the start of the screen ($58xx)
        JSR     fn_check_screen_start_address

        ; Store the updated MSB and clear the carry flag
        STA     zp_graphics_screen_or_buffer_msb
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
        LDA     zp_graphics_screen_or_buffer_lsb
        ADC     #$18
        STA     zp_graphics_screen_or_buffer_lsb
        LDA     zp_graphics_screen_or_buffer_msb
        ADC     #$01
        JSR     fn_check_screen_start_address

        CLC
        STA     zp_graphics_screen_or_buffer_msb
        DEC     zp_graphics_chunks_remaining
        BPL     get_next_graphic_chunk

        RTS

;L128D
.fn_check_keys_and_joystick
        ; Read key presses and joystick 
        ; and turn or accelerate boat
        ;  TODO 
        JSR     L1308

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

        ; Remove the Get Ready icon
        ; And remove the boat? 
        JSR     fn_toggle_get_ready_icon

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
        LDX     #$9E
left_key_game = read_left_key+1
        JSR     fn_read_key

        ; If key is being pressed then X will be $FF
        CPX     #$FF
        ; If it wasn't then branch ahead to check right
        BNE     check_right

;L12AB
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
;L12C0
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
        LDX     #$BD
right_key_game = read_right_key+1
        JSR     fn_read_key

        ; If key is being pressed then X will be $FF
        ; If it wasn't then branch ahead to check accelerate
        CPX     #$FF
        BNE     check_accelerate

;L12CE
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

;L12E3
.check_accelerate
        JSR     fn_check_joystick_button

        BNE     L12F1

.read_accelerate
        ; Check to see if the accelerate key has been pressed
        ; The value is changed programmatically to be 
        ; the user defined or default key from the loading
        ; menus - defaults to be Ctrl from the menus
        ; but shift in the code below   
        LDX     #$FF
accel_key_game = read_accelerate+1
        JSR     fn_read_key

        ; If key is being pressed then X will be $FF
        ; If it wasn't then branch ahead to check accelerate
        CPX     #$FF
        BNE     L1303

;L12F1
.accelerate_detected
        ; Detects acceleration 6 times in a row
        ; before doing anything - so we don't accelerate too
        ; fast
        ; TODO Are 05 and 06 both boat speed?
        ; Is 6 acceleration?
        INC     zp_acceleration_counter
        LDA     zp_acceleration_counter

        ; If the acceleration hasn't reached 6
        ; do nothing (branch ahead)
        CMP     #$06
        BNE     redraw_screen

        ; Set the acceleration to zero
        ; So we don't do the next increment of
        ; speed until we have detected 
        LDA     #$00
        STA     zp_acceleration_counter

        ; Are we already at top speed ($00) 
        ; Speed goes from 10 slow to 0 fast
        LDA     zp_boat_speed
        BEQ     redraw_screen

        ; Increase speed by (counter-intuitively?)
        ; reducing this variable
        DEC     zp_boat_speed

        ; TODO
; 1303
.redraw_screen
        JSR     L11ED

        ; Enable maskable interrupts and return
        CLI
        RTS

.L1308
        ; Use the direction of the boat which
        ; is stored as 0 - 15, to lookup
        ; which function we should call
        ; This is done by doubling the value and using
        ; it as an offset from the start of the function lookup
        ; table.  Each function address in the table is 2 bytes 
        ; in the table hence having to double the direction.
        LDA     zp_boat_direction
        ASL     A
        TAX
        LDA     lookup_table_boat_direction_fns,X
        STA     zp_addr_fn_boat_direction_lsb
        INX
        LDA     lookup_table_boat_direction_fns,X
        STA     zp_addr_fn_boat_direction_msb
        JMP     (zp_addr_fn_boat_direction_lsb)

;L131A
.lookup_table_boat_direction_fns
        ; Function look up table?
        EQUB    fn_boat_direction_0 MOD 256, fn_boat_direction_0 DIV 256
        EQUB    fn_boat_direction_1 MOD 256, fn_boat_direction_1 DIV 256
        EQUB    fn_boat_direction_2 MOD 256, fn_boat_direction_2 DIV 256
        EQUB    fn_boat_direction_3 MOD 256, fn_boat_direction_3 DIV 256
        EQUB    fn_boat_direction_4 MOD 256, fn_boat_direction_4 DIV 256
        EQUB    fn_boat_direction_5 MOD 256, fn_boat_direction_5 DIV 256
        EQUB    fn_boat_direction_6 MOD 256, fn_boat_direction_6 DIV 256
        EQUB    fn_boat_direction_7 MOD 256, fn_boat_direction_7 DIV 256
        EQUB    fn_boat_direction_8 MOD 256, fn_boat_direction_8 DIV 256
        EQUB    fn_boat_direction_9 MOD 256, fn_boat_direction_9 DIV 256
        EQUB    fn_boat_direction_10 MOD 256, fn_boat_direction_10 DIV 256
        EQUB    fn_boat_direction_11 MOD 256, fn_boat_direction_11 DIV 256
        EQUB    fn_boat_direction_12 MOD 256, fn_boat_direction_12 DIV 256
        EQUB    fn_boat_direction_13 MOD 256, fn_boat_direction_13 DIV 256
        EQUB    fn_boat_direction_14 MOD 256, fn_boat_direction_14 DIV 256
        EQUB    fn_boat_direction_15 MOD 256, fn_boat_direction_15 DIV 256

; 133A
.fn_boat_direction_0
        ; Boat direction 0 - $133A
        JSR     L13DA
        JMP     L13BA

        ; Boat direction 1 - $1340
.fn_boat_direction_1
        JSR     L13BA
        JMP     L13D2

.fn_boat_direction_2
        ; Boat direction 2 - $1346
        JSR     L13BA
        JMP     L13CA

.fn_boat_direction_3
        ; Boat direction 3 - $134C
        JSR     L13C2
        JMP     L13CA

.fn_boat_direction_4
        ; Boat direction 4 - $1352
        JSR     L13E5
        JMP     L13CA

.fn_boat_direction_5
        ; Boat direction 5 - $1358
        JSR     L13CA
        JMP     L13A2
        
.fn_boat_direction_6
        ; Boat direction 6 - $135E
        JSR     L13CA
        JMP     L139A

.fn_boat_direction_7
        ; Boat direction 7 - $1364
        JSR     L13D2
        JMP     L139A

.fn_boat_direction_8
        ; Boat direction 8 - $136A
        JSR     L13DA
        JMP     L139A

.fn_boat_direction_9
        ; Boat direction 9 - $1370
        JSR     L13B2
        JMP     L139A

.fn_boat_direction_10
        ; Boat direction 10 - $1376
        JSR     L13AA
        JMP     L139A

.fn_boat_direction_11
        ; Boat direction 11 - $137C
        JSR     L13AA
        JMP     L13A2

.fn_boat_direction_12
        ; Boat direction 12 - $1382
        JSR     L13E5
        JMP     L13AA

.fn_boat_direction_13        
        ; Boat direction 13 - $1388
        JSR     L13AA
        JMP     L13C2

.fn_boat_direction_14
        ; Boat direction 14 - $138E
        JSR     L13AA
        JMP     L13BA

.fn_boat_direction_15
        ; Boat direction 15 - $1394
        JSR     L13B2
        JMP     L13BA
       
;....

;L148D
.fn_colour_cycle_screen
        ; When the boat has run aground, colour cycle
        ; the palette

        ; TODO Reset something to 4...
        LDA     #$04
        STA     L0009

        ; OSWORD &07
        ; Play boat aground sound one
        ; Parameters are stored at $14E7
        ; All sounds use Envelope 2 (2nd parameter)        
        LDX     #sound_boat_aground_first MOD 256
        LDY     #sound_boat_aground_first DIV 256
        LDA     #$07
        JSR     OSWORD

        ; OSWORD &07
        ; Play sound two
        ; Parameters are stored at $14EF
        ; All sounds use Envelope 2 (2nd parameter)   
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
        JSR     fn_scroll_screen_up

        JSR     fn_copy_time_score_lap_to_screen_to_screen

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

;L14FF
.fn_init_graphics_buffers
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

.fn_set_timer_64ms
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
        ; TODO MAY NOT BE SCROLL MAY BE PREVIOUS LINE
        ; CALCULATION
        ;
        ; Scroll up a row - can only scroll a full row 
        ; 16 pixels / 8 bytes at a time up or down because
        ; the screen register is start address DIV 8
        ; 
        ; Subtract $140 / 320 from the screen start
        ; address
        LDA     zp_screen_start_lsb
        SEC
        SBC     #$40
        STA     write_to_screen_address + 1
        LDA     zp_screen_start_msb
        SBC     #$01
        JSR     fn_check_screen_start_address

        STA     write_to_screen_address + 2
        RTS

;16CE
; -------------------------------
; function - check s / q keys
.fn_check_sound_keys
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

.       check_q_key
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
.fn_check_freeze_continue_keys
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
        LDX     zp_boat_speed
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

; L1797
.fn_did_score_make_high_score_table
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

;L17B4
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
        LDA     high_score_names
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
        BEQ     demote_high_scores

        ; Move to the next high score in the table
        DEX
        JMP     demote_high_scores

.high_scores_demoted
        ; Write the player's score into the 
        ; write part of the high score array
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

.high_score_name_completed
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
        LDX     zp_high_score_position

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

;L1937
; The 8 high scores stored in LSB and MSB locations
; Scores are highest to lowest and divided by 10 when stored
.high_score_lsb
        EQUB    $5E,$2C,$FA,$C8,$64,$4B,$32,$19

;L193F
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
        ; Write 40 spaces to the bottom of the Mode 7 screen
        ; Not sure why this isn't down with OSWRCH like the
        ; rest
        LDX     #$00
        ; Code for space
        LDA     #$20
.write_space_to_screen
        ; Write to the bottom line of the screen        
        STA     L7FC0,X
        INX
        ; Have we written 40 spaces?
        CPX     #$28
        ; If not loop back around
        BNE     write_space_to_screen

        LDA     #$81
        STA     L7FC0
        LDA     #$9D
        STA     L7FC1

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
;L1A1F
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
        BEQ     first_routine

.end_fn_wait_for_intro_input
        RTS

; 1A3F
.fn_show_player_score_below_high_scores
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

;L1A50
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

;L1A6D
.string_press_space_or_fire
        EQUS    $87,$88,"Press SPACE or FIRE to start",$0D,$85

;L1A8C
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
        LDA     string_next_stage,X
        JSR     OSWRCH
        ; Increment index counter, check if we have all 68 chars
        ; of the string if not loop again to get next one
        INX
        CPX     #$44
        BNE     loop_read_next_stage_chars

        RTS

.string_next_stage
        EQUS    $11,$00,$11,$01,$1F,$02,$10,"Prepare to enter",
        EQUS    $1F,$03,$12,"the next stage",
        EQUS    $1C,$01,$0A,$12,$08,$11,$03,$11,$82,$0C,$0A,$09
        EQUS    "CONGRATULATIONS!"

;1B46

; TODO
.L1B47
        ; Store the lookup table address in 2B (MSB) and 2C (LSB)
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

        ; 1C00 + 2 controls how many times around this loop
        ; Once, tracked by X
.load_lookup_table_loop
        ; Get the value at that address + 3 and store it in 33
        ; Read 30 values and store in 0030 - 0060 (why are first three values different)
        LDA     (L002B),Y
        STA     L0033,X
        ; Y now 4
        INY
        INX
        ; Check to see if X is 30 or greater - if so loop
        CPX     L0030
        BNE     load_lookup_table_loop

        ; 
        LDA     (L002B),Y
        STA     L0032
        ;Y now 5
        INY
        ; X set to 0D
        LDX     L0032
.L1B6F
        LDA     (L002B),Y
        ; L0038 to L0045 set to (reversed though)
        ; 32 31 2F 30 33 7F 7E 7D 7F 7E 4A 4B 4A
        ; LSB of graphic
        STA     L0045,X
        ; y is now 6
        INY
        DEX
        BPL     L1B6F

        LDX     L0032
.L1B79
        ; L0046 to L0053 set to (reversed though)
        ; 4A 4C 4B 4C 4C 4D 4C 17 18 17 15 19 26
        ; MSB of graphic
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

; take the value we found in memory, divide it by 2
; and add $30 / 48 to it and save in 
; Take bit 1 and roll into 
        LDA     L0053,X
        ; Divide A by two
        LSR     A

        ; Roll the carry clag in the LSB just to throw away
        ; the carry (why not use CLC?)
        ROR     zp_graphics_tiles_storage_lsb
        ; add $30 to first buffered value and store in 71 (becomes 55)

        ; Add $30 / 48
        ADC     #$30

        ; Store result in LSB throwing away carry above
        STA     zp_graphics_tiles_storage_msb


        LDA     zp_graphics_tiles_storage_lsb
        ; Clear carry flag
        CLC
        ; add first buffer value to 0 or 128 and store it back in 70
        ADC     L0045,X
        STA     zp_graphics_tiles_storage_lsb

        ; 70 is now buffer 1[x] + 128 or 0
        ; 71 is now (buffer 2[x] / 2) + 30 = 55

        ; add zero to 71 (still 55)

        Tile address = (MSB00) / 2 + $3000 + LSB
        LDA     #$00
        ADC     zp_graphics_tiles_storage_msb
        STA     zp_graphics_tiles_storage_msb
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

        ; if negative set A to 3
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

; Look
.lookup_table_lsb
        EQUB    $00,$21,$35,$51,$69,$81,$9A,$AE
        EQUB    $C4,$DA,$F1

.lookup_table_msb
        EQUB    $1C,$1C,$1C,$1C,$1C,$1C,$1C,$1C
        EQUB    $1C,$1C,$1C

;....

; 1D10
.high_score_screen
        EQUS    $94,$9D,$87,"     ",$93,$F0,$F0,$F0,$B0," ",$96,$9A,$A0,$80,$B8,$A1,$F0,"  ",$B8,"                ",$94,$9D,$87,"HIGH ",$93,$FF,$A0," ",$FF,$9A,$96,$B6,$E0,$A6," ",$B6,$AC,$E1,$A6,$E3
        EQUS    $A1,$99,$93,$FF,"    ",$87,"SCORES ",$94,$9D,$87,"HIGH ",$93,$FF,$F0,$F0,$BF,$9A,$96,$A2,$A1,"  ",$A2,$A1,$A0,$A3,$A1,$99," ",$93,$FF,$AC,$AC,"  ",$87,"SCORES ",$94,$9D,$87,"HIGH "
        EQUS    $93,$FF,"  ",$FD,"  ",$FE,$A3,$A3,$FD,"  ",$A2,$A3,$A3,$FD,"  ",$FF,$9A,"   ",$87,"SCORES ",$94,$9D,$87,"HIGH ",$93,$FF,"  ",$FF,"  ",$FF,"  ",$FF,"  ",$FE,$A3,$A3,$FF,"  ",$FF,"  ",$FC," "
        EQUS    $87,"SCORES ",$94,$9D,$87,"     ",$93,$A3,$A3,$A3,$A1,"  ",$A2,$A3,$A3,$A1,"  ",$A2,$A3,$A3,$A1,"  ",$A2,$A3,$A3,$A1,"         "
; 1E00

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
	
     