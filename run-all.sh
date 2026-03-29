#!/bin/bash

echo "============================================="
echo "TRAX import pipeline started at $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================="
echo

./run-01.sh
if [ $? -ne 0 ]; then
    echo "run-01.sh failed. Exiting."
    echo "Failed at $(date '+%Y-%m-%d %H:%M:%S')"
    exit 1
fi

./run-02.sh
if [ $? -ne 0 ]; then
    echo "run-02.sh failed. Exiting."
    echo "Failed at $(date '+%Y-%m-%d %H:%M:%S')"
    exit 1
fi

echo
echo "============================================="
echo "TRAX import pipeline finished at $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================="
echo "Both scripts executed successfully."
