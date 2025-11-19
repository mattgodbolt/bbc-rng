oswrch = &FFEE
ptr = &70

ORG &2000

.start
    LDA #22:JSR oswrch
    LDA #7:JSR oswrch
    LDA #mytext MOD 256:STA ptr
    LDA #mytext DIV 256:STA ptr+1
    JSR print
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

.mytext EQUS "BBC Micro Disk Drive RNG", 10, 13, 0
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