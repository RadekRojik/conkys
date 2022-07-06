#! /usr/bin/env bash

socat TCP-LISTEN:7634,reuseaddr,fork EXEC:./hdd.sh
