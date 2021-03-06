#!/bin/bash

# Copyright (C) 2011-2012 R. Diez - see the orbuild project for licensing information.

set -o errexit

source "$ORBUILD_SANDBOX/Scripts/ShellModules/StandardShellHeader.sh"
source "$ORBUILD_SANDBOX/Scripts/ShellModules/MakeJVal.sh"

if [ $# -ne 3 ]; then
  abort "Invalid number of command-line arguments, see the source code for details."
fi

VERILOG_INCLUDE_DIR="$1"
shift
VERILATOR_EXE_DIR="$1"
shift
VERILATOR_EXE_FILENAME="$1"
shift

OR10_BASE_DIR="$ORBUILD_PROJECT_DIR/OR10"
TEST_BENCH_DIR="$OR10_BASE_DIR/TestBench"

TOP_LEVEL_MODULE="test_bench"

verify_var_is_set ()
{
    # $1 = variable name

    [ "${!1-first}" == "${!1-second}" ] || abort "Variable \"$1\" is not set, aborting."
}

ENABLE_DPI_MODULES=0

verify_var_is_set "JTAG_DPI_CHECKOUT_DIR"
verify_var_is_set "UART_DPI_CHECKOUT_DIR"

# Generate the DPI wrapper files.

JTAG_DPI_WRAPPER_FILENAME="$VERILATOR_EXE_DIR/jtag_dpi_wrapper.cpp"
UART_DPI_WRAPPER_FILENAME="$VERILATOR_EXE_DIR/uart_dpi_wrapper.cpp"

{
  printf "// This file was automatically generated by script: $0\n"
  printf "#include \"V$TOP_LEVEL_MODULE.h\"\n"
  printf "#include \"$JTAG_DPI_CHECKOUT_DIR/jtag_dpi.cpp\""
} >"$JTAG_DPI_WRAPPER_FILENAME"

{
  printf "// This file was automatically generated by script: $0\n"
  printf "#include \"V$TOP_LEVEL_MODULE.h\"\n"
  printf "#include \"$UART_DPI_CHECKOUT_DIR/uart_dpi.cpp\""
} >"$UART_DPI_WRAPPER_FILENAME"


pushd "$VERILATOR_EXE_DIR" >/dev/null

VERILATOR_OUTPUT_DIR="verilator_output"

declare -a INCLUDE_PATHS=(
    -I$OR10_BASE_DIR/TestBench
    -I$OR10_BASE_DIR/WishboneSwitch
    -I$OR10_BASE_DIR/Memory
    -I$OR10_BASE_DIR/CPU
    -I$OR10_BASE_DIR/Misc
    -I$OR10_BASE_DIR/JTAG
    -I$OR10_BASE_DIR/UART
    -I$JTAG_DPI_CHECKOUT_DIR
    -I$UART_DPI_CHECKOUT_DIR
  )

CMD="verilator"
CMD+=" ${INCLUDE_PATHS[@]}"
CMD+=" --Mdir \"$VERILATOR_EXE_DIR\""
CMD+=" -sv --cc --exe"
CMD+=" --autoflush"  # Reduces performance, but allows you to see more accurately where the simulation hangs.
CMD+=" -Wall -Wno-fatal --error-limit 10000"
CMD+=" -O3 --assert"
if [ $ENABLE_DPI_MODULES -ne 0 ]; then
  CMD+=" +define+ENABLE_DPI_MODULES+$ENABLE_DPI_MODULES"
fi
CMD+=" \"$TOP_LEVEL_MODULE.v\""
CMD+=" \"$TEST_BENCH_DIR/test_bench_verilator_driver.cpp\""
CMD+=" \"$JTAG_DPI_WRAPPER_FILENAME\""
CMD+=" \"$UART_DPI_WRAPPER_FILENAME\""
CMD+=" -o \"$VERILATOR_EXE_FILENAME\""

printf "$CMD\n\n"
eval "$CMD"

get_make_j_val MAKE_J_VAL

# Debug flags: export OPT="-O0 -g -Wall -Wwrite-strings -DDEBUG"
export OPT="-O3 -g -Wall -Wwrite-strings -DNDEBUG"
if [ $ENABLE_DPI_MODULES -eq 0 ]; then
  # I haven't way any other way to prevent the C++ compilation warnings that come up in this case.
  OPT+=" -Wno-unused-but-set-variable"
fi

CMD="make -f \"V$TOP_LEVEL_MODULE.mk\" -j \"$MAKE_J_VAL\""
printf "$CMD\n\n"
eval "$CMD"

popd >/dev/null
