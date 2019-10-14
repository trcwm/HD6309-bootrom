#!/bin/sh

../../lwtools-4.17/lwasm/lwasm boot.asm --format=hex --output=boot.hex --map=boot.map --list=boot.list
../../lwtools-4.17/lwasm/lwasm boot2.asm --format=raw --output=boot2.bin --map=boot2.map --list=boot2.list
