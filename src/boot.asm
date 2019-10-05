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

; ==================================================
; SYSTEM CONSTANTS
; ==================================================

RAMSTART  EQU $0000     ; lowest RAM location
RAMEND    EQU $E000     ; highest RAM location
STACK     EQU $DEFF     ; initial stack pointer

LINEPTR   EQU $DF00     ; pointer to 256 char line buffer

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
    ;LDA #10
    ;JSR OUTCHAR
    ;LDA #13
    ;JSR OUTCHAR
    PULS X
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
    LDX #PROMPT
    JSR PRINTSTRING

    ; get user input
    JSR GETLINE

    LDA #10
    JSR OUTCHAR
    LDA #13
    JSR OUTCHAR

    ; interpret user input

    JMP DO_PROMPT

SIGNON  .ascii "HD6309 Computer bootrom version 1.0"
        .db 10,13,0

PROMPT  .ascii "> "
        .db 0
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