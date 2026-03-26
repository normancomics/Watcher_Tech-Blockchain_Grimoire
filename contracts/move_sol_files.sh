#!/bin/bash

# Move all .sol files from the root and any non-contracts directories into the `contracts` folder.

# Define the source and destination directories
src_dirs=("./*.sol" "./other-directory/*.sol")  # Add any other non-contract directories here

# Loop through the source directories and move .sol files
for dir in "${src_dirs[@]}"; do
    mv $dir contracts/ 2>/dev/null
done
