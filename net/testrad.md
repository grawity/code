_testrad_ looks for preconfigured profiles in `~/.config/nullroute.eu.org/testrad.conf.sh`. The configuration uses Bash script syntax, so a profile looks roughly like this:

    server_example=(
        host 192.0.42.1
        secret testing123
    )

    profile_example=(
        via example
        user test@example.com
        pass rainbowdash
        eap ttls
    )
