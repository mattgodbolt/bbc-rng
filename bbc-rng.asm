oswrch = &FFEE
ptr = &70

ORG &2000

.start
    LDA #22:JSR oswrch
    LDA #7:JSR oswrch
    LDA #title MOD 256:STA ptr
    LDA #title DIV 256:STA ptr+1
    JSR print
    JSR print

    lda #10:JSR oswrch:lda #13: JSR oswrch

    LDA #$01
    JSR printHex
    LDA #$23
    JSR printHex
    LDA #$fe
    JSR printHex
    LDA #$9a
    JSR printHex

.done
    JMP done

.print
{
    LDY #0
.loop
    LDA (ptr), Y
    BEQ finished
    JSR oswrch
    INY
    BNE loop
.finished
    RTS
}

.printHex
{
    PHA
    LSR A
    LSR A
    LSR A
    LSR A
    JSR printNibble
    PLA
    AND #$0F
    JMP printNibble
.printNibble
    CMP #10
    BCC isDigit
    ADC #(97 - 10 - 1)
    JMP oswrch
.isDigit
    ADC #$30
.done
    JSR oswrch
    RTS
}

.title EQUS 141, 134, "BBC Micro Disk Drive RNG", 10, 13, 0
.end

SAVE "Code", start, end

; Dummy files purely to seek to.
{
ORG 0
.data EQUS "I am just data we don't care about"
.end
FOR n, 0, 15
    SAVE "D."+STR$~(n), data, end, 0, 0
NEXT
}