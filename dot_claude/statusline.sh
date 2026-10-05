#!/bin/bash
# Claude Code status line mirroring ~/.config/starship.toml (directory + git_branch + git_status)
# preceded by model, context used % and 5h session %. No network; git calls use --no-optional-locks.
cfg="$HOME/.config/starship.toml"
input=$(cat)
IFS=$'\t' read -r cwd model effort used sess < <(printf '%s' "$input" | jq -r '[(.workspace.current_dir // .cwd // ""), (.model.display_name // "-"), (.effort.level // "-"), (.context_window.used_percentage // "-"), (.rate_limits.five_hour.used_percentage // "-")] | @tsv')
[ -z "$cwd" ] && cwd=$PWD
[ "$model" = "-" ] && model=""; [ "$effort" = "-" ] && effort=""; [ "$used" = "-" ] && used=""; [ "$sess" = "-" ] && sess=""

# Catppuccin mocha truecolor (R;G;B triples)
MAUVE="203;166;247"; BLUE="137;180;250"; TEAL="148;226;213"
PEACH="250;179;135"; YEL="249;226;175"; RED="243;139;168"
CRUST=$'\e[38;2;17;17;27m'; RST=$'\e[0m'
SEP=$'\xee\x82\xb0'          # U+E0B0 powerline arrow

# Powerline builder: seg "R;G;B" "text" -> arrow from previous bg into this bg, then text
out=""; prev=""
seg() {
  if [ -n "$prev" ]; then out+=$'\e[38;2;'"${prev}m"$'\e[48;2;'"${1}m${SEP}"
  else out+=$'\e[48;2;'"${1}m"; fi
  out+="${CRUST}${2}"; prev=$1
}
# Colour for a percentage: base colour, Red at >=80%
pct_col() { [ "$(printf '%.0f' "$2")" -ge 80 ] && echo "$RED" || echo "$1"; }

# Symbols/substitutions read from starship.toml at runtime (fallbacks = Starship defaults)
branch_sym=$'\xee\x82\xa0'   # U+E0A0
subs=""
if [ -r "$cfg" ]; then
  s=$(awk -F'"' '/^\[git_branch\]/{f=1;next} /^\[/{f=0} f && /^symbol[ ]*=/{print $2; exit}' "$cfg")
  [ -n "$s" ] && branch_sym=$s
  subs=$(awk -F'"' '/^\[directory.substitutions\]/{f=1;next} /^\[/{f=0} f && NF>=4{print $2 "\t" $4}' "$cfg")
fi

git_() { git --no-optional-locks -C "$cwd" "$@" 2>/dev/null; }

# ---- directory (truncation_length=3, truncation_symbol="…/", truncate_to_repo) ----
root=$(git_ rev-parse --show-toplevel)
if [ -n "$root" ]; then
  rel=${cwd#"$root"}; rel=${rel#/}
  path="${root##*/}${rel:+/$rel}"
else
  path=$cwd
  case $path in "$HOME") path="~";; "$HOME"/*) path="~/${path#"$HOME"/}";; esac
fi
IFS='/' read -r -a parts <<< "$path"
# drop empty leading element for absolute paths
[ "${parts[0]}" = "" ] && parts=("${parts[@]:1}") && lead="/" || lead=""
if [ "${#parts[@]}" -gt 3 ]; then
  parts=("${parts[@]: -3}"); path="…/$(IFS=/; echo "${parts[*]}")"
else
  path="$lead$(IFS=/; echo "${parts[*]}")"
fi
while IFS=$'\t' read -r k v; do
  [ -n "$k" ] && path=${path//"$k"/"$v"}
done <<< "$subs"

# ---- model, context %, session % (5h limit; omitted if absent) ----
[ -n "$model" ] && seg "$MAUVE" " ${model}${effort:+ · $effort} "
[ -n "$used" ] && seg "$(pct_col "$BLUE" "$used")" " ctx $(printf '%.0f' "$used")% "
[ -n "$sess" ] && seg "$(pct_col "$TEAL" "$sess")" " 5h $(printf '%.0f' "$sess")% "

seg "$PEACH" " ${path} "

# ---- git_branch + git_status ----
if [ -n "$root" ]; then
  head=""; oid=""; ab=""; staged=0; mod=0; del=0; ren=0; conf=0
  while IFS= read -r l; do
    case $l in
      "# branch.oid "*) oid=${l#\# branch.oid }; oid=${oid:0:7};;
      "# branch.head "*) head=${l#\# branch.head };;
      "# branch.ab "*) ab=${l#\# branch.ab };;
      "1 "*|"2 "*)
        xy=${l:2:2}; x=${xy:0:1}; y=${xy:1:1}
        [ "$x" != "." ] && staged=1
        [ "$y" = "M" ] && mod=1
        { [ "$x" = "D" ] || [ "$y" = "D" ]; } && del=1
        [ "${l:0:1}" = "2" ] && ren=1;;
      "u "*) conf=1;;
    esac
  done < <(git_ status --porcelain=v2 --branch -uno)
  [ "$head" = "(detached)" ] && head=$oid
  st=""
  [ $conf = 1 ] && st+="="
  if [ -n "$ab" ]; then
    a=${ab%% *}; a=${a#+}; b=${ab##* }; b=${b#-}
    if [ "$a" -gt 0 ] && [ "$b" -gt 0 ]; then st+="⇕"
    elif [ "$a" -gt 0 ]; then st+="⇡"
    elif [ "$b" -gt 0 ]; then st+="⇣"; fi
  fi
  [ $mod = 1 ] && st+="!"
  [ $staged = 1 ] && st+="+"
  [ $ren = 1 ] && st+="»"
  [ $del = 1 ] && st+="✘"
  seg "$YEL" " ${branch_sym} ${head} ${st:+$st }"
fi

# final arrow on terminal default background
out+="${RST}"$'\e[38;2;'"${prev}m${SEP}${RST}"
printf '%s\n' "$out"
