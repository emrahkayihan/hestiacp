#!/bin/sh

# Identifies OS type and variant
# Setups variables and provides OS-agnostic wrapper functions

OS_TYPE=$(grep "^ID=" /etc/os-release | cut -f 2 -d '=' | sed -e 's/^"//' -e 's/"$//')
case "$OS_TYPE" in
debian|Debian)
    OS_BASE='debian'
    OS_VERSION=$(cat /etc/debian_version|grep -o "[0-9]\{1,2\}"|head -n1)
    ;;
ubuntu|Ubuntu)
    OS_BASE='debian'
    OS_VERSION="$(lsb_release -s -r)"
    ;;
centos|CentOS|rhel|RHEL|fedora|Fedora|RedHat)
    OS_BASE='rhel'
    OS_VERSION=$(cat /etc/os-release | grep VERSION_ID | sed -e "s/VERSION_ID=//" | sed -e 's/^"//' -e 's/"$//')
    ;;
*)
    OS_BASE='unknown'
    ;;
esac

OSAL_PATH="$(cd "$(dirname "$BASH_SOURCE")" >/dev/null 2>&1 ; pwd -P)"

for OSAL_FILE in "osal_${OS_BASE}_based" \
                 "osal_${OS_TYPE}" \
                 "osal_${OS_TYPE}_${OS_VERSION}"
do
    # Search for OS specific OSAL file and source it
    if [ -f "$OSAL_PATH/${OSAL_FILE}.sh" ]; then
        source "$OSAL_PATH/${OSAL_FILE}.sh"
    fi
done

# VAR=$(ini_get 'file' 'section' 'param' 'value')
osal_ini_get() {
    #echo /usr/bin/crudini --get $@
    retval=$(/usr/bin/crudini --get $@ 2>1)
    if [ $? -eq 0 ]; then
        echo $retval
    fi
}

# ini_set 'file' 'section' 'param' 'newvalue'
osal_ini_set() {
    if [ "$OSAL_DEBUG" ]; then
        echo /usr/bin/crudini --set $@
    fi
    /usr/bin/crudini --set $@
}

# For use in osal_kv_*
sed_escape() {
    sed -e 's/[]\/$*.^[]/\\&/g'
}

# osal_kv_write path key value
osal_kv_write() { 
    osal_kv_delete "$1" "$2"
    echo "$2=$3" >> "$1"
}

# value=$(osal_kv_read path key defaultvalue)
osal_kv_read() {
    kv_keyname=$(echo "$2" | sed_escape)
    if [ -f "$1" ]; then
        retval=$(grep "^$kv_keyname\s*=" "$1" | sed "s/^$kv_keyname\s*=\s*//" | tail -1)
        if [ "$retval" ]; then
            echo $retval
        else
            echo $3
        fi
    else
        echo $3
    fi
}

osal_kv_delete() { # path, key
    kv_keyname=$(echo "$2" | sed_escape)
    test -f "$1" && sed -i "/^${kv_keyname}\s*=.*$/d" "$1"
}

osal_kv_haskey() { # path, key
    kv_keyname=$(echo "$2" | sed_escape)
    test -f "$1" && grep "^${kv_keyname}\s*=" "$1" > /dev/null
    if [ $? -eq 0 ]; then
        echo 1
    fi
}

osal_kv_read_bool() {
    retval=$(osal_kv_read $@)
    if [ "${retval,,}" == "yes" ] \
        || [ "${retval,,}" == "true" ] \
        || [ "${retval,,}" == "on" ] \
        || [ "$retval" == "1" ]; then
        echo 1
    fi
}

osal_bool_yes() {
    if [ "${1,,}" == "yes" ] \
        || [ "${1,,}" == "true" ] \
        || [ "${1,,}" == "on" ] \
        || [ "$1" == "1" ]; then
        echo 'yes'
    else
        echo 'no'
    fi
}

osal_execute_with_spinner() {
    if [ "$OSAL_DEBUG" ]; then
        echo "$@"
        $@
    else
        $@ > /dev/null 2>&1 &
        BACK_PID=$!

        spinner="/-\|"
        spin_i=1
        while kill -0 $BACK_PID > /dev/null 2>&1 ; do
            printf "\b${spinner:spin_i++%${#spinner}:1}"
            sleep 0.5
        done

        # Do a blank echo to get the \n back
        echo
    fi
}
