_testrad_ looks for preconfigured profiles in `~/.config/nullroute.eu.org/testrad.conf.sh`. The configuration uses Bash script syntax, so a profile looks roughly like this:

    user[example]='test@example.com'
    pass[example]='rainbowdash'
    eap[example]='ttls'
    host[example]='192.0.42.1'
    secret[example]='testing123'
