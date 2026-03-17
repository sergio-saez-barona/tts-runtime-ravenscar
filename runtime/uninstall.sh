#! /bin/bash

GNARL_USER=arm-eabi/lib/gnat/embedded-stm32f4/gnarl_user

INSTALLDIR=$(dirname $(dirname $(which arm-eabi-gcc)))

if [ ! -d $INSTALLDIR ] ; then
    echo "Invalid GNAT directory '$INSTALLDIR'"
    echo "Maybe GNAT environment is not properly established"
    exit 1
else
    echo "GNAT directory: $INSTALLDIR";
fi

SRCDIR=${INSTALLDIR}/$GNARL_USER

FILES=$(cat files.txt)

for i in $FILES
do
    b=$(basename $i)

    if [ ! -f $b ] ; then
	continue
    fi
    
    f=${SRCDIR}/$i
    
    rm -vf ${f}
done

