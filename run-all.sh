#!/bin/bash

./run-01.sh
if [ $? -ne 0 ]; then
    echo "run-01.sh failed. Exiting."
    exit 1
fi

./run-02.sh
if [ $? -ne 0 ]; then
    echo "run-02.sh failed. Exiting."
    exit 1
fi
echo "Both scripts executed successfully."
