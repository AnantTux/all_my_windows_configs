# Neon cyberpunk fallback theme for Oh My Zsh.
local cyan='%F{cyan}' magenta='%F{magenta}' violet='%F{141}' green='%F{green}' reset='%f'
PROMPT='${cyan}╭─${magenta}%n${violet}@${cyan}%m ${violet} ${cyan}%~${reset}$(git_prompt_info)\n${cyan}╰─${magenta}❯${reset} '
ZSH_THEME_GIT_PROMPT_PREFIX=" ${violet} "
ZSH_THEME_GIT_PROMPT_SUFFIX="${reset}"
ZSH_THEME_GIT_PROMPT_DIRTY="${magenta}✚${reset}"
ZSH_THEME_GIT_PROMPT_CLEAN="${green}●${reset}"
