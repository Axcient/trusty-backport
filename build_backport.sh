#!/bin/sh
set -e
set -x

package=$1
shift

for debian_dir in "${package}/debian" "${package}/debian.master"; do
    changelog_file="${debian_dir}/changelog"
    test -f $changelog_file || continue
    echo "Modifying $changelog_file"
    debchange \
        --changelog "$changelog_file" \
        --local "~${VERSION}" \
        --distribution "${DISTRIBUTION}" \
        --force-distribution \
        "Backport for Trusty."

    # Validate version change somewhat
    head -n1 $changelog_file \
        | grep "~${VERSION}" \
        | grep "${DISTRIBUTION}"

done

cd $package && debuild $@ -i -uc -us
cd .. && rm -rf $package
