#!/bin/bash

# Function to detect package manager
detect_package_manager() {
    if command -v apt &>/dev/null; then
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

# Function to install packages based on package manager
install_package() {
    local package_manager=$1
    local package_name=$2
    
    case $package_manager in
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
    if [ "$PKG_MANAGER" = "UNKNOWN" ]; then
        echo "Could not detect package manager. Exiting..."
        exit 1
    fi
    
    echo "Detected package manager: $PKG_MANAGER"
    
    # Update package manager
    case $PKG_MANAGER in
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
        case $PKG_MANAGER in
            "apt")
                sudo apt-get install -y golang
                ;;
            "dnf"|"yum")
                sudo $PKG_MANAGER install -y golang
                ;;
            "pacman")
                sudo pacman -S --noconfirm go
                ;;
            "zypper")
                sudo zypper install -y go
                ;;
        esac
    fi
    
    # Set Zsh as default shell
    echo "Setting Zsh as default shell..."
    chsh -s $(which zsh)
    
    echo "Installation complete! Please log out and log back in to start using Zsh."
    echo "Don't forget to update the Git repository URL in the script before using it."
}

# Run main function
main