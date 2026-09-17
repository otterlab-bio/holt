ARG BASE_IMAGE=ghcr.io/otterlab-bio/holt-build:latest
FROM ${BASE_IMAGE}

USER root

# 配置 pacman 并行下载
RUN sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# ===== 阶段 1: 基础系统依赖安装 =====
RUN pacman -Sy --noconfirm && \
    pacman -S --noconfirm --needed \
        wget \
        mariadb \
        mariadb-clients \
        imagemagick \
        poppler \
        libxtst \
        openssh \
        bubblewrap \
        jdk-openjdk \
        cairo \
        pango \
        freetype2 \
        libpng \
        libjpeg-turbo \
        libtiff \
        noto-fonts-cjk && \
    pacman -Sc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/* /tmp/*

# ===== 阶段 2: JupyterLab 与 Ark 安装 =====
RUN pacman -S --noconfirm jupyterlab && \
    pacman -Sc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/* /tmp/*

# 安装 Ark (Posit Dev) - 增强 JupyterLab 的交互开发能力
RUN cd /tmp && \
    wget -q https://github.com/posit-dev/ark/releases/download/0.1.222/ark-0.1.222-linux-x64.zip && \
    unzip -q ark-0.1.222-linux-x64.zip && \
    mv ark /usr/bin/ && \
    chmod +x /usr/bin/ark && \
    ark --install && \
    rm -rf /tmp/ark*

# ===== 阶段 3: 用户管理向导工具 =====
COPY add_user_interactive.sh /usr/local/bin/add-user
RUN chmod +x /usr/local/bin/add-user

# ===== 阶段 4: 安装 otter 全套生物信息学工具集 =====
# 包含: otter, enva, craftmake, xenofilx, pairbam, seq2mat, methx, qctb, fastqcx, matsrun
ENV OTTER_VERSION=v1.0.0
RUN mkdir -p /opt/otter/bin /opt/otter/envs && \
    for tool in otter enva craftmake xenofilx pairbam seq2mat methx qctb fastqcx matsrun; do \
      echo "Downloading $tool..."; \
      curl -fL --retry 5 --retry-delay 2 --connect-timeout 20 \
        "https://github.com/otterlab-bio/otter/releases/download/${OTTER_VERSION}/${tool}-linux-amd64-static" \
        -o "/usr/local/bin/${tool}"; \
      chmod +x "/usr/local/bin/${tool}"; \
      ln -sf "/usr/local/bin/${tool}" "/opt/otter/bin/${tool}"; \
    done

# 拷贝 otter 环境定义文件
COPY envs/ /opt/otter/envs/

# ===== 阶段 5: 使用 enva 初始化 otter-core 环境 =====
ENV MAMBA_ROOT_PREFIX=/opt/conda
ENV OTTER_CORE_PREFIX=${MAMBA_ROOT_PREFIX}/envs/otter-core
RUN mkdir -p ${MAMBA_ROOT_PREFIX} && \
    /usr/local/bin/enva create --yaml /opt/otter/envs/otter-core.yaml --name otter-core --force --clean-cache && \
    chown -R otter-pup:otter-pup ${MAMBA_ROOT_PREFIX} /opt/otter

# ===== 阶段 6: SSH 服务与 otter-pup 用户配置 =====
RUN ssh-keygen -A && \
    mkdir -p /var/run/sshd /home/otter-pup/.ssh && \
    chown -R otter-pup:otter-pup /home/otter-pup/.ssh && \
    chmod 700 /home/otter-pup/.ssh

RUN cat > /etc/ssh/sshd_config <<'EOF'
Port 2222
Protocol 2
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
Subsystem sftp internal-sftp
EOF

RUN cat > /home/otter-pup/.ssh/authorized_keys <<'EOF'
# Add your SSH public keys here
# Format: ssh-rsa AAAAB3NzaC1yc2E... yourname@yourhost
EOF
RUN chown otter-pup:otter-pup /home/otter-pup/.ssh/authorized_keys && \
    chmod 600 /home/otter-pup/.ssh/authorized_keys

# ===== 阶段 7: 全局安装 AI 开发工具与 uv =====
RUN npm install -g @openai/codex @anthropic-ai/claude-code opencode-ai droid && \
    npm cache clean --force && \
    rm -rf /tmp/* /root/.npm /root/.node_modules

RUN curl -LsSf https://astral.sh/uv/install.sh | env UV_UNMANAGED_INSTALL="/usr/local/bin" sh && \
    uv --version && \
    rm -rf /tmp/* /root/.cache/*

# ===== 阶段 8: 环境变量与终端配置 =====
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    MAMBA_ROOT_PREFIX=/opt/conda \
    OTTER_HOME=/opt/otter \
    OTTER_CORE_PREFIX=/opt/conda/envs/otter-core \
    PATH=/opt/otter/bin:/opt/conda/envs/otter-core/bin:/home/otter-pup/go/bin:/home/otter-pup/.cargo/bin:/home/otter-pup/.local/bin:/opt/cargo/bin:/root/go/bin:$PATH \
    GOPATH=/home/otter-pup/go \
    CRYPTOGRAPHY_OPENSSL_NO_LEGACY=1 \
    JAVA_OPTS="-Djava.awt.headless=true" \
    LANG=C.UTF-8 \
    NODE_PATH=/home/otter-pup/.local/lib/node_modules:/root/.local/lib/node_modules \
    FACTORY_API_KEY=fk-uapnTYzc3bZ0zc5hWNmH-GebxIzVDVnbHQ8NGGEFuxoDNBmWYS2MxEkI5tgl3123

# 为 root 用户配置 .bashrc
RUN echo "export RUSTUP_HOME=/opt/rustup" >> /root/.bashrc && \
    echo "export CARGO_HOME=/opt/cargo" >> /root/.bashrc && \
    echo "export PATH=/opt/otter/bin:/opt/conda/envs/otter-core/bin:\$HOME/go/bin:\$HOME/.cargo/bin:\$HOME/.local/bin:/opt/cargo/bin:\$PATH" >> /root/.bashrc && \
    echo "export GOPATH=\$HOME/go" >> /root/.bashrc

# 为 otter-pup 用户配置 .bashrc
RUN echo "export RUSTUP_HOME=/opt/rustup" >> /home/otter-pup/.bashrc && \
    echo "export CARGO_HOME=/opt/cargo" >> /home/otter-pup/.bashrc && \
    echo "export PATH=/opt/otter/bin:/opt/conda/envs/otter-core/bin:\$HOME/go/bin:\$HOME/.cargo/bin:\$HOME/.local/bin:/opt/cargo/bin:\$PATH" >> /home/otter-pup/.bashrc && \
    echo "export GOPATH=\$HOME/go" >> /home/otter-pup/.bashrc && \
    chown otter-pup:otter-pup /home/otter-pup/.bashrc

# ===== 阶段 9: 启动服务脚本 =====
RUN cat > /usr/local/bin/start-services.sh <<'EOF'
#!/usr/bin/env bash
set -e

# 如果传入了自定义命令，直接执行自定义命令
if [ "$#" -gt 0 ]; then
    exec "$@"
fi

# 生成 SSH 主机密钥 (若缺失)
for key in rsa ecdsa ed25519; do
    if [ ! -f /etc/ssh/ssh_host_${key}_key ]; then
        if [ "$EUID" -eq 0 ]; then
            ssh-keygen -t $key -f /etc/ssh/ssh_host_${key}_key -N "" -q
        else
            sudo ssh-keygen -t $key -f /etc/ssh/ssh_host_${key}_key -N "" -q
        fi
    fi
done

echo "--- 启动 SSH 服务 ---"
if [ "$EUID" -eq 0 ]; then
    /usr/sbin/sshd -D &
    SSH_PID=$!
else
    sudo /usr/sbin/sshd -D &
    SSH_PID=$!
fi

echo "--- Holt 运行环境服务已就绪 ---"
echo "SSH 访问: ssh otter-pup@localhost -p 2222 (默认密码: otter-pup)"
echo ""
echo "内置工具集:"
echo "  Otter 全套工具: otter, enva, craftmake, xenofilx, pairbam, seq2mat, methx, qctb, fastqcx, matsrun"
echo "  Otter-Core 运行环境: /opt/conda/envs/otter-core (核心生信工具已集成至 PATH)"
echo "  AI 编程助手: claude-code, uv, codex"
echo ""
echo "JupyterLab 按需手动启动命令："
echo "  su - otter-pup -c 'jupyter-lab --no-browser --allow-root --ip=* --port=8889 &'"
echo ""
echo "用户管理工具："
echo "  sudo add-user"

# 等待 SSH 服务退出
trap 'sudo kill -9 $SSH_PID 2>/dev/null || kill -9 $SSH_PID 2>/dev/null' TERM INT QUIT
wait $SSH_PID
EOF

RUN chmod +x /usr/local/bin/start-services.sh

# ===== 阶段 10: 清理与暴露端口 =====
RUN pacman -Sc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/* \
           /tmp/* \
           /root/.cache/*

EXPOSE 2222 8889 8080 8787

# ===== 默认用户与入口 =====
USER otter-pup
WORKDIR /home/otter-pup

ENTRYPOINT ["/usr/local/bin/start-services.sh"]

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD ssh -q otter-pup@localhost -p 2222 exit || exit 1
