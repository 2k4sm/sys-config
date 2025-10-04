#!/bin/bash

set -e  # Exit on error

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
    
    echo "Installing package: $package_name"
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
            sudo zypper --non-interactive install "$package_name"
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
        "python3-pip")
            case $package_manager in
                "brew")
                    echo "python3"  # pip comes with python3 on macOS
                    ;;
                *)
                    echo "python3-pip"
                    ;;
            esac
            ;;
        "gcc")
            case $package_manager in
                "brew")
                    echo "gcc"
                    ;;
                *)
                    echo "gcc"
                    ;;
            esac
            ;;
        *)
            echo "$generic_name"
            ;;
    esac
}

# Function to install base dependencies
install_base_deps() {
    local pkg_manager=$1
    
    echo "Updating package manager..."
    case $pkg_manager in
        "brew")
            brew update
            ;;
        "apt")
            sudo apt-get update
            ;;
        "dnf"|"yum")
            sudo $pkg_manager check-update || true  # Prevent exit on update check
            ;;
        "pacman")
            sudo pacman -Sy
            ;;
        "zypper")
            sudo zypper refresh
            ;;
    esac
    
    # Common packages across distributions
    local packages=(
        "git"
        "curl"
        "unzip"
        "npm"
        "python3"
        "ripgrep"
        "make"
        "nodejs"
    )
    
    # Add platform-specific packages
    if [[ "$pkg_manager" != "brew" ]]; then
        packages+=("python3-pip" "gcc")
    else
        packages+=("gcc")
        # On macOS, pip comes with python3
    fi
    
    for package in "${packages[@]}"; do
        pkg_name=$(get_package_name "$pkg_manager" "$package")
        echo "Installing $pkg_name..."
        install_package "$pkg_manager" "$pkg_name"
    done

    # Ensure npm is up to date
    echo "Updating npm..."
    if [[ "$pkg_manager" == "brew" ]]; then
        npm install -g npm@latest
    else
        sudo npm install -g npm@latest
    fi
}

# Function to install Neovim
install_neovim() {
    local pkg_manager=$1
    
    echo "Installing Neovim..."
    case $pkg_manager in
        "brew")
            brew install neovim
            ;;
        "apt")
            # First try to add the unstable PPA
            if ! grep -q "neovim-ppa/unstable" /etc/apt/sources.list.d/* 2>/dev/null; then
                sudo apt-get install -y software-properties-common
                sudo add-apt-repository ppa:neovim-ppa/unstable -y
                sudo apt-get update
            fi
            sudo apt-get install -y neovim
            ;;
        "dnf")
            sudo dnf install -y neovim python3-neovim
            ;;
        "yum")
            sudo yum install -y epel-release
            sudo yum install -y neovim python3-neovim
            ;;
        "pacman")
            sudo pacman -S --noconfirm neovim python-pynvim
            ;;
        "zypper")
            sudo zypper install -y neovim python3-neovim
            ;;
    esac

    # Verify installation
    if ! command -v nvim &>/dev/null; then
        echo "Neovim installation failed!"
        exit 1
    fi
}

# Function to install Rust
install_rust() {
    echo "Installing Rust..."
    if ! command -v rustup &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    else
        echo "Rust is already installed, updating..."
        rustup update
    fi
}

# Function to install Go
install_go() {
    local pkg_manager=$1
    echo "Installing Go..."
    case $pkg_manager in
        "brew")
            brew install go
            ;;
        "apt")
            sudo apt-get install -y golang
            ;;
        "dnf"|"yum")
            sudo $pkg_manager install -y golang
            ;;
        "pacman")
            sudo pacman -S --noconfirm go
            ;;
        "zypper")
            sudo zypper install -y go
            ;;
    esac

    # Verify Go installation
    if ! command -v go &>/dev/null; then
        echo "Go installation failed!"
        exit 1
    fi

    # Set up GOPATH if not already set
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin
}

# Function to install language servers and tools
install_language_servers() {
    local pkg_manager=$1
    echo "Installing Language Servers..."
    
    # Python - pyright
    echo "Installing pyright..."
    if [[ "$pkg_manager" == "brew" ]]; then
        npm install -g pyright
    else
        sudo npm install -g pyright
    fi

    # Java - ensure JDK is installed
    echo "Installing Java JDK..."
    case $pkg_manager in
        "brew")
            brew install openjdk@17
            # Link the JDK for macOS
            sudo ln -sfn $(brew --prefix)/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
            ;;
        "apt")
            sudo apt-get install -y openjdk-17-jdk
            ;;
        "dnf"|"yum")
            sudo $pkg_manager install -y java-17-openjdk-devel
            ;;
        "pacman")
            sudo pacman -S --noconfirm jdk17-openjdk
            ;;
        "zypper")
            sudo zypper install -y java-17-openjdk-devel
            ;;
    esac

    # Create directory for jdtls
    mkdir -p ~/.local/share/nvim/mason/packages/jdtls
    
    # Rust - rust-analyzer
    echo "Installing rust-analyzer..."
    rustup component add rust-analyzer

    # Go - gopls
    echo "Installing gopls..."
    go install golang.org/x/tools/gopls@latest
    
    # C/C++ - clangd
    echo "Installing clangd..."
    case $pkg_manager in
        "brew")
            brew install llvm
            # Add LLVM to PATH
            echo 'export PATH="$(brew --prefix)/opt/llvm/bin:$PATH"' >> ~/.zshrc
            ;;
        "apt")
            sudo apt-get install -y clangd
            ;;
        "dnf"|"yum")
            sudo $pkg_manager install -y clang-tools-extra
            ;;
        "pacman")
            sudo pacman -S --noconfirm clang
            ;;
        "zypper")
            sudo zypper install -y clang
            ;;
    esac
}

# Function to verify all required tools are installed
verify_installation() {
    local required_commands=("nvim" "git" "npm" "python3" "go" "rustc")
    local missing_commands=()

    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done

    # Check for clangd (might be in different locations on macOS)
    if ! command -v clangd &>/dev/null; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if ! command -v "$(brew --prefix)/opt/llvm/bin/clangd" &>/dev/null; then
                missing_commands+=("clangd")
            fi
        else
            missing_commands+=("clangd")
        fi
    fi

    if [ ${#missing_commands[@]} -ne 0 ]; then
        echo "Error: The following required tools are not installed: ${missing_commands[*]}"
        exit 1
    fi
}

# Main installation function
main() {
    echo "Starting AstroNvim setup..."
    
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
    
    # Install base dependencies
    install_base_deps "$PKG_MANAGER"
    
    # Install Neovim
    install_neovim "$PKG_MANAGER"
    
    # Install Rust and Go
    install_rust
    install_go "$PKG_MANAGER"
    
    # Backup existing Neovim configuration
    echo "Backing up existing Neovim configuration..."
    if [ -d ~/.config/nvim ]; then
        mv ~/.config/nvim ~/.config/nvim.bak.$(date +%Y%m%d_%H%M%S)
    fi
    if [ -d ~/.local/share/nvim ]; then
        mv ~/.local/share/nvim ~/.local/share/nvim.bak.$(date +%Y%m%d_%H%M%S)
    fi
    
    # Install AstroNvim
    echo "Installing AstroNvim..."
    git clone --depth 1 https://github.com/AstroNvim/AstroNvim ~/.config/nvim
    
    # Install user configuration
    echo "Installing user configuration..."
    git clone https://github.com/2k4sm/user ~/.config/nvim/lua/user
    
    # Install language servers
    install_language_servers "$PKG_MANAGER"
    
    # Create initial setup file for Mason
    mkdir -p ~/.config/nvim/lua/user/mason-setup
    cat > ~/.config/nvim/lua/user/mason-setup/init.lua << 'EOL'
return {
  ensure_installed = {
    -- LSPs
    "jdtls",
    "pyright",
    "rust-analyzer",
    "gopls",
    "clangd",
    
    -- DAP
    "debugpy",
    "codelldb",
    
    -- Linters
    "flake8",
    "shellcheck",
    
    -- Formatters
    "black",
    "prettier",
    "stylua",
  },
}
EOL

    # Verify installation
    verify_installation

    echo "Installation complete!"
    echo "Please run 'nvim' to start Neovim and let AstroNvim complete the setup."
    echo "During first launch, AstroNvim will automatically install all configured language servers."
    echo "Note: For Java development, make sure you have JDK 17 or later installed."
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo ""
        echo "macOS-specific notes:"
        echo "  - LLVM/clangd has been installed and added to your PATH in ~/.zshrc"
        echo "  - OpenJDK 17 has been linked to the system Java directory"
        echo "  - You may need to restart your terminal for all changes to take effect"
    fi
}

# Run main function
main
