# Ident (RFC 1413) service for Windows NT

## Features

 * IPv6
 * Multi-user support

## Installation

    win32-identd.py --startup auto install
    win32-identd.py start

The service will automatically listen on `0.0.0.0` and `::` port 113.

Requests are logged to Event Log.

## Bugs

 * I should probably rewrite it using `asyncore`.
