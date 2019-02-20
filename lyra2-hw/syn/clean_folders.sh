#!/bin/bash

CUR_DIR=$(pwd)
mkdir -p ./bitstreams
echo "INFO :: Removing Vivado artifacts and keeping bitstreams only."
for DST in "." "vc707" "zcu102" "zcu104" 
do 
    echo "INFO :: Entering $(pwd)/$DST ..."
    cd ./$DST
    if [ $DST != "." ]
    then 
        find . -path $CUR_DIR/bitstreams -prune -o -name "*.bit" -type f -exec cp -vf {} $CUR_DIR/bitstreams \;
    fi
    rm -vfr .Xil/
    rm -vfr .cache/
    rm -vfr run_[012]*
    rm -vf vivado*.jou
    rm -vf vivado*.log
    rm -vf fsm_encoding.os
    if [ $DST != "." ]
    then 
        cd ..
    fi
done
echo "INFO :: Done."
