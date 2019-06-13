#!/bin/sh

rm *.xlog
rm *.snap

tarantool -i init.lua