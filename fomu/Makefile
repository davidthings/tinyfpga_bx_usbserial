# Simple Fomu Makefile
# --------------------
# This Makefile shows the steps to generate a DFU loadable image onto
# Fomu pvt board.

include ./board.mk

# Default FOMU revision.
FOMU_REV = pvt

# Source path and files.
BASENAME = hello_world
RTL_USB_DIR = ../usb
SOURCES = \
        $(RTL_USB_DIR)/edge_detect.v \
        $(RTL_USB_DIR)/serial.v \
        $(RTL_USB_DIR)/usb_fs_in_arb.v \
        $(RTL_USB_DIR)/usb_fs_in_pe.v \
        $(RTL_USB_DIR)/usb_fs_out_arb.v \
        $(RTL_USB_DIR)/usb_fs_out_pe.v \
        $(RTL_USB_DIR)/usb_fs_pe.v \
        $(RTL_USB_DIR)/usb_fs_rx.v \
        $(RTL_USB_DIR)/usb_fs_tx_mux.v \
        $(RTL_USB_DIR)/usb_fs_tx.v \
        $(RTL_USB_DIR)/usb_reset_det.v \
        $(RTL_USB_DIR)/usb_serial_ctrl_ep.v \
        $(RTL_USB_DIR)/usb_uart_bridge_ep.v \
        $(RTL_USB_DIR)/usb_uart_core.v \
        $(RTL_USB_DIR)/usb_uart_i40.v \
        ../pll.v

SRC = $(BASENAME).v $(SOURCES)

# Default target: run all required targets to build the DFU image.
all: $(BASENAME).dfu
	@true

.DEFAULT: all

# Use *Yosys* to generate the synthesized netlist.
# This is called the **synthesis** and **tech mapping** step.
$(BASENAME).json: $(SRC)
	yosys \
		$(YOSYSFLAGS) \
		-p 'synth_ice40 -top $(BASENAME) -json $(BASENAME).json' $(SRC)

# Use **nextpnr** to generate the FPGA configuration.
# This is called the **place** and **route** step.
$(BASENAME).asc: $(BASENAME).json $(PCF)
	nextpnr-ice40 \
		$(PNRFLAGS) \
		--pcf $(PCF) \
		--json $(BASENAME).json \
		--asc $(BASENAME).asc 

# Use icepack to convert the FPGA configuration into a "bitstream" loadable onto the FPGA.
# This is called the bitstream generation step.
$(BASENAME).bit: $(BASENAME).asc
	icepack $(BASENAME).asc $(BASENAME).bit

# Use dfu-suffix to generate the DFU image from the FPGA bitstream.
$(BASENAME).dfu: $(BASENAME).bit
	cp $(BASENAME).bit $(BASENAME).dfu
	dfu-suffix -v 1209 -p 70b1 -a $(BASENAME).dfu

# Use df-util to load the DFU image onto the Fomu.
load: $(BASENAME).dfu
	dfu-util -D $(BASENAME).dfu

.PHONY: load

# Cleanup the generated files.
clean:
	-rm -f $(BASENAME).json 	# Generate netlist
	-rm -f $(BASENAME).asc 	# FPGA configuration
	-rm -f $(BASENAME).bit 	# FPGA bitstream
	-rm -f $(BASENAME).dfu 	# DFU image loadable onto the Fomu

.PHONY: clean
