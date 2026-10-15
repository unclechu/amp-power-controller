cmake_minimum_required(VERSION 3.13)

include("$ENV{PICO_SDK_PATH}/pico_sdk_init.cmake")

project(amp-power-controller C CXX ASM)
pico_sdk_init()

add_executable(amp-power-controller main.c)

target_link_libraries(amp-power-controller pico_stdlib)

pico_enable_stdio_usb(amp-power-controller 1) # Enable USB TTY interface
pico_enable_stdio_uart(amp-power-controller 0) # No need for UART

pico_add_extra_outputs(amp-power-controller)
