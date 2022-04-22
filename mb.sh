as -g -o mindbend.o main.s &> /dev/null
if [[ $? -eq 0 ]]
then
    if ld -o mindbend mindbend.o
    then
        if rm mindbend.o
        then
            if ./mindbend $@
            then
                x=1
                #rm mindbend
            fi
        fi
    fi
else
as -g -o mindbend.o main.s
fi
