function zsh_history_check() {
	local last_time=0
	local LN=0
	local check_pass=0
	if ! [ -r "$1" ]; then
		echo "History file not readable!"
		return 2
	fi
	cat "$1" | while read -r line; do
		LN=$(( $LN + 1 ))
		local epoch_match="$(echo "$line" | grep -o '^: [0-9]*:[0-9]*;')"
		if [ -n "$epoch_match" ]; then
			local new_time="${epoch_match:2}"
			new_time="${new_time%:*}"
			if [ "$new_time" -lt "$last_time" ]; then
				echo "Note: time goes back for $(($last_time - $new_time))s in $LN"
			fi
			if [ "$last_time" -eq 0 ]; then
				echo -n "History start at: "
				date -d @"$new_time"
			fi
			last_time=$new_time
		else
			echo "EXTENDED_HISTORY format error in $LN"
			check_pass=1
		fi
		if [ $#line -gt ${ZSH_HISTORY_MAXLEN-256} ]; then
			echo "Length overflow in $LN"
			check_pass=1
		fi
	done
	if [ "$check_pass" -ne 1 ]; then
		echo -n "History end at: "
		date -d @"$last_time"
	fi
	last_time=$new_time
	return check_pass
}

function zsh_history_merge() {
	echo "Local history check"
	if ! zsh_history_check "$HISTFILE"; then
		echo "History check failed for local history, refuse to merge"
		return 1
	fi
	echo "Passed\n"

	echo "Remote history check"
	if ! [ -f "$1" ]; then
		echo "File not exist, creating"
		if ! ( touch "$1" ); then
			echo "Cannot create file"
			return 2
		else
			echo "File created"
		fi
	else
		if ! zsh_history_check "$1"; then
			echo "History check failed for remote history, refuse to merge"
			return 4
		fi
	fi
	if ! [ -w "$1" ] || ! [ -r "$1" ]; then
		echo "Cannot open target file for rw"
		return 3
	fi
	echo "Passed\n"

	echo "Merging"
	echo -n "$(wc -l < "$1")"+"$(wc -l < "$HISTFILE")"=
	cat "$HISTFILE" >> "$1"
	sort -uo "$1" "$1"
	echo "$(wc -l < "$1")"
}
