; Format:
;    Byte 0  - Width of hazard  (in numbers of tiles)
;    Byte 1  - Height of hazard (in numbers of tiles)
;    Byte 2  - Number of tiles that make up the hazard (they immediately follow)
;            - Note that this should always equal Byte 2 = Byte 0 x Byte 1
;    Byte 3  - First row, first tile of hazard 
;    ...
;    Byte n  - Second row, first tile of hazard
;    ...
;    Byte o  - ...last tile of hazard
;    Byte p  - Number of instancse of the harard
;    Byte q  - x co-ordinates of each instance of the hazard
;    ...
;    Byte r  - last x co-ordinate
;    Byte s  - y co-ordinates of each instance of the hazard
;    ...
;    Byte t  - last y co-ordinate

;     y=  0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17
;1c00
.hazard_ducks
EQUB    $01,$01,$01,$68,$0D,$32,$31,$2F,$30,$33,$7F,$7E,$7D,$7F,$7E,$4A,$4B,$4A,$4C,$4B,$4C,$4C,$4D,$4C,$17,$18,$17,$15,$19,$26,$27,$28,$28
;1c21
.hazard_buoys
EQUB    $02,$02,$04,$85,$86,$A5,$A6,$05,$69,$75,$6D,$4E,$1B,$60,$40,$35,$0F,$15,$2F,$30
;1c35
.hazard_islands
EQUB    $09,$02,$12,$6A,$6B,$6C,$6C,$6C,$6C,$6D,$6E,$6F,$8A,$8B,$8C,$8C,$8C,$8C,$8D,$8E,$8F,$02,$70,$23,$46,$0E,$04,$0D
;1c51 
.hazard_sea_serpents
EQUB    $06,$02,$0C,$69,$03,$03,$03,$03,$03,$87,$88,$89,$88,$89,$00,$03,$32,$51,$53,$18,$38,$3F,$4E,$4B
;1c69
.hazard_barriers
EQUB    $01,$02,$02,$C0,$E0,$08,$25,$20,$67,$63,$67,$6E,$7C,$60,$28,$33,$38,$04,$02,$36,$30,$1D,$3D,$4B
;1c81
.hazard_yachts
EQUB    $03,$03,$09,$03,$AE,$03,$03,$CE,$CF,$ED,$EE,$EF,$05,$0C,$54,$75,$5D,$3E,$32,$24,$07,$05,$26,$41,$04
;1c9a
.hazard_crocodiles
EQUB    $06,$01,$06,$C1,$C2,$C3,$C4,$C5,$C6,$04,$41,$78,$74,$1A,$17,$2D,$2C,$44,$46,$36
;1cae 
.hazard_sand_banks
EQUB    $04,$02,$08,$03,$A8,$A9,$03,$C7,$C8,$C9,$CA,$04,$44,$4D,$49,$20,$00,$1C,$02,$42,$00,$0E
;1cc4 
.hazard_gondolas
EQUB    $02,$04,$08,$AB,$AC,$CB,$CC,$CB,$CC,$EB,$EC,$04,$69,$68,$6C,$3E,$56,$0C,$29,$47,$4A,$37
;1cda 
.hazard_rafts
EQUB    $03,$03,$09,$AF,$AA,$03,$E1,$E2,$E3,$E4,$E5,$A7,$04,$38,$44,$4C,$0D,$11,$2F,$13,$39,$44,$2E
;1cf1 
.hazard_lighthouses
EQUB    $05,$02,$0A,$CD,$03,$03,$03,$03,$E6,$E7,$E8,$E9,$EA,$06,$71,$66,$76,$61,$26,$5F,$35,$13,$22,$3C,$45,$3A,$08,$01,$00,$00,$00
