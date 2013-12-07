
umask 022

PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/syno/sbin:/usr/syno/bin:/usr/local/sbin:/usr/local/bin:/opt/sbin:/opt/bin
export PATH

#This fixes the backspace when telnetting in.
#if [ "$TERM" != "linux" ]; then
#        stty erase
#fi

HOME=/root
export HOME

TERM=${TERM:-cons25}
export TERM

PAGER=more
export PAGER

export PS1='\u@\h:\W\$ '

alias dir="ls -al"
alias ll="ls -la"
