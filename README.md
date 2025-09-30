# Claude Configuration

个人 Claude Code 配置文件同步仓库。

## 包含文件

- `settings.json` - 全局设置（模型选择、思考模式等）
- `settings.local.json` - 本地权限设置
- `output-styles/` - 自定义输出风格
- `.gitignore` - Git忽略规则

## 使用方法

### 在新机器上克隆配置

```bash
# 备份现有配置（如果存在）
mv ~/.claude ~/.claude.backup

# 克隆配置仓库
git clone <your-github-repo-url> ~/.claude

# 重新安装 Claude Code（如果需要）
npm install -g @anthropic-ai/claude-code
```

### 更新配置

```bash
cd ~/.claude
git add .
git commit -m "更新配置"
git push
```

### 同步配置

```bash
cd ~/.claude
git pull
```

## 注意事项

- `history.jsonl` 和其他临时文件不会被同步
- 每台机器的 `local/` 目录是独立的
- 项目特定的配置存储在 `projects/` 目录，不会被同步