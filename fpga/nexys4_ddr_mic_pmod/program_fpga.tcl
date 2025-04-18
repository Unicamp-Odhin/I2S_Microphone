# Abre o gerenciador de hardware
open_hw_manager

# Conecta ao servidor local
connect_hw_server

current_hw_target [get_hw_targets "localhost:3121/xilinx_tcf/Digilent/210248722948"]
open_hw_target

set_property PROGRAM.FILE {build/out.bit} [get_hw_devices xc7z020_0]
program_hw_devices [get_hw_devices xc7z020_0]

# Fecha as conexões
close_hw_target
close_hw_manager
exit
