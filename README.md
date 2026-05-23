# cgss-patcher

用于 iOS CGSS（`jp.co.bandainamcoent.BNEI0242`）的注入补丁。

## 功能

1. 拦截并改写 CGSS 请求 URL 的 Host。
2. 支持配置 API 地址（默认：`apis.game.starlight-stage.jp/`）。
3. 支持配置资源地址（默认：`asset-starlight-stage.akamaized.net/`）。
4. 设置项支持国际化（English / 简体中文）。

## 设置规则

设置页中有两个输入项：

1. `API Endpoint`
2. `Asset Endpoint`

输入规则：

1. 仅填写主机名/域名（不要带 `http://` 或 `https://`）。
2. 如果输入了前缀，会自动去掉。
3. 如果结尾缺少 `/`，会自动补上。
4. 留空会恢复官方默认值。

## 本地构建

依赖：Theos（含 iOS SDK）。

```bash
# 安装 Theos（官方脚本）
bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"

# 编译
make clean
make
```

编译后可在 `.theos` 或 `obj` 目录下找到 `*.dylib`。

## 注入到 IPA（insert_dylib）

```bash
# 1) 解包 ipa
mkdir -p work
cp app.ipa work/app.zip
cd work
unzip app.zip

# 2) 复制注入文件
cp /path/to/cgss-patcher.dylib Payload/BNEI0242.app/
cp -R /path/to/Settings.bundle Payload/BNEI0242.app/Settings.bundle

# 3) 注入 dylib
insert_dylib \
  --all-yes \
  --strip-codesig \
  @executable_path/cgss-patcher.dylib \
  Payload/BNEI0242.app/BNEI0242 \
  Payload/BNEI0242.app/BNEI0242

# 4) 回包
zip -r patched.ipa Payload
```

1. 注入后需要重签名（主程序 + dylib + 整个 app）。
2. `Settings.bundle` 路径必须是 `Payload/BNEI0242.app/Settings.bundle`。
3. `cgss-patcher.plist` 主要用于越狱注入场景，IPA 直注通常不依赖。

## CI

GitHub Actions 在每次 push / pull request 时自动执行编译测试，并上传 artifact：

1. `*.dylib`
2. `cgss-patcher.plist`
3. `Settings.bundle`
