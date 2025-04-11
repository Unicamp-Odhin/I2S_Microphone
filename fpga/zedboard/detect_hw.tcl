open_hw_manager
connect_hw_server
puts "Dispositivos JTAG detectados:"
foreach hw_target [get_hw_targets] {
    puts " - $hw_target"
    current_hw_target $hw_target
    open_hw_target
    foreach hw_device [get_hw_devices] {
        puts "   * FPGA: $hw_device"
    }
    close_hw_target
}
close_hw_manager
exit
