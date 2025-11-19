ORG &70
.ptr            SKIP 2
.mt_index       SKIP 2      ; Current index (word)
.loop_index     SKIP 2      ; 16-bit loop counter
.state_ptr      SKIP 2      ; Pointer for state array access
.w0             SKIP 4      ; 32-bit work registers
.w1             SKIP 4
.w2             SKIP 4
.w3             SKIP 4
.temp           SKIP 4
.result         SKIP 4

oswrch = &FFEE

\ Constants
MT_N = 624
MT_M = 397
MT_MATRIX_A = &9908B0DF     ; Constant vector a
MT_UPPER_MASK = &80000000   ; Most significant bit
MT_LOWER_MASK = &7FFFFFFF   ; Least significant 31 bits

\ State array lives at &3000 (624 * 4 = 2496 bytes)
STATE_BASE = &3000

ORG &2000

.start
    LDA #22:JSR oswrch
    LDA #7:JSR oswrch
    LDA #title MOD 256:STA ptr
    LDA #title DIV 256:STA ptr+1
    JSR print
    JSR print
    jsr newline

    ; Initialize with seed 5489
    LDA #&11
    STA w0 + 0
    LDA #&15
    STA w0 + 1
    LDA #0
    STA w0 + 2
    STA w0 + 3
    JSR mt_init
    
    ; Generate first 10 numbers and print them
    LDX #10
.loop
    TXA:PHA
    JSR mt_rand

    LDA result + 3
    JSR printHex
    LDA result + 2
    JSR printHex
    LDA result + 1
    JSR printHex
    LDA result + 0
    JSR printHex
    JSR newline

\ First 10 values for seed 5489 should be:
\ 0xD091BB5C
\ 0x22AE9EF6
\ 0xE7E1FAEE
\ 0xD5C31F79
\ 0x2082352C
\ 0xF807B7DF
\ 0xE9D30005
\ 0x3895AFE1
\ 0xA1E24BBA
\ 0x4EE4092B

    PLA:TAX    
    DEX
    BNE loop

.done
    JMP done


.newline
    lda #10:JSR oswrch:lda #13:JMP oswrch

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


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; from claude!

\ ============================================================================
\ 32-bit arithmetic helpers
\ ============================================================================

\ Copy w0 to w1
.copy_w0_to_w1
{
    LDX #3
.loop
    LDA w0, X
    STA w1, X
    DEX
    BPL loop
    RTS
}

\ XOR w1 into w0: w0 = w0 XOR w1
.xor_w1_into_w0
{
    LDX #3
.loop
    LDA w0, X
    EOR w1, X
    STA w0, X
    DEX
    BPL loop
    RTS
}

\ AND w1 with w0: w0 = w0 AND w1
.and_w1_with_w0
{
    LDX #3
.loop
    LDA w0, X
    AND w1, X
    STA w0, X
    DEX
    BPL loop
    RTS
}

\ OR w1 with w0: w0 = w0 OR w1
.or_w1_with_w0
{
    LDX #3
.loop
    LDA w0, X
    ORA w1, X
    STA w0, X
    DEX
    BPL loop
    RTS
}

\ Right shift w0 by A bits (A must be 1-31)
.shr_w0
{
    TAX                     ; X = shift count
.shift_loop
    LSR w0 + 3
    ROR w0 + 2
    ROR w0 + 1
    ROR w0 + 0
    DEX
    BNE shift_loop
    RTS
}

\ Left shift w0 by A bits (A must be 1-31)
.shl_w0
{
    TAX                     ; X = shift count
.shift_loop
    ASL w0 + 0
    ROL w0 + 1
    ROL w0 + 2
    ROL w0 + 3
    DEX
    BNE shift_loop
    RTS
}

\ Add w1 to w0: w0 = w0 + w1
.add_w1_to_w0
{
    CLC
    LDX #0
.loop
    LDA w0, X
    ADC w1, X
    STA w0, X
    INX
    CPX #4
    BNE loop
    RTS
}

\ Multiply w0 by w1, result in w0 (32x32->32 bit multiply)
\ This is a simple shift-and-add multiply
.multiply_w0_by_w1
{
    ; Save w0 to temp
    LDX #3
.save_loop
    LDA w0, X
    STA temp, X
    DEX
    BPL save_loop
    
    ; Zero w0 (will accumulate result)
    LDA #0
    STA w0 + 0
    STA w0 + 1
    STA w0 + 2
    STA w0 + 3
    
    LDX #32                 ; 32 bits to process
    
.mult_loop
    ; If low bit of w1 set, add temp to w0
    LDA w1 + 0
    LSR A
    BCC skip_add
    
    ; Add temp to w0
    CLC
    LDY #0
.add_loop
    LDA w0, Y
    ADC temp, Y
    STA w0, Y
    INY
    CPY #4
    BNE add_loop
    
.skip_add
    ; Shift temp left
    ASL temp + 0
    ROL temp + 1
    ROL temp + 2
    ROL temp + 3
    
    ; Shift w1 right
    LSR w1 + 3
    ROR w1 + 2
    ROR w1 + 1
    ROR w1 + 0
    
    DEX
    BNE mult_loop
    
    RTS
}

\ ============================================================================
\ MT19937 Implementation
\ ============================================================================

\ Calculate state_ptr = STATE_BASE + (loop_index * 4)
.calc_state_ptr
{
    ; state_ptr = loop_index * 4
    LDA loop_index
    ASL A
    STA state_ptr
    LDA loop_index + 1
    ROL A
    STA state_ptr + 1
    ; * 2 again
    ASL state_ptr
    ROL state_ptr + 1
    ; Add STATE_BASE
    CLC
    LDA state_ptr
    ADC #LO(STATE_BASE)
    STA state_ptr
    LDA state_ptr + 1
    ADC #HI(STATE_BASE)
    STA state_ptr + 1
    RTS
}

\ Load state[loop_index] into w0
.load_state
{
    JSR calc_state_ptr
    LDY #0
    LDA (state_ptr), Y
    STA w0 + 0
    INY
    LDA (state_ptr), Y
    STA w0 + 1
    INY
    LDA (state_ptr), Y
    STA w0 + 2
    INY
    LDA (state_ptr), Y
    STA w0 + 3
    RTS
}

\ Store w0 into state[loop_index]
.store_state
{
    JSR calc_state_ptr
    LDY #0
    LDA w0 + 0
    STA (state_ptr), Y
    INY
    LDA w0 + 1
    STA (state_ptr), Y
    INY
    LDA w0 + 2
    STA (state_ptr), Y
    INY
    LDA w0 + 3
    STA (state_ptr), Y
    RTS
}

\ Initialize MT with seed in w0
.mt_init
{
    ; state[0] = seed
    LDA #0
    STA loop_index
    STA loop_index + 1
    JSR store_state
    ; Start at i = 1
    LDA #1
    STA loop_index
    LDA #0
    STA loop_index + 1

.init_loop
    ; Load state[i-1]
    ; Decrement loop_index temporarily
    LDA loop_index
    SEC
    SBC #1
    STA loop_index
    LDA loop_index + 1
    SBC #0
    STA loop_index + 1

    JSR load_state

    ; Increment back to i
    INC loop_index
    BNE no_carry1
    INC loop_index + 1
.no_carry1

    ; w1 = w0 (save original)
    JSR copy_w0_to_w1

    ; w0 = w0 >> 30
    LDA #30
    JSR shr_w0

    ; w0 = state[i-1] XOR (state[i-1] >> 30)
    ; w1 still has original value
    JSR xor_w1_into_w0

    ; w1 = 1812433253 (&6C078965)
    LDA #&65
    STA w1 + 0
    LDA #&89
    STA w1 + 1
    LDA #&07
    STA w1 + 2
    LDA #&6C
    STA w1 + 3

    ; w0 = w0 * 1812433253
    JSR multiply_w0_by_w1

    ; w0 = w0 + i (16-bit index)
    LDA loop_index
    STA w1 + 0
    LDA loop_index + 1
    STA w1 + 1
    LDA #0
    STA w1 + 2
    STA w1 + 3
    JSR add_w1_to_w0

    ; state[i] = w0
    JSR store_state

    ; Increment loop_index
    INC loop_index
    BNE no_carry2
    INC loop_index + 1
.no_carry2

    ; Compare with MT_N (624 = &270)
    LDA loop_index + 1
    CMP #HI(MT_N)
    BCC init_loop           ; High byte less, continue
    BNE init_done           ; High byte greater, done
    LDA loop_index
    CMP #LO(MT_N)
    BCC init_loop           ; Low byte less, continue

.init_done
    ; Reset index to MT_N to force twist on first use
    LDA #LO(MT_N)
    STA mt_index
    LDA #HI(MT_N)
    STA mt_index + 1

    RTS
}

\ Twist the generator
.mt_twist
{
    ; Initialize loop counter to 0
    LDA #0
    STA loop_index
    STA loop_index + 1

.twist_loop
    ; w0 = state[i] & UPPER_MASK
    JSR load_state
    LDA #&00
    STA w1 + 0
    STA w1 + 1
    STA w1 + 2
    LDA #&80
    STA w1 + 3              ; w1 = UPPER_MASK
    JSR and_w1_with_w0

    ; Save (state[i] & UPPER_MASK) to w2
    LDX #3
.save_upper
    LDA w0, X
    STA w2, X
    DEX
    BPL save_upper

    ; Save current i to temp+2,temp+3
    LDA loop_index
    STA temp + 2
    LDA loop_index + 1
    STA temp + 3

    ; Calculate (i+1) mod N
    ; loop_index = i + 1
    INC loop_index
    BNE no_carry_i1
    INC loop_index + 1
.no_carry_i1
    ; Check if >= N
    LDA loop_index + 1
    CMP #HI(MT_N)
    BCC load_next           ; < N
    BNE wrap_i1             ; > N (high byte)
    LDA loop_index
    CMP #LO(MT_N)
    BCC load_next           ; < N
.wrap_i1
    ; Wrap to 0
    LDA #0
    STA loop_index
    STA loop_index + 1

.load_next
    ; w0 = state[(i+1) mod N] & LOWER_MASK
    JSR load_state
    LDA #&FF
    STA w1 + 0
    STA w1 + 1
    STA w1 + 2
    LDA #&7F
    STA w1 + 3              ; w1 = LOWER_MASK
    JSR and_w1_with_w0

    ; w0 = (state[i] & UPPER) | (state[i+1] & LOWER)
    ; w2 has upper part
    LDX #3
.or_parts
    LDA w2, X
    STA w1, X
    DEX
    BPL or_parts
    JSR or_w1_with_w0

    ; Save y to w2
    LDX #3
.save_y
    LDA w0, X
    STA w2, X
    DEX
    BPL save_y

    ; Check if y is odd (save flag)
    LDA w2 + 0
    AND #1
    STA temp + 0            ; Save odd flag

    ; w0 = y >> 1
    LDA #1
    JSR shr_w0

    ; If y was odd, XOR with MATRIX_A
    LDA temp + 0
    BEQ not_odd

    LDA #&DF
    STA w1 + 0
    LDA #&B0
    STA w1 + 1
    LDA #&08
    STA w1 + 2
    LDA #&99
    STA w1 + 3              ; w1 = MATRIX_A
    JSR xor_w1_into_w0

.not_odd
    ; Save (y >> 1) XOR mag to w3
    LDX #3
.save_mag
    LDA w0, X
    STA w3, X
    DEX
    BPL save_mag

    ; Calculate (i + M) mod N
    ; Restore i to loop_index
    LDA temp + 2
    STA loop_index
    LDA temp + 3
    STA loop_index + 1

    ; Add M
    CLC
    LDA loop_index
    ADC #LO(MT_M)
    STA loop_index
    LDA loop_index + 1
    ADC #HI(MT_M)
    STA loop_index + 1

    ; Check if >= N, subtract N if so
    LDA loop_index + 1
    CMP #HI(MT_N)
    BCC load_im             ; < N
    BNE wrap_im             ; > N (high byte)
    LDA loop_index
    CMP #LO(MT_N)
    BCC load_im             ; < N
.wrap_im
    ; Subtract N
    SEC
    LDA loop_index
    SBC #LO(MT_N)
    STA loop_index
    LDA loop_index + 1
    SBC #HI(MT_N)
    STA loop_index + 1

.load_im
    ; w0 = state[(i+M) mod N]
    JSR load_state

    ; w0 = state[(i+M) mod N] XOR w3
    LDX #3
.xor_mag
    LDA w3, X
    STA w1, X
    DEX
    BPL xor_mag
    JSR xor_w1_into_w0

    ; Restore i and store result
    LDA temp + 2
    STA loop_index
    LDA temp + 3
    STA loop_index + 1
    JSR store_state

    ; Increment i
    INC loop_index
    BNE no_carry_main
    INC loop_index + 1
.no_carry_main

    ; Check if i >= N (done if so)
    LDA loop_index + 1
    CMP #HI(MT_N)
    BCC continue_twist      ; High byte less, continue
    BNE twist_done          ; High byte greater, done
    LDA loop_index
    CMP #LO(MT_N)
    BCS twist_done          ; Low byte >= N, done

.continue_twist
    JMP twist_loop

.twist_done
    RTS
}

\ Generate random number, return in result
.mt_rand
{
    ; Check if we need to twist (mt_index >= MT_N)
    LDA mt_index + 1
    CMP #HI(MT_N)
    BCC no_twist            ; High byte less, no twist
    BNE do_twist            ; High byte greater, twist
    LDA mt_index
    CMP #LO(MT_N)
    BCC no_twist            ; Low byte less, no twist

.do_twist
    JSR mt_twist
    LDA #0
    STA mt_index
    STA mt_index + 1

.no_twist
    ; Copy mt_index to loop_index for load_state
    LDA mt_index
    STA loop_index
    LDA mt_index + 1
    STA loop_index + 1
    JSR load_state
    
    ; Save original y to w2
    LDX #3
.save_y
    LDA w0, X
    STA w2, X
    DEX
    BPL save_y

    ; y ^= (y >> 11)
    LDA #11
    JSR shr_w0
    ; Copy w2 (original) to w1 for XOR
    LDX #3
.copy_for_xor1
    LDA w2, X
    STA w1, X
    DEX
    BPL copy_for_xor1
    JSR xor_w1_into_w0
    
    ; Save y
    LDX #3
.save1
    LDA w0, X
    STA w2, X
    DEX
    BPL save1
    
    ; y ^= (y << 7) & 0x9D2C5680
    JSR copy_w0_to_w1
    LDA #7
    JSR shl_w0
    
    LDA #&80
    STA w1 + 0
    LDA #&56
    STA w1 + 1
    LDA #&2C
    STA w1 + 2
    LDA #&9D
    STA w1 + 3
    JSR and_w1_with_w0
    
    LDX #3
.restore1
    LDA w2, X
    STA w1, X
    DEX
    BPL restore1
    JSR xor_w1_into_w0
    
    ; Save y
    LDX #3
.save2
    LDA w0, X
    STA w2, X
    DEX
    BPL save2
    
    ; y ^= (y << 15) & 0xEFC60000
    JSR copy_w0_to_w1
    LDA #15
    JSR shl_w0
    
    LDA #&00
    STA w1 + 0
    STA w1 + 1
    LDA #&C6
    STA w1 + 2
    LDA #&EF
    STA w1 + 3
    JSR and_w1_with_w0
    
    LDX #3
.restore2
    LDA w2, X
    STA w1, X
    DEX
    BPL restore2
    JSR xor_w1_into_w0
    
    ; y ^= (y >> 18)
    JSR copy_w0_to_w1
    LDA #18
    JSR shr_w0
    JSR xor_w1_into_w0
    
    ; Store result
    LDX #3
.store_result
    LDA w0, X
    STA result, X
    DEX
    BPL store_result
    
    ; Increment index
    INC mt_index
    BNE no_carry
    INC mt_index + 1
.no_carry
    
    RTS
}

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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