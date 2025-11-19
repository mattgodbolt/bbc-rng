oswrch = &FFEE
ptr = &70
rngseed = &72

ORG &2000

.start
    LDA #22:JSR oswrch
    LDA #7:JSR oswrch
    LDA #title MOD 256:STA ptr
    LDA #title DIV 256:STA ptr+1
    JSR print
    JSR print
    jsr newline

    lda #&e1:sta rngseed
    lda #&ac:sta rngseed+1

    LDY #16
.loop
    jsr rng8bits:jsr printHex
    DEY: BNE loop
    jsr newline

.done
    JMP done

.newline
    lda #10:JSR oswrch:lda #13:JMP oswrch

.rng8bits
{
    LDX #8
.loop
    JSR rng1bit
    ROL A
    DEX
    BNE loop
    RTS
}

.rng1bit ; carry bit has the new random bit
{
    LDA rngseed
    LSR A: LSR A: STA ptr ; lfsr >> 2
    LSR a: STA ptr+1 ; lfsr >> 3
    LSR A: LSR A ; lfsr >> 5
    EOR ptr+1
    EOR ptr
    AND #1
    CMP #1 ; carry set if bit 0 was 1
    LDA rngseed+1: ROR A: sta rngseed+1
    LDA rngseed: ROR A: sta rngseed
    rts
}

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