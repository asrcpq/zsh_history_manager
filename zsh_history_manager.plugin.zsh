function zsh_history_check() {
	local last_time=0
	local LN=0
	local check_pass=0
	cat "$HISTFILE" | while read -r line; do
		LN=$(( $LN + 1 ))
		if ( echo $line | grep '^: [0-9]*:[0-9]*;' > /dev/null ); then
			local new_time="$(echo $line | cut -d':' -f2 | tr -d ' ')"
			if [ "$new_time" -lt "$last_time" ]; then
				echo "Note: time goes back for $(($last_time - $new_time))s in $LN"
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
	return check_pass
}

function zsh_history_merge() {
	if ! zsh_history_check; then
		echo "History check failed, refuse to merge"
		return 1
	fi
	if ! [ -w "$1" ]; then
		if ! ( touch "$1" ); then
			echo "Cannot open target file for writing"
			return 2
		else
			echo "File created"
		fi
	fi
	echo -n "$(wc -l < "$1")"+"$(wc -l < "$HISTFILE")"=
	cat "$HISTFILE" >> "$1"
	sort -uo "$1" "$1"
	echo "$(wc -l < "$1")"
}
