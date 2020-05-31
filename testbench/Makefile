.PHONY: all
all: fmh_frame_buffer_testbench.fst \

FMH_FRAME_BUFFER_TEST_SRC = \
	../src/fmh_frame_buffer.vhd \
	fmh_frame_buffer_testbench.vhd
fmh_frame_buffer_testbench.fst: $(FMH_FRAME_BUFFER_TEST_SRC)
	nvc -a $(FMH_FRAME_BUFFER_TEST_SRC)
	nvc -e fmh_frame_buffer_testbench
	nvc -r fmh_frame_buffer_testbench --wave

.PHONY: clean
clean:
	rm -f work/*
	-rmdir work/
	rm -f *.fst

