# ───────── Git-aware prompt ─────────
# Line 1: [hh:mm:ss AM] full/path  🧾💸 repo ⎇ branch  status  ═══════ (fills to edge)
# Line 2: $   (red if the last command failed)
#
# Status legend:
#   ✔ clean          ● N staged        ✚ N modified      ? N untracked
#   ✖ N conflicts    ⚑ N stashed       ↑ N ahead         ↓ N behind
#   ○ local (no upstream branch)       ∅ empty (no commits yet)
#
# Repo emoji:
#   🧾 repo folder name contains "tb"     💸 full path contains "ledg"

shopt -s checkwinsize   # keep $COLUMNS current after resizing

__git_prompt() {
  local top status line xy a b
  top=$(git rev-parse --show-toplevel 2>/dev/null) || return
  status=$(git status --porcelain=v2 --branch --show-stash 2>/dev/null) || return

  local branch="" oid="" upstream=0 ahead=0 behind=0 stash=0
  local staged=0 modified=0 untracked=0 conflicts=0

  while IFS= read -r line; do
    case "$line" in
      "# branch.oid "*)      oid=${line#\# branch.oid } ;;
      "# branch.head "*)     branch=${line#\# branch.head } ;;
      "# branch.upstream "*) upstream=1 ;;
      "# branch.ab "*)       read -r _ _ a b <<< "$line"; ahead=${a#+}; behind=${b#-} ;;
      "# stash "*)           stash=${line#\# stash } ;;
      "1 "*|"2 "*)           xy=${line:2:2}
                             [[ ${xy:0:1} != . ]] && staged=$((staged+1))
                             [[ ${xy:1:1} != . ]] && modified=$((modified+1)) ;;
      "u "*)                 conflicts=$((conflicts+1)) ;;
      "? "*)                 untracked=$((untracked+1)) ;;
    esac
  done <<< "$status"

  [[ $branch == "(detached)" ]] && branch="detached@${oid:0:7}"

  # Bright variants so everything reads well on a black background
  local R='\[\e[0m\]' RED='\[\e[91m\]' GRN='\[\e[92m\]' YEL='\[\e[93m\]' \
        BLU='\[\e[38;5;75m\]' MAG='\[\e[38;5;213m\]' CYN='\[\e[96m\]' DIM='\[\e[38;5;248m\]' \
        LGRY='\[\e[38;5;253m\]'
  local G=' '   # gap between icon and text; use '  ' if icons look cramped

  local s=""
  if [[ $oid == "(initial)" ]]; then
    s+=" ${DIM}∅${G}empty${R}"
  fi
  ((conflicts)) && s+=" ${RED}✖${G}${conflicts} conflicts${R}"
  ((staged))    && s+=" ${GRN}●${G}${staged} staged${R}"
  ((modified))  && s+=" ${YEL}✚${G}${modified} modified${R}"
  ((untracked)) && s+=" ${DIM}?${G}${untracked} untracked${R}"
  ((stash))     && s+=" ${MAG}⚑${G}${stash} stashed${R}"
  if ((upstream)); then
    ((ahead))  && s+=" ${CYN}↑${G}${ahead} ahead${R}"
    ((behind)) && s+=" ${CYN}↓${G}${behind} behind${R}"
  elif [[ $oid != "(initial)" ]]; then
    s+=" ${DIM}○${G}local${R}"
  fi
  ((conflicts + staged + modified + untracked == 0)) && [[ $oid != "(initial)" ]] \
    && s+=" ${GRN}✔${G}clean${R}"

  # Emoji in front of the repo name
  local name=${top##*/} icon=""
  [[ ${name,,} == *tb*   ]] && icon+="🧾 "
  [[ ${PWD,,}  == *ledg* ]] && icon+="💸 "

  local BBLU='\[\e[1;38;5;75m\]' BMAG='\[\e[1;38;5;213m\]'
  printf '  %s%s%s%s %s⎇%s%s%s%s' "$icon" "$BBLU" "$name" "$R" "$LGRY" "$G" "$BMAG" "$branch" "$R$s"
}

__build_prompt() {
  local exit=$?
  local R='\[\e[0m\]' DIM='\[\e[38;5;248m\]' YEL='\[\e[93m\]' GRN='\[\e[92m\]' RED='\[\e[91m\]' \
        PUR='\[\e[38;5;141m\]' \
        EQ='\[\e[38;5;250m\]'   # equals-sign fill (unchanged)
  local sym="${GRN}\$${R}"
  ((exit)) && sym="${RED}\$${R}"

  local now line1 plain cols fill eq
  printf -v now '%(%I:%M:%S %p)T' -1
  now=${now#0}   # 09:31 -> 9:31
  line1="${PUR}[${now}]${R} ${YEL}${PWD}${R}$(__git_prompt)"

  # Visible width = line minus the \[...\] color codes
  plain=$(sed -E 's/\\\[[^]]*\\\]//g' <<< "$line1")
  cols=${COLUMNS:-$(tput cols 2>/dev/null || echo 80)}
  local wide=${plain//[^🧾💸]/}   # these emoji take up 2 columns each
  fill=$(( cols - ${#plain} - ${#wide} - 2 ))   # 1 space before, 1 col margin
  eq=""
  if ((fill > 0)); then
    printf -v eq '%*s' "$fill" ''
    eq=" ${EQ}${eq// /=}${R}"
  fi

  PS1="\n${line1}${eq}\n${sym} "
}
PROMPT_COMMAND=__build_prompt
