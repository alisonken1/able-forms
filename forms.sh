#!/bin/bash
#
# Copyright 2013 AbleTronics
# Author Ken Roberts
#
export dirBase="/drawer/forms"
export dirTemp="${dirBase}/tmp"
export prnSkip="adobepdf7 checks eltron invoice laserjet1 laserjet2 receipt_s shipping"
export prnStatus="lpstat"
export prnCommand="/usr/bin/lpr -P"
export prnList="${prnStatus} -a"
export menuDisplay="${dirTemp}/dialog-show.$$"
export menuAnswer="${dirTemp}/dialog-ans.$$"
export PRINTER=""
export PRINTER_LOC=""
export FORM=""
cd ${dirBase}
declare -a FORM_NAME=( $(ls *.ps) )
export FORM_NAME
rm ${dirTemp}/dialog* 2>/dev/null

[ -z ${DISPLAY} ] && {
  [ -x /usr/bin/dialog ] && export DIALOG="/usr/bin/dialog"
} || {
  [ -z "${DIALOG}" -a -x /usr/bin/kdialog ] && export DIALOG="/usr/bin/kdialog"
  [ -Z "${DIALOG}" -a -x /usr/bin/Xdialog ] && export DIALOG="/usr/bin/Xdialog"
}

# Dialog responses
dialog_OK=0
dialog_CANCEL=1
dialog_ESC=255


debug_me () {
  return
  echo "$*" >&2
}

cleanup () {
  rm ${menuAnswer} ${menuDisplay} 2>/dev/null
}

get_answer () {
  ans=${1}
  case ${ans} in
    0)
      # OK - printer selected
      cat ${menuAnswer}
      ;;
    *)
      # cancel or something else
      echo "Cancelled" >&2
      ;;
    esac
  return ${ans}
}

get_printer_location () {
  # Get the location of the printer"
  declare -a ss=( $(${prnStatus} -l -p ${1} | grep -i location | tr -s '[:blank:]\t' ' ' ) )
  debug_me "${ss[*]}"
  unset ss[0]
  echo "${ss[*]}"
}

get_printer () {
  # Retrieve printers and build a list of active printers
  # First, setup the menu
  echo -n "${DIALOG} --clear --title \"Printer selection\" " >${menuDisplay}
  echo -n " --menu \"Select printer below\"" >>${menuDisplay}
  [ -z "$(echo ${DIALOG} |grep [kx]dialog)" ] && echo -n " 20 78 12 " >>${menuDisplay}
  # Retrieve the printers and clean out invalid printers
  SKIP=1
  ${prnList} | while read pName pStatus zz ; do
    if [ "${pStatus}" != "accepting" ] ; then
      debug_me "Printer ${pName} not accepting jobs - skipping"
    elif [ -n "$(echo ${prnSkip} | grep -i ${pName})" ] ; then
      debug_me "Skipping printer ${pName}"
    else
      # direct ethernet printers
      case ${pName} in
      "HP_LaserJet_3055_192.168.1.11")
        pLoc="Cherie's Office Laser Printer"
        ;;
      "HP_LaserJet_P3005_192.168.1.10")
        pLoc="Upstairs Laser Printer"
        ;;
      "EPSON_Stylus_CX4800")
        pLoc="Rich's Inkjet"
        ;;
      "Brother_HL-2140_series_shipping")
        pLoc="Shipping Laser Printer"
        ;;
      "Brother_HL-2140_series_pos2")
        pLoc="Center Counter Laser Printer"
        ;;
      *)
        pLoc="$( get_printer_location ${pName} )"
        ;;
      esac
      echo -n " ${pName} \"${pLoc}\"" >>${menuDisplay}
    fi
  done
  echo -n " 2>${menuAnswer}" >>${menuDisplay}
}

get_form () {
  echo -n "${DIALOG} --title \"Select Form\" " >${menuDisplay}
  echo -n "--menu \"Please select the form you want to print \" " >>${menuDisplay}
  [ -z "$(echo ${DIALOG} |grep [kx]dialog)" ] && echo -n " 20 78 12 " >>${menuDisplay}
  c=0
  for i in ${FORM_NAME[*]} ; do
    zz="$(echo -n "${i}" | sed -e 's/\.[^\.]*$//' | tr '_' ' ')"
    echo -n "${c} " >>${menuDisplay}
    echo -n "\" ${zz}\" " | sed 's/[^ ]\+/\L\u&/g' >>${menuDisplay}
    c=$(( $c + 1 ))
  done
  echo -n " 2>${menuAnswer}" >>${menuDisplay}
}

${DIALOG} --no-shadow --infobox "Please wait while I get the active printers" 4 30


get_printer
source ${menuDisplay}
PRINTER="$(get_answer $?)"
[ $? -ne ${dialog_OK} ] && {
  cleanup ; exit
}
PRINTER_LOC="$(get_printer_location ${PRINTER})"

while /bin/true; do
  get_form
  source ${menuDisplay}
  FORM="$(get_answer $?)"
  [ $? -ne ${dialog_OK} ] && {
    cleanup
    break
  }

  ${prnCommand} ${PRINTER} ${FORM_NAME[$FORM]}
done
cleanup
