# Simple Fomu Makefile
# --------------------
# This Makefile shows the steps to generate a DFU loadable image onto
# Fomu board.

# Default FOMU revision.
FOMU_REV = pvt

# Select board options.
include ./board.mk

# Project name, source path and files.
PROJECT ?= hello_world
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
        $(RTL_USB_DIR)/usb_uart_i40.v

SRC = $(PROJECT).v $(SOURCES)

# Default target: run all required targets to build the DFU image.
all: $(PROJECT).dfu
	@true

.DEFAULT: all

# Use *Yosys* to generate the synthesized netlist.
# This is called the **synthesis** and **tech mapping** step.
$(PROJECT).json: $(SRC)
	yosys \
		$(YOSYSFLAGS) \
		-p 'synth_ice40 -top $(PROJECT) -json $(PROJECT).json' $(SRC)

# Use **nextpnr** to generate the FPGA configuration.
# This is called the **place** and **route** step.
$(PROJECT).asc: $(PROJECT).json $(PCF)
	nextpnr-ice40 \
		$(PNRFLAGS) \
		--pcf $(PCF) \
		--json $(PROJECT).json \
		--asc $(PROJECT).asc 

# Use icepack to convert the FPGA configuration into a "bitstream" loadable onto the FPGA.
# This is called the bitstream generation step.
$(PROJECT).bit: $(PROJECT).asc
	icepack $(PROJECT).asc $(PROJECT).bit

# Use dfu-suffix to generate the DFU image from the FPGA bitstream.
$(PROJECT).dfu: $(PROJECT).bit
	cp $(PROJECT).bit $(PROJECT).dfu
	dfu-suffix -v 1209 -p 70b1 -a $(PROJECT).dfu

# Use df-util to load the DFU image onto the Fomu.
load: $(PROJECT).dfu
	dfu-util -D $(PROJECT).dfu

.PHONY: load

# Cleanup the generated files.
clean:
	-rm -f abc.history      # ABC history
	-rm -f $(PROJECT).json  # Generate netlist
	-rm -f $(PROJECT).asc   # FPGA configuration
	-rm -f $(PROJECT).bit   # FPGA bitstream
	-rm -f $(PROJECT).dfu   # DFU image loadable onto the Fomu

.PHONY: clean
