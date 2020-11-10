#!/bin/bash

BUILD_DIR="artifacts/contracts/**/*.json"

for fn in $(ls $BUILD_DIR | grep -v "\.dbg\." ) 
do 
	[[ $fn = Test* ]] && continue
	[[ $fn = I* ]] && continue
	[[ $fn = Lib* ]] && continue
	bytecode=$(cat ${fn} | jq .deployedBytecode | awk -F "\"" '{print $2}') 
	[[ $bytecode = 0x ]] && continue
	let size=${#bytecode}/2
	name="$(basename $fn)"
	printf "%-40s%s\n" "${name}~" "~${size}" | tr ' ~' '- '
done
