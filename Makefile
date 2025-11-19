BEEBASM?=beebasm
BEEBASMOPTS=-v

.PHONY: default
default: bbc-rng.ssd

%.ssd: %.asm
	$(BEEBASM) -i $< -do $@ -boot Code $(BEEBASMOPTS)

.PHONY: clean
clean:
	rm -f *.ssd
