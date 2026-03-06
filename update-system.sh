#!/bin/bash

# ╔════════════════════════════════════════════════════════════╗
# ║              Ubuntu System Update Script                   ║
# ║              powered by nala  •  by Claude                 ║
# ╚════════════════════════════════════════════════════════════╝

# ── Colors & Styles ───────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

WHITE="\033[97m"
CYAN="\033[36m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
BLUE="\033[34m"
MAGENTA="\033[35m"

BG_BLUE="\033[44m"

# ── Helpers ────────────────────────────────────────────────────
TERM_WIDTH=$(tput cols 2>/dev/null || echo 60)

print_line() {
    local char="${1:-─}"
    printf "${DIM}"
    printf '%*s' "$TERM_WIDTH" '' | tr ' ' "$char"
    printf "${RESET}\n"
}

print_success() {
    printf "${BOLD}${GREEN}  ✔  ${RESET}${GREEN}%s${RESET}\n" "$1"
}

print_warning() {
    printf "${BOLD}${YELLOW}  ⚠  ${RESET}${YELLOW}%s${RESET}\n" "$1"
}

print_error() {
    printf "${BOLD}${RED}  ✘  ${RESET}${RED}%s${RESET}\n" "$1"
}

print_info() {
    printf "${DIM}${CYAN}  ›  %s${RESET}\n" "$1"
}

print_step() {
    local step="$1"
    local label="$2"
    printf "\n${BOLD}${BG_BLUE}${WHITE}  STEP ${step}  ${RESET}${BOLD}${BLUE}  ${label}${RESET}\n"
    print_line "─"
}

run_step() {
    local label="$1"
    shift
    local cmd=("$@")

    printf "\n${DIM}  Running: %s${RESET}\n\n" "${cmd[*]}"

    if "${cmd[@]}"; then
        echo
        print_success "${label} completed successfully."
    else
        local code=$?
        echo
        print_error "${label} encountered an issue (exit code: ${code})."
        print_warning "Continuing to next step..."
    fi
}

elapsed_time() {
    local seconds=$1
    printf "%dm %02ds" $((seconds / 60)) $((seconds % 60))
}

# ── Root Check ─────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo
    print_error "This script must be run as root."
    print_info  "Try: sudo ./update-system.sh"
    echo
    exit 1
fi

# ── Banner ─────────────────────────────────────────────────────
clear
echo
printf "${BOLD}${CYAN}"
cat << 'EOF'
   _____ _   _ ____  ____ _____ _____   _   _ ____  ____    _  _____ _____ 
  / ____| \ | |  _ \|  _ \_   _|  ___| | | | |  _ \|  _ \  / \|_   _| ____|
 | (___ |  \| | |_) | |_) || | | |_    | | | | |_) | | | |/ _ \ | | |  _|  
  \___ \| . ` |  __/|  _ < | | |  _|   | |_| |  __/| |_| / ___ \| | | |___ 
  |____/|_|\_|_|   |_| \_\|_| |_|      \___/|_|   |____/_/   \_\_| |_____|
                                                                             
EOF
printf "${RESET}"
printf "${DIM}${CYAN}  Ubuntu System Maintenance  •  $(date '+%A, %B %-d %Y  •  %H:%M:%S')${RESET}\n"
print_line "═"

HOSTNAME_VAL=$(hostname)
KERNEL=$(uname -r)
DISTRO=$(lsb_release -ds 2>/dev/null || echo "Ubuntu")

printf "\n  ${DIM}Host:${RESET}  ${BOLD}%-20s${RESET}  ${DIM}Kernel:${RESET}  ${BOLD}%s${RESET}\n" "$HOSTNAME_VAL" "$KERNEL"
printf "  ${DIM}OS:${RESET}    ${BOLD}%s${RESET}\n\n" "$DISTRO"
print_line "─"

# ── Nala Check / Install ────────────────────────────────────────
PKG_MANAGER=""

if command -v nala &>/dev/null; then
    PKG_MANAGER="nala"
    printf "\n  ${BOLD}${MAGENTA}⬡ nala${RESET}${DIM}  detected — using nala for a beautiful experience.${RESET}\n\n"
else
    printf "\n  ${BOLD}${YELLOW}  ⚠  nala not found.${RESET}\n"
    print_info "nala is a prettier front-end for apt with progress bars and parallel downloads."
    printf "\n"
    read -r -p "$(printf "  ${BOLD}Install nala now? [Y/n]:${RESET} ")" install_nala
    install_nala="${install_nala:-Y}"

    if [[ "$install_nala" =~ ^[Yy]$ ]]; then
        printf "\n${DIM}  Running: apt-get install -y nala${RESET}\n\n"
        if apt-get install -y nala; then
            echo
            print_success "nala installed successfully."
            PKG_MANAGER="nala"
        else
            echo
            print_warning "nala installation failed — falling back to apt-get."
            PKG_MANAGER="apt-get"
        fi
    else
        print_info "Skipping nala install — falling back to apt-get."
        PKG_MANAGER="apt-get"
    fi
fi

print_line "─"

if [[ "$PKG_MANAGER" == "nala" ]]; then
    printf "\n  ${BOLD}${MAGENTA}Package manager:${RESET}  ${BOLD}nala${RESET}  ${DIM}(parallel downloads • rich progress UI)${RESET}\n"
else
    printf "\n  ${BOLD}${CYAN}Package manager:${RESET}  ${BOLD}apt-get${RESET}\n"
fi

echo
print_line "═"

START_TIME=$SECONDS

# ── Step 1: Update Repositories ────────────────────────────────
print_step "1/4" "Updating Package Repositories"
print_info "Fetching latest package lists from all configured sources..."

if [[ "$PKG_MANAGER" == "nala" ]]; then
    run_step "Repository update" nala update
else
    run_step "Repository update" apt-get update
fi

# ── Step 2: Upgrade Packages ───────────────────────────────────
print_step "2/4" "Upgrading Installed Packages"
print_info "Upgrading all outdated packages to their latest versions..."

if [[ "$PKG_MANAGER" == "nala" ]]; then
    run_step "System upgrade" nala upgrade -y
else
    run_step "System upgrade" apt-get upgrade -y
fi

# ── Step 3: Autoremove ─────────────────────────────────────────
print_step "3/4" "Removing Unneeded Packages"
print_info "Removing orphaned dependencies and packages no longer required..."

if [[ "$PKG_MANAGER" == "nala" ]]; then
    run_step "Autoremove" nala autoremove -y
else
    run_step "Autoremove" apt-get autoremove -y
fi

# ── Step 4: Clean Cache ────────────────────────────────────────
print_step "4/4" "Cleaning Package Cache"
print_info "Clearing the local repository cache to free up disk space..."

if [[ "$PKG_MANAGER" == "nala" ]]; then
    run_step "Cache clean" nala clean
else
    run_step "Cache clean" apt-get clean
fi

# ── Summary ────────────────────────────────────────────────────
ELAPSED=$((SECONDS - START_TIME))

echo
print_line "═"
printf "${BOLD}${GREEN}  ✔  System maintenance complete!${RESET}\n"
print_line "─"
printf "  ${DIM}Package manager:${RESET}  ${BOLD}%s${RESET}\n"    "$PKG_MANAGER"
printf "  ${DIM}Finished at:${RESET}     ${BOLD}%s${RESET}\n"     "$(date '+%H:%M:%S')"
printf "  ${DIM}Time elapsed:${RESET}    ${BOLD}%s${RESET}\n"     "$(elapsed_time $ELAPSED)"
echo
printf "${DIM}  Your system is up to date.${RESET}\n"
print_line "═"
echo
