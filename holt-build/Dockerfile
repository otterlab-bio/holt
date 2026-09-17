FROM archlinux:latest

# 并行编译配置
COPY makepkg.conf /etc/makepkg.conf

# 系统初始化
RUN pacman-key --init && pacman-key --populate archlinux && \
    pacman -Syu --noconfirm && \
    pacman -Scc --noconfirm

# 基础开发工具
RUN pacman -S --needed --noconfirm \
    base-devel git sudo nano openssh which wget curl unzip \
    pigz pbzip2 cmake gcc-fortran fastfetch && \
    pacman -Scc --noconfirm

# 创建默认用户 otter-pup（具有 sudo 权限）
RUN useradd -m -s /bin/bash -u 1000 otter-pup && \
    echo 'otter-pup:otter-pup' | chpasswd && \
    echo 'otter-pup ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/otter-pup && \
    chmod 0440 /etc/sudoers.d/otter-pup

# 安装 yay（使用 otter-pup 构建）
USER otter-pup
WORKDIR /tmp
RUN set -eux; \
    git config --global http.version HTTP/1.1; \
    for i in 1 2 3; do \
      if git clone --depth=1 https://aur.archlinux.org/yay-bin.git; then \
        break; \
      fi; \
      rm -rf yay-bin; \
      sleep "$((i * 2))"; \
    done; \
    if [ ! -d yay-bin ]; then \
      curl -fL --retry 5 --retry-delay 2 --connect-timeout 20 \
        -o yay-bin.tar.gz https://aur.archlinux.org/cgit/aur.git/snapshot/yay-bin.tar.gz; \
      tar -xzf yay-bin.tar.gz; \
    fi; \
    cd yay-bin; \
    makepkg -si --noconfirm; \
    cd /tmp; \
    rm -rf yay-bin yay-bin.tar.gz
WORKDIR /
USER root

# 内置 Go、Node.js / npm、Python 3、R
RUN pacman -S --needed --noconfirm python python-pip r nodejs npm go && \
    pacman -Sc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/* /tmp/* && \
    rm -rf /root/.cache/* /root/.local/share/pip/cache/*

# 安装 R pak 包管理器
RUN mkdir -p /root/.R && \
    echo "options(repos = c(CRAN = 'https://mirrors.tuna.tsinghua.edu.cn/CRAN/'))" > /root/.Rprofile && \
    R_LIBS=/usr/lib/R/library R -e "install.packages('pak', repos = 'https://mirrors.tuna.tsinghua.edu.cn/CRAN/')" && \
    rm -rf /tmp/Rtmp* /root/.R/pack/

# 配置 R：默认安装到用户目录，避免无权限写系统库
RUN RHOME="$(R RHOME)" && \
    mkdir -p /etc/R "$RHOME/etc" && \
    touch /etc/R/Renviron.site "$RHOME/etc/Renviron.site" && \
    grep -q '^R_LIBS_USER=' /etc/R/Renviron.site || \
      echo 'R_LIBS_USER=~/.local/share/R/%p-library/%V' >> /etc/R/Renviron.site && \
    grep -q '^R_LIBS_USER=' "$RHOME/etc/Renviron.site" || \
      echo 'R_LIBS_USER=~/.local/share/R/%p-library/%V' >> "$RHOME/etc/Renviron.site"

# 安装 Rust
RUN pacman -S --noconfirm rustup && \
    rustup default stable && \
    pacman -Sc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/* /tmp/*

# 配置环境变量与工作目录
ENV GOPATH=/home/otter-pup/go
ENV PATH=/home/otter-pup/go/bin:/home/otter-pup/.cargo/bin:/home/otter-pup/.local/bin:/root/.cargo/bin:/root/go/bin:$PATH

# 为 otter-pup 初始化环境
RUN mkdir -p /home/otter-pup/go/bin /home/otter-pup/.local/bin /home/otter-pup/.cargo/bin && \
    echo 'export GOPATH=$HOME/go' >> /home/otter-pup/.bashrc && \
    echo 'export PATH=$HOME/go/bin:$HOME/.cargo/bin:$HOME/.local/bin:$PATH' >> /home/otter-pup/.bashrc && \
    chown -R otter-pup:otter-pup /home/otter-pup

# 验证语言环境安装
RUN python --version && R --version && node --version && npm --version && \
    rustc --version && cargo --version && go version

# 设置默认用户
USER otter-pup
WORKDIR /home/otter-pup

CMD ["/bin/bash"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD python --version && R --version && node --version && cargo --version && go version || exit 1
