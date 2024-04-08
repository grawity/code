# Ident (RFC 1413) service for Windows NT

## Features

 * IPv6
 * Multi-user support

## Requirements

 * [PyWin32](http://starship.python.net/crew/mhammond/win32/Downloads.html)
 * Windows XP or later

## Installation

    win32-identd.py --startup auto install
    win32-identd.py start

The service will automatically listen on `0.0.0.0` and `::` port 113.

Requests are logged to Event Log.

## Bugs

 * I should probably rewrite it using `asyncore`.
