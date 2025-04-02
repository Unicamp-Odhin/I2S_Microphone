.PHONY: all load

all: out.bit

out.bit: out.config
	ecppack --compress --input out.config --bit out.bit

out.config: out.json pin.lpf
	nextpnr-ecp5 --json out.json --lpf pin.lpf --textcfg out.config \
	--package CABGA381 --45k --speed 6

out.json: main.sv
	yosys -p "read_verilog -sv *.sv; synth_ecp5 -json out.json -abc9"

load: out.bit
	openFPGALoader -b colorlight-i9 out.bit

iverilog:
	iverilog -g2012 -o main_tb -s main_tb *.sv simulation/main_tb.sv
	vvp main_tb

clean:
	rm -f out.json out.config out.bit