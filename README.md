# 🎙️ I2S Microphone Peripheral

**SystemVerilog Peripheral for MSM261S4030H0 Microphone using I2S Interface**

This project implements a digital microphone peripheral using the I2S interface in SystemVerilog. It is designed for use with the **MSM261S4030H0** microphone, whose datasheet is available at `documentation/microphone.pdf`.

## 📘 About the Project

The main goal is to capture real-time audio data using an FPGA, process it, and make it available via SPI to an embedded system or computer. The project is compatible with various FPGA platforms and includes a software layer for converting the data into `.wav` files.

### 📌 Supported Devices

- **Colorlight i9**
- **Nexys4 DDR**
- **Nexys4 DDR with PMOD**
- **ZedBoard**

## 📁 Repository Structure

```text
├── documentation                # Datasheets and technical documents
│   └── microphone.pdf
├── format_sv.sh                 # Script for automatic formatting of .sv files
├── fpga                         # Folders and scripts specific to each FPGA
│   ├── colorlight_i9
│   ├── detect_hw.tcl
│   ├── nexys4_ddr
│   ├── nexys4_ddr_mic_pmod
│   └── zedboard
├── LICENSE
├── README.md                    # This file
├── rtl                          # RTL modules in SystemVerilog
│   ├── fifo.sv
│   ├── leds.sv
│   ├── i2s_capture.sv
│   ├── i2s_fpga.sv
│   ├── sample_reduce.sv
│   └── spi_slave.sv
├── software                     # Software layer for data extraction and conversion
│   ├── c                        # C code for embedded platforms
│   └── python                   # Python scripts for handling captured data
└── src                          # Generated files (bitstream, configs, simulations)
    ├── out.bit
    ├── out.config
    ├── out.json
    └── simulation
```

## ⚙️ Formatter Installation

This project uses [`verible-verilog-format`](https://github.com/chipsalliance/verible) to ensure code standardization. The `format_sv.sh` script can be used to apply formatting.

### 🔧 Ubuntu/Debian

```bash
sudo apt update
sudo apt install verible
```

### 🐧 Arch Linux

```bash
yay -S verible-bin
```

## 🔨 How to Synthesize and Load to Your FPGA

```bash
cd fpga
cd <desired_fpga>   # E.g., colorlight_i9, nexys4_ddr, zedboard
make all            # Performs synthesis
make load           # Loads the bitstream to the FPGA
```

### 🧰 Tools Used

- [x] **Yosys** - Synthesis of SystemVerilog modules
- [x] **nextpnr** - Place-and-route for supported FPGAs
- [x] **openFPGALoader** - Uploads the bitstream to the FPGA
- [x] **Icarus Verilog (iverilog)** - Simulation of modules
- [x] **Vivado** - Required for synthesis on boards like ZedBoard or Nexys4 DDR

## 🧠 Future Improvements (TODO)

- [ ] Add support for new I2S microphones
- [ ] Support for multiple channels (stereo)
- [ ] Improve SPI read interface, add a software reset for the FPGA

## 📜 License

This project is licensed under the terms of the MIT License. See the [LICENSE](./LICENSE) file for details.