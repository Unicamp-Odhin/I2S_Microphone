#!/bin/bash

find . -type f -name "*.sv" | while read -r file; do
  verible-verilog-format \
    --indentation_spaces=4 \
    --column_limit=120 \
    --inplace \
    --assignment_statement_alignment=align \
    --case_items_alignment=align \
    --module_net_variable_alignment=align \
    --named_port_alignment=align \
    --port_declarations_alignment=align \
    --struct_union_members_alignment=align \
    "$file"
done

