BEEBASM?=beebasm
BEEBASMOPTS=-v

.PHONY: default
default: example.ssd

%.ssd: %.asm
	$(BEEBASM) -i $< -do $@ -boot MyCode $(BEEBASMOPTS)

.PHONY: clean
clean:
	rm -f *.ssd
