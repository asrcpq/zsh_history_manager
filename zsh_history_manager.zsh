# only for fc formatted version! not for HISTFILE
_zsh_history_check() {
	set -e
	[ -r "$1" ] || ( echo "History file not readable!" && return 1 );
	if [ "$(cut -f1 -d' ' "$1" \
		| sort \
		| uniq -c \
		| sort -n \
		| tail -1 \
		| awk '{print $1}')" -gt 10 ]; then
		echo "Risk of epoch rewrite/dirty history detected"
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
	zsh_history_check "$1"
	[ "$?" = 0 ] || return 9
	printf "Passed\n\n"

	echo "Generating tmp histfile and check"
	local tmphist="${XDG_CACHE_HOME-$HOME/.cache}/zsh_history_manager/tmp_history"
	mkdir -p "$(dirname "$tmphist")"
	fc -n -t "%s" -l 0 > "$tmphist"
	zsh_history_check "$tmphist"
	[ "$?" = 0 ] || return 10
	printf "Passed\n\n"

	echo "Matching sync-ed history"
	local LN
	LN="$(grep -n "^$(head -1 "$tmphist")$" "$1" | head -1 | grep -o '^[0-9]*')"
	echo "target split: $LN/$(wc -l <"$1")"
	local hist_ln=1 # LN of first new line in tmphist
	local line_target
	local line_hist
	local yn
	local match_ln
	if [ -n "$LN" ]; then
		echo "Find record in $LN, matching remaining"
		while true; do
			# order is important!
			IFS= read -r line_target <&3 || break
			IFS= read -r line_hist <&4 || ( echo "Early EOF of tmphist" && return 5 )
			if [ "$line_hist" != "$line_target" ]; then
				echo "Line mismatch in target file:$LN tmphist:$hist_ln"
				echo "Trying to match trailing lines"
				local ln=$LN
				trailing_match() {
					match_ln="$( \
						grep -n "^$line_target$" "$tmphist" \
						| grep -o "^[0-9]*" \
						| tr '\n' ',' \
					)"
					if [ -n "$match_ln" ]; then
						echo "$ln<-->${match_ln%,}"
					else
						echo "$ln<-->FAILED..."
						return 6
					fi
					ln=$(( ln + 1 ))
				}
				trailing_match || return 6
				while IFS= read -r line_target <&3; do
					trailing_match || return 6
				done
				echo "Proceed(y)?"
				read -r yn
				[ "$yn" != "y" ] && return 7
				local target_tmp="$XDG_CACHE_HOME/zsh/target_tmp"
				head -"$(( LN - 1 ))" "$1" > "$target_tmp"
				mv -f "$target_tmp" "$1"
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
	local last_target
	last_target="$(tail -1 "$1" | grep -o "^[0-9]*")"
	if [ -n "$last_target" ]; then # If saved history exists
		local first_tmphist
		first_tmphist="$(sed -nE "${hist_ln}p" "$tmphist" | grep -o "^[0-9]*")"
		if [ -z "$first_tmphist" ]; then
			echo "Nothing to append"
			return 0
		fi
		echo -E "$first_tmphist vs $last_target"
		if [ "$first_tmphist" -lt "$last_target" ]; then
			echo "Date check failed"
			return 8
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
