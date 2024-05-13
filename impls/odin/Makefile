STEPS = step0_repl step1_read_print step2_eval step3_env step4_if_fn_do step5_tco step6_file step7_quote step8_macros step9_try stepA_mal

all: $(STEPS)

# This is a 'Static Pattern Rule'.
# It works on any member of STEPS,
# capturing the input with % and checking
# if the corresponding .odin file exists.
$(STEPS): %: %.odin
	odin build $< -file

.PHONY: clean $(STEPS)

clean:
	rm -f $(STEPS)
