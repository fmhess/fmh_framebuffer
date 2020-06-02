.PHONY: all
all: fmh_framebuffer_testbench.fst

FMH_FRAMEBUFFER_TEST_SRC = \
	../src/fmh_framebuffer_ocram.vhd \
	../src/fmh_framebuffer.vhd \
	fmh_framebuffer_testbench.vhd
fmh_framebuffer_testbench.fst: $(FMH_FRAMEBUFFER_TEST_SRC)
	nvc -a $(FMH_FRAMEBUFFER_TEST_SRC)
	nvc -e fmh_framebuffer_testbench
	nvc -r fmh_framebuffer_testbench --wave

.PHONY: clean
clean:
	rm -f work/*
	-rmdir work/
	rm -f *.fst

