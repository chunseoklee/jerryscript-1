#!/bin/bash

trap "exit" INT

function pr_err() {
	echo -e "\e[91mError: $@\e[39m"
}

function exit_err() {
	pr_err $@
	exit
}

USAGE="Usage:\n    sudo bash run.sh OLD_ENGINE NEW_ENGINE REPEATS"

if [ "$(whoami)" != "root" ]
then
	pr_err "start script with sudo..."
	echo -e $USAGE
	exit
fi

if [ "$#" -ne 3 ]
then
	pr_err "Argument number mismatch..."
	echo -e $USAGE
	exit
fi

ENGINE_OLD="$1"
ENGINE_NEW="$2"
REPEATS=$3

if [ $REPEATS -lt 1 ]
then
	exit_err "REPEATS must be greater than 0"
fi

if [ ! -x $ENGINE_OLD ]
then
	exit_err "\"$ENGINE_OLD\" is not an executable file..."
fi

if [ ! -x $ENGINE_NEW ]
then
	exit_err "\"$ENGINE_NEW\" is not an executable file..."
fi

#check if all required programs are exist
REQUIRED_PROGS="awk bash bc cpufreq-set printf renice taskset time timeout "
MISSING_PROGS=""

for program in $REQUIRED_PROGS
do
	if [ -z $(command -v $program) ]
	then
		MISSING_PROGS="$MISSING_PROGS $program"
	fi
done

if [ -n "$MISSING_PROGS" ]
then
	pr_err "install missing programs and try again:"
	for program in $MISSING_PROGS
	do
		echo "   $program"
	done
	exit
fi

SINGLE_TEST_TIMEOUT="5"
TIMEOUT=$(echo "$3" "${SINGLE_TEST_TIMEOUT}" | awk '{print $1 * $2;}')
CPU=3

RAND_VA_SPACE="/proc/sys/kernel/randomize_va_space"
echo 0 > $RAND_VA_SPACE || exit_err "setting $RAND_VA_SPACE"

renice -n -20 $$ || exit_err "renice unsuccedeed"
cpufreq-set -g performance || exit_err "couldn't set performance governor"
#cpufreq-set -c ${CPU} -f 1GHz
taskset -p -c ${CPU} $$ || exit_err "couldn't set affinity"

perf_n=0
mem_n=0

perf_rel_mult=1.0
mem_rel_mult=1.0

function run-compare()
{
  COMMAND=$1
  PRE=$2
  TEST=$3

  OLD=$(timeout "${TIMEOUT}" ${COMMAND} "${ENGINE_OLD}" "${TEST}") || return 1
  printf "%6s->" "$OLD"

  NEW=$(timeout "${TIMEOUT}" ${COMMAND} "${ENGINE_NEW}" "${TEST}") || return 1

  #check result
  ! $OLD || ! $NEW || return 1

  #calc relative speedup
  rel=$(echo "${OLD}" "${NEW}" | awk '{print $2 / $1; }')

  #increment n
  ((${PRE}_n++))

  #accumulate relative speedup
  eval "rel_mult=\$${PRE}_rel_mult"
  rel_mult=$(echo "$rel_mult" "$rel" | awk '{print $1 * $2;}')
  eval "${PRE}_rel_mult=\$rel_mult"

  #calc percent to display
  percent=$(echo "$rel" | awk '{print (1.0 - $1) * 100; }')
  printf "%6s(%5.3f)\t\t" "$NEW" "$percent"
}

function run-test()
{
  TEST=$1

  printf "%50s\t\t" "${TEST}"

  timeout ${SINGLE_TEST_TIMEOUT} "${ENGINE_OLD}" "${TEST}" > /dev/null 2>&1 || return 1
  timeout ${SINGLE_TEST_TIMEOUT} "${ENGINE_NEW}" "${TEST}" > /dev/null 2>&1 || return 1

  run-compare "bash ./tools/rss-measure.sh"      "mem"   "${TEST}" || return 1
  run-compare "bash ./tools/perf.sh ${REPEATS}"  "perf"  "${TEST}" || return 1

  printf "\n"
}

function run-suite()
{
  FOLDER=$1

  for BENCHMARK in ${FOLDER}/*.js
  do
    run-test "${BENCHMARK}" 2> /dev/null || printf "<FAILED>\n" "${BENCHMARK}";
  done
}

printf "%50s\t\t%18s\t\t%18s\n" "Benchmark" "Rss" "Perf"

#run-suite ./tests/benchmarks/sunspider-0.9.1
run-suite ./tests/benchmarks/sunspider-1.0.2
run-suite ./tests/benchmarks/ubench

mem_rel_gmean=$(echo "$mem_rel_mult" "$mem_n" | awk '{print $1 ^ (1.0 / $2);}')
mem_percent_gmean=$(echo "$mem_rel_gmean" | awk '{print (1.0 - $1) * 100;}')

perf_rel_gmean=$(echo "$perf_rel_mult" "$perf_n" | awk '{print $1 ^ (1.0 / $2);}')
perf_percent_gmean=$(echo "$perf_rel_gmean" | awk '{print (1.0 - $1) * 100;}')

printf " -------------------------------------- \n"
printf "%50s\t\t%18s\t\t%18s\n" "Results:" "(RSS reduction: $mem_percent_gmean%)" "(Speed up: $perf_percent_gmean%)"
