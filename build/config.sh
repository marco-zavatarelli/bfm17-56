#!/bin/bash -e
#
## Configuration for the BFM-NEMO coupling in the PELAGOS configuration. 
#
#  This script creates a directory $blddir with the Memory Layout files and the FCM include for the coupling. 
#  The COMPILE flag starts the compilation using the makenemo tool.
#  Requires the environmental variables BFMDIR and NEMODIR to be set and pointing to the
#  root directories of BFM and NEMO 
# 

#  Currently available macros (cppdefs) are:
#  INCLUDE_PELFE                          : use Iron component to the pelagic system
#  INCLUDE_PELCO2, INCLUDE_BENCO2         : activate Carbonate System 
#  INCLUDE_BEN, INCLUDE_BENPROFILES       : Add Benthic compartment
#  INCLUDE_SILT                           : use Silt component
#  INCLUDE_SEAICE                         : activate SeaIce Ecology 
#  INCLUDE_DIAG3D, INCLUDE_DIAG2D         : additional diagnostics available for output
#  BFM_PARALLEL                           : used to run BFM with MPP

#  Warnings
# 1. Still not working for benthic BFM don't use DIAG with D1SOURCE and ONESOURCE
# 2. Using the key DEBUG will add more output information

# Author: Esteban Gutierrez (CMCC) based on Tomas lobato (CMCC) scripts to config BFM
# -----------------------------------------------------

LOGFILE=logfile_$$.log
LOGDIR="Logs"
CONFDIR="build/Configurations"
MKMF="mkmf"
GMAKE="gmake"
PERL="perl"
GENCONF="generate_conf"
MKNEMO="makenemo"
BFMSTD="bfm_standalone.x"
NEMOEXE="nemo.exe"
OPTIONS=( MODE CPPDEFS BFMDIR NEMODIR ARCH PROC NETCDF EXP NMLDIR PROC QUEUE )

#----------------- USER CONFIGURATION DEFAULT VALUES -----------------
MODE="STANDALONE"
CPPDEFS="-DINCLUDE_PELCO2 -DINCLUDE_DIAG3D"
PRESET="STANDALONE"
ARCH="gfortran"
PROC=4
EXP="EXP00"
QUEUE="poe_short"
CLEAN="clean"
# --------------------------------------------------------------------


#print usage message 
usage(){
    more << EOF
NAME
    This script compile and/or execute the BFM model.

SYNOPSIS
    usage: $0 -h
    usage: $0 {-g -c -e} [options]

DESCRIPTION
    MUST specify at least one these OPTIONS:
       -h         Shows this help
       -g         Generate
       -c         Compile with makenemo (include generation)
       -e         Execute

    alternative COMPILATION OPTIONS are:
       -v
                  Verbose mode to print all messages (Deactivated by default)
       -p PRESET
                  Preset to generate the configuration. (Default: "STANDALONE")
                  - For other presets, list files *.conf in: BFMDIR/${CONFDIR}
       -m MODE
                  Mode for compilation and execution. Available models are: (Default: "STANDALONE")
                  - STANDALONE (without NEMO. Compile and run in local machine)
                  - NEMO (with NEMO. Compile and run ONLY in LSF platform)
       -k CPPDEFS
                  Key options to configure the model. (Default: "-DINCLUDE_PELCO2 -DINCLUDE_DIAG3D")                 
       -b BFMDIR
                  The environmental variable BFMDIR pointing to the root directory of BFM (Default: "${BFMDIR}")
       -n NEMODIR
                  The environmental variable NEMODIR pointing to the root directory of NEMO. (Default: "${NEMODIR}")
       -a ARCH
                  NEMO specific architecture file (Default: "gfortran")
                  - For STANDALONE preset available archs, list dir : BFMDIR/compilers
                  - For other presets available archs, execute command: NEMODIR/NEMOGCM/CONFIG/makenemo -h all
       -r PROC
                  Number of procs used for compilation. Default: 4
       -f
                  Fast mode. Dont execute "clean" command in compilation (Deactivated by default)
       -t NETCDF
                  Path to netcdf library and header files. (Default: /usr/local)
    alternative EXECUTION OPTIONS are:
       -x EXP
                  Name of the experiment for generation of the output (Default: "EXP00")
       -l NMLDIR
                  Input dir where are the namelists to run the experiment (Default: "BFMDIR/build/PRESET")
       -r PROC
                  Number of procs used for running. Default: 4
       -q QUEUE
                  Name of the queue number of procs used for running. Default
    NOTE: Options with parameters can be specified inside the PRESET file using the fortran F90 namelist format:
        &BFM_conf
          <key>=<value>,
          ...
          <key>=<value>
        /
        - Available keys: ${OPTIONS[*]}
        - Options in file override value of command line options
        - Don't use " to surround values, use ' instead
EOF
}



# ------------------------- PROGRAM STARTS HERE ----------------------------

#print in log file
if [ ! -d ${LOGDIR} ]; then mkdir ${LOGDIR}; fi
mkfifo ${LOGDIR}/${LOGFILE}.pipe
tee < ${LOGDIR}/${LOGFILE}.pipe ${LOGDIR}/${LOGFILE} &
exec &> ${LOGDIR}/${LOGFILE}.pipe
rm ${LOGDIR}/${LOGFILE}.pipe


#get user options from commandline
while getopts "hvgcep:m:k:b:n:a:r:ft:x:l:q:" opt; do
    case $opt in
      h )                   usage                        ; exit             ;;
      v )                   echo "verbose mode"          ; VERBOSE=1        ;;
      g ) [ ${VERBOSE} ] && echo "generation activated"  ; GEN=1            ;;
      c ) [ ${VERBOSE} ] && echo "compilation activated" ; CMP=1; GEN=1     ;;
      e ) [ ${VERBOSE} ] && echo "execution activated"   ; EXE=1            ;;
      p ) [ ${VERBOSE} ] && echo "preset $OPTARG"        ; PRESET=$OPTARG   ;;
      m ) [ ${VERBOSE} ] && echo "mode $OPTARG"          ; MODE=$OPTARG     ;;
      k ) [ ${VERBOSE} ] && echo "key options $OPTARG"   ; CPPDEFS=$OPTARG  ;;
      b ) [ ${VERBOSE} ] && echo "BFMDIR=$OPTARG"        ; BFMDIR=$OPTARG   ;;
      n ) [ ${VERBOSE} ] && echo "NEMODIR=$OPTARG"       ; NEMODIR=$OPTARG  ;;
      a ) [ ${VERBOSE} ] && echo "architecture $OPTARG"  ; ARCH=$OPTARG     ;;
      r ) [ ${VERBOSE} ] && echo "n. procs $OPTARG"      ; PROC=$OPTARG     ;;
      f ) [ ${VERBOSE} ] && echo "fast mode activated"   ; CLEAN=           ;;
      t ) [ ${VERBOSE} ] && echo "netcdf path $OPTARG"   ; NETCDF=$OPTARG   ;;
      x ) [ ${VERBOSE} ] && echo "experiment $OPTARG"    ; EXP=$OPTARG      ;;
      l ) [ ${VERBOSE} ] && echo "namelist dir $OPTARG"  ; NMLDIR=$OPTARG   ;;
      q ) [ ${VERBOSE} ] && echo "queue name $OPTARG"    ; QUEUE=$OPTARG    ;;
      * ) echo "option not recognized"                   ; exit             ;;
    esac
done

#check must parameters
if [[ ! ${EXE} && ! ${CMP} && ! ${GEN} ]]; then
    echo "ERROR: YOU MUST specify one of the \"must\" arguments"
    echo "Execute $0 -h for help if you don't what the hell is going wrong. PLEASE read CAREFULLY before bother someone else"
    exit
fi

#activate/deactivate verbose mode
if [ $VERBOSE ]; then
    set -xv
    cmd_mkmf="${MKMF} -v"
    cmd_gmake="${GMAKE}"
    cmd_gen="${GENCONF}.pl -v"
    cmd_mknemo="${MKNEMO}"
else
    cmd_mkmf="${MKMF}"
    cmd_gmake="${GMAKE} -s"
    cmd_gen="${GENCONF}.pl"
    cmd_mknemo="${MKNEMO} -v0"
fi

blddir="${BFMDIR}/build/${PRESET}"
myGlobalDef="${PRESET}.conf"

#get the configuration parameters from file and replace current ones
bfmconf=`perl -ne "/BFM_conf/ .. /\// and print" ${BFMDIR}/${CONFDIR}/${myGlobalDef}`
#echo ${bfmconf}
for option in "${OPTIONS[@]}"; do
    value=`perl -e "print ( \"${bfmconf}\" =~ m/\${option}\ *=\ *[\"\']*([^\"\'\,]+)[\"\']*[\,\/]*/ );"`
    if [ "${value}" ]; then 
        [ ${VERBOSE} ] && echo "replacing ${option}=${value}"
        eval ${option}=\"\${value}\"
    fi
done

#Check some optional parameter values
if [[ ! $BFMDIR || ! $NEMODIR ]]; then 
    echo "ERROR: BFMDIR and/or NEMODIR not specified"
    echo "Execute $0 -h for help if you don't what the hell is going wrong. PLEASE read CAREFULLY before bother someone else"
    exit
fi
if [[ "$MODE" != "STANDALONE" && "$MODE" != "NEMO" ]]; then 
    echo "ERROR: MODE value not valid ($MODE). Available values are: STANDALONE or NEMO."
    echo "Execute $0 -h for help if you don't what the hell is going wrong. PLEASE read CAREFULLY before bother someone else"
    exit
fi
if [[ ${PROC} ]] && ! [[ "$PROC" =~ ^[0-9]+$ ]] ; then 
    echo "ERROR: PROC must be a number"
    echo "Execute $0 -h for help if you don't what the hell is going wrong. PLEASE read CAREFULLY before bother someone else"
    exit
fi

#start generation of files
if [ ${GEN} ]; then

    if [ ! -f ${BFMDIR}/${CONFDIR}/${myGlobalDef} ]; then
         echo "ERROR: ${BFMDIR}/${CONFDIR}/${myGlobalDef} not exsits"
         echo "Execute $0 -h for help if you don't what the hell is going wrong. PLEASE read CAREFULLY before bother someone else"
         exit
    fi

    if [ ! -d ${blddir} ]; then mkdir ${blddir}; fi
    cd ${blddir}
    rm -rf *
    
    # generate BFM Memory Layout files and namelists
    ${PERL} -I${BFMDIR}/build/scripts/conf/ ${BFMDIR}/build/scripts/conf/${cmd_gen} \
        ${CPPDEFS} \
        -r ${BFMDIR}/${CONFDIR}/${myGlobalDef}  \
        -f ${BFMDIR}/src/BFM/proto \
        -t ${blddir} || exit

    if [[ ${MODE} == "STANDALONE" ]]; then
        cppdefs="-DBFM_STANDALONE ${CPPDEFS}"
        # list files
        find ${BFMDIR}/src/BFM/General -name "*.?90" -print > BFM.lst
        find ${BFMDIR}/src/standalone -name "*.?90" -print >> BFM.lst
        find ${BFMDIR}/src/share -name "*.?90" -print >> BFM.lst
        find ${BFMDIR}/src/BFM/Pel -name "*.?90" -print >> BFM.lst
        find ${BFMDIR}/src/BFM/PelBen -name "*.?90" -print >> BFM.lst
        find ${BFMDIR}/src/BFM/Ben -name "*.?90" -print >> BFM.lst
        find ${BFMDIR}/src/BFM/Light -name "*.?90" -print >> BFM.lst
        find ${BFMDIR}/src/BFM/Oxygen -name "*.?90" -print >> BFM.lst
        find ${BFMDIR}/src/BFM/Forcing -name "*.?90" -print >> BFM.lst
        find ${BFMDIR}/src/BFM/CO2 -name "*.?90" -print >> BFM.lst

        #change netcdf path in file if Mac
        if [ ${NETCDF} ]; then
            [ ${VERBOSE} ] && echo "changing netcd path!"
            sed -e "s,/usr/local,${NETCDF}," ${BFMDIR}/compilers/${ARCH}.inc > ${blddir}/${ARCH}.inc
        else
            cp ${BFMDIR}/compilers/${ARCH}.inc ${blddir}/${ARCH}.inc
        fi

        # Make makefile
        ${BFMDIR}/bin/${cmd_mkmf} \
            -c "${cppdefs}" \
            -o "-I${BFMDIR}/include -I${BFMDIR}/src/BFM/include" \
            -t "${blddir}/${ARCH}.inc" \
            -p "${BFMDIR}/bin/bfm_standalone.x" \
            BFM.lst && echo ""

        # Link to the configuration file
        ln -sf ${BFMDIR}/${CONFDIR}/${myGlobalDef} GlobalDefsBFM.model
        [ ${VERBOSE} ] && echo "${PRESET} compilation done!"

        # If COMPILE, launch gmake
        if [ ${CMP} ]; then
            if [ ${CLEAN} ]; then
                [ ${VERBOSE} ] && echo "Cleaning up ${PRESET}..."
                #${cmd_gmake} clean
            fi
            [ ${VERBOSE} ] && echo "Starting ${PRESET} compilation..."
            ${cmd_gmake}
            [ ${VERBOSE} ] && echo "${PRESET} compilation done!"
        fi
    else
        cppdefs="-DBFM_PARALLEL ${CPPDEFS}"
        # Generate the specific bfm.fcm include file for makenemo
        cppdefs=`echo ${cppdefs} | sed -e "s/"-D"//g"` 
        # some macros are default with NEMO
        FCMMacros="BFM_NEMO USEPACK BFM_NOPOINTERS ${cppdefs}"
        sed -e "s/_place_keys_/${FCMMacros}/" -e "s/_place_def_/${myGlobalDef}/" \
            ${BFMDIR}/${CONFDIR}/Default_bfm.fcm > ${blddir}/bfm.fcm
        [ ${VERBOSE} ] && echo "Memory Layout generated in local folder: ${blddir}."

        # Move BFM Layout files to target folders 
        cp ${blddir}/*.F90 ${BFMDIR}/src/BFM/General
        mv ${BFMDIR}/src/BFM/General/init_var_bfm.F90 ${BFMDIR}/src/share
        cp ${blddir}/init_var_bfm.F90 ${BFMDIR}/src/share
        cp ${blddir}/INCLUDE.h ${BFMDIR}/src/BFM/include
        cp ${blddir}/bfm.fcm ${BFMDIR}/src/nemo
        [ ${VERBOSE} ] && echo "Files copied to target folders."

        # If COMPILE, launch makenemo
        if [ ${CMP} ]; then
            cd ${NEMODIR}/NEMOGCM/CONFIG/

            if [ ${CLEAN} ]; then
                [ ${VERBOSE} ] && echo "Cleaning up ${PRESET}..."
                ./${cmd_mknemo} -n ${PRESET} -m ${ARCH} clean
            fi
            [ ${VERBOSE} ] && echo "Starting NEMO compilation..."
            ./${cmd_mknemo} -n ${PRESET} -m ${ARCH} -e ${BFMDIR}/src/nemo -j ${PROC}
            [ ${VERBOSE} ] && echo "${PRESET} compilation done!"
        fi
    fi
fi

#start execution of BFM
if [ ${EXE} ]; then
    [ ${VERBOSE} ] && echo "Executing ${PRESET}"

    if [ ! -d ${blddir} ]; then
        echo "ERROR: directory ${blddir} not exists"
        echo "Execute $0 -h for help if you don't what the hell is going wrong. PLEASE read CAREFULLY before bother someone else"
    fi
 
    exedir="${BFMDIR}/run/${EXP}"
    if [ ! -d ${exedir} ]; then 
        mkdir ${exedir}; 
    fi
    cd ${exedir}
    rm -rf *

    # copy and link necessary files
    if [ ${NMLDIR} ]; then cp ${NMLDIR}/* .; else cp ${blddir}/*.nml .; fi

    if [[ ${MODE} == "STANDALONE" ]]; then
        ln -sf ${BFMDIR}/bin/${BFMSTD} ${BFMSTD}
        ./${BFMSTD}
    else
        # copy and link necessary files
        cp ${BFMDIR}/build/scripts/conf/nemo/* ./
        ln -sf ${NEMODIR}/NEMOGCM/CONFIG/${PRESET}/BLD/bin/${NEMOEXE} ${NEMOEXE}
        #change values in runscript
        sed -e "s,_EXP_,${EXP},g"       \
            -e "s,_EXE_,${NEMOEXE},g" \
            -e "s,_VERBOSE_,${VERBOSE},g" \
            -e "s,_PRESET_,${PRESET},g" \
            -e "s,_QUEUE_,${QUEUE},g"   \
            -e "s,_PROC_,${PROC},g"     ${BFMDIR}/build/scripts/conf/runscript > ./runscript_${EXP}
        bsub < ./runscript_${EXP}
        [ ${VERBOSE} ] && echo "Execution logs will be generated in ${exedir}"
    fi

    [ ${VERBOSE} ] && echo "Output generated in ${exedir}"
fi
