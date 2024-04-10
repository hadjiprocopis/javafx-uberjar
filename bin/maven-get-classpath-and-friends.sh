 #!/bin/sh

#############################################################
#
# >>> s o u r c e   this script in order to get arrays back:
# e.g. source script.sh; echo $MODULESSTR
#
#  CLASSPATH, MODULEPATH, MODULES
# and these strings:
#  CLASSPATHSTR (which is ':'-separated) !!! windows wants ';' !!!
#  MODULEPATHSTR (which is ':'-separated) !!! windows wants ';' !!!
#  MODULESSTR (which is ','-separated)
#  MAINCLASSSTR (just a fully qualified class name e.g. org.aba.main)
#  PROJECTNAMESTR (the project name as a string)
#  PROJECTJARSTR (the project jar when creating one with maven, just filename not path)
# It returns 1 on failure or 0 on success (see $?)
#############################################################

#############################################################
# WARNING: it runs mvn and stores output into CLASSPATHFILE
# if that file exists then it uses it and does not re-run mvn
# If 1st argument is 'force' then it will erase file and
# re-run for freshness
#############################################################

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	echo "script ${BASH_SOURCE[0]} must be source'ed !"
	exit 1
fi

tmpbase=/tmp/$$
CLASSPATHFILE="classpaths.out"

if [[ "$1" != "" ]] && [[ "$1" == "force" ]]; then
	echo "$0 : force re-calculate classpath ..."
	rm -f "${CLASSPATHFILE}"
fi

# WARNING: shitty mvn does not like breaking the lines with \
# run a dry-run
if [ ! -f "${CLASSPATHFILE}" ]; then
	read -r -d '' CMD <<'EOC'
mvn -X javafx:run@dry-run-cli
EOC
	echo "$0: executing command : ${CMD}";eval ${CMD} &> "${CLASSPATHFILE}"; if [ $? -ne 0 ]; then echo "$0 : command has failed: ${CMD}"; return 1; fi
else
	echo "$0 : file with classpath data found and re-using it, delete it to force re-calculate it : '${CLASSPATHFILE}'"
fi

tmpf2="${tmpbase}.pl"
cat << 'EOP' > "${tmpf2}"
use strict;
use warnings;
my $FH;
open($FH, "<", "$ENV{XXX}") or die "failed to open";
my $sv = 0;
my (@classpath, @modulepath, @modules, $mainclass, $projectname, $projectjar);
while( my $line = <$FH> ){
	last unless defined $line;
	chomp($line);
	# they have 1 space after [DEBUG]
	if( $line =~ /^\[DEBUG\] Classpath:\s*\d+$/ ){ $sv = 1; next; }
	elsif( $line =~ /^\[DEBUG\] +Modulepath:\s*\d+$/s ){ $sv = 2; next; }
	elsif( $line =~ /^\[DEBUG\] Project:\s*.+?\:(.+?)\:(.+?)\s*$/ ){
		$projectname = $1;
		$projectjar = $projectname.'-'.$2.'.jar';
		next;
	} elsif( $line =~ /^\[DEBUG\] Executing command line: \[.+?\bjava\b.+?\-\-dry\-run.+?\-\-add\-modules(.+?, ).+?,\s+([^ ]+)\]$/ ){
		$mainclass=$2;
		my $xx = $1; $xx =~ s/^\s*(,\s*)?//; $xx =~ s/,?\s*$//;
		my %modules = map { $_ => 1 } split(/\s*,\s*/, $xx);
		@modules = keys %modules;
		next;
	}
	# leave this last:
	elsif( $line =~ /^\[DEBUG\] [^ ]/ ){ $sv = 0; next; }
	# they have 2 spaces after [DEBUG]
	if( $sv == 1 ){
		if( $line =~ /^\[DEBUG\]  (.+)$/ ){ push @classpath, $1 }
	} elsif( $sv == 2 ){
		if( $line =~ /^\[DEBUG\]  (.+)$/ ){ push @modulepath, $1 }
	}
}
close $FH;
print join('|', @classpath)."\n";
print join('|', @modulepath)."\n";
print join('|', @modules)."\n";
print "${mainclass}\n";
print "${projectname}\n";
print "${projectjar}\n";
EOP

tmpf3="${tmpbase}.2.out"
read -r -d '' CMD <<EOC
XXX="${CLASSPATHFILE}" perl "${tmpf2}" > "${tmpf3}"
EOC
echo "$0: executing command : ${CMD}";eval ${CMD}; if [ $? -ne 0 ]; then echo "$0 : command has failed: ${CMD}"; return 1; fi

# process the classpath
readarray -td'|' CLASSPATH < <(printf '%s' "$(sed -n 1p ${tmpf3} | tr -d '\n')")
echo "$0 : read "${#CLASSPATH[@]}" classpath elements";

# process the modulepath
readarray -td'|' MODULEPATH < <(printf '%s' "$(sed -n 2p ${tmpf3} | tr -d '\n')")
echo "$0 : read "${#MODULEPATH[@]}" modulepath elements";

# process the modules
readarray -td'|' MODULES < <(printf '%s' "$(sed -n 3p ${tmpf3} | tr -d '\n')")
echo "$0 : read "${#MODULES[@]}" modules elements";

# process the main class (string)
MAINCLASSSTR=$(printf '%s' "$(sed -n 4p ${tmpf3} | tr -d '\n')")
if [ "${MAINCLASSSTR}" == "" ]; then echo "$0 : error, failed to find main class string."; return 1; fi

# process the projectname (string)
PROJECTNAMESTR=$(printf '%s' "$(sed -n 5p ${tmpf3} | tr -d '\n')")
if [ "${PROJECTNAMESTR}" == "" ]; then echo "$0 : error, failed to find the project name string."; return 1; fi

# process the projectjar (string)
PROJECTJARSTR=$(printf '%s' "$(sed -n 6p ${tmpf3} | tr -d '\n')")
if [ "${PROJECTJARSTR}" == "" ]; then echo "$0 : error, failed to find the project jar string."; return 1; fi

CLASSPATHSTR=$(IFS=':'; echo "${CLASSPATH[*]}") 
MODULEPATHSTR=$(IFS=':'; echo "${MODULEPATH[*]}") 
MODULESSTR=$(IFS=','; echo "${MODULES[*]}") 

rm -f "${tmpf2}" "${tmpf3}"

return 0; # success
