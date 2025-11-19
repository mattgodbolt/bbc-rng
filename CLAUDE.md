# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BBC Micro assembly project implementing a random number generator using disk drive timing entropy. The goal is to implement a Mersenne Twister PRNG seeded from physical disk drive seek timings on real BBC Master hardware.

## Build Commands

```bash
make              # Build bbc-rng.ssd disk image
make clean        # Remove generated .ssd files
```

Requires `beebasm` assembler to be installed.

## Architecture

- **bbc-rng.asm** - Main assembly source containing:
  - LFSR-based 16-bit RNG (placeholder for Mersenne Twister)
  - Helper routines: print, printHex, newline
  - Dummy data files (D.0-D.F) for disk seek entropy collection
  - Code loads at &2000, uses zero-page locations &70-&73

The project outputs an SSD disk image bootable on BBC Micro/Master hardware or emulators.

## 6502 Assembly Conventions

- BeebAsm syntax with local labels using braces `{ }`
- OS calls via vectors (oswrch = &FFEE)
- Zero-page variables for working memory
