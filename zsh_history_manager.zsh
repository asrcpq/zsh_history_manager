# 210210: simplified, it will only append history entries after the timestamp
# This might drop some history but will greatly accelarate the process

# only for fc formatted version! not for HISTFILE
_zsh_history_check() {
	[ -r "$1" ] || ( echo "History file not readable!" && return 1 );
	if [ "$(cut -f1 -d' ' "$1" \
		| sort \
		| uniq -c \
		| sort -n \
		| tail -1 \
		| awk '{print $1}')" -gt 10 ]; then
		echo "History may be corrupted."
		return 2
	fi
	return 0
}

_zsh_history_merge() {
	echo "Remote history check"
	if ! [ -f "$1" ]; then
		echo "File not exist, creating"
		if ! ( touch "$1" ); then
			echo "Cannot create file"
			return 2
		else
			echo "File created"
		fi
	fi
	if ! [ -w "$1" ] || ! [ -r "$1" ]; then
		echo "Cannot open target file for rw"
		return 3
	fi
	_zsh_history_check "$1"
	[ "$?" = 0 ] || return 9
	printf "Passed\n\n"

	echo "Generating tmp histfile and check"
	local tmphist="${XDG_CACHE_HOME-$HOME/.cache}/zsh_history_manager/tmp_history"
	mkdir -p "$(dirname "$tmphist")"
	fc -n -t "%s" -l 0 > "$tmphist"
	_zsh_history_check "$tmphist"
	[ "$?" = 0 ] || return 10
	printf "Passed\n\n"

	echo "Date extraction"
	local last_target
	last_target="$(tail -1 "$1" | grep -o "^[0-9]*")"
	local hist_ln=1
	if [ -n "$last_target" ]; then # If saved history exists
		while read -r line; do
			newdate="${line%%[[:space:]]*}"
			if [[ "$newdate" -gt "last_target" ]]; then
				break
			fi
			((++hist_ln))
		done < "$tmphist"
		echo "Success"
	else
		echo "but skip"
	fi
	printf "Passed\n\n"

	echo "Appending new history and cleaning"
	wc -l "$1"
	tail +"$hist_ln" "$tmphist" >> "$1"
	wc -l "$1"
	rm "$tmphist"
	printf "Passed\n\n"
}
