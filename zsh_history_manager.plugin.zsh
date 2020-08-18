function zsh_history_merge() {
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
	echo "Passed\n"

	echo "Generating tmp histfile"
	tmphist="${XDG_CACHE_HOME-$HOME/.cache}/zsh_history_manager/tmp_history"
	mkdir -p "$(dirname $tmphist)"
	fc -n -t "%s" -D -l 0 > $tmphist
	echo "Passed\n"

	echo "Matching sync-ed history"
	LN="$(cat "$1" | grep -n "^$(cat "$tmphist" | head -1)$" | head -1 | grep -o '^[0-9]*')"
	echo "target split: $LN/$(cat "$1" | wc -l)"
	hist_ln=1 # LN of first new line in tmphist
	if [ -n "$LN" ]; then
		echo "Find record in $LN, matching remaining"
		cat "$1" | tail +$LN | while true; do
			# order is important!
			IFS= read -r line_target || break
			IFS= read -r line_hist <&3 || ( echo "Early EOF of tmphist" && return 5 )
			if [ "$line_hist" != "$line_target" ]; then
				echo "Line mismatch in target file:$LN tmphist:"
				return 6
			fi
			LN=$(( $LN + 1 ))
			hist_ln=$(( $hist_ln + 1 ))
		done 3<"$tmphist"
	else
		echo "No record found"
	fi
	echo "local split: $hist_ln/$(cat "$tmphist" | wc -l)"
	echo "Passed\n"

	echo "Joint date verification"
	last_target="$(cat "$1" | tail -1 | grep -o "^[0-9]*")"
	if [ -n "$last_target" ]; then # If saved history exists
		first_tmphist="$(cat "$tmphist" | sed -nE "${hist_ln}p" | grep -o "^[0-9]*")"
		if [ -z $first_tmphist ]; then
			echo "Nothing to append"
			return 0
		fi
		echo -E "$first_tmphist vs $last_target"
		if [ "$first_tmphist" -lt "$last_target" ]; then
			echo "Date check failed"
			return 7
		fi
		echo "Success"
	else
		echo "but skip"
	fi
	echo "Passed\n"

	echo "Appending new history and cleaning"
	wc -l "$1"
	cat "$tmphist" | tail +$hist_ln >> "$1"
	wc -l "$1"
	rm $tmphist
	echo "Passed\n"
}
