STEPS = step0_repl step1_read_print step2_eval step3_env step4_if_fn_do step5_tco step6_file step7_quote step8_macros step9_try stepA_mal

all: $(STEPS)

step0_repl: step0_repl/step0_repl.odin
	cd step0_repl && odin build .

step1_read_print: step1_read_print/step1_read_print.odin
	cd step1_read_print && odin build .

# %: %/%.odin
# 	cd $@ && odin build .

.PHONY: clean $(STEPS)

clean:
	rm -f $(STEPS)
