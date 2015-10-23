#!/bin/bash
vim <(cat "$@" | iconv -f cp437 | sed 's//•/g')
