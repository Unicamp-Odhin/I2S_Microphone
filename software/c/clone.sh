#!/bin/bash

if ! command -v sshpass &> /dev/null; then
    echo "Erro: run sudo pacman -S sshpass"
    exit 1
fi

sshpass -p "starfive" scp user@192.168.15.117:/home/user/development/read_mic/dump.hex .

g++ hex2wav.cpp -o hex2wav
if [ $? -ne 0 ]; then
    echo "Erro na compilação do hex2wav.cpp"
    exit 1
fi

./hex2wav

if [ "$1" == "--play" ]; then
    aplay dump.wav
fi
