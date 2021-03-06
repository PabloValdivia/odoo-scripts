#!/bin/bash
if [ -z "$HOME" ]; then
    echo "ERROR: Instalation error, HOME is not defined"
    exit 1
fi

show_error() {
    local error=$1
    local output=$2

    echo "ERROR: $error";
    if [ -n "$output" ] && [ -f $output ]; then
        echo "----------------------------------------------------------------"
        cat $output
        echo "----------------------------------------------------------------"
        rm -rf $output
    fi
}

repo_reset() {
    local name=$1
    local error=0
    local head=

    local temp=/tmp/odoo_repos_reset.$$.tmp
    if [ -z "$FORCE_BRANCH" ]; then
        git -C $(pwd)/$name symbolic-ref HEAD > $temp 2>&1
        error=$?; if [ $error -ne 0 ]; then printf "[?] %-28s - " "$name"; show_error "No HEAD ref"; return $error; fi
        head=$(cat $temp)
    else
        head="refs/heads/$FORCE_BRANCH"
    fi
    local branch=$(expr $head : 'refs/heads/\(.*\)')
    local remote=$(git -C $(pwd)/$name config branch.$branch.remote)
    local remote_branch=$(expr $(git -C $(pwd)/$name config branch.$branch.merge) : 'refs/heads/\(.*\)')
    local status=''
    git -C $(pwd)/$name status --porcelain > $temp 2>&1
    if [ -n "$(cat $temp)" ]; then status='DIRTY'; fi

    if [ "$status" == 'DIRTY' ]; then
        echo "[?] $name is dirty:"
        echo "----------------------------------------------------------------"
        cat $temp
        echo "----------------------------------------------------------------"
    elif [ -z "$remote" ] || [ -z "$remote_branch" ]; then
        echo "[?] $name has no tracking branch: remote = '$remote', remote_branch = '$remote_branch'"
    else
        printf "[ ] %-28s - Checkout to %s:%s ... " "$name" "$remote" "$remote_branch"
        git -C $(pwd)/$name checkout $remote_branch > $temp 2>&1
        error=$?; if [ $error -ne 0 ]; then show_error $error $temp; return $error; fi
        echo "OK"
    fi
    rm -rf $temp
}

odoo_reset() {
    cd $HOME
    if [ -d $HOME/OCB/.git ]; then
        repo_reset OCB
    elif [ -d $HOME/odoo/.git ]; then
        repo_reset odoo
    elif [ -d $HOME/openerp/.git ]; then
        repo_reset openerp
    fi
}

if [ "$1" == "-f" ]; then
    shift
    FORCE_BRANCH="$1"
    shift
fi

repo="$1"

if [ -z "$repo" ]; then
    # All repos in home, except Odoo
    for repo in $(find -maxdepth 2 -type d -name ".git" -printf '%h\n' | grep -v '^./odoo$' | grep -v '^./OCB$' | grep -v '^./openerp$' | sort); do
        name=${repo#./}
        repo_reset $name
    done
    # All repos in home/repos
    if [ -d $HOME/repos ]; then
        cd $HOME/repos
        for repo in $(find -maxdepth 2 -type d -name ".git" -printf '%h\n' | sort); do
            name=${repo#./}
            repo_reset $name
        done
    fi
    # Odoo repo
    odoo_reset
else
    if [ "$repo" == 'odoo' ]; then
        odoo_reset
    elif [ -d $HOME/repos/$repo/.git ]; then
        cd $HOME/repos
        repo_reset $repo
    elif [ -d $HOME/$repo/.git ]; then
        cd $HOME
        repo_reset $repo
    elif [ -d $repo/.git ]; then
        cd $(dirname $repo)
        repo_reset $(basename $repo)
    else
        echo "ERROR: Repo '$repo' not found"
    fi
fi
