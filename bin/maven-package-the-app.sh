#!/bin/bash

############################################################
# This script creates a zip file for distributing
# your java+javafx+maven application to the three main OS:
#   linux, mac and the unnamed (hint: M$)
# It requires maven.
############################################################

WHEREAMI="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

TARGETDIR="${WHEREAMI}/../target"
declare -a KNOWNTARGETOS=('linux' 'mac' 'win')

######################### nothing to change below #########################

# the launchers subdir in the output archive, it will contain all scripts
launchersbasedir="launchers"
dbbasedir="db"
function usage {
	echo "Usage : $0 <options>"
	echo "Options are:"
	echo " -o OUTZIP : specify the output distribution zip-ball. Default is a file with the project-jar name and the zip extension in target dir '${TARGETDIR}'."
	echo " -F : do not repackage the application but use possibly stale files. This is not recommended when producing your final distribution"
	echo " -l : do not test the app before creating the distribution archive. Default is to run all the tests and fail if tests fail. If you want to run only some tests, give that as an extra option to maven, see the -L option below."
	echo " -L : extra options to maven command, for example in order to exclude certain tests use -L '-DexcludedGroups=livetest'. You can use this option multiple times for declaring more than one options."
	echo " -t targetOS : specify one or more (using this option multiple times) target OS. Known target OS are: ${KNOWNTARGETOS[@]}"
	echo " -D : debugging mode, it will not erase tmp files for inspection."
	echo " -T tempdir : specify a tempdir (which will be deleted unless -D is specified). There is a default."
	echo " -E dir1 [-E dir2 ... ] : one or more directories to be included into the output distribution archive. Use this option as many times as there are extra directories (i.e. multiple -E options, each with one dir)."
	echo; echo "this script will produce a zip archive for distributing a maven+java+javafx application to foreign OS(es). If successful, an output distribution zip archive will be created which will contain the app's classes as well as all the dependency jar files, including javafx module files and any other directories specified by the user. At the target machine, unzip the produced archive, change to the app directory and run the launcher script. The output distribution archive may contain files to be run on more than one target OS. The launchers for each specified OS will be located under dir '${launchersbasedir}'. For linux and mac, the launchers can be run from any location and will find the classes and lib dir relative to the launchers' location. Unless you specify the environment variable MYAPPBASEDIR to point to the directory containing 'classes' and 'lib'. In shitty windows you can only set the environment variable to where the classes are. Or chdir to the app dir and run the launchers from in there (and pray)."
	echo; echo "Example:"
	echo "  $0 -t linux -t mac -L '-DexcludedGroups=livetest' -T xxx -D"
}

FORCE=1 # always recompile!
DOTEST="1" # do all tests before packaging
DEBUG="0" # debug will leave back temp files
OUTZIP="" # optional output filename or a default will be used
TMPBASE="/tmp/$$"
declare -A TARGETOS=()
declare -A EXTRADIRS=()
declare -a EXTRAMAVENOPTIONS=()
while getopts "Fc:lL:t:T:o:E:Dh" anopt; do
    case "${anopt}" in
	E)
		# dirs to be included in the out zip
		# use it as many times as dirs, one dir at a time
		EXTRADIRS+=("${OPTARG}")
		;;
	T)
		TMPBASE="${OPTARG}"
		;;
	L)
		EXTRAMAVENOPTIONS+=("${OPTARG}")
		;;
	o)
		OUTZIP="${OPTARG}"
		;;
	D)
		DEBUG="1"
		;;
	t)
		# the CLASSIFIER string must match win/linux/mac
		# and it is in the jar filename from maven repository
		# e.g. lib/javafx-media-22-ea+11-linux.jar
		if (
			shopt -s nocasematch;
			[[ "${OPTARG}" =~ (win)|(ms)|(m\$)|(micro) ]]
		); then
			TARGETOS[win]=1
		elif (
			shopt -s nocasematch;
			[[ "${OPTARG}" =~ (linux)|(unix) ]]
		); then
			TARGETOS[linux]=1
		elif (
			shopt -s nocasematch;
			[[ "${OPTARG}" =~ (mac)|(osx)|(apple) ]]
		); then
			TARGETOS[mac]=1
		else
			echo "$0 : target OS '${OPTARG}' is not known. Known OS are: ${KNOWNTARGETOS[@]}"
			exit 1
		fi
		;;
	F)
		FORCE="0"
		;;
	l)
		DOTEST="1"
		;;
	h)
		usage
		exit 0
		;;
	?)
		echo "$0 : invalid option -${OPTARG}"
		exit 1
		;;
    esac
done

############################
### nothing to change below

if [ ${#TARGETOS[@]} -eq 0 ]; then echo "$0 : error, at least one target OS is required (use the -t option). Known target OS: ${KNOWNTARGETOS[@]}"; exit 1; fi

SF="${WHEREAMI}/maven-get-classpath-and-friends.sh"
source "${SF}"
if [ $? -ne 0 ]; then echo "$0 : error, sourcing '${SF}' has failed."; exit 1; fi

# after the above source we get arrays back: CLASSPATH, MODULEPATH, MODULES
# and these strings: CLASSPATHSTR (':'-separated), MODULEPATHSTR (':'-separated), MODULESSTR (','-separated), MAINCLASSSTR, PROJECTNAMESTR, PROJECTJARSTR
# returns 1 on failure or 0 on success (check $?)

OUTJAR="${TARGETDIR}/${PROJECTJARSTR}"
if [ -z ${OUTZIP+x} ] || [ "${OUTZIP}" == "" ]; then OUTZIP=${OUTJAR/%\.jar/.zip}; fi

echo "$0 : target OS : ${!TARGETOS[@]}"
echo "$0 : project name : '${PROJECTNAMESTR}'"
echo "$0 : output distribution archive: '${OUTZIP}'"

if [ "${FORCE}" == "1" ]; then
	echo "$0 : forcing re-building of '${OUTJAR}' to be up-to-date with sources."
	rm -f "${OUTJAR}"
fi

if [ ! -f "${OUTJAR}" ]; then
	# this will create the app jar in $OUTJAR
	read -r -d '' CMD <<EOC
mvn clean compile install spring-boot:repackage
EOC
	if [ "${DOTEST}" != "1" ]; then CMD+=" -Dmaven.test.skip=true"; fi
	for ao in "${EXTRAMAVENOPTIONS[@]}"; do CMD+=" ${ao}"; done
	echo "$0: executing command : ${CMD}";eval ${CMD}; if [ $? -ne 0 ]; then echo "$0 : command has failed: ${CMD}"; exit 1; fi
else
	echo "$0: reusing old package, I hope this is not for production : '${OUTJAR}'"
fi

# now extract the libs from the output jar
tmpd="${TMPBASE}.d/${PROJECTNAMESTR}"
rm -rf "${tmpd}"
mkdir -p "${tmpd}"; if [ ! -d "${tmpd}" ]; then echo "$0 : error, failed to create temporary output dir '${tmpd}'."; exit 1; fi
launchersdir="${tmpd}/${launchersbasedir}"
mkdir -p "${launchersdir}"
libdir="${tmpd}/lib"
# check first if the outjar contains the structure we expect
read -r -d '' CMD <<EOC
unzip -t "${OUTJAR}" 'BOOT-INF/lib/*' &> /dev/null
EOC
eval ${CMD}; if [ $? -ne 0 ]; then echo "$0 : failed to find the structure I expected in file '${OUTJAR}' which was created by spring-boot maven plugin. A 'BOOT-INF/lib' dir with jar files was expected but not found."; exit 1; fi
# and unzip those jar files into our temp distribution dir:
read -r -d '' CMD <<EOC
unzip "${OUTJAR}" 'BOOT-INF/lib/*' -d "${tmpd}" 
EOC
echo "$0: executing command : ${CMD}";eval ${CMD}; if [ $? -ne 0 ]; then echo "$0 : command has failed: ${CMD}"; exit 1; fi

mv "${tmpd}/BOOT-INF/lib" "${libdir}"

# copy the app's classes in the output tmp dir
read -r -d '' CMD <<EOC
cp -r "${WHEREAMI}/../target/classes" "${tmpd}/"
EOC
echo "$0: executing command : ${CMD}";eval ${CMD}; if [ $? -ne 0 ]; then echo "$0 : command has failed: ${CMD}"; exit 1; fi

# if we have extra dirs to be included then copy them
mkdir "${tmpd}/extra" # even if it may be empty
for ad in "${EXTRADIRS[@]}"; do
	read -r -d '' CMD <<EOC
cp -r "${ad}" "${tmpd}/extra/"
EOC
	echo "$0: executing command : ${CMD}";eval ${CMD}; if [ $? -ne 0 ]; then echo "$0 : command has failed: ${CMD}"; exit 1; fi
done

# erase any OS-specific jars which are not needed from the distribution
for clastr in "${KNOWNTARGETOS[@]}"; do
	if [ "${TARGETOS[${clastr}]}" != "1" ]; then
		# it is not requested, erase its specific jars
		find "${tmpd}/lib" -type f -name '*-'"${clastr}"'.jar' -exec rm -f \{\} \;
	fi
done

# create the launch scripts
pushd . &> /dev/null
cd "${libdir}/.."
for clastr in "${!TARGETOS[@]}"; do
	if [ "${TARGETOS[${clastr}]}" != "1" ]; then continue; fi

	cA=;cB=;lf=;pf=
	if [ "${clastr}" == "win" ]; then
		lf="${launchersbasedir}/win.bat"
		# these jars will be excluded from the classpath/modulepath
		cA='-mac.jar'; cB='-linux.jar'
		pf='%XX123%'
		# NOTE: XX123 must be an empty string if MYAPPBASEDIR is not specified
		# but shitty windows messes this up. Just pray the below will do:
		# see https://stackoverflow.com/a/29165555
		cat > "${lf}" <<'EOX'
@echo off
IF Defined MYAPPBASEDIR (
  set "XX123=%MYAPPBASEDIR%"
  IF NOT %XX123:~-1% == \ (
    set "XX123=%XX123%\"
  )
) else (set "XX123=%~dp0\..\")
EOX
	elif [ "${clastr}" == "mac" ]; then
		lf="${launchersbasedir}/mac.sh"
		# these jars will be excluded from the classpath/modulepath
		cA='-win.jar'; cB='-linux.jar'
		pf='${XX123}'
		cat > "${lf}" <<'EOX'
#!/bin/sh
XX123=
if [ ! -z ${MYAPPBASEDIR+x} ] && [ "${MYAPPBASEDIR}" != "" ]; then
  XX123="${MYAPPBASEDIR}"
  if [ "${XX123:(-1)}" != "/" ]; then XX123="${XX123}/"; fi
else
  XX123=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/../"
fi
EOX
	elif [ "${clastr}" == "linux" ]; then
		lf="${launchersbasedir}/linux.sh"
		# these jars will be excluded from the classpath/modulepath
		cA='-mac.jar'; cB='-win.jar'
		pf='${XX123}'
		cat > "${lf}" <<'EOX'
#!/bin/sh
XX123=
if [ ! -z ${MYAPPBASEDIR+x} ] && [ "${MYAPPBASEDIR}" != "" ]; then
  XX123="${MYAPPBASEDIR}"
  if [ "${XX123:(-1)}" != "/" ]; then XX123="${XX123}/"; fi
else
  XX123=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/../"
fi
EOX
	else
		echo "$0 : do not know how to handle target OS '${clastr}'. This should not be happening."
		exit 1
	fi
	declare -a nCLASSPATH=("${pf}classes")
	declare -a nMODULEPATH=()

	while IFS= read -r -d '' afile; do
		# check if it is a module, it must contain this file at top level
		unzip -t "${afile}" 'module-info.class' &> /dev/null
		if [ $? -eq 0 ]; then
			# it is a module
			nMODULEPATH+=("${pf}${afile}")
		else
			nCLASSPATH+=("${pf}${afile}")
		fi
	done < <(find lib -type f -name '*.jar' ! -name '*'$cA ! -name '*'$cB -print0)

	if [ "${clastr}" == "win" ]; then
		# WINDOWS wants ';' as classpath separator!!!
		nCLASSPATHSTR=$(IFS=';'; echo "${nCLASSPATH[*]}") 
		nMODULEPATHSTR=$(IFS=';'; echo "${nMODULEPATH[*]}")
		# and also the shitty \
		nCLASSPATHSTR=${nCLASSPATHSTR//\//\\}
		nMODULEPATHSTR=${nMODULEPATHSTR//\//\\}
	else
		nCLASSPATHSTR=$(IFS=':'; echo "${nCLASSPATH[*]}") 
		nMODULEPATHSTR=$(IFS=':'; echo "${nMODULEPATH[*]}")
	fi
	# write it out
	# paths with spaces within double quotes in shitty windows seem to be fine (pray!)
	if [ "${clastr}" == "win" ]; then
		cat >> "${lf}" <<EOL
java -classpath "${nCLASSPATHSTR}" --module-path "${nMODULEPATHSTR}" --add-modules "${MODULESSTR}" "${MAINCLASSSTR}" %*
EOL
	else
		cat >> "${lf}" <<EOL
java -classpath "${nCLASSPATHSTR}" --module-path "${nMODULEPATHSTR}" --add-modules "${MODULESSTR}" "${MAINCLASSSTR}" \$*
EOL
	fi

	# and convert bat launcher to shitty windows, a unix2dos basically
	if [ "${clastr}" == "win" ]; then
		perl -i -pe 's/([^\015]|^)\012/$1\015\012/g' "${lf}"
	fi
done
popd &> /dev/null

if [ "${OUTZIP}" != "" ]; then
	pushd . &> /dev/null
	cd "${tmpd}/.."
	# and zip it
	read -r -d '' CMD <<EOC
zip -r "${OUTZIP}" "${PROJECTNAMESTR}"
EOC
	echo "$0: executing command : ${CMD}";eval ${CMD}; if [ $? -ne 0 ]; then echo "$0 : command has failed: ${CMD}"; exit 1; fi
	popd &> /dev/null
	echo "$0 : done, created archive for distribution at '${OUTZIP}'"
fi

if [ "${DEBUG}" == "1" ] || [ "${OUTZIP}" == "" ]; then
	# do not erase the output dir unless specified an output zip file
	# or not in debug mode
	echo "$0 : temporary files at: $tmpd"
	if [  "${OUTZIP}" == "" ]; then echo "$0 : done, created dir (not archive) for distribution at '${tmpd}'"; fi
else
	rm -rf "${tmpd}"
fi
