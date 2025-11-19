#!/usr/bin/env python3
"""
MT19937 debug script for BBC Micro implementation.
Verifies expected values and mirrors 6502 code for debugging.
"""

# MT19937 constants
MT_N = 624
MT_M = 397
MATRIX_A = 0x9908B0DF
UPPER_MASK = 0x80000000
LOWER_MASK = 0x7FFFFFFF
MASK_32 = 0xFFFFFFFF

def standard_mt19937(seed):
    """Standard MT19937 implementation for reference."""
    state = [0] * MT_N
    index = MT_N

    # Initialize
    state[0] = seed & MASK_32
    for i in range(1, MT_N):
        state[i] = (1812433253 * (state[i-1] ^ (state[i-1] >> 30)) + i) & MASK_32

    def twist():
        nonlocal index
        for i in range(MT_N):
            y = (state[i] & UPPER_MASK) | (state[(i + 1) % MT_N] & LOWER_MASK)
            state[i] = state[(i + MT_M) % MT_N] ^ (y >> 1)
            if y & 1:
                state[i] ^= MATRIX_A
        index = 0

    def extract():
        nonlocal index
        if index >= MT_N:
            twist()

        y = state[index]
        y ^= (y >> 11)
        y ^= (y << 7) & 0x9D2C5680
        y ^= (y << 15) & 0xEFC60000
        y ^= (y >> 18)

        index += 1
        return y & MASK_32

    return extract


def mirror_6502_mt19937(seed, verbose=False):
    """
    Mirror of the 6502 implementation for debugging.
    Follows the exact same steps as the assembly code.
    """
    state = [0] * MT_N
    index = MT_N  # Start at MT_N to force twist on first use

    # Initialize - mirrors mt_init
    state[0] = seed & MASK_32
    if verbose:
        print(f"state[0] = {state[0]:08X}")

    for i in range(1, MT_N):
        prev = state[i-1]

        # w0 = state[i-1]
        w0 = prev

        # w1 = w0 (copy)
        w1 = w0

        # w0 = w0 >> 30
        w0 = w0 >> 30

        # w0 = w0 XOR w1
        w0 = w0 ^ w1

        # w1 = 1812433253
        w1 = 1812433253

        # w0 = w0 * w1 (32-bit truncated)
        w0 = (w0 * w1) & MASK_32

        # w0 = w0 + i
        w0 = (w0 + i) & MASK_32

        state[i] = w0

        if verbose and i <= 5:
            print(f"state[{i}] = {state[i]:08X}")

    if verbose:
        print(f"state[623] = {state[623]:08X}")
        print()

    def twist():
        nonlocal index
        if verbose:
            print("Twisting...")

        for i in range(MT_N):
            # y = (state[i] & UPPER_MASK) | (state[(i+1) % N] & LOWER_MASK)
            upper = state[i] & UPPER_MASK
            lower = state[(i + 1) % MT_N] & LOWER_MASK
            y = upper | lower

            # mag = (y >> 1) ^ (MATRIX_A if y & 1 else 0)
            mag = y >> 1
            if y & 1:
                mag ^= MATRIX_A

            # state[i] = state[(i + M) % N] ^ mag
            state[i] = state[(i + MT_M) % MT_N] ^ mag

        index = 0

        if verbose:
            print(f"After twist, state[0] = {state[0]:08X}")
            print()

    def extract():
        nonlocal index
        if index >= MT_N:
            twist()

        y = state[index]
        if verbose:
            print(f"Extracting state[{index}] = {y:08X}")

        # Tempering
        # y ^= (y >> 11)
        y1 = y >> 11
        y = y ^ y1
        if verbose:
            print(f"  After y ^= (y >> 11): {y:08X}")

        # y ^= (y << 7) & 0x9D2C5680
        y2 = (y << 7) & 0x9D2C5680
        y = y ^ y2
        if verbose:
            print(f"  After y ^= (y << 7) & mask: {y:08X}")

        # y ^= (y << 15) & 0xEFC60000
        y3 = (y << 15) & 0xEFC60000
        y = y ^ y3
        if verbose:
            print(f"  After y ^= (y << 15) & mask: {y:08X}")

        # y ^= (y >> 18)
        y4 = y >> 18
        y = y ^ y4
        if verbose:
            print(f"  After y ^= (y >> 18): {y:08X}")

        index += 1
        return y & MASK_32

    return extract, state


def main():
    seed = 5489

    print("=" * 60)
    print("Standard MT19937 Reference Output")
    print("=" * 60)
    rng = standard_mt19937(seed)
    print("First 10 values for seed 5489:")
    expected = []
    for i in range(10):
        val = rng()
        expected.append(val)
        print(f"{val:08X}")

    print()
    print("=" * 60)
    print("Mirror 6502 Implementation (verbose for first value)")
    print("=" * 60)
    extract, state = mirror_6502_mt19937(seed, verbose=True)

    print("First 10 values:")
    for i in range(10):
        val = extract()
        match = "OK" if val == expected[i] else "MISMATCH!"
        print(f"{val:08X} {match}")

    print()
    print("=" * 60)
    print("Expected values (for reference in code comments):")
    print("=" * 60)
    for i, val in enumerate(expected):
        print(f"  {i+1}. 0x{val:08X}")


if __name__ == "__main__":
    main()
