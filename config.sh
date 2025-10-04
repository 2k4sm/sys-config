#!/bin/bash

# Function to detect package manager
detect_package_manager() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &>/dev/null; then
            echo "brew"
        else
            echo "BREW_MISSING"
        fi
    elif command -v apt &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v zypper &>/dev/null; then
        echo "zypper"
    else
        echo "UNKNOWN"
    fi
}

# Function to install Homebrew on macOS
install_homebrew() {
    echo "Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon Macs
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

# Function to install packages based on package manager
install_package() {
    local package_manager=$1
    local package_name=$2
    
    case $package_manager in
        "brew")
            brew install "$package_name"
            ;;
        "apt")
            sudo apt-get install -y "$package_name"
            ;;
        "dnf"|"yum")
            sudo $package_manager install -y "$package_name"
            ;;
        "pacman")
            sudo pacman -S --noconfirm "$package_name"
            ;;
        "zypper")
            sudo zypper install -y "$package_name"
            ;;
        *)
            echo "Unsupported package manager"
            exit 1
            ;;
    esac
}

# Function to map package names across different distributions
get_package_name() {
    local package_manager=$1
    local generic_name=$2
    
    case $generic_name in
        "zsh")
            echo "zsh"
            ;;
        "git")
            echo "git"
            ;;
        "curl")
            echo "curl"
            ;;
        "fastfetch")
            case $package_manager in
                "brew")
                    echo "fastfetch"
                    ;;
                "apt")
                    echo "fastfetch"
                    ;;
                "dnf"|"yum")
                    echo "fastfetch"
                    ;;
                "pacman")
                    echo "fastfetch"
                    ;;
                "zypper")
                    echo "fastfetch"
                    ;;
            esac
            ;;
        "golang")
            case $package_manager in
                "brew")
                    echo "go"
                    ;;
                "apt")
                    echo "golang"
                    ;;
                "dnf"|"yum")
                    echo "golang"
                    ;;
                "pacman")
                    echo "go"
                    ;;
                "zypper")
                    echo "go"
                    ;;
            esac
            ;;
        *)
            echo "$generic_name"
            ;;
    esac
}

# Main installation function
main() {
    echo "Starting Zsh environment setup..."
    
    # Detect package manager
    PKG_MANAGER=$(detect_package_manager)
    
    if [ "$PKG_MANAGER" = "BREW_MISSING" ]; then
        install_homebrew
        PKG_MANAGER="brew"
    elif [ "$PKG_MANAGER" = "UNKNOWN" ]; then
        echo "Could not detect package manager. Exiting..."
        exit 1
    fi
    
    echo "Detected package manager: $PKG_MANAGER"
    
    # Update package manager
    case $PKG_MANAGER in
        "brew")
            brew update
            ;;
        "apt")
            sudo apt-get update
            ;;
        "dnf"|"yum")
            sudo $PKG_MANAGER check-update
            ;;
        "pacman")
            sudo pacman -Sy
            ;;
        "zypper")
            sudo zypper refresh
            ;;
    esac
    
    # Install required packages
    for package in zsh git curl fastfetch; do
        pkg_name=$(get_package_name "$PKG_MANAGER" "$package")
        echo "Installing $pkg_name..."
        install_package "$PKG_MANAGER" "$pkg_name"
    done
    
    # Install Oh My Zsh
    echo "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    
    # Install Zsh plugins
    echo "Installing Zsh plugins..."
    
    # zsh-syntax-highlighting
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting
    
    # zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    
    # Download and set up .zshrc
    echo "Setting up .zshrc..."
    if [ -f ~/.zshrc ]; then
        mv ~/.zshrc ~/.zshrc.backup
        echo "Existing .zshrc backed up to ~/.zshrc.backup"
    fi
    
    git clone git@github.com:2k4sm/sys-config.git /tmp/zsh-config
    cp /tmp/zsh-config/.zshrc ~/
    rm -rf /tmp/zsh-config
    
    # Install Bun
    echo "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
    
    # Install Go if not present
    if ! command -v go &>/dev/null; then
        echo "Installing Go..."
        go_pkg=$(get_package_name "$PKG_MANAGER" "golang")
        install_package "$PKG_MANAGER" "$go_pkg"
    fi
    
    # Set Zsh as default shell
    echo "Setting Zsh as default shell..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS method
        sudo chsh -s $(which zsh) $USER
    else
        # Linux method
        chsh -s $(which zsh)
    fi
    
    echo "Installation complete! Please log out and log back in to start using Zsh."
    echo "Don't forget to update the Git repository URL in the script before using it."
}

# Run main function
main
