{ common-sh
, coreutils
, docker
, nix-project-lib
}:

{ tutorial
, command
, projectRoot
}:

let
    prog_name = "run_${tutorial}_${command}_docker-run";
    desc = "run \"example-nix-run ${command} -t ${tutorial}\" within Docker";
in

nix-project-lib.writeShellChecked prog_name desc
''
set -eu
set -o pipefail


. "${nix-project-lib.lib-sh}/bin/lib.sh"
. "${common-sh}/bin/common.sh"


BUILD_IMAGE="nixpkgs/nix:nixos-20.03"
VOLUME_ROOT="example-nix-home"
VOLUME_NIX="example-nix-cache"
REPO_ROOT="${projectRoot}"
NIX_EXE="$(command -v nix || true)"


print_usage()
{
    ${coreutils}/bin/cat - <<EOF
USAGE: ${prog_name} [OPTION] COMMAND

DESCRIPTION:

    ${desc}

OPTIONS:

    -h --help           print this help message
    -N --nix PATH       filepath of 'nix' executable to use

EOF
}

main()
{
    parse_args "$@"

    intro '${desc}'
    add_nix_to_path "$NIX_EXE"

    log "This script reruns itself in a Docker container, executing the" \
	"requested \"${command}\" command for the \"${tutorial}\" tutorial." \
	"The \"$BUILD_IMAGE\" Docker image we'll use has Nix already on it," \
	"so you don't need Nix installed on your host machine (though you do" \
        "need Docker installed)."

    log "Nix caches builds in /nix/store, but Docker containers discard" \
	"changes within images unless you use Docker volumes. We'll first" \
        "set up two volumes, one for /root, and another for /nix."

    create_volume_if_missing "$VOLUME_ROOT" /root
    create_volume_if_missing "$VOLUME_NIX" /nix
    run_in_docker example-nix-run ${command} --tutorial ${tutorial}
}

create_volume_if_missing()
(
    volume="$1"
    source="$2"
    if ! volume_exists "$volume"
    then
        create_volume "$volume" "$source"
    else
	log "It looks like the \"$volume\" volume for $source is already" \
            "created, so we'll reuse that."
    fi
)

run_in_docker()
{
    log "We can finally use Docker to rerun this script within a container." \
	"We'll mount a copy of the example-nix project to /mnt and make the" \
        "same example-nix-run call, but without the --docker flag:"
    log_and_run_unindented ${docker}/bin/docker run \
        --rm \
        --interactive \
        --tty \
        --env PATH=/bin:/usr/bin:/mnt/run \
        --volume "$REPO_ROOT:/mnt" \
        --volume "$VOLUME_ROOT:/root" \
        --volume "$VOLUME_NIX:/nix" \
        --volume "/var/run/docker.sock:/var/run/docker.sock" \
        --workdir /mnt \
        "$BUILD_IMAGE" \
        "$@"
}

volume_exists()
{
    local volume="$1"
    ${docker}/bin/docker inspect "$volume" 1>/dev/null 2>/dev/null
}

create_volume()
{
    local volume="$1"
    local source="$2"
    log "Here's the commands to create a volume called \"$volume\" and" \
	"prepopulate it with the $source directory of the \"$BUILD_IMAGE\"" \
        "image:"
    log_and_run ${docker}/bin/docker volume create "$volume"
    log_and_run_silently ${docker}/bin/docker run \
        --rm -v "$volume:/mnt" "$BUILD_IMAGE" \
        cp -a -T "$source" /mnt
}

parse_args()
{
    while ! [ "''${1:-}" = "" ]
    do
        case "$1" in
        -h|--help)
            print_usage
            exit 0
            ;;
        -N|--nix)
            NIX_EXE="''${2:-}"
            if [ -z "$NIX_EXE" ]
            then die "'$1' requires argument"
            fi
            shift
            ;;
        *)
            die "'$1' not recognized"
            ;;
        esac
        shift
    done
}


main "$@"
''
