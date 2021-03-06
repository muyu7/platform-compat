#!/usr/bin/env bash

source_directory=$BUILD_SOURCESDIRECTORY
core_root_directory=
architecture=x64
framework=netcoreapp3.0
compilation_mode=tiered
repository=$BUILD_REPOSITORY_NAME
branch=$BUILD_SOURCEBRANCH
commit_sha=$BUILD_SOURCEVERSION
build_number=$BUILD_BUILDNUMBER
internal=false
kind="micro"
run_categories="coreclr corefx"
csproj="src\benchmarks\micro\MicroBenchmarks.csproj"
configurations=
run_from_perf_repo=false
use_core_run=true

while (($# > 0)); do
  lowerI="$(echo $1 | awk '{print tolower($0)}')"
  case $lowerI in
    --sourcedirectory)
      source_directory=$2
      shift 2
      ;;
    --corerootdirectory)
      core_root_directory=$2
      shift 2
      ;;
    --architecture)
      architecture=$2
      shift 2
      ;;
    --framework)
      framework=$2
      shift 2
      ;;
    --compilationmode)
      compilation_mode=$2
      shift 2
      ;;
    --repository)
      repository=$2
      shift 2
      ;;
    --branch)
      branch=$2
      shift 2
      ;;
    --commitsha)
      commit_sha=$2
      shift 2
      ;;
    --buildnumber)
      build_number=$2
      shift 2
      ;;
    --kind)
      kind=$2
      shift 2
      ;;
    --runcategories)
      run_categories=$2
      shift 2
      ;;
    --csproj)
      csproj=$2
      shift 2
      ;;
    --internal)
      internal=true
      shift 1
      ;;
    --configurations)
      configurations=$2
      shift 2
      ;;
    --help)
      echo "Common settings:"
      echo "  --corerootdirectory <value>    Directory where Core_Root exists, if running perf testing with --corerun"
      echo "  --architecture <value>         Architecture of the testing being run"
      echo "  --configurations <value>       List of key=value pairs that will be passed to perf testing infrastructure."
      echo "                                 ex: --configurations \"CompilationMode=Tiered OptimzationLevel=PGO\""
      echo "  --help                         Print help and exit"
      echo ""
      echo "Advanced settings:"
      echo "  --framework <value>            The framework to run, if not running in master"
      echo "  --compliationmode <value>      The compilation mode if not passing --configurations"
      echo "  --sourcedirectory <value>      The directory of the sources. Defaults to env:BUILD_SOURCESDIRECTORY"
      echo "  --repository <value>           The name of the repository in the <owner>/<repository name> format. Defaults to env:BUILD_REPOSITORY_NAME"
      echo "  --branch <value>               The name of the branch. Defaults to env:BUILD_SOURCEBRANCH"
      echo "  --commitsha <value>            The commit sha1 to run against. Defaults to env:BUILD_SOURCEVERSION"
      echo "  --buildnumber <value>          The build number currently running. Defaults to env:BUILD_BUILDNUMBER"
      echo "  --csproj                       The relative path to the benchmark csproj whose tests should be run. Defaults to src\benchmarks\micro\MicroBenchmarks.csproj"
      echo "  --kind <value>                 Related to csproj. The kind of benchmarks that should be run. Defaults to micro"
      echo "  --runcategories <value>        Related to csproj. Categories of benchmarks to run. Defaults to \"coreclr corefx\""
      echo "  --internal                     If the benchmarks are running as an official job."
      echo ""
      exit 0
      ;;
  esac
done

if [[ "$repository" == "dotnet/performance" ]]; then
    run_from_perf_repo=true
fi

if [ -z "$configurations" ]; then
    configurations="CompliationMode=$compilation_mode"
fi

if [ -z "$core_root_directory" ]; then
    use_core_run=false
fi

payload_directory=$source_directory/Payload
performance_directory=$payload_directory/performance
workitem_directory=$source_directory/workitem
extra_benchmark_dotnet_arguments="--iterationCount 1 --warmupCount 0 --invocationCount 1 --unrollFactor 1 --strategy ColdStart --stopOnFirstError true"
perflab_arguments=
queue=Ubuntu.1804.Amd64.Open
creator=$BUILD_DEFINITIONNAME
helix_source_prefix="pr"

if [[ "$internal" == true ]]; then
    perflab_arguments="--upload-to-perflab-container"
    helix_source_prefix="official"
    creator=
    extra_benchmark_dotnet_arguments=
    
    if [[ "$architecture" = "arm64" ]]; then
        queue=Ubuntu.1804.Arm64.Perf
    else
        queue=Ubuntu.1804.Amd64.Perf
    fi
fi

common_setup_arguments="--frameworks $framework --queue $queue --build-number $build_number --build-configs $configurations"
setup_arguments="--repository https://github.com/$repository --branch $branch --get-perf-hash --commit-sha $commit_sha $common_setup_arguments"

if [[ "$run_from_perf_repo" = true ]]; then
    payload_directory=
    workitem_directory=$source_directory
    performance_directory=$workitem_directory
    setup_arguments="--perf-hash $commit_sha $common_setup_arguments"
else
    git clone --branch master --depth 1 --quiet https://github.com/dotnet/performance $performance_directory
    
    docs_directory=$performance_directory/docs
    mv $docs_directory $workitem_directory
fi

if [[ "$use_core_run" = true ]]; then
    new_core_root=$payload_directory/Core_Root
    mv $core_root_directory $new_core_root
fi

# Make sure all of our variables are available for future steps
echo "##vso[task.setvariable variable=UseCoreRun]$use_core_run"
echo "##vso[task.setvariable variable=Architecture]$architecture"
echo "##vso[task.setvariable variable=PayloadDirectory]$payload_directory"
echo "##vso[task.setvariable variable=PerformanceDirectory]$performance_directory"
echo "##vso[task.setvariable variable=WorkItemDirectory]$workitem_directory"
echo "##vso[task.setvariable variable=Queue]$queue"
echo "##vso[task.setvariable variable=SetupArguments]$setup_arguments"
echo "##vso[task.setvariable variable=Python]python3"
echo "##vso[task.setvariable variable=PerfLabArguments]$perflab_arguments"
echo "##vso[task.setvariable variable=ExtraBenchmarkDotNetArguments]$extra_benchmark_dotnet_arguments"
echo "##vso[task.setvariable variable=BDNCategories]$run_categories"
echo "##vso[task.setvariable variable=TargetCsproj]$csproj"
echo "##vso[task.setvariable variable=RunFromPerfRepo]$run_from_perf_repo"
echo "##vso[task.setvariable variable=Creator]$creator"
echo "##vso[task.setvariable variable=HelixSourcePrefix]$helix_source_prefix"
echo "##vso[task.setvariable variable=Kind]$kind"
echo "##vso[task.setvariable variable=_BuildConfig]$architecture.$kind.$framework"