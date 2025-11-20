ORG &70
.ptr            SKIP 2
.mt_index       SKIP 2      ; Current index (word)
.loop_index     SKIP 2      ; 16-bit loop counter
.k_counter      SKIP 2      ; 16-bit counter for init_by_array
.state_ptr      SKIP 2      ; Pointer for state array access
.w0             SKIP 4      ; 32-bit work registers
.w1             SKIP 4
.w2             SKIP 4
.w3             SKIP 4
.temp           SKIP 4
.result         SKIP 4
.current_file   SKIP 1      ; Current D.x file for entropy
.entropy_idx    SKIP 1      ; Index into entropy array (0-15)

oswrch = &FFEE
osfile = &FFDD

\ Constants
MT_N = 624
MT_M = 397
ENTROPY_COUNT = 16

\ VIA timer for entropy collection (User VIA Timer 1)
VIA_T1CL = &FE64
VIA_T1CH = &FE65

ORG &2000

.start
    LDA #22:JSR oswrch
    LDA #7:JSR oswrch
    LDA #LO(title):STA ptr
    LDA #HI(title):STA ptr+1
    JSR print
    JSR print
    jsr newline

    ; Collect entropy from disc seeks and initialize MT
    JSR collect_entropy
    JSR print0: EQUS 134, "Initialising MT19937 with entropy...", 10, 13, 0
    JSR mt_init_by_array

    JSR print0: EQUS 134, "Generating random numbers:", 10, 13, 0

    LDX #8
.loop
    TXA:PHA

    LDA #130:JSR oswrch
    JSR mt_rand:JSR print32result:lda #32: jsr oswrch
    JSR mt_rand:JSR print32result:lda #32: jsr oswrch
    JSR mt_rand:JSR print32result:lda #32: jsr oswrch
    JSR mt_rand:JSR print32result
    JSR newline

    PLA:TAX    
    DEX
    BNE loop

.done
    JMP done

.title EQUS 141, 129, "BBC Micro", 133, "Disc Drive RNG", 10, 13, 0

.newline
    lda #10:JSR oswrch:lda #13:JMP oswrch

.print32result
{
    ldy #3
.loop
    TYA:PHA
    LDA result, Y
    JSR printHex
    PLA:TAY
    DEY
    bpl loop
    RTS
}

.print0
    PLA: CLC: ADC #1: STA ptr
    PLA: ADC #0 : STA ptr+1
    JSR print
    TYA: CLC: ADC ptr: STA ptr
    LDA#0: ADC ptr+1: PHA
    LDA ptr: PHA: RTS

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; from claude!

\ ============================================================================
\ 32-bit arithmetic helpers
\ ============================================================================

\ Copy 4 bytes from zp address A to zp address X
.copy32
{
    STA src+1
    STX dst+1
    LDX #3
.loop
.src LDA &00, X
.dst STA &00, X
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
    LDX #256-4          ; Start at -4, count up to 0
    CLC
.loop
    LDA w0+4, X         ; X=$FC accesses w0+0, etc.
    ADC w1+4, X
    STA w0+4, X
    INX
    BNE loop
    RTS
}

\ Multiply w0 by w1, result in w0 (32x32->32 bit multiply)
\ This is a simple shift-and-add multiply
.multiply_w0_by_w1
{
    ; Save w0 to temp
    LDA #w0 : LDX #temp : JSR copy32
    
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
    LDA w0 + 0
    ADC temp + 0
    STA w0 + 0
    LDA w0 + 1
    ADC temp + 1
    STA w0 + 1
    LDA w0 + 2
    ADC temp + 2
    STA w0 + 2
    LDA w0 + 3
    ADC temp + 3
    STA w0 + 3
    
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
\ Entropy Collection
\ ============================================================================

\ Zero the entropy array
.zero_entropy
{
    LDA #0
    LDX #ENTROPY_COUNT * 4 - 1
.loop
    STA entropy_array, X
    DEX
    BPL loop
    RTS
}

\ Collect entropy from disc seeks
\ Performs a number of disc seeks, mixing timing into 16 entropy words
.collect_entropy
{
    JSR print0: EQUS 134, "Collecting entropy...", 10, 13, 0
    JSR zero_entropy

    ; Get initial file from timer
    LDA VIA_T1CL
    AND #&0F
    STA current_file

    ; Initialize entropy index
    LDA #0
    STA entropy_idx

    ; Loop counter (two samples per entropy word)
ENTROPY_SAMPLES = ENTROPY_COUNT * 2
    LDA #ENTROPY_SAMPLES
    STA temp

.collect_loop
    ; Read start time
    LDA VIA_T1CL
    STA w0
    LDA VIA_T1CH
    STA w0 + 1

    ; Load the file D.{current_file}
    JSR load_entropy_file

    ; Read end time and calculate difference
    SEC
    LDA VIA_T1CL
    SBC w0
    STA w0              ; Low byte of difference
    LDA VIA_T1CH
    SBC w0 + 1
    STA w0 + 1          ; High byte of difference

    LDA w0: JSR printHex
    LDA w0 + 1: JSR printHex
    LDA #131: JSR oswrch
    LDA #'(': JSR oswrch
    LDA #33: SEC: SBC temp: JSR printHex
    JSR print0: EQUS "/", STR$~(ENTROPY_SAMPLES),")", 13, 0

    ; Mix into entropy[entropy_idx]
    ; entropy = ROL(entropy, 5) XOR sample

    ; Calculate entropy array address
    LDA entropy_idx
    ASL A
    ASL A
    CLC
    ADC #LO(entropy_array)
    STA state_ptr
    LDA #HI(entropy_array)
    ADC #0
    STA state_ptr + 1

    ; Load entropy word into w2
    LDY #0
    LDA (state_ptr), Y
    STA w2 + 0
    INY
    LDA (state_ptr), Y
    STA w2 + 1
    INY
    LDA (state_ptr), Y
    STA w2 + 2
    INY
    LDA (state_ptr), Y
    STA w2 + 3

    ; Rotate w2 right by 3 (= rotate left by 5)
    LDX #3
.rotate
    LSR w2 + 3
    ROR w2 + 2
    ROR w2 + 1
    ROR w2 + 0
    DEX
    BNE rotate

    ; XOR with sample (16-bit)
    LDA w2 + 0
    EOR w0
    STA w2 + 0
    LDA w2 + 1
    EOR w0 + 1
    STA w2 + 1

    ; Store back to entropy array
    LDY #0
    LDA w2 + 0
    STA (state_ptr), Y
    INY
    LDA w2 + 1
    STA (state_ptr), Y
    INY
    LDA w2 + 2
    STA (state_ptr), Y
    INY
    LDA w2 + 3
    STA (state_ptr), Y

    ; Update entropy_idx
    LDA entropy_idx
    CLC:ADC #1
    CMP #ENTROPY_COUNT
    BCC no_wrap
    LDA #0
.no_wrap
    STA entropy_idx

    ; Update current_file = sample AND &0F
    LDA w0
    AND #&0F
    STA current_file

    ; Decrement loop counter
    DEC temp
    BEQ collect_done
    JMP collect_loop

.collect_done
    JMP newline
}

\ Load file D.{current_file}
.load_entropy_file
{
    ; Build filename "D.x" where x is hex digit
    LDA current_file
    CMP #10
    BCC is_digit
    ADC #('A' - 10 - 1)
    JMP store_char
.is_digit
    ADC #'0'
.store_char
    STA filename + 2

    JSR print0: EQUS 131, "Timing D.", 0
    LDA filename+2: JSR oswrch
    LDA #129: JSR oswrch

    LDA #LO(load_buffer): STA osfile_block + 2
    LDA #HI(load_buffer): STA osfile_block + 3
    LDA #0: STA osfile_block + 4
    STA osfile_block + 5
    STA osfile_block + 6
    LDA #&FF
    LDX #LO(osfile_block)
    LDY #HI(osfile_block)
    JMP osfile
}

.filename EQUS "D.0", 13
.osfile_block
    EQUW filename
    EQUD 0
    EQUD 0
    EQUD 0
    EQUD 0

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
    ; Add state_array base
    CLC
    LDA state_ptr
    ADC #LO(state_array)
    STA state_ptr
    LDA state_ptr + 1
    ADC #HI(state_array)
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
    ; Load state[i-1] by computing ptr for i then subtracting 4
    JSR calc_state_ptr
    SEC
    LDA state_ptr
    SBC #4
    STA state_ptr
    LDA state_ptr + 1
    SBC #0
    STA state_ptr + 1
    ; Load from state_ptr (which now points to state[i-1])
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

    ; w1 = w0 (save original)
    LDA #w0 : LDX #w1 : JSR copy32

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

\ Initialize MT with array of seeds (at ENTROPY_BASE, ENTROPY_COUNT elements)
\ Standard MT19937 init_by_array algorithm
.mt_init_by_array
{
    ; First initialize with fixed seed 19650218 (&012BC86A)
    LDA #&6A
    STA w0 + 0
    LDA #&C8
    STA w0 + 1
    LDA #&2B
    STA w0 + 2
    LDA #&01
    STA w0 + 3
    JSR mt_init

    ; i = 1, j = 0
    LDA #1
    STA loop_index
    LDA #0
    STA loop_index + 1
    STA entropy_idx         ; j = 0

    ; k = max(N, key_length) = N since N > 16
    ; We'll do N iterations for first loop
    LDA #LO(MT_N)
    STA k_counter
    LDA #HI(MT_N)
    STA k_counter + 1

.loop1
    ; Load state[i-1]
    JSR calc_state_ptr
    SEC
    LDA state_ptr
    SBC #4
    STA state_ptr
    LDA state_ptr + 1
    SBC #0
    STA state_ptr + 1
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

    ; w1 = w0
    LDA #w0 : LDX #w1 : JSR copy32

    ; w0 = w0 >> 30
    LDA #30
    JSR shr_w0

    ; w0 = state[i-1] XOR (state[i-1] >> 30)
    JSR xor_w1_into_w0

    ; w1 = 1664525 (&0019660D)
    LDA #&0D
    STA w1 + 0
    LDA #&66
    STA w1 + 1
    LDA #&19
    STA w1 + 2
    LDA #&00
    STA w1 + 3

    ; w0 = w0 * 1664525
    JSR multiply_w0_by_w1

    ; Save multiply result to w1
    LDA #w0 : LDX #w1 : JSR copy32

    ; Load state[i] into w0
    JSR load_state

    ; w0 = state[i] XOR (previous calculation in w1)
    JSR xor_w1_into_w0

    ; Add init_key[j] (from entropy array)
    LDA entropy_idx
    ASL A
    ASL A
    TAY
    LDA entropy_array + 0, Y
    STA w1 + 0
    LDA entropy_array + 1, Y
    STA w1 + 1
    LDA entropy_array + 2, Y
    STA w1 + 2
    LDA entropy_array + 3, Y
    STA w1 + 3
    JSR add_w1_to_w0

    ; Add j
    LDA entropy_idx
    STA w1 + 0
    LDA #0
    STA w1 + 1
    STA w1 + 2
    STA w1 + 3
    JSR add_w1_to_w0

    ; Store to state[i]
    JSR store_state

    ; i++
    INC loop_index
    BNE no_wrap1
    INC loop_index + 1
.no_wrap1
    ; if i >= N, i = 1, state[0] = state[N-1]
    LDA loop_index + 1
    CMP #HI(MT_N)
    BCC no_iwrap1
    BNE do_iwrap1
    LDA loop_index
    CMP #LO(MT_N)
    BCC no_iwrap1
.do_iwrap1
    ; Copy state[N-1] to state[0]
    LDA #LO(MT_N - 1)
    STA loop_index
    LDA #HI(MT_N - 1)
    STA loop_index + 1
    JSR load_state
    LDA #0
    STA loop_index
    STA loop_index + 1
    JSR store_state
    ; i = 1
    LDA #1
    STA loop_index
    LDA #0
    STA loop_index + 1
.no_iwrap1

    ; j++, if j >= key_length, j = 0
    INC entropy_idx
    LDA entropy_idx
    CMP #ENTROPY_COUNT
    BCC no_jwrap1
    LDA #0
    STA entropy_idx
.no_jwrap1

    ; k--
    LDA k_counter
    SEC
    SBC #1
    STA k_counter
    LDA k_counter + 1
    SBC #0
    STA k_counter + 1
    ; if k > 0, continue
    ORA k_counter
    BEQ loop1_done
    JMP loop1
.loop1_done

    ; Second loop: k = N-1
    LDA #LO(MT_N - 1)
    STA k_counter
    LDA #HI(MT_N - 1)
    STA k_counter + 1

.loop2
    ; Load state[i-1]
    JSR calc_state_ptr
    SEC
    LDA state_ptr
    SBC #4
    STA state_ptr
    LDA state_ptr + 1
    SBC #0
    STA state_ptr + 1
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

    ; w1 = w0
    LDA #w0 : LDX #w1 : JSR copy32

    ; w0 = w0 >> 30
    LDA #30
    JSR shr_w0

    ; w0 = state[i-1] XOR (state[i-1] >> 30)
    JSR xor_w1_into_w0

    ; w1 = 1566083941 (&5D588B65)
    LDA #&65
    STA w1 + 0
    LDA #&8B
    STA w1 + 1
    LDA #&58
    STA w1 + 2
    LDA #&5D
    STA w1 + 3

    ; w0 = w0 * 1566083941
    JSR multiply_w0_by_w1

    ; Save multiply result to w1
    LDA #w0 : LDX #w1 : JSR copy32

    ; Load state[i] into w0
    JSR load_state

    ; w0 = state[i] XOR (previous calculation in w1)
    JSR xor_w1_into_w0

    ; Subtract i (w0 = w0 - i)
    SEC
    LDA w0 + 0
    SBC loop_index
    STA w0 + 0
    LDA w0 + 1
    SBC loop_index + 1
    STA w0 + 1
    LDA w0 + 2
    SBC #0
    STA w0 + 2
    LDA w0 + 3
    SBC #0
    STA w0 + 3

    ; Store to state[i]
    JSR store_state

    ; i++
    INC loop_index
    BNE no_wrap2
    INC loop_index + 1
.no_wrap2
    ; if i >= N, i = 1, state[0] = state[N-1]
    LDA loop_index + 1
    CMP #HI(MT_N)
    BCC no_iwrap2
    BNE do_iwrap2
    LDA loop_index
    CMP #LO(MT_N)
    BCC no_iwrap2
.do_iwrap2
    ; Copy state[N-1] to state[0]
    LDA #LO(MT_N - 1)
    STA loop_index
    LDA #HI(MT_N - 1)
    STA loop_index + 1
    JSR load_state
    LDA #0
    STA loop_index
    STA loop_index + 1
    JSR store_state
    ; i = 1
    LDA #1
    STA loop_index
    LDA #0
    STA loop_index + 1
.no_iwrap2

    ; k--
    LDA k_counter
    SEC
    SBC #1
    STA k_counter
    LDA k_counter + 1
    SBC #0
    STA k_counter + 1
    ; if k > 0, continue
    ORA k_counter
    BEQ loop2_done
    JMP loop2
.loop2_done

    ; state[0] = 0x80000000
    LDA #0
    STA loop_index
    STA loop_index + 1
    LDA #0
    STA w0 + 0
    STA w0 + 1
    STA w0 + 2
    LDA #&80
    STA w0 + 3
    JSR store_state

    ; Reset index to force twist
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
    LDA w0 + 3
    AND #&80
    STA w0 + 3
    LDA #0
    STA w0 + 0
    STA w0 + 1
    STA w0 + 2

    ; Save (state[i] & UPPER_MASK) to w2
    LDA #w0 : LDX #w2 : JSR copy32

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
    LDA w0 + 3
    AND #&7F
    STA w0 + 3
    ; Lower 3 bytes unchanged

    ; w0 = (state[i] & UPPER) | (state[i+1] & LOWER)
    ; w2 has upper part
    LDA #w2 : LDX #w1 : JSR copy32
    JSR or_w1_with_w0

    ; Save y to w2
    LDA #w0 : LDX #w2 : JSR copy32

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
    LDA #w0 : LDX #w3 : JSR copy32

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
    LDA #w3 : LDX #w1 : JSR copy32
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
    LDA #w0 : LDX #w2 : JSR copy32

    ; y ^= (y >> 11)
    LDA #11
    JSR shr_w0
    ; Copy w2 (original) to w1 for XOR
    LDA #w2 : LDX #w1 : JSR copy32
    JSR xor_w1_into_w0

    ; Save y
    LDA #w0 : LDX #w2 : JSR copy32
    
    ; y ^= (y << 7) & 0x9D2C5680
    LDA #w0 : LDX #w1 : JSR copy32
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

    LDA #w2 : LDX #w1 : JSR copy32
    JSR xor_w1_into_w0

    ; Save y
    LDA #w0 : LDX #w2 : JSR copy32
    
    ; y ^= (y << 15) & 0xEFC60000
    LDA #w0 : LDX #w1 : JSR copy32
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

    LDA #w2 : LDX #w1 : JSR copy32
    JSR xor_w1_into_w0
    
    ; y ^= (y >> 18)
    LDA #w0 : LDX #w1 : JSR copy32
    LDA #18
    JSR shr_w0
    JSR xor_w1_into_w0
    
    ; Store result
    LDA #w0 : LDX #result : JSR copy32
    
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

DUMMY_FILE_SIZE = 4096
.state_array    SKIP MT_N * 4
.entropy_array  SKIP ENTROPY_COUNT * 4
.load_buffer    SKIP DUMMY_FILE_SIZE

; Dummy files purely to seek to.
{
ORG 0
.data EQUS "I am just data we don't care about"
.end
FOR n, 0, 15
    SAVE "D."+STR$~(n), data, data + DUMMY_FILE_SIZE, 0, 0
NEXT
}
