#!/usr/bin/env bash

SOURCE_DIR=${1:-$PWD}
if [[ $SOURCE_DIR =~ ^[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}$ ]]; then
	SOURCE_DIR="$HOME/Library/Application Support/AddressBook/Sources/${BASH_REMATCH[0]}"
fi
[[ -e $SOURCE_DIR ]] || { echo >&2 "$SOURCE_DIR not found"; exit 1; }
[[ ! -d $SOURCE_DIR ]] && SOURCE_DIR=$(dirname "$SOURCE_DIR")
SOURCE_DIR=$(realpath "$SOURCE_DIR")
ADBK_GUID=${SOURCE_DIR##*/}
SOURCE_ADBK_DB="${SOURCE_DIR}/AddressBook-v22.abcddb"

if [[ ! -f $SOURCE_ADBK_DB ]]; then
	cat <<-EOF >&2
	Run this script from a GUID dir within one of your AddressBook Sources directories,
	or, supply a complete path (or just the GUID) of a dir containing an AddressBook-v22.abcddb file as an arg

	possible choices:
	$(find "$HOME/Library/Application Support/AddressBook/Sources" -mindepth 1 -maxdepth 1 -type d | awk -F/ '{printf "    %s\n", $NF}')

	EOF
	exit
fi

cd "$SOURCE_DIR" || exit 1
[[ -d Metadata ]] || mkdir Metadata
cd Metadata || exit 1

sqlite3 ../AddressBook-v22.abcddb "SELECT ZUNIQUEID from ZABCDRECORD where ZCONTAINER1 IS NOT NULL and ZEXTERNALFILENAME IS NOT NULL order by ZUNIQUEID ASC;" |
sed 's/:ABPerson$/:ABPerson.abcdp/' > "/private/tmp/${ADBK_GUID}-db.txt"

dc=0; cc=0
find -s . -type f -name "*.abcdp" -maxdepth 1 | cut -c3- > "/private/tmp/${ADBK_GUID}-files.txt"
while read -r f; do
	echo "removing orphan: $f"
	trash "$f"
	(( dc++ ))
done < <(comm -23 "/private/tmp/${ADBK_GUID}-files.txt" "/private/tmp/${ADBK_GUID}-db.txt")
while read -r f; do
	echo "creating: $f"
	touch "$PWD/$f"
	(( cc++ ))
done < <(comm -13 "/private/tmp/${ADBK_GUID}-files.txt" "/private/tmp/${ADBK_GUID}-db.txt")

cat <<EOF
created: $cc
deleted: $dc
EOF
