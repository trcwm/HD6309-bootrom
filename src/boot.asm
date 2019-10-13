;
; HD6309 Computer Boot ROM
; Copyright N.A. Moseley 2019
;
; License: Mozilla Public License Version 2.0
;

; Define some easier to read instructions
;

; increment X register
INCX    MACR
        LEAX 1,X
        ENDM

; decrement X register
DECX    MACR
        LEAX -1,X
        ENDM

; clear carry flag
CLC     MACR
        ANDCC #%11111110
        ENDM 

; set carry flag
STC     MACR
        ORCC #%00000001
        ENDM

; clear carry flag
CLZ     MACR
        ANDCC #%11111011
        ENDM 

; set carry flag
STZ     MACR
        ORCC #%00000100
        ENDM

; ==================================================
; SYSTEM CONSTANTS
; ==================================================

RAMSTART  EQU $0000     ; lowest RAM location
RAMEND    EQU $E000     ; highest RAM location
STACK     EQU $DEF0     ; initial stack pointer

LINEPTR   EQU $DF00     ; pointer to 256 char line buffer
HEXADDR   EQU $DEFB     ; 4-digit hex number
SRECCHK   EQU $0000     ; 8 bits
SRECERR   EQU $0001     ; 8 bits
SRECTMP   EQU $0002     ; 8 bits

; ==================================================
; UART ADDRESSES
; ==================================================
SER_TX     EQU $E000
SER_RX     EQU $E000
SER_IER    EQU $E001
SER_FCR    EQU $E002
SER_ISR    EQU $E002
SER_LCR    EQU $E003
SER_MCR    EQU $E004
SER_LSR    EQU $E005
SER_MSR    EQU $E006
SER_SPR    EQU $E007
SER_DLL    EQU $E000
SER_DLM    EQU $E001

; ==================================================
; ISR TRAMPOLINE ADDRESSES
; ==================================================

NMIADDR   EQU $DFEA     ; 16 bits
SWIADDR   EQU $DFE8     ; 16 bits
IRQADDR   EQU $DFE6     ; 16 bits
FIRQADDR  EQU $DFE4     ; 16 bits
SWI2ADDR  EQU $DFE2     ; 16 bits                        
SWI3ADDR  EQU $DFE0     ; 16 bits

    ORG $F000

; ==================================================    
; OUTPUT CHARACTER TO CONSOLE
;   A : CHAR TO OUTPUT
;
;   DESTROYS: FLAGS
;
;   BLOCKS ON UART FULL
; ================================================== 

OUTCHAR:
    PSHS B
OUTCHAR_1:
    LDB SER_LSR
    BITB #32
    NOP
    NOP
    BEQ OUTCHAR_1
    STA SER_TX
    PULS B
    RTS


; ==================================================    
; PRINT STRING: PRINT A ZERO-TERMINATED ASCII STRING
;   X : pointer to the string
;
;   DESTROYS: flags, X
;
;   BLOCKS ON UART FULL
; ==================================================    

PRINTSTRING:
    PSHS A
PRINTSTRING_1:
    LDA ,X+
    BEQ PS_END
    JSR OUTCHAR
    JMP PRINTSTRING_1
PS_END:
    PULS A
    RTS

; ==================================================    
; GET A CHARACTER FROM THE TERMINAL
;
;   DESTROYS: FLAGS
;
;   RETURNS: CHAR IN A
;
;   BLOCKS ON UART EMPTY
; ================================================== 

INCHAR:
    PSHS B
INCHAR_1:
    LDB SER_LSR
    BITB #1
    NOP
    NOP    
    BEQ INCHAR_1
    LDA SER_RX
    PULS B
    RTS

; ==================================================    
; GET A CHARACTER FROM THE TERMINAL WITH ECHO
;
;   DESTROYS: FLAGS
;
;   RETURNS: CHAR IN A
;
;   BLOCKS ON UART EMPTY
; ================================================== 

INCHARE:
    JSR INCHAR
    JSR OUTCHAR
    RTS

; ==================================================
; GET A CHARACTER FROM THE CONSOLE AND ECHO IT
; TO THE OUTPUT
;
; BLOCKS ON UART RX EMPTY
; ================================================== 

INCHARECHO:
    JSR INCHAR
    JSR OUTCHAR
    RTS

; ==================================================
; CHECK IF A CHARACTER IS AVAILABLE
; SETS NE CONDITION IF CHAR IS AVAILABLE
; ==================================================    

INCHECK:
    PSHS B
    LDB SER_LSR
    BITB #1    
    PULS B
    RTS


; ==================================================    
; GET A LINE FROM THE TERMINAL WITH ECHO
;
;   ESCAPE clears the entire line
;   CR or LF terminate the line
;
;   DESTROYS: FLAGS
;
;   RETURNS: LENGTH OF LINE IN B
;
;   BLOCKS ON UART EMPTY
; ================================================== 

GETLINE:
    PSHS X
    CLRB
    LDX #LINEPTR

NEXTCHAR:
    JSR INCHAR
    CMPA #13        ; CR
    BEQ LINEDONE
    CMPA #10        ; LF
    BEQ LINEDONE
    CMPA #27        ; ESCAPE
    BEQ ESCAPE
    CMPA #8         ; BACKSPACE
    BEQ BACKSPACE

    ; regular character -> store
    INCB
    CMPB #0
    BEQ OVERFLOW    ; don't store on overflow
    STA ,X+

    ; echo charater to console
    JSR OUTCHAR
    JMP NEXTCHAR

OVERFLOW:
    DECB
    JMP NEXTCHAR

ESCAPE:             ; delete current line and return carriage
    CLRB            ; to the beginning of the line
    LDX #LINEPTR
    LDA #13         ; CR
    JSR OUTCHAR
    JMP NEXTCHAR
    
BACKSPACE:
    CMPB #0
    BEQ NEXTCHAR    ; can't delete if there are no chars
    DECB
    DECX
    JSR OUTCHAR    
    JMP NEXTCHAR

LINEDONE:
    PULS X
    RTS

; ==================================================    
; COMMAND INTERPRETER
; ==================================================  

CMDINT:
    LDX #PROMPT         ; show the prompt
    JSR PRINTSTRING

    JSR GETLINE         ; get user input
    
    LDA #10
    JSR OUTCHAR
    LDA #13
    JSR OUTCHAR

    LDX #LINEPTR

CMDNEXTCHAR:
    CMPB #0             ; no more chars left?
    BEQ CMDINT
    LDA ,X+
    DECB
    CMPA #' '
    BEQ CMDNEXTCHAR     ; skip spaces
    CMPA #'M'           ; memory <addr> command
    BEQ CMD_MEMDUMP
    CMPA #'R'           ; run <addr> command
    BEQ CMD_RUN
    CMPA #'L'           ; Load SREC
    BEQ CMD_SREC

    ; command not accepted
    LDX #HUH
    JSR PRINTSTRING
    JMP CMDINT    

CMD_MEMDUMP:
    JSR PARSEHEXADDR
    BNE CMD_EXIT1       ; error parsing HEX address

    LDB #16
    LDX HEXADDR

MEMNXTLINE:
    ; display HEX address
    LDA HEXADDR
    JSR WRITEHEX
    LDA HEXADDR+1
    JSR WRITEHEX

MEMNXTBYTE:
    ; space
    LDA #32
    JSR OUTCHAR

    LDA ,X+
    JSR WRITEHEX
    DECB
    BNE MEMNXTBYTE

    LDA #10         ; next line on console
    JSR OUTCHAR
    LDA #13
    JSR OUTCHAR

    STX HEXADDR     ; update hex address for next line
    LDB #16

    ; if user presses space, continue
    ; otherwise exit
    JSR INCHAR
    CMPA #32        ; space!
    BEQ MEMNXTLINE

CMD_EXIT1:    
    JMP CMDINT

CMD_RUN:
    JSR PARSEHEXADDR    ; get HEX jump address
    BNE CMDINT
    JMP [HEXADDR]

CMD_SREC:
    LDX #SRECTXT
    JSR PRINTSTRING
    JMP SRECLOADER

PROMPT  .ascii "> "
        .db 0

HUH .ascii "?"
    .db 10,13,0

SRECTXT .ascii "Expecting SREC"
        .db 10,13,0

; ==================================================    
; SRECORD LOADER
;   https://en.wikipedia.org/wiki/SREC_(file_format)
; SUPPORTS
;   S0 - dumps to the terminal (not implemented)
;   S1 - 16-bit address data record
;   S9 - 16-bit start address
;
; Inspired by Alan Garfield's loader
; https://github.com/alangarf/amx_axc_m68k/blob/master/loader.s#L206
; ================================================== 
SRECLOADER:
    JSR  INCHAR     ; get character
    CMPA #'S'       ; is it an S record?
    BNE  SRECLOADER ; skip, if it isnt
    
    JSR  INCHAR     ; get next char
    CMPA #'1'       ; is it an S5 count
    BEQ  _LD_S1    
    CMPA #'9'       ; is it an S9 termination record?
    BEQ  _LD_S9
    JMP  SRECLOADER
    
_LD_S1:
    CLRB
    STB  SRECCHK    ; clear checksum
    STB  SRECERR    ; clear error flag
    JSR  SRECREAD   ; get S1 packet length
    SUBA #3         ; calculate number of payload bytes
    PSHS A          ; save the count
    JSR  SRECREAD   ; load MSB of address
    TFR  A,B        ; 
    JSR  SRECREAD   ; load LSB of address
    EXG  A,B        ; D = [MSB, LSB]
    TFR  D,X        ; X = load address
    PULS B          ; B = byte count
    JMP  _LD_DATA
    
_LD_S9:
    CLRB
    STB  SRECCHK    ; clear checksum
    JSR  SRECREAD   ; get S9 packet length
    JSR  SRECREAD   ; load MSB of address
    TFR  A,B        ; 
    JSR  SRECREAD   ; load LSB of address
    EXG  A,B        ; D = [MSB, LSB]
    STD  HEXADDR    ; store jump address
    JSR SRECREAD    ; read checksum byte
    LDB SRECCHK
    INCB            ; adjust for 1s complement!
    BEQ _LD_OK      ; total sum should be zero
    LDA #$FF
    STA SRECERR     ; set error flag    
_LD_OK:
    JMP _LD_TERM

; Load data part of packet
; expects B to have the number of
; bytes to read. Data is stored
; using the X index register
_LD_DATA:    
    JSR SRECREAD
    STA ,X+
    DECB
    BNE _LD_DATA    ; loop until there is no more data to read
    JSR SRECREAD    ; read checksum byte
    LDB SRECCHK
    INCB            ; adjust for 1s complement!
    BEQ _LD_DATA_OK ; total sum should be zero
    LDA #'X'        ; print X for every bad record
    JSR OUTCHAR
    LDA #$FF
    STA SRECERR     ; set error flag
    JMP SRECLOADER  ; try again .. 

_LD_DATA_OK:
    LDA #'*'        ; print * for every good record
    JSR OUTCHAR
    JMP SRECLOADER  ; next record .. 
    
; Check for errors
_LD_TERM:
    LDA SRECERR         ; load error flags
    BEQ _LD_NOERRORS    
    LDX #SRECERRORSTR    ; report error
    JSR PRINTSTRING
    JMP SRECLOADER      ; try again..
_LD_NOERRORS:
    LDX #ADDRSTR
    JSR PRINTSTRING
    LDA HEXADDR
    JSR WRITEHEX
    LDA HEXADDR+1
    JSR WRITEHEX
    LDX #EOLSTR
    JSR PRINTSTRING
    JMP [HEXADDR]       ; jump to start address
    
SRECERRORSTR:
        .db 13,10
        .ascii "SREC checksum errors! Aborting."
EOLSTR:        
        .db 13,10,0

ADDRSTR:
        .db 13,10
        .ascii "Jumping to $"
        .db 0

; ========================================
;   SREC LOADER
;   READ BYTE AS ASCII HEX DIGIT
;
;   return contents in A, update checksum
; ========================================
SRECREAD:
    PSHS B
    CLRA
    JSR  READHEXDIGIT
    LSLA
    LSLA
    LSLA
    LSLA
    JSR  READHEXDIGIT
    ; update checksum
    TFR  A,B
    ADDB SRECCHK
    STB  SRECCHK
    PULS B
    RTS

; ========================================
;   SREC LOADER - READ HEX DIGIT
;
; read an ASCII hex digit 0-9,A-F from
; the UART, convert to 4-bit binary
; and OR it with the contents in A.
; ========================================
READHEXDIGIT:
    PSHS B
    PSHS A          ; save A for later    
    JSR INCHAR
    SUBA #'0'       ; move ascii 0 down to binary 0
    BMI READHEX_ERR
    CMPA #9
    BLE READHEX_OK  ; 0-9 found
    SUBA #7         ; drop 'A' down to 10
    CMPA #$F
    BLE READHEX_OK
    
READHEX_ERR:
    PULS A
    PULS B
    RTS

READHEX_OK:
    STA SRECTMP     ; store 4-bit value in temp
    PULS A          ; restore old value
    ORA SRECTMP     ; or the hex value
    PULS B
    RTS

; ==================================================
;   PARSE ASCII HEX ADDRESS (X) INTO 'HEXADDR'
;
;   Decrements B by number of chars read
;   Increments X by number of chars read
;
;   Sets zero flag to 1 if ok, else error
; ==================================================

PARSEHEXADDR:
    CMPB #0             ; no more chars left?
    BEQ PSHEXERR
    LDA ,X+
    DECB
    CMPA #' '
    BEQ PARSEHEXADDR    ; skip spaces

    JSR INITHEX

    ; read hex address (digit 1)
    JSR GETHEX          ; put hex digit in D register
    BNE PSHEXERR        ; check if we got a HEX character
                        ; if not, it's not a valid address

    ; read hex address (digit 2)
    LDA ,X+
    DECB
    BMI PSHEXOK
    JSR GETHEX          
    BNE PSHEXOK         ; 2nd hex character does not exist
                        ; it might be a valid address

    ; read hex address (digit 3)
    LDA ,X+
    DECB
    BMI PSHEXOK
    JSR GETHEX
    BNE PSHEXOK         ; 3rd hex character does not exist
                        ; it might be a valid address

    ; read hex address (digit 4)
    LDA ,X+
    DECB
    BMI PSHEXOK
    JSR GETHEX

PSHEXOK:
    STZ    
    RTS

PSHEXERR:
    CLZ
    RTS

; =============================================================================
;   PARSE HEX DIGIT IN A REGISTER AND SHIFT IT INTO 16-bit 'HEXADDR'
; =============================================================================

GETHEX:
    CMPA #'0'
    BLO GH_ERROR
    CMPA #'9'
    BHI GH_ALPHA    ; not numeric, might be alpha

GH_OK:
    LSL HEXADDR+1   ; shift 16-bit number at addr HEXADDR left x4
    ROL HEXADDR
    LSL HEXADDR+1
    ROL HEXADDR
    LSL HEXADDR+1
    ROL HEXADDR
    LSL HEXADDR+1
    ROL HEXADDR
    ANDA #%00001111 ; keep the lower nibble
    ADDA HEXADDR+1
    STA HEXADDR+1
    JMP GH_EXIT

GH_ALPHA:
    CMPA #'A'
    BLO GH_ERROR
    CMPA #'F'
    BHI GH_ERROR
    SUBA #7         ; convert 'A'..'F' -> 10 .. 15
    JMP GH_OK

GH_ERROR:
    CLZ             ; clear zero flag -> error
    RTS

GH_EXIT:
    STZ             ; set zero flag -> ok
    RTS

; =============================================================================
;   INITIALISE HEXADDR
; =============================================================================
INITHEX:
    PSHS    B,X
    CLRB
    LDX     #HEXADDR
    STB     ,X+
    STB     0,X
    PULS    B,X
    RTS

; =============================================================================
;   WRITE CONTENTS OF A TO CONSOLE AS HEX NUMBER
; =============================================================================
WRITEHEX:
    PSHS A,B
    TFR A,B
    LSRA
    LSRA
    LSRA
    LSRA
    CMPA #9
    BHI WH_ALPHA
    ADDA #48
    JSR OUTCHAR
    JMP WH_DIGIT2

WH_ALPHA:
    ADDA #55
    JSR OUTCHAR

WH_DIGIT2:
    TFR B,A
    ANDA #%00001111
    CMPA #9
    BHI WH_ALPHA2
    ADDA #48
    JSR OUTCHAR
    JMP WH_EXIT

WH_ALPHA2:
    ADDA #55
    JSR OUTCHAR

WH_EXIT:
    PULS A,B
    RTS

; =============================================================================
;   ENTRY POINT
; =============================================================================
    
START:
    ORCC #%01010000 ; disable interrupts
    LDS  #STACK     ; set the stack pointer

    ; ****************************************
    ; init UART 
    ;   baud divisor to 48 -> 9600 baud
    ;   8 bits, 1 stop bit, no parity
    ; 
    ; ****************************************
    CLRA 
    STA SER_IER     ; no interrupts
    NOP
    NOP
    NOP
    NOP
    STA SER_FCR     ; no FIFO
    NOP
    NOP
    NOP
    NOP    
    LDA #$83        ; 8 bits per symbol, no parity, enable baud reg access
    STA SER_LCR     ;   line control
    NOP
    NOP
    NOP
    NOP    
    LDA #$4         ; set at least one led to ON
    STA SER_MCR     ;   modem control
    NOP
    NOP
    NOP
    NOP    
    LDA #48
    STA SER_DLL
    NOP
    NOP
    NOP
    NOP    
    CLRA
    STA SER_DLM
    NOP
    NOP
    NOP
    NOP    
    LDA #$03        ; 8 bits per symbol, no parity, disable baud reg access
    STA SER_LCR
    NOP
    NOP    
    NOP
    NOP

    ; print the sign-on string
    LDX #SIGNON
    JSR PRINTSTRING 

DO_PROMPT:
    JMP CMDINT

SIGNON  .ascii "HD6309 Computer bootrom version 1.0"
        .db 10,13,0

; ==================================================    
; ROM ROUTINE JUMP TABLE
; ==================================================    

    ORG $FFA0
    .dw CMDINT    
    .dw INCHAR
    .dw INCHARE
    .dw INCHECK
    .dw OUTCHAR
    .dw PRINTSTRING
    .dw WRITEHEX


; ==================================================    
; INTERRUPT SERVICE ROUTINE INDIRECTIONS
; ==================================================    

SWI3VECTOR_ISR:
    JMP START

SWI2VECTOR_ISR:
    JMP [SWI2ADDR]
    
FIRQVECTOR_ISR:
    JMP [FIRQADDR]
    
IRQVECTOR_ISR:
    JMP [IRQADDR]
    
SWIVECTOR_ISR:
    JMP [SWIADDR]
    
NMIVECTOR_ISR:
    JMP [NMIADDR]

; =============================================================================
;   INTERRUPT VECTORS
; =============================================================================

    ORG $FFF2

SWI3VECTOR:  FDB SWI3VECTOR_ISR
SWI2VECTOR:  FDB SWI2VECTOR_ISR
FIRQVECTOR:  FDB FIRQVECTOR_ISR
IRQVECTOR:   FDB IRQVECTOR_ISR
SWIVECTOR:   FDB SWIVECTOR_ISR
NMIVECTOR:   FDB NMIVECTOR_ISR
RESETVECTOR: FDB START
