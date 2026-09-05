;;=============================================================================
;; Galois LFSR Screen Filling Version 2 (05sep2026)
;;
;; Address 16417 (40FBh) signals the action (1 = Plot or 0 = Unplot)
;; Poking 128 (80h - bit 7 = 1), executes a Pause of 3 seconds.
;;
;; To press the space key to abort the generation.
;;
;; To mount with the TELEMARK Cross-assembler. (NOT IS THE BORLAND TASM)
;;
;; Mounting Syntax: "tasm -80 -b lfsr2.asm lfsr2.p"
;;=============================================================================


#define  db  .byte           ; TASM cross-assembler definitions
#define  dw  .word
#define  ds  .block
#define  org .org
#define  end .end

 
;============================ ZX81 System Variables ===========================
 
    org  $4009 
 
;   Data            ZX81 System Variables Names
;------------------------------------------------------------------------------
    db 0           ;VERSN 
    dw 9999        ;E_PPC    ;line of the [>] cursor
    dw D_File      ;D_FILE
    dw D_File + 1  ;DF_CC    ;address of PRINT into D_File 
    dw Var         ;VARS 
    dw 0           ;DEST 
    dw Var+1       ;E_LINE 
    dw Last-1      ;CH_ADD 
    dw 0           ;X_PTR 
    dw Last        ;STKBOT 
    dw Last        ;STKEND 
    db 0           ;BERG 
    dw MemBot      ;MEM 
    db 1           ;not used (4021h/16417) ; But here says for the code if
                   ; it have to Plot or Unplot on screen.
    db 2           ;DF_SZ 
    dw 5           ;S_TOP    ;First line to show after the List command
    db $FF,$FF     ;LAST_K   ;(4025h)
    db $FF         ;DEBOUN
    db 55          ;MARGIN   ;37 for 50 Hz (PAL) or 55 for 60 Hz (NTSC) 
    dw Line_10     ;NXTLIN   ;auto-start line after of LOAD (DFile=no auto-start)
    dw 0           ;OLDPPC 
    db 0           ;FLAGX 
    dw 0           ;STRLEN 
    dw $0C8D       ;T_ADDR 

LFSR_Seed:
    dw 3072 / 2    ;SEED     ;LFSR value (3072 / 2 is the center of screen)
    dw $FFFF       ;FRAMES 
    db 0,0         ;COORDS   ;coordinates x,y of PLOT/UNPLOT (4021h)
    db $BC         ;PR_CC    ;lsb of the address of printer buffer
    db 33,24       ;S_POSN   ;coordinates x,y for print
    db 01000000B   ;CDFLAG 
    ds 33          ;Print buffer (32 chars + New Line)

MemBot:
    ds 30          ;Calculator's memory area

Initial_Seed:
    dw 3072 / 2    ;not used (407Bh, 10507d) ; Will hold the initial seed
                                             ; in the code, to find the last
                                             ; pixel plotted on the screen.

;========================== End of ZX81 System Variables ======================


;================== First BASIC line, (allocation for asm code) ===============

; REM line with the machine code
REM_Line:
    db 0,0                   ; Number of the REM line (0)
    dw REM_Line_End - $ - 2  ; Length of REM line
    db $EA                   ; REM code

 
;--------------------- Beginning of Assembly Program Code ---------------------

Code_Start:
    bit  7,(iy + $3B)        ; Checks FAST mode
    call z,$0F2B             ; Call SLOW mode if in FAST


;------------------------------------------------------------------------------
; Checks if the 3 Seconds Pause Flag (16417 address value bit 7) is On (1)
;------------------------------------------------------------------------------
    ld   a,(16417)
    and  $80                 ; Is 3 seconds Pause Flag (bit 7) on?
    jr   z,Effect_Start      ; Then to wait 3 seconds and exit


;------------------------------------------------------------------------------
; 3 Seconds Pause (150/180 Frames) (POKE 16417,128)
;------------------------------------------------------------------------------
    ld   a,($4028)           ; MARGIN var
    sub  $37                 ; Turns A = 0 if 50 Hz (PAL System)
    sbc  a,a                 ; Turns A = 255 if 60 Hz (NTSC System)
    or   $E1                 ; Turns A = 255 if in NTSC or 225 if in PAL
    ld   ($4034),a           ; initializes the Frames Counter (with 255 or 225)

Pause_180_Loop:
    call Check_Space         ; Checks the Space key pressing
    ret  z                   ; The Space key was pressed
    ld   a,($4034)           ; Gets frames counter
    cp   255 - 180           ; Past 3 seconds? (150/180 frames)
    jr   nc,Pause_180_Loop   ; Not yet
    ret


;------------------------------------------------------------------------------
; Beggining of LFSR Effect Code
;------------------------------------------------------------------------------
Effect_Start:    
    call Get_Initial_Seed

Plotting_Loop:
    call Get_XY              ; Converts the LFSR value in Plot coordinates
    call Plot_Routine        ; Plots the dot
    call Gen_LFSR            ; Prepares the next LFSR value

;    ; Checks the Keyboard for Space Key (Break) Pressing
;    ld   hl,($4025)          ; Gets the scancode of the last pressed key
;    ld   a,l                 ; Checks if any key was pressed
;    cp   $7F                 ; Scancode 1 for Space key
;    jr   nz,Check_Scn_Full
;    ld   a,h
;    cp   $FD                 ; Scancode 2 for Space key (FCh for Shift+Space)
    call Check_Space         ; Checks the Space key pressing
    ld   bc,1                ; Error code to return, case interromped by user
    ret  z                   ; The Space key was pressed

    ; All Dots Plotted?
Check_Scn_Full:    
    ld   hl,(LFSR_Seed)
    ld   de,(Initial_Seed)
    ld   a,h
    cp   d
    jr   nz,Plotting_Loop
    ld   a,l
    cp   e
    jr   nz,Plotting_Loop
    
;    ld   bc,0                ; Success error code (0)
    dec  bc                  ; Success error code (0)
    ret                      ; Backs to BASIC


;------------------------------------------------------------------------------
; Checks the Space Key (Break) Pressing
; -------------------------------------
;
; Returns Z if the Space key was pressed.
;------------------------------------------------------------------------------
Check_Space:    
    ld   hl,($4025)          ; Gets the scancode of the last pressed key
    ld   a,l                 ; Checks if any key was pressed
    cp   $7F                 ; Scancode 1 for Space key
    ret  nz                  ; The Space key is not pressed (Z flag = 0)
    ld   a,h
    cp   $FD                 ; Scancode 2 for Space key (FCh for Shift+Space)
    ret                      ; Returns with the Space key status in Z flag 
                             ; (Z = 1 = The Space key was pressed)

;------------------------------------------------------------------------------
; Initial Seed to LFSR Generator
;------------------------------------------------------------------------------
Get_Initial_Seed:
    ld   a,r
    ld   l,a
    cpl
    and  $0B
    ld   h,a                 ; Loads H with an inverted value (Avoid a Seed = 0)
    ld   (LFSR_Seed),hl      ;
    ld   (Initial_Seed),hl   ; To check if all screen is ploted or unploted
    ret


;------------------------------------------------------------------------------
; Turn the LFSR Value into a Column (X) and Row (Y) Coordinate
; ------------------------------------------------------------
;
; Input :
;         None.
;
; Output:
;         B = Y coordinate (row)
;         C = X coordinate (column)
;
; Destroys:
;         A, HL, D.
;------------------------------------------------------------------------------
Get_XY:
    ld   hl,(LFSR_Seed)      ; Gets the LFSR value
    dec  hl                  ; Adjusts to a range 0-3071
                             ; (LFSR Seed range is 1 up to 3072)

    ; Extracts the Coordinate X (Bits 0 to 5 from L) to the C register
    ld   a,l
    and  $3F                 ; Get only the lower 6 bits
    ld   c,a                 ; C = Coordinate X (column from 0 to 63)

    ; Put the Coordinate Y in B register
    add  hl,hl
    add  hl,hl
    ld   b,h
    ret


;------------------------------------------------------------------------------
; Plot/Unplot Routine Version 2.2b (checks bit 0 from address 4021h for action)
; -----------------------------------------------------------------------------
;
; Input:
;        B register = plot/unplot's row (Y)
;        C register = plot/unplot's column (X)
; Destroys:
;        BC, DE, HL
;------------------------------------------------------------------------------
Plot_Routine:
    ; Calcula caractere do Plot/Unplot
    ld   a,1
    sra  b                   ; Divide the value of Plot row (Y) by 2
    jr   nc,$+4
    ld   a,4
    sra  c                   ; Divide the value of Plot column (X) by 2
    jr   nc,$+3
    rlca
    push af                  ; Saves the char of Plot/Unplot to use later
    call Calc_Plot_Address   ; Calculate the address of the Plot/Unplot
                             ; on video

    ; Checks if Char in Plot/Unplot address is graphic
    ld   a,(hl)
    rlca
    cp   $10
    jr   nc,$+8
    rrca
    jr   nc,$+4
    xor  $8F
    ld   b,a

    ; Checks Action (Plot/Unplot?)
    ; Address 4021h not is used by system. Then is used here as a flag
    ; signaling to Plot (1) or Unplot (0) on screen.
    ld   a,(16417)           ; Gets action: Even = To Unplot, Odd = To Plot
    and  1                   ; Test if Accumulator content is odd (To Plot)
    jp   nz,Plot             ; Yes. Let's to plot

    ; Unplots
    pop  af                  ; Restores the Unplot character
    cpl
    and  b                   ; Combine with the character in address
    jr   $+4

Plot:
    ; Plots
    pop  af                  ; Restores the Plot character
    or   b                   ; Combine with the character in address
    cp   8
    jr   c,$+4               ; To print the new char
    xor  $8F

    ld   (hl),a              ; Prints the Plot/Unplot on screen
    ret



;------------------------------------------------------------------------------
; Gets the Address into D-File Where to Plot or Unplot
; ----------------------------------------------------
;
; Input:
;        B = Coordinate Y (line) to print (0-23)
;        C = Coordinate X (column) to print (0-31)
; Output:
;        HL = Address into D-File to print
; Destroys:
;        DE
;------------------------------------------------------------------------------
Calc_Plot_Address:
    ld   a,b                 ; copia linha da impressao em A
    rlca                     ; line * 2
    rlca                     ; line * 4
    rlca                     ; line * 8
    ld   l,a
    ld   a,b
    add  a,c
    ld   e,a
    ld   d,0
    ld   h,d
    add  hl,hl               ; line * 16
    add  hl,hl               ; line * 32
    add  hl,de               ; line * 33
    ex   de,hl
    ld   hl,($400C)          ; Gets D-File address
    inc  hl                  ; Skips the 1st NEWLINE (CHR$ 118)
    add  hl,de
    ret                      ; Returns with HL = printing address


;------------------------------------------------------------------------------
; LFSR Galois Generator with a Period of 1 to 3072
; ------------------------------------------------
;
; Input  : None.
; Output : HL = New valid LFSR.
;------------------------------------------------------------------------------
Gen_LFSR:
    ld    hl,(LFSR_Seed)     ; Gets the last LFSR value (Stored in the ZX81
                             ; System SEED variable)
New_LFSR:
    srl   h
    rr    l
    jr    nc,Skip_XOR

    ; Apply Tap of 12 bits (Maximum Period = 4095 states)
    ld    a,h
    xor   $08
    ld    h,a
    ld    a,l
    xor   $29
    ld    l,a

Skip_XOR:
    ; Discards Values > 3072 (To decrement HL before of use, to get 0-3071)
    ; 3072 in hexa is 0x0C00. If HL > 0x0C00, the pixel is out of screen.
    ; Then calculates a new value.
    dec  hl                  ; Decrements HL temporarily for boundary test
    ld   a,h                 ; Loads A with the adjusted boundary for test
    inc  hl                  ; Restores original HL value
    cp   $0C                 ; Tests adjusted boundary (3072)
    jr   nc,New_LFSR         ; LFSR Seed > 3072 (generate a new value)
    ld   (LFSR_Seed),hl      ; Saves the new valid LFSR value...
    ret                      ; ...and exit

;------------------------ End of Assembly Program Code ------------------------
    
    db   $76                 ; NEWLINE code (end of the REM line) 

;------------------------------------------------------------------------------
; Marks the End of REM Line (used to calculate the size of the REM line)
;------------------------------------------------------------------------------
REM_Line_End:

;============================== End of REM line ===============================


;================================ BASIC Code ==================================

; 5 REM =======================
    db  00h,05h,19h,00h,0EAh,14h,14h,14h
    db  14h,14h,14h,14h,14h,14h,14h,14h
    db  14h,14h,14h,14h,14h,14h,14h,14h
    db  14h,14h,14h,14h,76h

; 6 REM GALOIS LFSR GENERATION
    db  00h,06h,18h,00h,0EAh,2Ch,26h,31h
    db  34h,2Eh,38h,00h,31h,2Bh,38h,37h
    db  00h,2Ch,2Ah,33h,2Ah,37h,26h,39h
    db  2Eh,34h,33h,76h

; 7 REM IN 05/SEP/2026 BY CJB
    db  00h,07h,17h,00h,0EAh,2Eh,33h,00h
    db  1Ch,21h,18h,38h,2Ah,35h,18h,1Eh
    db  1Ch,1Eh,22h,00h,27h,3Eh,00h,28h
    db  2Fh,27h,76h

; 8 REM ========================
    db  00h,08h,19h,00h,0EAh,14h,14h,14h
    db  14h,14h,14h,14h,14h,14h,14h,14h
    db  14h,14h,14h,14h,14h,14h,14h,14h
    db  14h,14h,14h,14h,76h

; 9 REM
    db  00h,09h,02h,00h,0EAh,76h

; 10 POKE 16417,1            (LFSR Plots. Execution Starts Here)
Line_10:
    db  00h,0Ah,15h,00h,0F4h,1Dh,22h,20h
    db  1Dh,23h,7Eh,8Fh,00h,42h,00h,00h
    db  1Ah,1Dh,7Eh,81h,00h,00h,00h,00h
    db  76h

; 20 RAND USR 16514
    db  00h,14h,0Eh,00h,0F9h,0D4h,1Dh,22h
    db  21h,1Dh,20h,7Eh,8Fh,01h,04h,00h
    db  00h,76h

; 30 PRINT AT 10,7; "THE SCREEN IS FULL"
    db  00h,1Eh,28h,00h,0F5h,0C1h,1Dh,1Ch
    db  7Eh,84h,20h,00h,00h,00h,1Ah,23h
    db  7Eh,83h,60h,00h,00h,00h,19h,0Bh
    db  0B9h,0ADh,0AAh,80h,0B8h,0A8h,0B7h,0AAh
    db  0AAh,0B3h,80h,0AEh,0B8h,80h,0ABh,0BAh
    db  0B1h,0B1h,0Bh,76h

;; 40 FOR P=0 TO 100          (Pause Between the Effects)
;    db  00h,28h,15h,00h,0EBh,35h,14h,1Ch
;    db  7Eh,00h,00h,00h,00h,00h,0DFh,1Dh
;    db  1Ch,1Ch,7Eh,87h,48h,00h,00h,00h
;    db  76h
;
;; 45 NEXP P   
;    db  00h,2Dh,03h,00h,0F3h,35h,76h
;

; 40 POKE 16417,128          (Execute Pause)
    db  00h,28h,17h,00h,0F4h,1Dh,22h,20h
    db  1Dh,23h,7Eh,8Fh,00h,42h,00h,00h
    db  1Ah,1Dh,1Eh,24h,7Eh,88h,00h,00h
    db  00h,00h,76h

; 45 RAND USR 16514          (Pause of 3 Seconds Between the Effects)
    db  00h,2Dh,0Eh,00h,0F9h,0D4h,1Dh,22h
    db  21h,1Dh,20h,7Eh,8Fh,01h,04h,00h
    db  00h,76h

; 50 POKE 16417,0            (LFSR Unplots)
    db   00h,32h,15h,00h,0F4h,1Dh,22h,20h
    db   1Dh,23h,7Eh,8Fh,00h,42h,00h,00h
    db   1Ah,1Ch,7Eh,00h,00h,00h,00h,00h
    db   76h

; 60 RAND USR 16514
    db  00h,3Ch,0Eh,00h,0F9h,0D4h,1Dh,22h
    db  21h,1Dh,20h,7Eh,8Fh,01h,04h,00h
    db  00h,76h

; 70 PRINT AT 10,6; "THE SCREEN IS CLEAN"
    db  00h,46h,29h,00h,0F5h,0C1h,1Dh,1Ch
    db  7Eh,84h,20h,00h,00h,00h,1Ah,22h
    db  7Eh,83h,40h,00h,00h,00h,19h,0Bh
    db  39h,2Dh,2Ah,00h,38h,28h,37h,2Ah
    db  2Ah,33h,00h,2Eh,38h,00h,28h,31h
    db  2Ah,26h,33h,0Bh,76h

;; 80 FOR P=0 TO 100          (Pause Between the Effects)
;    db  00h,50h,15h,00h,0EBh,35h,14h,1Ch
;    db  7Eh,00h,00h,00h,00h,00h,0DFh,1Dh
;    db  1Ch,1Ch,7Eh,87h,48h,00h,00h,00h
;    db  76h
;
;; 85 NEXP P   
;    db  00h,55h,03h,00h,0F3h,35h,76h

; 80 POKE 16417,128          (Execute Pause)
    db  00h,50h,17h,00h,0F4h,1Dh,22h,20h
    db  1Dh,23h,7Eh,8Fh,00h,42h,00h,00h
    db  1Ah,1Dh,1Eh,24h,7Eh,88h,00h,00h
    db  00h,00h,76h

; 85 RAND USR 16514          (Pause of 3 Seconds Between the Effects)
    db  00h,55h,0Eh,00h,0F9h,0D4h,1Dh,22h
    db  21h,1Dh,20h,7Eh,8Fh,01h,04h,00h
    db  00h,76h

; 90 GOTO 10                 (Again)
    db  00h,5Ah,0Ah,00h,0ECh,1Dh,1Ch,7Eh
    db  84h,20h,00h,00h,00h,76h

; 100 SAVE "LFSR2" 
    db  00h,64h,09h,00h,0F8h,0Bh,31h,2Bh
    db  38h,37h,9Eh,0Bh,76h

; 110 RUN
    db  00h,6Eh,02h,00h,0F7h,76h

;============================ End of BASIC Code ===============================


;------------------------------- Display File ---------------------------------

D_File:
    db $76 
    ds $20 \ db $76    ; Line 01
    ds $20 \ db $76    ; Line 02
    ds $20 \ db $76    ; Line 03
    ds $20 \ db $76    ; Line 04
    ds $20 \ db $76    ; Line 05
    ds $20 \ db $76    ; Line 06
    ds $20 \ db $76    ; Line 07
    ds $20 \ db $76    ; Line 08
    ds $20 \ db $76    ; Line 09
    ds $20 \ db $76    ; Line 10
    ds $20 \ db $76    ; Line 11
    ds $20 \ db $76    ; Line 12
    ds $20 \ db $76    ; Line 13
    ds $20 \ db $76    ; Line 14
    ds $20 \ db $76    ; Line 15
    ds $20 \ db $76    ; Line 16
    ds $20 \ db $76    ; Line 17
    ds $20 \ db $76    ; Line 18
    ds $20 \ db $76    ; Line 19
    ds $20 \ db $76    ; Line 20
    ds $20 \ db $76    ; Line 21
    ds $20 \ db $76    ; Line 22
    ds $20 \ db $76    ; Line 23
    ds $20 \ db $76    ; Line 24
 

;------------------------------ BASIC-Variables -------------------------------

Var:
    db $80 

 
;---------------------------- End of program area -----------------------------

Last: 
    end 
