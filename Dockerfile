# ---------- 构建阶段 ----------
FROM rust:1.70 as builder

WORKDIR /usr/src/tuic

# 安装 musl 工具链，用于静态编译
RUN rustup target add x86_64-unknown-linux-musl \
 && apt-get update && apt-get install -y musl-tools pkg-config libssl-dev

# 复制 Cargo 配置
COPY Cargo.toml Cargo.lock ./

# 准备依赖缓存
RUN mkdir -p src/tuic-server && echo "fn main() {}" > src/tuic-server/main.rs

# 先构建依赖，利用缓存
RUN cargo build --release --target x86_64-unknown-linux-musl --bin tuic-server || true

# 删除临时 src
RUN rm -rf src

# 复制完整源码
COPY . .

# 正式构建 server
RUN cargo build --release --target x86_64-unknown-linux-musl --bin tuic-server

# ---------- 运行阶段 ----------
FROM scratch

WORKDIR /app

# 拷贝 ca-certificates（部分 TLS 需要）
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# 拷贝静态编译后的二进制
COPY --from=builder /usr/src/tuic/target/x86_64-unknown-linux-musl/release/tuic-server /tuic-server

ENTRYPOINT ["/tuic-server"]
CMD ["-c", "/config/config.json"]
