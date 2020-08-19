zsh_history_merge() {
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
	printf "Passed\n\n"

	echo "Generating tmp histfile"
	tmphist="${XDG_CACHE_HOME-$HOME/.cache}/zsh_history_manager/tmp_history"
	mkdir -p "$(dirname "$tmphist")"
	fc -n -t "%s" -l 0 > "$tmphist"
	printf "Passed\n\n"

	echo "Matching sync-ed history"
	LN="$(grep -n "^$(head -1 "$tmphist")$" "$1" | head -1 | grep -o '^[0-9]*')"
	echo "target split: $LN/$(wc -l <"$1")"
	hist_ln=1 # LN of first new line in tmphist
	if [ -n "$LN" ]; then
		echo "Find record in $LN, matching remaining"
		while true; do
			# order is important!
			IFS= read -r line_target <&3 || break
			IFS= read -r line_hist <&4 || ( echo "Early EOF of tmphist" && return 5 )
			if [ "$line_hist" != "$line_target" ]; then
				echo "Line mismatch in target file:$LN tmphist:$hist_ln"
				echo "Trying to match trailing lines"
				for ln in {$LN..$(wc -l < "$1")}; do
					match_ln="$(grep -n "$(sed -nE "${ln}p" "$1")" "$tmphist" | grep -o "^[0-9]*")"
					if [ -n "$match_ln" ]; then
						echo "$ln<-->$match_ln"
					else
						echo "$ln<-->FAILED..."
						return 6
					fi
				done
				echo "Proceed(y)?"
				read -r yn
				[ "$yn" != "y" ] && return 7
				target_tmp="$XDG_CACHE_HOME/zsh/target_tmp"
				head -"$(( LN - 1 ))" "$1" > "$target_tmp"
				mv "$target_tmp" "$1"
				break
			fi
			LN=$(( LN + 1 ))
			hist_ln=$(( hist_ln + 1 ))
		done 3<<<"$(tail +"$LN" "$1")" 4<"$tmphist"
	else
		echo "No record found"
	fi
	echo "local split: $hist_ln/$(wc -l < "$tmphist")"
	printf "Passed\n\n"

	echo "Joint date verification"
	last_target="$(tail -1 "$1" | grep -o "^[0-9]*")"
	if [ -n "$last_target" ]; then # If saved history exists
		first_tmphist="$(sed -nE "${hist_ln}p" "$tmphist" | grep -o "^[0-9]*")"
		if [ -z "$first_tmphist" ]; then
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
	printf "Passed\n\n"

	echo "Appending new history and cleaning"
	wc -l "$1"
	tail +"$hist_ln" "$tmphist" >> "$1"
	wc -l "$1"
	rm "$tmphist"
	printf "Passed\n\n"
}
