#!/bin/sh
case "$1"
in
off)
    echo 6 > /dev/ttyS1
    echo 7 > /dev/ttyS1
    ;;
on)
    echo 4 > /dev/ttyS1
    echo 8 > /dev/ttyS1
    ;;
esac
