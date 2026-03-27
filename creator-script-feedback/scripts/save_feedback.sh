#!/bin/bash
# 保存达人脚本反馈到Obsidian

# 参数检查
if [ $# -lt 3 ]; then
    echo "Usage: $0 <creator_name> <script_topic> <feedback_content>"
    echo "Example: $0 卡尔 '文科生学AI第五弹' '反馈内容...'"
    exit 1
fi

CREATOR_NAME="$1"
SCRIPT_TOPIC="$2"
FEEDBACK_CONTENT="$3"
DATE=$(date +%Y-%m-%d)

# Obsidian路径
OBSIDIAN_PATH="$HOME/Documents/Obsidian Vault/B.达人运营"

# 创建目录（如果不存在）
mkdir -p "$OBSIDIAN_PATH"

# 文件名
FILENAME="${CREATOR_NAME}-脚本反馈-${DATE}-${SCRIPT_TOPIC}.md"
FILEPATH="$OBSIDIAN_PATH/$FILENAME"

# 写入文件
cat > "$FILEPATH" << EOF
# ${CREATOR_NAME} 脚本反馈 - ${SCRIPT_TOPIC}

**日期**：${DATE}
**脚本来源**：[待填写]
**反馈人**：AI助手

---

${FEEDBACK_CONTENT}

---

## 后续跟进
- [ ] 达人确认修改方向
- [ ] 二稿反馈
- [ ] 定稿
EOF

echo "反馈已保存到: $FILEPATH"
