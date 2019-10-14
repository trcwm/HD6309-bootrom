;
; HD6309 Computer Secondary boot stage
; for booting FLEX
;
; Copyright N.A. Moseley 2019
;
; License: Mozilla Public License Version 2.0
;

    org $B800

; SETUP
STACK   EQU $C07F
SCTBUF  EQU $C300

; ROM ROUTINES
OUTCHAR         EQU $FFA8
PRINTSTRING     EQU $FFAA
WRITEHEX        EQU $FFAC

; FAKE DRIVER EQUATES
REG_CMD         EQU $E020       ; command register (write = perform action)
REG_DATA        EQU $E021       ; data register
REG_DRIVESEL    EQU $E022       ; drive select
REG_TRACK       EQU $E023       ; track
REG_SECTOR      EQU $E024       ; sector

CMD_READSECTOR  EQU 1
CMD_WRITESECTOR EQU 2
CMD_SEEKSECTOR  EQU 3

; ENTRY POINT
START:
    BRA LOAD0

; NOTE: this must start at offset 0x002
      .db 0,0,0
TRK   .db 1         TRACK ON DISK
SCT   .db 1         SECTOR ON DISK
TADR  .dw $C100     TRANSFER ADDRESS
LADR  .dw 0         LOAD ADDRESS

LDTXT .ascii "  stage 2:"
      .db 0

LOAD0:
    LDS #STACK
    LDD TRK
    STD SCTBUF

    LDY #SCTBUF+256 ; END OF BUFFER -> TRIGGER LOAD
    
    LDX #LDTXT
    JSR [PRINTSTRING]

    ; load file from sector 1
LOAD1:
    BSR GETCH
    CMPA #$02       ; DATA RECORD?
    BEQ LOAD2
    CMPA #$16       ; XFER RECORD?
    BNE LOAD1

    ; process xfer record
    LDA #43         ; ascii +
    JSR [OUTCHAR]    
    BSR GETCH
    STA TADR
    BSR GETCH
    STA TADR+1
    BRA LOAD1

    ; process data record
LOAD2:
    LDA #42         ; ascii asterisk
    JSR [OUTCHAR]
    BSR GETCH       ; GET LOAD ADDRESS
    STA LADR
    BSR GETCH
    STA LADR+1
    BSR GETCH       ; GET BYTE COUNT (MAX 252)
    TFR A,B
    TSTA
    BEQ LOAD1
    LDX LADR

LOAD3:
    PSHS B,X
    BSR GETCH
    PULS B,X
    STA ,X+
    DECB
    BNE LOAD3
    BRA LOAD1

; 
; GETCH - read a single byte from sector
; 

GETCH:
    CMPY #SCTBUF+256  ; OUT OF DATA?
    BNE GETCH4
GETCH2:
    LDX #SCTBUF
    LDD 0,X           ; get forward link (track,sector)
    BEQ GO            ; if (0,0) -> jump to xfer address!
    BSR READ          ; read the next sector
    ;BNE LOAD
    LDY #SCTBUF+4     ; pointer to actual data
GETCH4:
    LDA ,Y+           ; get character
    RTS


;
; READ - load a sector into memory
;     sector is in B
;     track is in A
READ:
    STB REG_SECTOR
    STA REG_TRACK

    ; DEBUG: show track/sector
    ;JSR [WRITEHEX]
    ;TFR B,A
    ;JSR [WRITEHEX]
    ;LDA #10
    ;JSR [OUTCHAR]
    ;LDA #13
    ;JSR [OUTCHAR]

    CLRA
    STA REG_DRIVESEL  ; drive 0
    LDA #CMD_READSECTOR
    STA REG_CMD
    LDX #SCTBUF
    CLRB
READ1:
    LDA REG_DATA
    STA ,X+
    DECB
    BNE READ1
    RTS    

;
; GO - jump to xfer address
;
GO:
    LDA $10
    JSR [OUTCHAR]
    LDA $13
    JSR [OUTCHAR]
    JMP [TADR]

    END START