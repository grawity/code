exec {f}>/dev/tcp/$addr/80;echo -e "GET / HTTP/1.0\r\nHost: $addr\r\n\r\n">&$f;sed '1,/^\r$/d'<&$f;exec {f}>&-

(echo -e "GET $path HTTP/1.0\r\nHost: $addr\r\n\r\n">&0;sed '1,/^\r$/d')</dev/tcp/$addr/80
